---
name: vault-troubleshooting
description: Comprehensive troubleshooting guide for Vault issues including connectivity, auth, secrets, performance, and recovery
---

# Vault Troubleshooting

This reference provides diagnostic procedures for common Vault issues.

---

## Diagnostic Commands

### Quick Health Check

```bash
# Vault status
vault status

# Check seal status, HA mode, version
# Key fields:
#   Sealed: true/false
#   HA Enabled: true
#   Active: true (or standby)

# API health endpoint
curl $VAULT_ADDR/v1/sys/health

# Health response codes:
# 200 - active, unsealed
# 429 - standby, unsealed
# 472 - DR secondary
# 473 - performance standby
# 501 - uninitialized
# 503 - sealed
```

### Token Inspection

```bash
# View current token info
vault token lookup

# Check token capabilities on path
vault token capabilities secret/data/myapp/config

# View token by accessor
vault token lookup -accessor <accessor>
```

### Audit Log Check

```bash
# List audit devices
vault audit list

# Enable file audit
vault audit enable file file_path=/var/log/vault-audit.log

# Audit logs contain all requests/responses (sensitive data is hashed)
```

---

## Common Issues

### Vault is Sealed

**Symptoms:**

- `vault status` shows `Sealed: true`
- HTTP 503 responses
- Cannot access secrets

**Diagnosis:**

```bash
vault status
# Check: Sealed, Threshold, Unseal Progress
```

**Solutions:**

```bash
# Manual unseal (repeat until threshold met)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>

# Check unseal progress
vault status | grep "Unseal Progress"
```

**Prevention:**

- Configure auto-unseal with cloud KMS
- Set up monitoring for seal status

```hcl
# Auto-unseal configuration (vault.hcl)
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/vault-unseal"
}
```

---

### Permission Denied

**Symptoms:**

- `Error: permission denied`
- 403 HTTP response
- Can authenticate but cannot access secrets

**Diagnosis:**

```bash
# Check your token's policies
vault token lookup

# Check capabilities on specific path
vault token capabilities secret/data/myapp/config
# Output: read, list, deny, etc.

# Read the policy
vault policy read <policy-name>
```

**Common Causes:**

1. **Missing capability**: Policy lacks required permission
2. **Wrong path**: KV v2 requires `/data/` in path
3. **Explicit deny**: Another policy denies access
4. **Case sensitivity**: Paths are case-sensitive

**Solutions:**

```bash
# KV v2 paths - note the /data/ segment
# CLI hides it:
vault kv get secret/myapp/config

# But policy needs it:
path "secret/data/myapp/config" {
  capabilities = ["read"]
}

# Check for conflicting policies
vault token lookup | grep policies
```

---

### Token Expired

**Symptoms:**

- `permission denied` after previously working
- `token has expired` error
- HTTP 403 responses

**Diagnosis:**

```bash
# Check token TTL
vault token lookup

# Key fields:
#   expire_time
#   ttl (remaining)
#   renewable
```

**Solutions:**

```bash
# Renew token before expiry
vault token renew

# Re-authenticate if expired
vault login -method=<auth-method>

# For applications, implement renewal logic
# Python example:
# client.auth.token.renew_self()
```

**Prevention:**

- Use periodic tokens for long-running services
- Implement token renewal in applications
- Set appropriate TTLs

---

### Cannot Connect to Vault

**Symptoms:**

- `connection refused`
- `timeout`
- `certificate` errors

**Diagnosis:**

```bash
# Check VAULT_ADDR
echo $VAULT_ADDR

# Test connectivity
curl -v $VAULT_ADDR/v1/sys/health

# Check if Vault is running
systemctl status vault
# or
docker ps | grep vault

# Check network
telnet vault.example.com 8200
```

**Solutions:**

```bash
# Set correct address
export VAULT_ADDR='https://vault.example.com:8200'

# TLS certificate issues
export VAULT_CACERT=/path/to/ca.crt
# or skip verification (dev only)
export VAULT_SKIP_VERIFY=true

# Check firewall
sudo iptables -L -n | grep 8200

# Check Vault listener config
cat /etc/vault.d/vault.hcl | grep -A5 listener
```

---

### Authentication Failures

**Symptoms:**

- `authentication failed`
- `invalid credentials`
- Cannot get token

**Diagnosis by Auth Method:**

**AppRole:**

```bash
# Verify role exists
vault read auth/approle/role/my-app

# Check role-id
vault read auth/approle/role/my-app/role-id

# Verify secret-id is valid (hasn't expired or been used)
# Generate new secret-id
vault write -f auth/approle/role/my-app/secret-id
```

**Kubernetes:**

```bash
# Check auth method config
vault read auth/kubernetes/config

# Check role binding
vault read auth/kubernetes/role/my-app

# Verify ServiceAccount token is valid
kubectl get sa my-app-sa -o yaml

# Test from within pod
JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl --request POST \
    --data "{\"jwt\": \"$JWT\", \"role\": \"my-app\"}" \
    $VAULT_ADDR/v1/auth/kubernetes/login
```

**OIDC:**

```bash
# Check OIDC config
vault read auth/oidc/config

# Verify callback URLs
vault read auth/oidc/role/default

# Check OIDC provider is accessible
curl https://accounts.google.com/.well-known/openid-configuration
```

---

### Secrets Not Found

**Symptoms:**

- `secret not found`
- Empty response
- 404 errors

**Diagnosis:**

```bash
# List secrets at path
vault kv list secret/
vault kv list secret/myapp/

# Check if using correct KV version
vault secrets list

# KV v2 metadata
vault kv metadata get secret/myapp/config
```

**Common Issues:**

1. **Wrong path**: Typo or wrong directory
2. **KV version mismatch**: Using v1 commands on v2 engine
3. **Secret deleted**: Check metadata for versions
4. **Namespace**: Secret is in different namespace

```bash
# Check namespace
export VAULT_NAMESPACE="team-a"
vault kv get secret/myapp/config

# Recover deleted secret (KV v2)
vault kv undelete -versions=1 secret/myapp/config
```

---

### Dynamic Secrets Not Generating

**Symptoms:**

- Database credentials fail
- AWS credentials not returned
- Lease errors

**Diagnosis:**

```bash
# Check secrets engine status
vault secrets list
vault read database/config/my-postgres

# Test database connection
vault write database/config/my-postgres \
    plugin_name=postgresql-database-plugin \
    connection_url="..." \
    username="..." \
    password="..." \
    verify_connection=true

# Check role
vault read database/roles/readonly
```

**Common Issues:**

1. **Connection failed**: Database unreachable from Vault
2. **Permission denied**: Vault user lacks privileges
3. **Role misconfigured**: Bad creation statements

```bash
# Test credential generation
vault read database/creds/readonly

# Check lease
vault lease lookup <lease-id>

# Revoke and retry
vault lease revoke <lease-id>
```

---

### HA / Cluster Issues

**Symptoms:**

- Standby nodes not syncing
- Split-brain concerns
- Leader election failures

**Diagnosis:**

```bash
# Check cluster status
vault operator raft list-peers

# Check leader
vault status | grep "Active Node"

# Raft autopilot status
vault operator raft autopilot state

# Check Raft storage
vault operator raft snapshot-status
```

**Solutions:**

```bash
# Remove unhealthy node
vault operator raft remove-peer <node-id>

# Force new leader election
vault operator step-down

# Take Raft snapshot for backup
vault operator raft snapshot save backup.snap
```

---

### Performance Issues

**Symptoms:**

- Slow response times
- High latency
- Request timeouts

**Diagnosis:**

```bash
# Check telemetry (if enabled)
curl $VAULT_ADDR/v1/sys/metrics | jq

# Key metrics:
#   vault.core.handle_request (latency)
#   vault.core.fetch_acl_and_token
#   vault.database.* (for dynamic secrets)
```

**Common Causes:**

1. **Storage latency**: Backend database/storage slow
2. **Audit device blocking**: Audit device unreachable
3. **Large number of leases**: Too many active leases
4. **Policy complexity**: Large/complex policies

**Solutions:**

```bash
# Check lease count
vault read sys/leases/count

# Revoke orphan leases
vault lease revoke -prefix database/creds/

# Check audit device
vault audit list
# Disable blocking audit device temporarily
vault audit disable file

# Enable connection pooling
# In app: reuse Vault client connections
```

---

### Vault Agent Template Issues

**Symptoms:**

- Templates not rendering
- Empty files in `/vault/secrets/`
- Agent exits with template errors

**Diagnosis:**

```bash
# Check Agent logs
vault agent -config=agent.hcl -log-level=debug

# Verify template syntax
# Test with consul-template standalone
consul-template -once -dry -template="template.ctmpl:output.txt"
```

**Common Causes:**

1. **Secret path wrong**: Check path in template matches actual Vault path
2. **Missing permissions**: Token doesn't have read access
3. **Template syntax**: Go template errors

**Solutions:**

```bash
# Allow empty secrets (don't fail if secret not found)
# Set environment variable
export VAULT_AGENT_TEMPLATING_EMPTY_SECRET_ALLOW=true

# Or in agent config
template {
  source      = "/vault/templates/config.ctmpl"
  destination = "/vault/secrets/config.txt"
  error_on_missing_key = false
}

# Debug template rendering
# Add to template for debugging
{{ with secret "secret/data/myapp/config" }}
# Keys available: {{ .Data.data | keys }}
{{ end }}
```

### Lease Issues

**Symptoms:**

- `lease not found`
- Credentials stopped working
- Renewal failures

**Diagnosis:**

```bash
# Lookup lease
vault lease lookup <lease-id>

# Check max TTL
vault read sys/mounts/database/tune
```

**Solutions:**

```bash
# Renew lease
vault lease renew <lease-id>

# Extend renewal increment
vault lease renew -increment=2h <lease-id>

# Revoke and get new credentials
vault lease revoke <lease-id>
vault read database/creds/my-role
```

---

## Log Analysis

### Log Levels

```bash
# Set log level (vault.hcl)
log_level = "debug"  # trace, debug, info, warn, error

# Runtime log level change
vault write sys/loggers/level level=debug
```

### Common Log Patterns

```bash
# Permission denied
grep "permission denied" /var/log/vault.log

# Auth failures
grep "login failed" /var/log/vault.log

# Storage errors
grep "storage" /var/log/vault.log | grep -i error

# Leadership changes
grep "leader" /var/log/vault.log
```

---

## Emergency Procedures

### Recovery from Lost Keys

```bash
# If you have recovery keys (auto-unseal)
vault operator generate-root -init

# Follow prompts with recovery keys
vault operator generate-root

# Complete root token generation
vault operator generate-root \
    -decode=<encoded-token> \
    -otp=<otp>
```

### Force Seal (Emergency)

```bash
# Seal Vault immediately
vault operator seal

# Requires unsealing to restore access
```

### Snapshot Recovery

```bash
# Take snapshot
vault operator raft snapshot save backup.snap

# Restore snapshot
vault operator raft snapshot restore backup.snap
```

---

## Monitoring & Metrics Reference

### Critical Metrics with Alert Thresholds

| Metric | Threshold | Action |
| -------- | ----------- | -------- |
| `vault.core.unsealed` | 0 | CRITICAL: Vault is sealed |
| `vault.core.active` | 0 | CRITICAL: No active node |
| `vault.audit.log_response_failure` | >0 | CRITICAL: Audit logging failing (stops all operations) |
| `vault.expire.num_leases` | >256,000 | WARNING: Approaching 256K lease limit |
| `vault.runtime.heap_objects` | >1M | WARNING: Memory pressure |

### Leadership & Cluster Health

| Metric | Threshold | Meaning |
| -------- | ----------- | --------- |
| `vault.core.leadership_setup_failed` | >0 | Leadership election failure |
| `vault.core.leadership_lost` | >0 per hour | Leadership instability |
| `vault.raft.leader.lastContact` | >200ms | Follower communication delay |
| `vault.raft.commitTime` | >50ms | Raft commit latency |
| `vault.raft.rpc.appendEntries` | sudden drop | Cluster communication issues |

### Performance Metrics

| Metric | Threshold | Meaning |
| -------- | ----------- | --------- |
| `vault.core.handle_request` (p99) | >100ms | Request latency too high |
| `vault.barrier.get` (avg) | >10ms | Storage read latency |
| `vault.barrier.put` (avg) | >15ms | Storage write latency |
| `vault.token.lookup` (p99) | >50ms | Token lookup slow |

### Replication Metrics (Enterprise)

| Metric | Threshold | Action |
| -------- | ----------- | -------- |
| `vault.replication.merkle.diff` | >10000 | Large replication backlog |
| `vault.replication.wal.last_wal` | gap >100 | WAL sync lag |
| `vault.replication.wal.gc_counter` | not increasing | WAL GC stalled |

### Resource Metrics

| Metric | Threshold | Action |
| -------- | ----------- | -------- |
| `vault.runtime.alloc_bytes` | >80% memory | Consider scaling |
| `vault.runtime.num_goroutines` | >10000 | Goroutine leak |
| `vault.runtime.gc_pause_ns` (avg) | >10ms | GC pressure |

### Token & Lease Metrics

| Metric | Threshold | Meaning |
| -------- | ----------- | --------- |
| `vault.token.count` | >100,000 | Token cleanup needed |
| `vault.token.count.by_auth` | varies | Track by auth method |
| `vault.expire.num_leases` | >200,000 | Approaching limits |
| `vault.expire.revoke` (rate) | sudden spike | Mass revocation event |

### Privileged Endpoint Monitoring

Track these paths for security auditing:

| Endpoint Pattern | Why Monitor |
| ----------------- | ------------- |
| `sys/seal` | Vault seal operations |
| `sys/unseal` | Unseal attempts |
| `sys/generate-root` | Root token generation |
| `sys/rekey` | Unseal key rekeying |
| `sys/policies/acl/*` | Policy changes |
| `sys/auth/*` | Auth method changes |
| `sys/mounts/*` | Secrets engine changes |
| `sys/audit*` | Audit device changes |
| `identity/*` | Identity modifications |

### Telemetry Configuration

```hcl
# Enable Prometheus metrics
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
  
  # Usage gauges for capacity planning
  usage_gauge_period = "10m"
  
  # Enable lease metrics
  lease_metrics_epsilon = 1h
  num_lease_metrics_buckets = 168
  add_lease_metrics_namespace_labels = true
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/tls.crt"
  tls_key_file  = "/vault/tls/tls.key"
  
  # Expose Prometheus metrics
  telemetry {
    unauthenticated_metrics_access = true
  }
}
```

### Grafana Alert Rules Example

```yaml
groups:
  - name: vault_critical
    rules:
      - alert: VaultSealed
        expr: vault_core_unsealed == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Vault is sealed"
          
      - alert: VaultNoLeader
        expr: vault_core_active == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "No active Vault leader"
          
      - alert: VaultAuditFailure
        expr: increase(vault_audit_log_response_failure[5m]) > 0
        labels:
          severity: critical
        annotations:
          summary: "Vault audit logging failing"
          
      - alert: VaultHighLeaseCount
        expr: vault_expire_num_leases > 200000
        labels:
          severity: warning
        annotations:
          summary: "High lease count approaching limits"
```

---

## Monitoring Checklist

- [ ] Seal status (`vault.core.unsealed`)
- [ ] Leader election health (`vault.core.active`)
- [ ] Replication lag (Enterprise) (`vault.replication.merkle.diff`)
- [ ] Audit device availability (`vault.audit.log_response_failure`)
- [ ] Token/lease counts (`vault.token.count`, `vault.expire.num_leases`)
- [ ] Response latency (`vault.core.handle_request`)
- [ ] Storage backend health (`vault.barrier.get/put`)
- [ ] Certificate expiration (external monitoring)

---

## Additional Resources

- [Troubleshooting Documentation](https://developer.hashicorp.com/vault/docs/troubleshooting)
- [Operational Considerations](https://developer.hashicorp.com/vault/docs/internals)
- [Vault Monitoring](https://developer.hashicorp.com/vault/tutorials/monitoring)

---

## Related

- [Production Operations](production-operations.md) - Monitoring and alerting
- [Auth Methods](auth-methods.md) - Auth troubleshooting details
- [Vault Agent](vault-agent.md) - Agent-specific issues
