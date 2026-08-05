# Replication Testing Reference

Testing Vault replication requires Enterprise features. Use the provided helpers to spin up replicated clusters easily.

## Quick Start

Pick your topology, call one function, use the accessors. Done.

## Topologies

### Perf Primary + Perf Secondary (2 replication groups)

```go
conf, opts := teststorage.ClusterSetup(nil, nil, teststorage.InmemBackendSetup)
clusters := testhelpers.GetPerfReplicatedClusters(t, conf, opts)
defer clusters.Cleanup()

_, _, primaryClient   := clusters.Primary()
_, _, secondaryClient := clusters.Secondary()
```

### Perf Primary + DR Secondary (2 replication groups)

```go
conf, opts := teststorage.ClusterSetup(nil, nil, teststorage.InmemBackendSetup)
clusters := testhelpers.GetDRReplicatedClusters(t, conf, opts)
defer clusters.Cleanup()

_, _, primaryClient := clusters.Primary()
_, _, drClient      := clusters.PrimaryDR()
```

### Full 4-Group Topology (perf + both DRs)

```go
conf, opts := teststorage.ClusterSetup(&vault.CoreConfig{
    DisableAutopilot: true,
}, &vault.TestClusterOptions{
    HandlerFunc: vaulthttp.Handler,
}, teststorage.InmemBackendSetup)

clusters := testhelpers.GetFourReplicatedClustersWithConf(t, conf, opts)
defer clusters.Cleanup()

_, _, primaryClient     := clusters.Primary()
_, _, secondaryClient   := clusters.Secondary()
_, _, primaryDRClient   := clusters.PrimaryDR()
_, _, secondaryDRClient := clusters.SecondaryDR()
```

### Multiple HA Nodes per Replication Group

Set `NumCores` before passing `opts`:

```go
opts.NumCores = 3  // active + 2 standbys in each group
```

## Rules

1. **Only use the `*api.Client` from the accessors.** Never touch `.Core` directly.
2. **Always `defer clusters.Cleanup()` immediately after creation.**
3. **Use `testhelpers.EnsureCoresUnsealed(t, clusters.PerfPrimaryCluster)` if you unseal/reseal in the test.**
4. **Add `//go:build ent` at the top of any file using these helpers.**

---

## Common Replication Test Operations

### Wait for Sync / Convergence

| Operation | Helper | How to Assert Correctly | Gaps |
|---|---|---|---|
| Wait for WAL index | `testhelpers.WaitForWAL(t, core, walIndex)` | Blocks until `core.EntLastWAL() >= walIndex` | After DR promotion, re-verify threshold WAL was reached on new primary before reading data |
| Perf/DR WAL drain | `WaitForPerformanceWAL(t, clusters)` / `WaitForDRWAL(t, clusters)` | Poll until secondary WAL ≥ primary WAL | No assertion that data written before the wait is actually readable on secondary after |
| Merkle roots match | `WaitForMatchingMerkleRoots(t, endpoint, pri, sec)` / `WaitForMatchingMerkleRootsCore` | Compare `status.Data["dr"]["merkle_root"] == drStatus.Data["merkle_root"]` directly | Not just "equal eventually" — assert exact root values from both sides in the same snapshot |
| Perf replication working | `WaitForPerfReplicationWorking(t, pri, sec)` | Writes a probe KV key on primary, reads non-nil on secondary | Assert the read value matches the written value; probe key is deleted but not value-checked |
| Perf replication working (by path) | `WaitForPerfReplicationWorkingWithMount(t, pri, sec, mount)` | Same as above, scoped to a specific mount | Same value-check gap as above |
| Perf replication working (clients) | `WaitForPerfReplicationWorkingClients(ctx, priClient, secClient, mount)` | Polls `secClient.Logical().Read(path)` until non-nil | Does not assert response value matches what was written |
| DR replication working | `WaitForDRReplicationWorking(t, pri, sec)` | Waits for `state == StreamWALs` and `last_remote_wal > 0` | No assertion that actual data (beyond token events) is visible on DR secondary |
| Replication connection status | `WaitForPerfReplicationConnectionStatus(t, secClient)` | Polls until `connection_status == "connected"` | Also assert `last_heartbeat` is recent (non-zero, within 30s) |
| Active node + perf standbys | `WaitForActiveNodeAndPerfStandbys(t, cluster)` | Waits until active and standbys are ready | Assert each standby returns `health.PerformanceStandby == true` via `EnsureCoreIsPerfStandby` |
| Replication state enum | `WaitForReplicationState(t, core, state)` | Polls `core.ReplicationState().HasState(state)` | No timeout surfacing — failure message does not include observed state |
| Wait for arbitrary status predicate | `WaitForReplicationStatus(t, client, isDR, pred)` | Predicate receives `status.Data["dr"/"performance"]` map | Tests often check only `mode`; `last_wal`, `last_remote_wal`, `state` frequently unchecked |

---

### Simulate Node/Primary Failure

| Operation | Helper | How to Assert Correctly | Gaps |
|---|---|---|---|
| Stop a node | `cluster.StopCore(t, nodeIndex)` | Call `WaitForActiveNode(t, cluster)` to verify another node activated | Assert stopped node's client returns errors (unhealthy/sealed), not just that a new active exists |
| Seal all nodes | `testhelpers.SealCores(t, cluster)` | Before DR promotion: assert `health.Sealed == true` on all old-primary nodes | No assertion that writes to the old primary during sealed state return appropriate errors |
| Unseal all nodes | `testhelpers.EnsureCoresUnsealed(t, cluster)` | Assert `health.Sealed == false` and `health.Initialized == true` on each node | No re-check of replication state post-unseal |
| Inject replication failure mode | `vault.SetReplicationFailureMode(core, vault.ReplicationFailureModeReindexNeeded)` | Assert `sys/replication/status` surfaces a warning; then assert promote/demote succeeds or fails as intended | Tests check the result of `promote` but do not verify the failure mode appears in status warnings before the operation |

---

### DR Failover & Failback

| Operation | Helper | How to Assert Correctly | Gaps |
|---|---|---|---|
| Promote DR secondary | `testhelpers.PromoteDRSecondary(t, drCluster)` | `GetRepStatusUntil(ctx, t, drClient, isDR=true, mode=="primary")` | Also assert `known_secondaries == []` immediately after promotion |
| Update DR secondary primary | `testhelpers.UpdatePrimaryDRSecondary(t, cluster, token, caFile)` | `GetRepStatus(t, client, isDR=true)["mode"] == "secondary"` and `["secondary_id"] == expectedID` | Also assert old primary shows the new secondary in its `known_secondaries` |
| Demote DR primary | `client.Logical().Write("sys/replication/dr/primary/demote", ...)` | `WaitForReplicationStatus(client, isDR=true, mode=="secondary")` | No check that the demoted node's perf replication also stops |
| Full DR failback (A→B→A) | `SealCores` → `PromoteDRSecondary` → `EnsureCoresUnsealed` → `demote` → `UpdatePrimaryDRSecondary` | Final: both DR and perf `known_secondaries` match expected IDs; `mode == "primary"` on restored node | Data written during B-is-primary window is never verified to survive the failback to A |
| Write DR operation | `testhelpers.WriteDROperation(t, client, path, token)` | Assert `resp != nil`; `GetRepStatus` after to confirm state change took effect | Return value contents are not verified, only non-nil |
| Create DR op batch token | `testhelpers.CreatePathBatchToken(t, client, path)` | Assert the token is non-empty and has correct policy via a test read/write against the path | Token is used directly without verifying its capability scope |
| No replication loop after failover | `vault.TestClusterCoreGetReplFSM(activeCore).State()` | `state == StreamWALs`; subscribe `changeCh`, assert no state change for 5s | FSM loop check is not consistently applied on both the promote *and* the failback path |
| Perf secondary reconnects after DR failover | `EnablePerformanceSecondaryNoWait(t, token, newPri, sec, updatePrimary=true)` | `GetRepStatusUntil(secClient, perf, mode=="secondary" && primary_cluster_addr == newClusterAddr)` | `WaitForPerfReplicationWorking(newPrimary, perfSec)` is missing after reconnect in several tests |

---

### Perf Replication Topology Changes

| Operation | Helper | How to Assert Correctly | Gaps |
|---|---|---|---|
| Revoke perf secondary | `clusters.RevokePerfReplicationSecondary(t)` | Assert secondary no longer in primary's `known_secondaries`; secondary mode becomes `"disabled"` | No assertion that writes to the secondary after revocation return errors |
| Disable perf secondary | `clusters.DisablePerfReplicationSecondary(t)` | `WaitForReplicationStatus(secClient, DR=false, mode=="disabled")` | No assertion that previously replicated data is still locally readable after disable |
| Promote perf secondary | `client.Logical().Write("sys/replication/performance/secondary/promote", ...)` | `GetRepStatusUntil(secClient, perf, mode=="primary")` and `known_secondaries == []` | Missing: verify old primary can no longer reach this node as a secondary |
| Reconnect secondary to new primary | `EnablePerformanceSecondary(t, token, newPri, sec, updatePrimary=true, ...)` | `WaitForPerfReplicationWorking(newPri, sec)` | Use `api.RequireState(priorState)` on secondary client to guarantee reads reflect pre-reconnect writes |

---

### Assert Replication Health & State

| Operation | Helper | How to Assert Correctly | Gaps |
|---|---|---|---|
| Check replication health (health endpoint) | `testhelpers.CheckRepHealth(t, client, coreIdx, clusterName, perfMode, drMode)` | Checks `ReplicationPerformanceMode` and `ReplicationDRMode` | Does not assert `Sealed`, `Standby`, or `Initialized` — a sealed node can return stale mode strings |
| Get raw replication status | `testhelpers.GetRepStatus(t, client, isDR)` | Assert `mode`, `known_secondaries`, `secondary_id`, `primary_cluster_addr` | `last_wal`, `last_remote_wal`, `state` frequently unchecked |
| Poll replication status with predicate | `testhelpers.GetRepStatusUntil(ctx, t, client, isDR, pred)` | Context timeout surfaces last observed status | Predicates usually only check `mode`; should also validate WAL and connection fields |
| Replication status secondaries list | `compareReplicationStatusSecondaries(t, secondaries, knownSecondaries)` | Asserts `len` equal and `[0].NodeID` matches | Only checks index 0; does not assert full list or ordering |
| Replication metrics correctness | Retry loop over `testhelpers.SysMetricsReq`; check gauge values per cluster role | Roles held: gauge `== 1`; roles not held: gauge `== 0` | No assertion that metrics reset after role change (e.g. after DR promotion, old primary's `dr.primary` gauge does not drop to 0) |
| Raft voter configuration | `testhelpers.VerifyRaftVoters(t, client, expected map[nodeID]isVoter)` | Full voter map comparison via `cmp.Diff` | Should be called after every topology change but is often omitted |

---

### Simulate Replication Lag / Network Conditions

| Operation | Helper | How to Assert Correctly | Gaps |
|---|---|---|---|
| Latency injection | `latencyInjector.SetLatency(d)` on `physical.TransactionalLatencyInjector` | `getReplicationLag(client) >= injectedLatency` after injection; `< 1s` before, via `RetryUntil` | No assertion that operations still succeed under latency; no assertion on error rates |
| Block Raft FSM applies | `testhelpers.BlockRaftAppliesUntil412Seen(tc, &retryCounter)` | Assert `retryCounter > 0` after the operation; always `defer cleanup()` | No assertion on data outcome after unblocking; the write may have been lost |
| Replication canary lag | `client.Sys().ReplicationPerformanceStatusWithContext(ctx).Secondaries[0].ReplicationPrimaryCanaryAgeMillis` | Assert `< threshold` before injection; `>= injectedLatency` after, via `RetryUntil` | No assertion that canary age resets after latency is removed |
| WAL wait duration config | `testhelpers.ReplicationConfig(waitDuration)` combined with `WaitForDRWAL` | Assert secondary WAL catches up within the configured window | Missing: assert no data visible on secondary before WAL catches up |

---

### Storage/Mount Operations That Test Replication Propagation

| Operation | Helper / API | How to Assert Correctly | Gaps |
|---|---|---|---|
| Write on primary, read on secondary | `WaitForPerfReplicationWorking` / `WaitForPerfReplicationWorkingClients` | Write probe key; read on secondary and assert non-nil | Assert the *value* matches: `require.Equal(t, expected, secret.Data["bar"])`; current tests only check non-nil |
| Replication causality | `api.RecordState(&state)` on write; `api.RequireState(state)` on secondary read | Secondary read guaranteed to see the write via X-Vault-Index header enforcement | Not used consistently — most tests rely on `time.Sleep`, making them timing-sensitive |
| Mount replication | `testhelpers.IsMounted(t, secClient, ns, mount)` | Assert `true` on secondary after mount on primary | Assert the mount is *absent* before replication settles to catch false positives |
| Cross-namespace remount | `client.Sys().Remount(oldPath, newPath)` | Read data at new path on secondary; assert accessible at new path and gone from old path | Tests only assert the API call succeeds; secondary read at both old and new paths is missing |
| Manual reindex | `client.Logical().Write("sys/replication/reindex", ...)` | Wait for `"verified reindex"` log message; then re-check Merkle roots match | Fragile log-string matching; no assertion that data integrity holds post-reindex |
| Local-path data after DR failover | Mount with `Local: true` or `PassthroughWithLocalPathsFactory`, then promote DR | Assert local-path data is *absent* on DR secondary after promotion — it must never replicate | Entirely absent in current tests; local data on primary is never verified to be missing on DR secondary |

---

## Cache Invalidation on Secondaries

Understanding how cache invalidation works is essential for writing correct replication tests.

### The Two Invalidation Paths

#### 1. Sync Invalidation (`syncInvalidate`) — Critical Tables

Triggered directly by the replication FSM as each WAL entry is applied. **Synchronous and blocking** — the FSM apply does not return until invalidation completes.

| Path Key | What Gets Invalidated |
|---|---|
| `coreMountConfigPath` | Mount table (add/remove/tune mounts) |
| `coreAuthConfigPath` | Auth method table |
| `coreAuditConfigPath` | Audit device table |
| `namespaceConfigPath` | Namespace table |
| `pluginCatalogPath` | Plugin catalog |
| `coreKeyringCanaryPath` | Keyring / rekey |
| `apiLockStateFullPath` | API lock state |
| `coreReplicatedSecondaryFilteredPathsPath` | Filtered paths (perf secondaries only) |

#### 2. Async Invalidation (`asyncInvalidateKey`) — Everything Else

The replication FSM drops the storage path onto `invalidationCh` (buffered channel, size `AsyncInvalidationChannelSize = 256`). A background goroutine drains it:

```
Primary write → WAL entry → replicated to secondary FSM
→ secondary FSM applies entry to storage
→ storage path sent to invalidationCh
→ asyncInvalidateHandler goroutine picks it up
→ asyncInvalidateKey resolves path → backend via router
→ backend.InvalidateKey(ctx, backendPathSuffix)
```

---

## Cache Invalidation Test Patterns

### Pattern 1: `require.Eventually` Poll (Most Common)

Write on primary, poll secondary until new value appears:

```go
// Write on primary
_, err := primaryClient.Logical().Write("sys/config/my-feature", data)
require.NoError(t, err)

// Poll secondary until cache is invalidated and new value is visible
require.Eventually(t, func() bool {
    secret, err := secondaryClient.Logical().Read("sys/config/my-feature")
    if err != nil || secret == nil || secret.Data == nil {
        return false
    }
    return secret.Data["field"] == expectedValue
}, 30*time.Second, 500*time.Millisecond, "update should replicate to secondary")
```

**When to use**: Default for cross-cluster (perf/DR) invalidation tests.

### Pattern 2: `api.RecordState` + `api.RequireState` (Causal Consistency)

Captures WAL index from primary write, enforces it on secondary read. Secondary returns HTTP 412 if WAL hasn't caught up:

```go
var state string
primaryClient.WithResponseCallbacks(api.RecordState(&state)).Logical().Write(path, data)

// Secondary read blocked (412) until WAL index >= state
secondaryClient.WithRequestCallbacks(api.RequireState(state)).Logical().Read(path)
```

To verify 412 actually fired (invalidation was async):

```go
var retryCount atomic.Int32
cleanup := testhelpers.BlockRaftAppliesUntil412Seen(secondary.Cores[1], &retryCount)
defer cleanup()
// ... do write + RequireState read ...
require.Greater(t, retryCount.Load(), int32(0), "secondary was behind, should have retried")
```

**When to use**: Within a single cluster (perf standbys); proves causal ordering.

**Note**: Does not work cross-cluster — only within a single cluster's perf standbys.

### Pattern 3: Force Synchronous Invalidation (Deterministic Tests)

Set `AsyncInvalidationChannelSize = 0` to force FSM to block until invalidation completes:

```go
oldSize := vault.AsyncInvalidationChannelSize
vault.AsyncInvalidationChannelSize = 0
defer func() { vault.AsyncInvalidationChannelSize = oldSize }()

// Now writes and secondary reads are synchronous — no Eventually needed
```

**When to use**: When deterministic tests without timing sensitivity are required.

### Summary

| Pattern | Mechanism | Use Case |
|---|---|---|
| `require.Eventually` poll | Retry read until value matches | Cross-cluster (perf/DR) invalidation |
| `RecordState` + `RequireState` | WAL-index via X-Vault-Index header; 412 retry | Single cluster perf standbys; causal ordering |
| `AsyncInvalidationChannelSize = 0` | Force async → sync | Deterministic tests without timing sensitivity |
