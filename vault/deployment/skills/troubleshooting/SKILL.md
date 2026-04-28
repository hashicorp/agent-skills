---
name: troubleshooting
description: Diagnose and resolve Vault issues. Use when asked about Vault errors, sealed Vault, permission denied, token expired, performance problems, connection issues, audit log analysis, or common operational problems.
---

# Vault Troubleshooting

## What Error Are You Seeing?

### "Vault is sealed"
→ Unseal manually or check auto-unseal configuration. [Jump to Sealed Vault](#vault-is-sealed)

### "permission denied"
→ Check token policies and path syntax (KV v2 needs `/data/`). [Jump to Permission Denied](#permission-denied)

### "token expired" or "token not found"
→ Check TTL and renew or re-authenticate. [Jump to Token Expired](#token-expired)

### "Kubernetes pod can't authenticate"
→ Verify service account and Kubernetes auth config. [Jump to Authentication Failures](#authentication-failures)

### "Vault is slow or timing out"
→ Check metrics, storage backend, and audit devices. [Jump to Performance Issues](#performance-issues)

---

## Diagnostic Workflow

1. **Check status** → `vault status` (is it sealed? HA leader?)
2. **Check token** → `vault token lookup` (what policies? TTL remaining?)
3. **Check capabilities** → `vault token capabilities <path>` (can I access this path?)
4. **Check audit logs** → Find the actual error in request/response
5. **Check metrics** → Identify bottlenecks

---

## Reference

- [Vault Troubleshooting Guide](https://developer.hashicorp.com/vault/docs/troubleshooting)
- For complete diagnostic workflows and error resolution, see [references/troubleshooting.md](references/troubleshooting.md)

---

## Quick Diagnostics

### Health Check

```bash
# Check Vault status
vault status

# Check seal status specifically
vault status -format=json | jq '.sealed'

# Check leader and HA status
vault operator raft list-peers
```

### Token and Policy Check

```bash
# View current token info
vault token lookup

# Check capabilities for a path
vault token capabilities secret/data/myapp

# View attached policies
vault policy read app-policy
```

---

## Common Issues

### Vault is Sealed

**Symptoms**: All operations return "Vault is sealed"

**Solution**:
```bash
# Manual unseal (repeat for threshold keys)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

**If using auto-unseal**:
```bash
# Check seal configuration
vault status -format=json | jq '.seal_type'

# For AWS KMS issues
aws kms describe-key --key-id alias/vault-unseal

# For Azure Key Vault issues
az keyvault key show --vault-name vault-unseal --name vault-key
```

### Permission Denied

**Symptoms**: `Error making API request: permission denied`

**Diagnostic steps**:
```bash
# 1. Check token policies
vault token lookup

# 2. Check capabilities for the path
vault token capabilities secret/data/myapp

# 3. View the policy
vault policy read <policy-name>
```

**Common causes**:
- **KV v2 path issue**: Policy needs `/data/` in path, CLI doesn't
  ```hcl
  # Policy: path "secret/data/myapp/*"
  # CLI:    vault kv get secret/myapp/config
  ```
- **Missing `list` capability**: Need `list` to see path contents
- **Wrong path**: Typo or incorrect mount path

### Token Expired

**Symptoms**: `permission denied` after successful auth

**Solution**:
```bash
# Check token TTL
vault token lookup -format=json | jq '.data.ttl'

# Renew token (if renewable)
vault token renew

# Re-authenticate
vault login -method=oidc  # or your auth method
```

### Authentication Failures

**Kubernetes auth**:
```bash
# Check service account token
kubectl exec <pod> -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Verify Kubernetes auth config
vault read auth/kubernetes/config

# Check role binding
vault read auth/kubernetes/role/<role-name>
```

**AppRole auth**:
```bash
# Verify role exists
vault read auth/approle/role/<role-name>

# Check if secret ID is expired
# (secret IDs have TTL - generate new one)
vault write -f auth/approle/role/<role-name>/secret-id
```

---

## Performance Issues

### Slow Response Times

**Check metrics**:
```bash
curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/sys/metrics?format=prometheus | \
  grep vault_core_handle_request
```

**Common causes**:
- High number of concurrent requests
- Large secrets (>1MB)
- Storage backend latency
- Missing audit device (blocks on writes)

**Solutions**:
```bash
# Enable caching with Vault Agent
vault agent -config=agent.hcl

# Check storage latency
vault read sys/storage/raft/status

# Review audit device health
vault audit list
```

### Memory Issues

```bash
# Check runtime memory
vault read sys/host-info -format=json | jq '.data.memory'

# Look for lease accumulation
vault list sys/leases/lookup/<mount>/
```

---

## Audit Log Analysis

```bash
# Search for specific errors
grep -i "error" /var/log/vault-audit.log | tail -20

# Find permission denied for a path
jq 'select(.error != null) | {path: .request.path, error: .error}' \
  /var/log/vault-audit.log

# Track specific client
jq 'select(.request.client_token == "<token-accessor>")' \
  /var/log/vault-audit.log
```

---

## Debug Mode

```bash
# Enable debug logging (don't use in production long-term)
vault server -log-level=debug -config=config.hcl

# Or via environment
VAULT_LOG_LEVEL=debug vault server -config=config.hcl
```

---

## Best Practices for Troubleshooting

1. **Check `vault status` first** - confirms seal state and HA status
2. **Use `vault token lookup`** - shows policies and TTL
3. **Test with `vault token capabilities`** - validates path access
4. **Review audit logs** - shows actual requests and errors
5. **Check metrics** - identifies performance bottlenecks
6. **Test incrementally** - isolate the failing component

---

For comprehensive troubleshooting procedures, error code reference, and advanced diagnostics, see [references/troubleshooting.md](references/troubleshooting.md).
