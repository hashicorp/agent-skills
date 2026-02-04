---
name: vault-production-operations
description: Comprehensive guidance on running Vault in production including HA, DR, monitoring, backup, and security hardening
---

# Vault Production Operations

This reference provides comprehensive guidance for operating Vault in production environments, including monitoring, backup/recovery, upgrades, and operational best practices.

---

## Monitoring

### Telemetry Configuration

```hcl
# vault.hcl
telemetry {
  statsd_address           = "statsd.example.com:8125"
  prometheus_retention_time = "30s"
  disable_hostname         = true
  
  # Additional metrics
  usage_gauge_period       = "10m"
  maximum_gauge_cardinality = 500
}
```

### Critical Metrics (Alert Immediately)

| Metric | Threshold | Impact | Action |
| -------- | ----------- | -------- | -------- |
| `vault.audit.log_request_failure` | > 0 | **CRITICAL** - Vault stops if all audit devices fail | Check audit device health immediately |
| `vault.audit.log_response_failure` | > 0 | **CRITICAL** - Same as above | Check audit device health immediately |
| `vault.core.unsealed` | = 0 | Node is sealed | Investigate cause, unseal if appropriate |
| `vault.autopilot.healthy` | = 0 | Cluster health issue | Check node status, leadership |

### Leadership & Consensus Metrics

| Metric | Threshold | Meaning | Action |
| -------- | ----------- | --------- | -------- |
| `vault.raft.leader.lastContact` | > 200ms | Consensus unhealthy | Check network latency, storage I/O |
| `vault.raft.state.candidate` | > 0 | Elections occurring | Investigate stability issues |
| `vault.raft.state.leader` | Frequent changes | Leadership instability | Check node health, network |
| `vault.core.leadership_lost` | Any occurrence | Leadership transition | Verify new leader, check cause |

### Performance Metrics

| Metric | Threshold | Meaning | Action |
| -------- | ----------- | --------- | -------- |
| `vault.core.handle_request` | > 50% deviation | Request latency issue | Check storage, resources |
| `vault.core.handle_login_request` | > 50% deviation or 3σ | Auth latency issue | Check auth backend, network |
| `vault.barrier.get` | > 50% deviation | Storage read issue | Check storage backend |
| `vault.barrier.put` | > 50% deviation | Storage write issue | Check storage backend |
| `vault.runtime.gc_pause_ns` | > 2s/min (warn), > 5s/min (crit) | Memory pressure | Increase memory, check leaks |

### WAL & Replication Metrics

| Metric | Threshold | Meaning | Action |
| -------- | ----------- | --------- | -------- |
| `vault.wal.flushReady` | > 500ms | Replication backpressure | Check secondary clusters |
| `vault.wal.persistWALs` | > 1000ms | WAL persistence issues | Check storage performance |
| `vault.merkle.diff` | Large values | Replication sync issues | Check network, secondary health |
| `vault.replication.merkleSync` | Prolonged activity | Initial or catch-up sync | Monitor until complete |

### Resource Metrics

| Metric | Threshold | Meaning | Action |
| -------- | ----------- | --------- | -------- |
| `cpu.iowait_cpu` | > 10% | I/O bottleneck | Upgrade storage, check disk health |
| `mem.used_percent` | > 90% | Memory pressure | Increase memory, check for leaks |
| `swap.used_percent` | > 0% | Swap should be disabled | Disable swap (`swapoff -a`) |
| `linux_sysctl_fs.file-nr` | > 80% of file-max | File descriptor exhaustion | Increase limits, check for leaks |

### Token & Lease Metrics

| Metric | Threshold | Meaning | Action |
| -------- | ----------- | --------- | -------- |
| `vault.expire.num_leases` | Unexpected large delta | Runaway application | Investigate source, implement quotas |
| `vault.token.create_root` | Any increment | Security alert | Verify authorized ceremony |
| `vault.core.license.expiration_time_epoch` | < 30 days | License expiring | Renew license |

### Privileged Endpoints to Monitor

Configure audit log alerts for access to these `/sys` endpoints:

```bash
# Example: Alert on privileged endpoint access
grep -E "/sys/(generate-root|rekey|replication|audit|rotate|polic)" audit.log
```

| Endpoint | Risk | Alert Priority |
| ---------- | ------ | ---------------- |
| `/sys/generate-root` | Root token generation | Critical |
| `/sys/rekey` | Seal key regeneration | Critical |
| `/sys/rekey-recovery-keys` | Recovery key regeneration | Critical |
| `/sys/replication` | Replication changes | High |
| `/sys/audit` | Audit device modifications | Critical |
| `/sys/rotate` | Master key rotation | Critical |
| `/sys/policy`, `/sys/policies` | Policy modifications | High |

---

## Audit Logging

### Multiple Audit Devices (Required)

> **Critical**: Vault stops ALL operations if it cannot write to at least one audit device.

```bash
# Enable file audit device (local fallback)
vault audit enable file file_path=/var/log/vault/audit.log

# Enable socket device for centralized logging
vault audit enable socket address="127.0.0.1:9090" socket_type="tcp"

# Enable syslog for remote logging
vault audit enable syslog tag="vault" facility="AUTH"

# Verify audit devices
vault audit list -detailed
```

### Audit Log Configuration

```bash
# File audit with HMAC disabled for debugging (NOT recommended for production)
vault audit enable file \
    file_path=/var/log/vault/audit.log \
    log_raw=false \
    hmac_accessor=true

# Socket audit with fallback
vault audit enable socket \
    address="splunk-hec.example.com:8088" \
    socket_type="tcp" \
    write_timeout="30s"
```

### Log Rotation

```bash
# /etc/logrotate.d/vault
/var/log/vault/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0600 vault vault
    postrotate
        # Vault automatically re-opens log files
        /bin/true
    endscript
}
```

### Dedicated Audit Log Volume

```bash
# Separate partition prevents audit logs from filling system disk
# /etc/fstab entry:
# /dev/xvdf1 /var/log/vault ext4 defaults,noatime 0 2

# Size recommendation: 2x expected failure resolution time worth of logs
# At 1MB/min, for 4-hour resolution window: minimum 500MB
```

---

## Backup & Recovery

### Automated Raft Snapshots

```bash
# Take manual snapshot
vault operator raft snapshot save backup-$(date +%Y%m%d-%H%M%S).snap

# Verify snapshot
vault operator raft snapshot inspect backup.snap

# Restore from snapshot (requires sealed Vault)
vault operator raft snapshot restore backup.snap
```

### Automated Snapshot Configuration (Vault 1.12+)

```hcl
# vault.hcl
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"
  
  autopilot {
    cleanup_dead_servers         = true
    last_contact_threshold       = "200ms"
    dead_server_last_contact_threshold = "24h"
    server_stabilization_time    = "10s"
  }
}

# API configuration for automated snapshots
# POST /v1/sys/storage/raft/snapshot-auto/config/hourly
```

```bash
# Configure automated snapshots via API
vault write sys/storage/raft/snapshot-auto/config/hourly \
    interval="1h" \
    retain=168 \
    path_prefix="vault-backup" \
    storage_type="aws-s3" \
    aws_s3_bucket="vault-snapshots" \
    aws_s3_region="us-east-1" \
    aws_s3_kms_key="alias/vault-backups"

# Verify configuration
vault read sys/storage/raft/snapshot-auto/config/hourly

# Check snapshot status
vault read sys/storage/raft/snapshot-auto/status/hourly
```

### Snapshot Best Practices

| Requirement | Implementation |
| ------------- | ---------------- |
| Frequency | Match RPO (typically hourly) |
| Storage | Off-host, geo-redundant (S3, GCS) |
| Encryption | KMS encryption at rest |
| Take from DR | Backup from DR cluster to avoid loading primary |
| Test restores | Quarterly restore testing |
| Retention | 7-30 days typical |
| Verification | `vault operator raft snapshot inspect` |

### What NOT to Use for Backup

> **Never use VM/SAN snapshots** - Raft consistency requirements mean these can cause data corruption on restore.

| Backup Method | Supported? | Notes |
| --------------- | ------------ | ------- |
| Vault Raft snapshots | ✅ Yes | Recommended |
| Consul snapshots | ✅ Yes | For Consul storage backend |
| VM snapshots | ❌ No | Causes Raft consistency issues |
| SAN/Volume snapshots | ❌ No | Same issue |
| File system copy | ❌ No | Data corruption risk |

---

## Disaster Recovery

### DR Failover Procedure

```bash
# 1. Verify DR secondary is caught up
vault read sys/replication/dr/status

# 2. Generate DR operation token (should be pre-created for emergencies)
vault operator generate-root -dr-token -init
# Provide recovery keys until threshold met
vault operator generate-root -dr-token -otp=<otp>

# 3. Promote DR secondary to primary
vault write sys/replication/dr/secondary/promote \
    dr_operation_token=<token>

# 4. Update load balancer/DNS to point to new primary

# 5. Verify new primary is operational
vault status
vault read sys/replication/dr/status
```

### DR Failover Runbook Checklist

- [ ] Confirm primary is unavailable (not just network partition)
- [ ] Verify DR secondary replication status
- [ ] Notify stakeholders of failover
- [ ] Execute DR promotion
- [ ] Validate new primary functionality
- [ ] Update load balancer/DNS
- [ ] Configure new DR secondary
- [ ] Document incident

### Pre-created DR Tokens

For faster failover, pre-generate DR operation tokens:

```bash
# Generate and securely store DR operation token
vault write sys/replication/dr/secondary/generate-operation-token

# Store token securely (encrypted, separate from recovery keys)
```

### Migration Using Replication

**Performance Replication Migration Strategy:**

1. Set up new Performance Secondary in target environment
2. Set up new DR Secondary attached to new Perf Secondary
3. Validate replication status and data integrity
4. Switch load balancer to new Performance Secondary
5. Demote old Primary to secondary
6. Promote new Performance Secondary to Primary
7. Clean up old clusters

**Key Considerations:**

- Local mounts are NOT replicated (verify with `vault read sys/mounts`)
- Tokens and leases are NOT replicated - apps must re-authenticate
- **Never enable two primaries simultaneously**

---

## Upgrades

### Upgrade Strategy Matrix

| Upgrade Type | Method | Downtime |
| -------------- | -------- | ---------- |
| Patch (1.15.0 → 1.15.1) | Rolling upgrade | Zero |
| Minor (1.15.x → 1.16.x) | Rolling with Autopilot | Zero |
| Major (1.15.x → 1.17.x) | Blue-green via DR | Minimal |
| OSS → Enterprise | Binary swap | Minimal |

### Rolling Upgrade Procedure

```bash
# 1. Pre-upgrade checks
vault status
vault read sys/replication/status  # If using replication

# 2. Take snapshot
vault operator raft snapshot save pre-upgrade-$(date +%Y%m%d).snap

# 3. Upgrade followers first (one at a time)
# On each follower:
sudo systemctl stop vault
sudo cp /usr/bin/vault /usr/bin/vault.backup
sudo cp vault-new /usr/bin/vault
sudo systemctl start vault

# 4. Verify follower rejoins cluster
vault operator raft list-peers

# 5. After all followers upgraded, upgrade leader
# Leader will step down, election occurs
sudo systemctl stop vault
sudo cp vault-new /usr/bin/vault
sudo systemctl start vault

# 6. Verify cluster health
vault status
vault operator raft list-peers
```

### Blue-Green Upgrade via DR

```bash
# 1. Build new cluster with target version
# 2. Configure new cluster as DR secondary of old primary
vault write sys/replication/dr/secondary/enable token=<dr-token>

# 3. Wait for replication sync
vault read sys/replication/dr/status

# 4. Promote new cluster
vault write sys/replication/dr/secondary/promote dr_operation_token=<token>

# 5. Update load balancer to new cluster
# 6. Demote old cluster (optional, or just decommission)
```

### Upgrade Order for Replication

1. DR secondaries
2. Performance secondaries
3. Primary standbys
4. Primary leader

> **Never** replicate from newer version to older version.

### Pre-Upgrade Checklist

- [ ] Within N-2 of target version
- [ ] Review version-specific upgrade guide
- [ ] Take Raft snapshot
- [ ] Test in non-production first
- [ ] Document rollback procedure
- [ ] Schedule maintenance window
- [ ] Notify stakeholders

---

## Rate Limiting & Quotas

### Rate Limit Quotas

```bash
# Global rate limit (all paths)
vault write sys/quotas/rate-limit/global \
    rate=1000 \
    interval="1s"

# Path-specific rate limit
vault write sys/quotas/rate-limit/database \
    rate=100 \
    path="database/"

# Namespace rate limit
vault write sys/quotas/rate-limit/team-a \
    path="team-a/" \
    rate=500

# View quotas
vault list sys/quotas/rate-limit
vault read sys/quotas/rate-limit/global
```

### Lease Count Quotas

```bash
# Global lease limit
vault write sys/quotas/lease-count/global \
    max_leases=100000

# Per-path lease limit
vault write sys/quotas/lease-count/database \
    max_leases=10000 \
    path="database/"

# Per-namespace lease limit
vault write sys/quotas/lease-count/team-a \
    max_leases=5000 \
    path="team-a/"
```

### Quota Best Practices

| Quota Type | Recommended Starting Value | Adjust Based On |
| ------------ | --------------------------- | ----------------- |
| Global rate limit | 1000/s | Cluster capacity, client count |
| Database rate limit | 100/s | Connection pool size |
| PKI rate limit | 500/s | Certificate issuance patterns |
| Global lease count | 100,000 | Storage capacity |
| Per-app lease count | 5,000-10,000 | Application requirements |

---

## Load Balancer Configuration

### Health Check Endpoint

```text
/v1/sys/health?perfstandbyok=true&standbyok=true
```

### Response Codes

| Code | Meaning | Route Traffic? |
| ------ | --------- | ---------------- |
| 200 | Active, unsealed | Yes |
| 429 | Standby, unsealed | Yes (with standbyok) |
| 472 | DR secondary | No (unless failover) |
| 473 | Performance standby | Yes (with perfstandbyok) |
| 501 | Uninitialized | No |
| 503 | Sealed | No |

### Layer 4 vs Layer 7

| Requirement | Layer 4 (TCP) | Layer 7 (HTTP) |
| ------------- | --------------- | ---------------- |
| TLS Passthrough | ✅ Native | ❌ Requires re-encryption |
| TLS Certificate Auth | ✅ Works | ❌ Broken |
| Simplicity | ✅ Simple | ⚠️ Complex |
| Recommendation | **Preferred** | Only if required |

### Example Configurations

**AWS NLB (Layer 4):**

```hcl
# Terraform example
resource "aws_lb" "vault" {
  name               = "vault-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnets
}

resource "aws_lb_target_group" "vault" {
  name     = "vault-tg"
  port     = 8200
  protocol = "TCP"
  vpc_id   = var.vpc_id
  
  health_check {
    protocol            = "HTTPS"
    path                = "/v1/sys/health?perfstandbyok=true"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
```

---

## Operational Procedures

### Daily Operations

- [ ] Check cluster health: `vault status`
- [ ] Verify all nodes: `vault operator raft list-peers`
- [ ] Review audit log alerts
- [ ] Check replication lag (if applicable)

### Weekly Operations

- [ ] Review metrics dashboards
- [ ] Check certificate expirations
- [ ] Review failed authentication attempts
- [ ] Verify backup completion

### Monthly Operations

- [ ] Test backup restoration
- [ ] Review and rotate service tokens
- [ ] Audit policy assignments
- [ ] Check for Vault updates

### Quarterly Operations

- [ ] DR failover test
- [ ] Review and rotate recovery keys (if personnel changes)
- [ ] Security review of policies
- [ ] Capacity planning review

---

## Production Hardening Checklist

### System Level

- [ ] Disable swap: `swapoff -a`
- [ ] Disable core dumps: `ulimit -c 0`
- [ ] Set file descriptor limits: `ulimit -n 65536`
- [ ] Dedicated service account (not root)
- [ ] Immutable infrastructure (no SSH)
- [ ] CIS benchmarked base image

### Vault Configuration

- [ ] End-to-end TLS configured
- [ ] Multiple audit devices enabled
- [ ] Auto-unseal configured
- [ ] Root token revoked
- [ ] Recovery keys distributed (PGP encrypted)
- [ ] Rate limiting configured
- [ ] Lease quotas configured

### Monitoring & Alerting

- [ ] Telemetry enabled
- [ ] Critical metrics alerting configured
- [ ] Audit log monitoring enabled
- [ ] Certificate expiration monitoring
- [ ] License expiration monitoring

### Backup & DR

- [ ] Automated snapshots configured
- [ ] DR replication configured
- [ ] DR failover runbook documented
- [ ] Quarterly DR tests scheduled

---

## Additional Resources

- [Vault Production Hardening Guide](https://developer.hashicorp.com/vault/docs/concepts/production-hardening)
- [Vault Monitoring Guide](https://developer.hashicorp.com/vault/tutorials/monitoring)
- [Vault Telemetry Reference](https://developer.hashicorp.com/vault/docs/configuration/telemetry)
- [Integrated Storage Tutorial](https://developer.hashicorp.com/vault/tutorials/raft)

---

## Related

- [Enterprise](enterprise.md) - Replication and DR configuration
- [Troubleshooting](troubleshooting.md) - Operational issue resolution
- [Secrets Engines](secrets-engines.md) - Performance tuning for secrets
