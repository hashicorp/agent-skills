---
name: vault-enterprise
description: Comprehensive guidance on Vault Enterprise features including namespaces, replication, Sentinel, and HSM
---

# Vault Enterprise Features

This reference covers features available only in Vault Enterprise and HCP Vault.

---

## Feature Availability

| Feature | Community | Enterprise | HCP Vault |
| --------- | ----------- | ------------ | ----------- |
| Secrets Engines | ✅ | ✅ | ✅ |
| Auth Methods | ✅ | ✅ | ✅ |
| Policies (ACL) | ✅ | ✅ | ✅ |
| Audit Logging | ✅ | ✅ | ✅ |
| **Namespaces** | ❌ | ✅ | ✅ |
| **Performance Replication** | ❌ | ✅ | ✅ |
| **DR Replication** | ❌ | ✅ | ✅ |
| **Sentinel Policies** | ❌ | ✅ | ✅ |
| **MFA** | ❌ | ✅ | ✅ |
| **Control Groups** | ❌ | ✅ | ✅ |
| **HSM Auto-Unseal** | ❌ | ✅ | N/A |
| **KMIP** | ❌ | ✅ | ✅ |

---

## Namespaces

Multi-tenancy isolation within a single Vault cluster.

### Concept

- Each namespace is an isolated Vault environment
- Separate secrets engines, auth methods, policies
- Hierarchical structure (parent/child namespaces)
- Root namespace is the default

### Namespace Design Decision Tree

Before creating a namespace, ask these questions:

| Question | If Yes | If No |
| ---------- | -------- | ------- |
| Does this org unit need separate policy administration? | Create namespace | Use policies |
| Are there different compliance requirements? | Create namespace | Use policies |
| Are these distinct business units? | Create namespace | Use policies |
| Is this for team-level isolation only? | Consider policies first | Use policies |
| Is this for per-application isolation? | Use policies | Use policies |
| Is this for environment separation (dev/prod)? | Use separate clusters | Use policies |

### Namespace Architecture Best Practices

**Recommended Structure (Flat):**

```text
root/
├── shared-services/     # Shared auth, PKI roots
├── business-unit-a/     # LOB-level namespace
│   ├── team-1/          # Max 2-3 levels deep
│   └── team-2/
└── business-unit-b/
    └── team-3/
```

**Authentication Placement:**

| Auth Method | Mount Location | Rationale |
| ------------- | ---------------- | ----------- |
| OIDC/LDAP (human) | Root namespace | Reduces entity duplication |
| Kubernetes | Child namespace (per cluster) | Isolation per K8s cluster |
| AppRole | Child namespace | Scoped to application group |
| AWS/Azure/GCP | Root or child | Depends on account structure |

**Namespace Limits:**

| Configuration           | Approximate Limit   |
| ----------------------- | ------------------- |
| Default mount table     | ~4,600 namespaces   |
| Recommended max depth   | 2-3 levels          |

### Namespace Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| -------------- | --------- | ------------------ |
| Deep nesting (>3 levels) | Operational complexity | Keep hierarchy flat |
| Namespace per person | Scalability issues | Use policy templating |
| Environment names in paths | Encourages cross-env access | Business-oriented naming |
| Namespace per application | Administrative overhead | Use policies instead |

### Namespace Management

> **Naming Restrictions**: Namespace names cannot contain the following: `/`, `\`, `..`, `%`, or `+`.

```bash
# Create namespace
vault namespace create team-a
vault namespace create team-b

# List namespaces
vault namespace list

# Create child namespace
vault namespace create -namespace=team-a dev
vault namespace create -namespace=team-a prod

# Delete namespace
vault namespace delete team-a
```

### Administrative Namespaces

Create namespaces with limited API access for enhanced security:

```bash
# Create namespace that restricts certain API paths
vault namespace create -custom-metadata=admin=restricted team-c
```

Restricted namespaces cannot access certain `sys/*` endpoints.

### Working Within Namespaces

```bash
# Set namespace for session
export VAULT_NAMESPACE="team-a"

# Or use header
vault kv put -namespace="team-a" secret/app key=value

# Enable secrets engine in namespace
vault secrets enable -namespace="team-a" -path=secret kv-v2

# Create policy in namespace
vault policy write -namespace="team-a" app-policy policy.hcl
```

### Namespace Hierarchy Example

```text
root/
├── team-a/
│   ├── dev/
│   └── prod/
└── team-b/
    ├── staging/
    └── prod/
```

### Cross-Namespace Access

```hcl
# Policy granting access across namespaces (rare, use carefully)
path "team-a/secret/data/shared/*" {
  capabilities = ["read"]
}
```

---

## Replication

### Types of Replication

| Type | Use Case | Data Synced | Write Location |
| --- | --- | --- | --- |
| **Performance** | Geographic distribution, read scaling | All data | Primary only |
| **Disaster Recovery** | Failover, business continuity | All data | Primary only (DR is standby) |

### Performance Replication

Read replicas for geographic distribution.

```bash
# On primary cluster
vault write -f sys/replication/performance/primary/enable

# Generate secondary token
vault write sys/replication/performance/primary/secondary-token \
    id="us-west-secondary"

# On secondary cluster
vault write sys/replication/performance/secondary/enable \
    token="<secondary-token>"

# Check status
vault read sys/replication/status
```

### Disaster Recovery Replication

Warm standby for failover.

```bash
# On primary cluster
vault write -f sys/replication/dr/primary/enable

# Generate secondary token
vault write sys/replication/dr/primary/secondary-token \
    id="dr-secondary"

# On DR secondary
vault write sys/replication/dr/secondary/enable \
    token="<dr-token>"

# Promote DR secondary (during failover)
vault write -f sys/replication/dr/secondary/promote
```

### DR Failover Procedure

```bash
# 1. Verify DR secondary is caught up
vault read sys/replication/dr/status

# 2. Generate DR operation token
vault operator generate-root -dr-token -init
vault operator generate-root -dr-token  # Provide recovery keys

# 3. Promote DR secondary to primary
vault write sys/replication/dr/secondary/promote \
    dr_operation_token=<token>

# 4. Update load balancer to new primary
# 5. Configure new DR secondary
```

### Replication Migration Strategy

Use this pattern for migrating Vault clusters with minimal downtime:

1. Set up new Performance Secondary in target environment
2. Set up new DR Secondary attached to new Performance Secondary
3. Validate replication status and data integrity
4. Switch load balancer to new Performance Secondary
5. Demote old Primary to secondary
6. Promote new Performance Secondary to Primary
7. Clean up old clusters

**Critical Considerations:**

| Item | Behavior |
| ------ | ---------- |
| Local mounts | NOT replicated (verify with `vault read sys/mounts`) |
| Tokens | NOT replicated to PR clusters |
| Leases | NOT replicated - apps must re-authenticate |
| Batch tokens | Portable across PR clusters |
| Two primaries | **NEVER** enable simultaneously - causes data loss |

### Replication Filters

Control what data replicates.

```bash
# Create filter (paths to exclude)
vault write sys/replication/performance/primary/paths-filter/us-west \
    mode="deny" \
    paths="secret/data/eu-only/*,pki/issue/eu-certs"

# Apply filter to secondary
vault write sys/replication/performance/primary/secondary-token \
    id="us-west" \
    paths_filter_id="us-west"
```

---

## Sentinel Policies

Policy-as-code for fine-grained access control beyond ACLs.

### Policy Types

- **Endpoint Governing Policies (EGP)**: Applied to API paths
- **Role Governing Policies (RGP)**: Applied to identity entities/groups

### EGP Example: Business Hours

```sentinel
# Only allow access during business hours
import "time"

precondition "valid_request" {
  message = "Access only allowed during business hours (9am-5pm EST)"
  when = rule {
    time.now.hour >= 9 and time.now.hour < 17
  }
}

main = rule { true }
```

### EGP Example: Require MFA

```sentinel
import "mfa"
import "strings"

# Require TOTP MFA for sensitive paths
main = rule when strings.has_prefix(request.path, "secret/data/prod/") {
  mfa.methods.totp.valid
}
```

### RGP Example: Limit Token Creation

```sentinel
import "strings"

# Prevent tokens with TTL > 24h
main = rule when strings.has_prefix(request.path, "auth/token/create") {
  request.data.ttl <= duration("24h")
}
```

### Deploy Sentinel Policies

```bash
# Write EGP
vault write sys/policies/egp/business-hours \
    policy=@business-hours.sentinel \
    paths="secret/data/prod/*" \
    enforcement_level="hard-mandatory"

# Write RGP
vault write sys/policies/rgp/token-limits \
    policy=@token-limits.sentinel \
    enforcement_level="soft-mandatory"

# Enforcement levels:
# - advisory: log only
# - soft-mandatory: can be overridden
# - hard-mandatory: strictly enforced
```

---

## Multi-Factor Authentication (MFA)

Require additional verification for sensitive operations.

### TOTP MFA

```bash
# Enable TOTP MFA
vault write sys/mfa/method/totp/my-totp \
    issuer="Vault" \
    period=30 \
    key_size=20 \
    algorithm="SHA256" \
    digits=6

# Associate with entity
vault write identity/mfa/method/totp/my-totp/admin-generate \
    entity_id="<entity-id>"

# Create login enforcement
vault write sys/mfa/login-enforcement/require-totp \
    mfa_method_ids="my-totp" \
    auth_method_accessors="auth_userpass_1234" \
    identity_group_ids="<admin-group-id>"
```

### Duo MFA

```bash
vault write sys/mfa/method/duo/my-duo \
    mount_accessor="auth_userpass_1234" \
    integration_key="<integration-key>" \
    secret_key="<secret-key>" \
    api_hostname="api-xxxxxxxx.duosecurity.com"
```

### MFA Validation

```bash
# Login with MFA
vault write auth/userpass/login/myuser \
    password="password" \
    -mfa="my-totp:123456"
```

---

## Control Groups

Multi-person approval for sensitive operations.

### Configure Control Group

```bash
# Create authorizer policy
vault policy write authorizers - <<EOF
path "secret/data/super-secret/*" {
  capabilities = ["read"]
  control_group = {
    factor "authorizers" {
      identity {
        group_names = ["security-approvers"]
        approvals = 2
      }
    }
  }
}
EOF
```

### Workflow

```bash
# User requests access
vault kv get secret/super-secret/key
# Returns wrapping token, request pending

# Approvers authorize
vault write sys/control-group/authorize accessor="<accessor>"

# After required approvals, unwrap
vault unwrap <wrapping-token>
```

---

## License Management

```bash
# Check license status
vault read sys/license/status

# Install license
vault write sys/license text=@vault.hclic

# Check features
vault read sys/license/features
```

---

## Performance Standby Nodes

Read-only nodes for horizontal scaling.

```bash
# Check node status
vault status

# Performance standby nodes forward writes to active
# Reads are served locally
```

---

## Auto-Unseal Options

### Cloud KMS

```hcl
# Vault config for AWS KMS auto-unseal
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/vault-unseal"
}

# Azure Key Vault
seal "azurekeyvault" {
  tenant_id      = "<tenant-id>"
  vault_name     = "my-keyvault"
  key_name       = "vault-unseal"
}

# GCP Cloud KMS
seal "gcpckms" {
  project     = "my-project"
  region      = "global"
  key_ring    = "vault"
  crypto_key  = "unseal"
}
```

### HSM (Hardware Security Module)

```hcl
seal "pkcs11" {
  lib            = "/usr/lib/softhsm/libsofthsm2.so"
  slot           = "0"
  pin            = "1234"
  key_label      = "vault-hsm-key"
  hmac_key_label = "vault-hsm-hmac"
}
```

---

## KMIP (Key Management Interoperability Protocol)

Manage encryption keys for VMware, NetApp, and other enterprise systems.

```bash
# Enable KMIP engine
vault secrets enable kmip

# Create scope
vault write kmip/scope/vsan -f

# Create role
vault write kmip/scope/vsan/role/admin \
    operation_all=true

# Generate credentials
vault write -f kmip/scope/vsan/role/admin/credential/generate

# Returns certificate and private key for KMIP clients
```

---

## Best Practices

1. **Use namespaces** for tenant isolation
2. **Implement DR replication** for business continuity
3. **Use Sentinel** for complex access requirements
4. **Enable MFA** for privileged operations
5. **Monitor replication lag** with telemetry
6. **Test DR failover** regularly
7. **Use HSM auto-unseal** for security-critical deployments

---

## Additional Resources

- [Enterprise Documentation](https://developer.hashicorp.com/vault/docs/enterprise)
- [Namespaces Tutorial](https://developer.hashicorp.com/vault/tutorials/enterprise/namespaces)
- [Replication Tutorial](https://developer.hashicorp.com/vault/tutorials/enterprise/disaster-recovery)
- [Sentinel Documentation](https://developer.hashicorp.com/vault/docs/enterprise/sentinel)

---

## Related

- [Policies](policies.md) - Sentinel policy configuration
- [Production Operations](production-operations.md) - DR and replication operations
- [Secrets Engines](secrets-engines.md) - Namespace-scoped secrets
