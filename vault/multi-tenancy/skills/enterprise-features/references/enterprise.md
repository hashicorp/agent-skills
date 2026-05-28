---
name: vault-enterprise-features
description: Detailed configuration reference for Vault Enterprise features including namespaces, replication, Sentinel, MFA, Control Groups, and HSM integration
---

# Vault Enterprise Features Reference

This reference provides detailed configuration for Vault Enterprise features.

---

## Namespaces

### Creating and Managing Namespaces

```bash
# Create namespace
vault namespace create business-unit-a

# Create nested namespace (max 2-3 levels recommended)
vault namespace create -namespace=business-unit-a team-1

# List namespaces
vault namespace list
vault namespace list -namespace=business-unit-a

# Delete namespace (must be empty)
vault namespace delete business-unit-a/team-1
```

### Namespace API Paths

```bash
# All operations in namespace context
export VAULT_NAMESPACE=business-unit-a/team-1

# Or use API path prefix
curl -H "X-Vault-Token: $VAULT_TOKEN" \
     -H "X-Vault-Namespace: business-unit-a/team-1" \
     $VAULT_ADDR/v1/secret/data/myapp
```

### Authentication Placement Strategy

| Auth Method | Recommended Location | Rationale |
|-------------|---------------------|-----------|
| OIDC/LDAP (humans) | Root namespace | Reduces entity duplication |
| Kubernetes | Child namespace | Per-cluster isolation |
| AppRole | Child namespace | Per-application group |
| AWS/Azure/GCP | Root or child | Depends on account structure |

### Cross-Namespace Access

```hcl
# Policy granting access to another namespace's secrets
path "ns1/secret/data/shared/*" {
  capabilities = ["read"]
}

# Grant access to child namespace
path "+/secret/data/shared/*" {
  capabilities = ["read"]
}
```

### Namespace Lock/Unlock (Incident Response)

```bash
# Lock namespace - all API calls return 503
vault namespace lock business-unit-a
# Returns unlock key

# Unlock namespace
vault namespace unlock business-unit-a -unlock-key=<key>
```

### Namespace Limits and Restrictions

| Configuration | Value/Limit |
|---------------|-------------|
| Default mount table limit | ~4,600 namespaces |
| Recommended max depth | 2-3 levels |
| Invalid characters | `/`, `\`, `..`, `%`, `+` |
| Reserved names | `sys`, `auth`, `identity`, `cubbyhole` |

---

## Performance Replication

Performance Replication provides read scaling and geographic distribution.

### Enable Performance Replication

```bash
# On Primary Cluster
vault write -f sys/replication/performance/primary/enable

# Generate activation token
vault write sys/replication/performance/primary/secondary-token \
    id=region-2 \
    ttl=1h

# On Secondary Cluster
vault write sys/replication/performance/secondary/enable \
    token=<activation-token>
```

### Promote Secondary to Primary

```bash
# On secondary (emergency failover)
vault write -f sys/replication/performance/secondary/promote

# Demote old primary
vault write -f sys/replication/performance/primary/demote
```

### Performance Replication Considerations

| Item | Replicated? |
|------|-------------|
| Secrets engine mounts | Yes |
| Auth method mounts | Yes |
| Policies | Yes |
| Tokens | **No** |
| Leases | **No** |
| Local mounts | **No** |

### Batch Tokens for Cross-Cluster Operations

Batch tokens ARE portable across PR clusters:

```bash
# Create batch token
vault token create -type=batch -policy=my-policy

# Use on any PR cluster
export VAULT_TOKEN=<batch-token>
vault kv get -namespace=ns1 secret/data/myapp
```

---

## Disaster Recovery Replication

DR Replication provides a hot standby for business continuity.

### Enable DR Replication

```bash
# On Primary Cluster
vault write -f sys/replication/dr/primary/enable

# Generate activation token
vault write sys/replication/dr/primary/secondary-token \
    id=dr-site \
    ttl=1h

# On DR Secondary Cluster
vault write sys/replication/dr/secondary/enable \
    token=<activation-token>
```

### DR Failover Procedure

```bash
# 1. On DR secondary, generate operation token (requires recovery keys)
vault operator generate-root -dr-token

# 2. Promote DR secondary to primary
vault write -f sys/replication/dr/secondary/promote \
    dr_operation_token=<operation-token>

# 3. Update DNS/load balancer to point to new primary

# 4. After recovery, demote old primary and re-establish replication
```

### DR Best Practices

1. DR cluster MUST be in separate region from primary
2. Mirror primary cluster specifications exactly
3. Use different KMS/HSM in DR region
4. Take backups from DR cluster to avoid loading primary
5. Test DR failover quarterly with documented runbooks
6. Never promote PR as DR - use dedicated DR clusters

---

## Sentinel Policies

### Policy Types

| Type | Applies To | Use Case |
|------|-----------|----------|
| EGP (Endpoint Governing) | API paths | Enforce rules on specific endpoints |
| RGP (Role Governing) | Tokens/identities | Apply rules based on requester identity |

### Write Sentinel Policy

```bash
# Create EGP policy
vault write sys/policies/egp/require-mfa \
    policy=@require-mfa.sentinel \
    paths="secret/*" \
    enforcement_level="hard-mandatory"
```

### Enforcement Levels

| Level | Behavior |
|-------|----------|
| `advisory` | Log failure but allow operation |
| `soft-mandatory` | Block operation but can be overridden |
| `hard-mandatory` | Block operation, no override |

### Example: Require MFA for Admin Paths

```python
# require-mfa.sentinel
import "mfa"
import "strings"

# Only apply to sys/ paths
precond = rule {
    strings.has_prefix(request.path, "sys/")
}

main = rule when precond {
    mfa.methods.totp.valid
}
```

### Example: Restrict by Time

```python
# business-hours.sentinel
import "time"

# Block writes outside business hours
main = rule when request.operation in ["create", "update", "delete"] {
    time.now.hour >= 9 and 
    time.now.hour < 17 and
    time.now.weekday_name not in ["Saturday", "Sunday"]
}
```

### Example: Restrict by Identity Group

```python
# require-group.sentinel
import "identity"

# Only security-team can access privileged paths
main = rule {
    "security-team" in identity.groups.names
}
```

---

## Multi-Factor Authentication (MFA)

### Login MFA vs Step-up MFA

| Type | When Applied | Configuration |
|------|--------------|---------------|
| Login MFA | During authentication | Configure on auth method |
| Step-up MFA | During path access | Configure in policy |

### Configure TOTP Method

```bash
# Create TOTP method
vault write sys/mfa/method/totp/my-totp \
    issuer="MyCompany Vault" \
    period=30 \
    key_size=20 \
    algorithm=SHA1 \
    digits=6 \
    skew=1

# For Login MFA - bind to auth method
vault write auth/userpass/mfa_config \
    type="totp" \
    mount_accessor=$(vault auth list -format=json | jq -r '.["userpass/"].accessor')
```

### Generate TOTP for User (Step-up MFA)

```bash
# Admin generates QR code for entity
vault write sys/mfa/method/totp/my-totp/admin-generate \
    entity_id=$(vault read -field=id identity/entity/name/alice)
```

### Configure Step-up MFA in Policy

```hcl
path "secret/data/sensitive/*" {
  capabilities = ["read"]
  mfa_methods = ["my-totp"]
}
```

---

## Control Groups

Control Groups require approval from authorized users before granting access.

### Configure Control Group Policy

```hcl
path "secret/data/production/*" {
  capabilities = ["read"]
  
  control_group = {
    factor "approvers" {
      identity {
        group_names = ["security-team", "senior-engineers"]
        approvals = 2
      }
    }
    ttl = "1h"
    max_ttl = "4h"
  }
}
```

### Control Group Workflow

```bash
# 1. User requests access
vault kv get secret/production/database
# Returns: control group accessor

# 2. Approvers authorize
vault write sys/control-group/authorize accessor=<accessor>

# 3. After required approvals, user completes request
vault kv get secret/production/database
```

---

## HSM Integration

### PKCS#11 Configuration

```hcl
# Vault configuration file
seal "pkcs11" {
  lib            = "/usr/lib/softhsm/libsofthsm2.so"
  slot           = "0"
  pin            = "1234"
  key_label      = "vault-hsm-key"
  hmac_key_label = "vault-hsm-hmac"
  generate_key   = "true"
}
```

### HSM Best Practices

1. Use dedicated HSM partition for Vault
2. Configure HSM HA for seal availability
3. Test HSM failover procedures
4. Monitor HSM health alongside Vault health
5. Plan for HSM key rotation procedures

---

## Additional Resources

- [Namespaces](https://developer.hashicorp.com/vault/docs/enterprise/namespaces)
- [Performance Replication](https://developer.hashicorp.com/vault/docs/enterprise/replication)
- [DR Replication](https://developer.hashicorp.com/vault/docs/enterprise/replication/dr)
- [Sentinel Policies](https://developer.hashicorp.com/vault/docs/enterprise/sentinel)
- [MFA](https://developer.hashicorp.com/vault/docs/enterprise/mfa)
- [Control Groups](https://developer.hashicorp.com/vault/docs/enterprise/control-groups)
- [HSM Integration](https://developer.hashicorp.com/vault/docs/enterprise/hsm)

---

## Related

- [auth-methods.md](../../authentication/skills/auth-methods/references/auth-methods.md) - Authentication configuration
- [policies.md](../../authentication/skills/policies/references/policies.md) - ACL policy syntax
- [production-operations.md](../../operations/skills/production-operations/references/production-operations.md) - HA and DR operations
