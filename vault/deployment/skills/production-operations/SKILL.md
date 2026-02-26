---
name: production-operations
description: Deploy and operate Vault in production. Use when asked about HA architecture, Integrated Storage (Raft), auto-unseal, DR replication, monitoring, metrics, backup/recovery, upgrades, or Enterprise features like namespaces and Sentinel.
---

# Vault Production Operations

## What Are You Trying to Solve?

### "I need Vault to be highly available"
→ Deploy a **3 or 5 node cluster** with Integrated Storage. [Jump to HA Architecture](#high-availability)

### "I don't want to manually unseal Vault after restarts"
→ Configure **auto-unseal** with cloud KMS. [Jump to Auto-Unseal](#auto-unseal-with-aws-kms)

### "I need Vault in multiple regions for performance"
→ Set up **Performance Replication** (Enterprise). [Jump to Enterprise Features](#enterprise-features)

### "I need a disaster recovery strategy"
→ Configure **DR Replication** or Raft snapshots. [Jump to Backup and Recovery](#backup-and-recovery)

### "I need to monitor Vault for issues"
→ Configure **Prometheus metrics** and alerts. [Jump to Monitoring](#monitoring)

---

## How Production Vault Works

1. **Cluster** → 3 or 5 nodes with one active leader, others standby
2. **Storage** → Integrated Storage (Raft) handles replication and consensus
3. **Seal/Unseal** → Auto-unseal with cloud KMS eliminates manual intervention
4. **Audit** → All operations logged to configured audit devices
5. **Monitor** → Prometheus scrapes metrics endpoint for alerting

---

## Architecture Overview

```
                    ┌─────────────┐
                    │ Load Balancer│
                    └──────┬──────┘
            ┌──────────────┼──────────────┐
            │              │              │
      ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
      │  Active   │  │  Standby  │  │  Standby  │
      │  (Leader) │  │           │  │           │
      └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
            │              │              │
            └──────────────┼──────────────┘
                           │
                    ┌──────▼──────┐
                    │ Raft Storage│
                    │ (Integrated)│
                    └─────────────┘
```

---

## Reference

- [Vault Operations Documentation](https://developer.hashicorp.com/vault/docs/internals)
- For complete HA patterns and seal configuration, see [references/production-operations.md](references/production-operations.md)
- For Enterprise-specific operations, see [references/enterprise.md](references/enterprise.md)

---

## Quick Reference

### Integrated Storage (Raft)

```hcl
# vault.hcl
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-1"
  
  retry_join {
    leader_api_addr = "https://vault-2:8200"
  }
  retry_join {
    leader_api_addr = "https://vault-3:8200"
  }
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault/tls/vault.crt"
  tls_key_file  = "/etc/vault/tls/vault.key"
}

api_addr     = "https://vault-1:8200"
cluster_addr = "https://vault-1:8201"
```

### Auto-Unseal with AWS KMS

```hcl
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/vault-unseal"
}
```

### Auto-Unseal with Azure Key Vault

```hcl
seal "azurekeyvault" {
  tenant_id  = "tenant-id"
  vault_name = "vault-unseal-kv"
  key_name   = "vault-unseal-key"
}
```

### Cluster Operations

```bash
# Check cluster status
vault operator raft list-peers

# Add a new node
vault operator raft join https://vault-1:8200

# Remove a failed node
vault operator raft remove-peer vault-3

# Snapshot for backup
vault operator raft snapshot save backup.snap

# Restore from snapshot
vault operator raft snapshot restore backup.snap
```

---

## Monitoring

### Telemetry Configuration

```hcl
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}
```

### Key Metrics to Monitor

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `vault.core.unsealed` | Vault seal status | 0 (sealed) |
| `vault.raft.leader` | Raft leadership | Leadership changes |
| `vault.token.count` | Active tokens | Unusual spikes |
| `vault.expire.num_leases` | Active leases | Approaching max |
| `vault.runtime.alloc_bytes` | Memory usage | > 80% available |

### Prometheus Scrape Config

```yaml
scrape_configs:
  - job_name: vault
    metrics_path: /v1/sys/metrics
    params:
      format: [prometheus]
    bearer_token_file: /etc/prometheus/vault-token
    static_configs:
      - targets: ['vault:8200']
```

---

## Backup and Recovery

### Raft Snapshots

```bash
# Manual backup
vault operator raft snapshot save /backup/vault-$(date +%Y%m%d).snap

# Automated backup (cron)
0 */4 * * * vault operator raft snapshot save /backup/vault-$(date +\%Y\%m\%d-\%H\%M).snap
```

### Recovery Procedure

1. **Seal all nodes** to prevent split-brain
2. **Stop Vault** on all nodes
3. **Restore snapshot** on one node
4. **Start that node** as new leader
5. **Join other nodes** to the cluster

---

## Enterprise Features

| Feature | Description |
|---------|-------------|
| **Namespaces** | Multi-tenant isolation |
| **Performance Replication** | Read replicas for global distribution |
| **DR Replication** | Warm standby for failover |
| **Sentinel** | Policy-as-code beyond ACLs |
| **MFA** | Multi-factor authentication |
| **Control Groups** | Multi-person approval workflows |

### Namespace Operations

```bash
# Create namespace
vault namespace create engineering

# Work within namespace
export VAULT_NAMESPACE=engineering
vault secrets enable kv
```

---

## Best Practices

- **Use Integrated Storage (Raft)** for simplicity
- **Configure auto-unseal** with cloud KMS
- **Deploy 3 or 5 nodes** for HA (odd number for quorum)
- **Enable audit logging** in production
- **Automate backups** with Raft snapshots
- **Monitor key metrics** and set up alerts
- **Test DR failover** regularly

---

For complete production deployment guides, replication setup, and Enterprise configuration, see:
- [references/production-operations.md](references/production-operations.md)
- [references/enterprise.md](references/enterprise.md)
