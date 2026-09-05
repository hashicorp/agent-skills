---
name: vault-test-authoring
description: Design and write tests for HashiCorp Vault following best practices. Use when deciding what type of test to write (unit vs core), choosing cluster implementations (NewTestCluster vs NewCore), implementing API-based tests, or applying the DoTest pattern. Covers test structure, package organization, and blackbox testing guidelines.
compatibility: Requires Go 1.22+, access to Vault repository
---

# Vault Test Authoring

## Overview

This skill provides guidance on designing and structuring tests for Vault, helping you choose the right testing approach for different scenarios.

## Test Categories

### Unit Tests vs Core Tests

| Type | Description | When to Use |
|------|-------------|-------------|
| **Unit tests** | Tests that don't require a `vault.Core` | Pure logic, parsers, validators, utilities |
| **Core tests** | Tests using `vault.Core` (via clusters or direct) | Integration behavior, API endpoints, storage |

**Rule**: Prefer unit tests when possible. If you need a Core, consider refactoring the code out of package `vault/`.

### Core Test Types

| Implementation | Package | Use Case |
|----------------|---------|----------|
| `NewTestCluster` | `vault.NewTestCluster` | Default choice for core tests |
| `NewTestDockerCluster` | Docker containers | Cross-binary testing |
| `NewTestExecDevCluster` | Subprocesses | External process testing |

## Key Principles

### 1. Prefer Unit Tests

```go
// GOOD: Unit test with no Core dependency
func TestParseConfig(t *testing.T) {
    cfg, err := ParseConfig([]byte(`{"key": "value"}`))
    require.NoError(t, err)
    require.Equal(t, "value", cfg.Key)
}
```

**Benefits**:

- Fast compilation
- No non-determinism from Core internals
- Lower CI costs

### 2. Consider Both Unit AND Core Tests

Even with comprehensive unit tests, write a core test for integration assurance:

```go
// Unit test for quick iteration
func TestEntityValidation(t *testing.T) { /* ... */ }

// Core test for integration coverage
func TestEntityViaAPI(t *testing.T) { /* ... */ }
```

### 3. Use the API Exclusively

**Never access Core directly in core tests**. Use HTTP API only.

```go
// BAD: Direct Core access (whitebox testing)
func TestBad(t *testing.T) {
    cluster := vault.NewTestCluster(t, &conf, &opts)
    core := cluster.Cores[0].Core
    core.HandleRequest(ctx, req)  // ❌ Avoid
}

// GOOD: API-based testing (blackbox testing)
func TestGood(t *testing.T) {
    cluster := vault.NewTestCluster(t, &conf, &opts)
    client := cluster.Cores[0].Client
    _, err := client.Logical().Write("path/to/endpoint", data)  // ✓ Use API
}
```

**Why API-only?**

- Blackbox testing catches real integration issues
- Tests can run against Docker/exec clusters
- Dogfoods the API, revealing UX issues
- Enables future cloud testing

### 4. Avoid NewCore and Its Wrappers

**Do not use** these in `package vault`:

- `NewCore`
- `TestCoreWithSealAndUI`
- `TestCoreWithSeal`
- `TestCoreWithConfig`
- `TestCoreUnsealedWithConfig`

**Problems**:

- Only marginally faster than `NewTestCluster` with `NumCores=1`
- Less coverage (no auditing, networking, etc.)
- Creates duplication and wrapper proliferation
- Keeps tests in `package vault`, which should shrink

### 5. Use NewTestCluster as Default

Standard pattern:

```go
func TestFeature(t *testing.T) {
    conf, opts := teststorage.ClusterSetup(nil, nil, nil)
    cluster := vault.NewTestCluster(t, &conf, &opts)
    t.Cleanup(cluster.Cleanup)
    
    client := cluster.Cores[0].Client
    // Test using client API
}
```

**Note**: `cluster.Start()` is now a no-op and can be omitted.

### 6. Use Single-Node Clusters When Possible

If your test doesn't exercise performance standbys:

```go
// Explicit about single node
opts.NumCores = 1

// Or use the helper
cluster := minimal.NewTestSoloCluster(t)
```

This saves resources and makes test intent clear.

### 7. Avoid logs in tests that don't add value

The following log line do not add any extra information about a test and it's execution path or the state of the system under test.

```go
func DoTestJWTToken_CubbyholeIsolation(t *testing.T, cluster testcluster.VaultCluster) {
  // code here to test JWT Cubbyhole isolation...
  t.Log("JWT Token Cubbyhole Isolation passed successfully")
```

If required log important checkpoints and system state, errors of system in a test that aid in further debugging. Do not log errors that would anyway be logged in the test execution summary.

## The DoTest Pattern

Factor out cluster creation for maximum flexibility and compilation speed.

### Structure

```
vault/external_tests/$pkgname/
├── tests/
│   └── do_test_x.go      # DoTestX function (NOT _test.go)
├── cluster_test.go       # TestX using NewTestCluster
└── binary/
    └── docker_test.go    # TestX using NewTestDockerCluster
```

### Implementation

**Step 1**: Define the test logic (not in a `_test.go` file):

```go
// vault/external_tests/identity/tests/do_test_entity.go
package tests

import (
    "testing"
    "github.com/hashicorp/vault/sdk/helper/testcluster"
)

func DoTestEntityCreate(t *testing.T, cluster testcluster.VaultCluster) {
    client := cluster.Nodes()[0].APIClient()
    
    // Actual test using only API calls
    _, err := client.Logical().Write("identity/entity", map[string]interface{}{
        "name": "test-entity",
    })
    require.NoError(t, err)
}
```

**Step 2**: Call from cluster-specific test:

```go
// vault/external_tests/identity/cluster_test.go
package identity_test

func TestEntityCreate(t *testing.T) {
    conf, opts := teststorage.ClusterSetup(nil, nil, nil)
    cluster := vault.NewTestCluster(t, &conf, &opts)
    t.Cleanup(cluster.Cleanup)
    
    tests.DoTestEntityCreate(t, cluster)
}
```

**Step 3**: Optionally test with Docker:

```go
// vault/external_tests/identity/binary/docker_test.go
package binary

func TestEntityCreate(t *testing.T) {
    if os.Getenv("RUN_DOCKER_TESTS") == "" {
        t.Skip("Set RUN_DOCKER_TESTS to run")
    }
    
    cluster := testcluster.NewDockerCluster(t, opts)
    t.Cleanup(cluster.Cleanup)
    
    tests.DoTestEntityCreate(t, cluster)
}
```

### Benefits

- `DoTestX` compiles fast (no `vault/` import)
- Same test logic runs against multiple cluster types
- Tests live outside `package vault`

## Package Organization

### Avoid `package vault_test`

Using `vault_test` in files within `vault/` creates hidden complexity. Instead:

**Move tests to `external_tests/`**:

```
vault/external_tests/
├── identity/
├── quotas/
└── replication/
```

### Why External Tests?

1. Shrinks `package vault` (compilation speed)
2. Forces API-only testing
3. Clear separation of concerns

## Decision Tree

```
Need to test new code?
│
├─ Can test without Core?
│  └─ YES → Write unit test
│
├─ Need Core for integration?
│  │
│  ├─ Code lives in package vault?
│  │  └─ Consider refactoring out first
│  │
│  └─ Write core test:
│     ├─ Use NewTestCluster (not NewCore)
│     ├─ Use API only (not Core methods)
│     ├─ Place in external_tests/
│     └─ Consider DoTest pattern
│
└─ Testing both unit AND integration?
   └─ BEST APPROACH: Write both!
```

## Quick Reference

| Goal | Approach |
|------|----------|
| Test pure logic | Unit test, no Core |
| Test API behavior | `NewTestCluster` + API client |
| Test with real binary | `NewTestDockerCluster` |
| Reusable across clusters | DoTest pattern |
| Reduce `vault/` size | `external_tests/` + API-only |
| Single-node test | `NumCores: 1` or `NewTestSoloCluster` |

## Final Step: Format Code

**Always run `make fmt` as the last step** in any development or test authoring cycle:

```bash
make fmt
```

This ensures all Go files are properly formatted before committing or submitting a PR.

## Next Steps

- See [references/DOTEST_EXAMPLES.md](references/DOTEST_EXAMPLES.md) for complete DoTest examples
- See [references/CLUSTER_SETUP.md](references/CLUSTER_SETUP.md) for cluster configuration options
- See [references/REPLICATION_TESTING.md](references/REPLICATION_TESTING.md) for replication test setup (Enterprise)
