---
name: enterprise-features
description: Configure Vault Enterprise features. Use when asked about namespaces, multi-tenancy, Performance Replication, Disaster Recovery replication, Sentinel policies, MFA (Login or Step-up), Control Groups, or HSM integration. Covers enterprise-only capabilities requiring Vault Enterprise license.
---

# Vault Enterprise Features

Vault Enterprise extends HashiCorp Vault with features for large-scale, regulated, and multi-tenant deployments. All features on this page require a Vault Enterprise license.

## Reference

- [Vault Enterprise Documentation](https://developer.hashicorp.com/vault/docs/enterprise)
- [Detailed Enterprise Reference](references/enterprise.md)

---

## When to Use This Skill

- **Namespaces**: Multi-tenant isolation for business units or teams
- **Replication**: Cross-datacenter sync (Performance or Disaster Recovery)
- **Sentinel**: Policy-as-code for compliance requirements
- **MFA**: Multi-factor authentication for sensitive operations
- **Control Groups**: Approval workflows for privileged actions
- **HSM**: Hardware Security Module integration for key protection

---

## Namespaces

Namespaces provide isolated Vault environments within a single cluster.

### When to Use Namespaces

| Criterion | Use Namespace? |
|-----------|---------------|
| Separate policy administration needed | Yes |
| Different compliance requirements | Yes |
| Distinct business units | Yes |
| Team-level isolation | Maybe (consider policies first) |
| Per-application isolation | No (use policies) |
| Per-environment (dev/prod) | No (use separate clusters) |

### Recommended Architecture

```text
root/
├── shared-services/     # Shared auth, PKI roots
├── business-unit-a/     # LOB-level namespace
│   ├── team-1/          # Max 2-3 levels deep
│   └── team-2/
└── business-unit-b/
```

### Common Operations

```bash
# Create namespace
vault namespace create business-unit-a
vault namespace create -namespace=business-unit-a team-1

# List namespaces
vault namespace list

# Target namespace
export VAULT_NAMESPACE=business-unit-a/team-1
vault secrets list

# Lock namespace (incident response)
vault namespace lock business-unit-a

# Unlock namespace
vault namespace unlock business-unit-a -unlock-key=<key>
```

### Anti-Patterns

- Deep nesting (> 3 levels)
- Namespace per person
- Environment names in paths (dev/staging/prod)
- Namespace per application

### Namespace Limits

| Configuration | Approximate Limit |
|---------------|-------------------|
| Default mount table | ~4,600 namespaces |
| Recommended max depth | 2-3 levels |
| Naming restrictions | No `/`, `\`, `..`, `%`, or `+` |

---

## Replication

### Performance Replication (PR)

Read scaling and geographic distribution. Tokens and leases are NOT replicated.

```bash
# Primary cluster
vault write -f sys/replication/performance/primary/enable

# Get secondary activation token
vault write sys/replication/performance/primary/secondary-token id=region-2

# Secondary cluster
vault write sys/replication/performance/secondary/enable token=<activation-token>
```

### Disaster Recovery (DR)

Business continuity with hot standby. DR cluster is read-only until promoted.

```bash
# Primary cluster
vault write -f sys/replication/dr/primary/enable

# Get secondary activation token  
vault write sys/replication/dr/primary/secondary-token id=dr-site

# Secondary cluster (standby)
vault write sys/replication/dr/secondary/enable token=<activation-token>

# DR Failover (on secondary)
vault write -f sys/replication/dr/secondary/promote
```

### Key Considerations

- Local mounts are NOT replicated
- Batch tokens ARE portable across PR clusters
- Never enable two primaries simultaneously
- Upgrade secondaries BEFORE primary

---

## Sentinel Policies

Policy-as-code for advanced access control beyond ACLs.

### Policy Types

| Type | Scope | Use Case |
|------|-------|----------|
| EGP (Endpoint Governing) | Specific paths | Enforce rules on API endpoints |
| RGP (Role Governing) | Tokens/identities | Apply rules based on who is making request |

### Example: Require MFA for Admin Operations

```python
import "mfa"
import "strings"

# Require MFA for /sys/ operations
precond = rule {
    strings.has_prefix(request.path, "sys/")
}

main = rule when precond {
    mfa.methods.totp.valid
}
```

### Example: Time-Based Restrictions

```python
import "time"

# Only allow writes during business hours
main = rule when request.operation in ["create", "update"] {
    time.now.hour >= 9 and time.now.hour < 17 and
    time.now.weekday_name not in ["Saturday", "Sunday"]
}
```

---

## Multi-Factor Authentication (MFA)

### Login MFA vs Step-up MFA

| Type | When Applied | Use Case |
|------|--------------|----------|
| Login MFA | During authentication | Require MFA for all logins |
| Step-up MFA | During specific operations | Require MFA for sensitive paths only |

### Configure TOTP MFA

```bash
# Enable TOTP MFA method
vault write sys/mfa/method/totp/my-totp \
    issuer=Vault \
    period=30 \
    key_size=20 \
    algorithm=SHA1 \
    digits=6

# Generate admin QR code (Step-up MFA)
vault write sys/mfa/method/totp/my-totp/admin-generate \
    entity_id=<entity-id>
```

---

## Control Groups

Require approval from authorized users before granting access.

```bash
# Create control group policy
vault policy write requires-approval - <<EOF
path "secret/data/sensitive/*" {
  capabilities = ["read"]
  control_group = {
    factor "authorizers" {
      identity {
        group_names = ["security-team"]
        approvals = 2
      }
    }
  }
}
EOF
```

---

## Best Practices

- **Namespaces**: Keep hierarchy flat (2-3 levels max)
- **Replication**: Test DR failover quarterly
- **Sentinel**: Start with audit mode before enforcement
- **MFA**: Use Step-up MFA for sensitive operations only
- **Control Groups**: Require 2+ approvers for critical paths

---

For detailed configuration including HSM integration and advanced replication patterns, see [references/enterprise.md](references/enterprise.md).
