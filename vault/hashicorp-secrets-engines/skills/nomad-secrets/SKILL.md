---
name: nomad-secrets
description: Use when generating dynamic Nomad ACL tokens through Vault, configuring the Nomad secrets engine, or integrating Vault with Nomad job scheduling. Covers role mapping and credential generation.
---

# Nomad Secrets Engine

## What Are You Trying to Solve?

### "My CI/CD pipeline needs to submit jobs to Nomad"
→ Create a **client token role** with submit-job policy. [Jump to Job Submitter](#job-submitter-policy)

### "I need full admin access to Nomad"
→ Create a **management token role**. [Jump to Token Type](#token-type)

### "I want short-lived Nomad tokens for automation"
→ Configure **TTL on roles**, Vault handles revocation. [Jump to Lease Management](#lease-management)

### "I have a multi-region Nomad cluster"
→ Use **global tokens**. [Jump to Multi-Region](#multi-region-configuration)

---

## How Nomad Secrets Engine Works

1. **Configure** → Vault connects to Nomad with management token
2. **Create roles** → Map Vault roles to Nomad ACL policies
3. **Generate credentials** → Apps request tokens from Vault
4. **Automatic revocation** → Tokens revoked when lease expires

**Requirement:** Nomad 0.7.0+ with ACLs enabled.

---

## Token Type Selection

| Your Need | Token Type | Configuration |
|-----------|------------|---------------|
| Submit jobs, read logs | Client | `type="client"` + policies |
| Full cluster access | Management | `type="management"` |
| Multi-region access | Global Client | `global=true` |

---

## Reference

- [Nomad Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/nomad)
- [Vault Nomad Tutorial](https://developer.hashicorp.com/nomad/tutorials/integrate-vault/vault-nomad-secrets)
- For complete role configuration and token types, see [references/nomad-secrets.md](references/nomad-secrets.md)

## Setup

### Enable the Engine

```bash
vault secrets enable nomad
```

### Bootstrap Nomad ACLs

```bash
# If Nomad ACLs not bootstrapped yet
nomad acl bootstrap
# Accessor ID  = 95a0ee55-eaa6-2c0a-a900
# Secret ID    = c25b6ca0-ea4e-000f-807a (save this!)
```

### Configure Vault Access

```bash
# Using bootstrap or management token
vault write nomad/config/access \
  address="http://127.0.0.1:4646" \
  token="$NOMAD_MANAGEMENT_TOKEN"

# With TLS
vault write nomad/config/access \
  address="https://nomad.example.com:4646" \
  token="$NOMAD_MANAGEMENT_TOKEN" \
  ca_cert="@/path/to/ca.crt"
```

### Configure Lease Settings

```bash
vault write nomad/config/lease \
  ttl=3600 \
  max_ttl=86400
```

## Role Configuration

### Map to Single Policy

```bash
vault write nomad/roles/deployer \
  policies="deploy"
```

### Map to Multiple Policies

```bash
vault write nomad/roles/platform \
  policies="deploy,read-logs,submit-jobs"
```

### Global Tokens

```bash
# For multi-region Nomad clusters
vault write nomad/roles/global-admin \
  policies="admin" \
  global=true
```

### Token Type

```bash
# Client token (default)
vault write nomad/roles/app-submitter \
  policies="submit-job" \
  type="client"

# Management token (full access)
vault write nomad/roles/nomad-admin \
  type="management"
```

## Generate Credentials

```bash
# Generate token
vault read nomad/creds/deployer

# Key              Value
# lease_id         nomad/creds/deployer/abc123
# lease_duration   1h
# lease_renewable  true
# accessor_id      a715994d-f5fd-1194-73df
# secret_id        b31fb56c-0936-5428-8c5f
```

### Use the Token

```bash
# Set environment variable
export NOMAD_TOKEN=$(vault read -field=secret_id nomad/creds/deployer)

# Submit a job
nomad job run myapp.nomad

# Verify token
nomad acl token self
```

## Nomad Policy Examples

### Read-Only Policy

```hcl
# readonly.policy.hcl
namespace "*" {
  policy = "read"
}
node {
  policy = "read"
}
```

### Job Submitter Policy

```hcl
# deploy.policy.hcl
namespace "default" {
  policy = "write"
  capabilities = ["submit-job", "read-logs", "alloc-exec"]
}
node {
  policy = "read"
}
```

### Namespace Admin Policy

```hcl
# ns-admin.policy.hcl
namespace "production" {
  policy = "write"
  capabilities = ["submit-job", "read-logs", "alloc-exec", "alloc-lifecycle"]
}
namespace "staging" {
  policy = "write"
}
```

### Create Policies in Nomad

```bash
nomad acl policy apply readonly readonly.policy.hcl
nomad acl policy apply deploy deploy.policy.hcl
```

## Integration Pattern

```
┌──────────┐   1. Request creds   ┌───────────┐
│  CI/CD   │ ──────────────────►  │   Vault   │
│ Pipeline │                      └─────┬─────┘
└────┬─────┘                            │
     │                           2. Create ACL token
     │                                  │
     │                                  ▼
     │                           ┌───────────┐
     │ 3. Submit job             │   Nomad   │
     └──────────────────────────►│  Cluster  │
                                 └───────────┘
```

## Lease Management

### Renew Token Lease

```bash
vault lease renew nomad/creds/deployer/abc123
```

### Revoke Token

```bash
vault lease revoke nomad/creds/deployer/abc123
```

### Revoke All Tokens for Role

```bash
vault lease revoke -prefix nomad/creds/deployer
```

## Multi-Region Configuration

For federated Nomad clusters:

```bash
# Configure region in access
vault write nomad/config/access \
  address="https://nomad.dc1.example.com:4646" \
  token="$NOMAD_TOKEN"

# Generate global tokens
vault write nomad/roles/global-deployer \
  policies="deploy" \
  global=true
```

## API Examples

### Create Role

```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"policies":"deploy","type":"client"}' \
  $VAULT_ADDR/v1/nomad/roles/deployer
```

### Generate Credentials

```bash
curl -X GET \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/nomad/creds/deployer
```

## CI/CD Integration

### GitHub Actions Example

```yaml
jobs:
  deploy:
    steps:
      - name: Get Nomad Token
        run: |
          NOMAD_TOKEN=$(vault read -field=secret_id nomad/creds/deployer)
          echo "NOMAD_TOKEN=$NOMAD_TOKEN" >> $GITHUB_ENV
      
      - name: Deploy to Nomad
        run: nomad job run app.nomad
```

### GitLab CI Example

```yaml
deploy:
  script:
    - export NOMAD_TOKEN=$(vault read -field=secret_id nomad/creds/deployer)
    - nomad job run app.nomad
```

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| "ACL support disabled" | Nomad ACLs not enabled | Enable ACLs in Nomad config |
| "Permission denied" | Vault token lacks management | Use management token for config |
| Policy not found | Policy name mismatch | Verify policy exists in Nomad |
| Token immediately invalid | Clock skew | Sync time between Vault and Nomad |
