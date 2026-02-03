---
name: vault-policies
description: Detailed guidance on writing and managing Vault ACL policies and Sentinel policies
---

# Vault Policies

This reference provides detailed guidance on writing and managing Vault policies.

---

## Overview

Policies define **what actions** are allowed on **which paths**. They are written in HCL (HashiCorp Configuration Language) and attached to tokens via authentication.

### Policy Evaluation

- **Default deny**: If no policy grants access, the operation is denied
- **Additive**: Multiple policies combine permissions (most permissive wins)
- **Root token**: Bypasses all policy checks (avoid in production)

---

## Policy Syntax

### Basic Structure

```hcl
# Comment describing the policy
path "<path-pattern>" {
  capabilities = ["<capability>", ...]
}
```

### Capabilities

| Capability | HTTP Verb | Description |
| ------------ | ----------- | ------------- |
| `create` | POST | Create new data |
| `read` | GET | Read data |
| `update` | POST/PUT | Modify existing data |
| `delete` | DELETE | Delete data |
| `list` | LIST | List keys at path |
| `sudo` | - | Access protected endpoints |
| `deny` | - | Explicitly deny (overrides all) |

---

## Path Patterns

> **Important for KV v2**: Policy paths must include `/data/` for secrets access.
> For example, if your secret is at `secret/myapp/config`, the policy path is `secret/data/myapp/config`.
> The CLI hides this, but policies require the full path.

### Exact Match

```hcl
# Only matches exactly secret/data/myapp/config
path "secret/data/myapp/config" {
  capabilities = ["read"]
}
```

### Glob Patterns

```hcl
# Matches any immediate child
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

# Matches all descendants (recursive)
path "secret/data/myapp/+" {
  capabilities = ["read"]
}
```

### Segment Wildcards

```hcl
# + matches exactly one path segment
path "secret/data/+/config" {
  capabilities = ["read"]
}
# Matches: secret/data/app1/config, secret/data/app2/config
# Not: secret/data/app1/nested/config
```

---

## Common Policy Examples

### Application Read-Only

```hcl
# Read application secrets
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

# Allow token self-management
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
```

### Application Read-Write

```hcl
path "secret/data/myapp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/myapp/*" {
  capabilities = ["read", "list", "delete"]
}
```

### Database Credentials

```hcl
# Generate dynamic database credentials
path "database/creds/readonly" {
  capabilities = ["read"]
}

# Manage leases
path "sys/leases/renew" {
  capabilities = ["update"]
}

path "sys/leases/revoke" {
  capabilities = ["update"]
}
```

### AWS Credentials

```hcl
path "aws/creds/deploy" {
  capabilities = ["read"]
}

path "aws/sts/deploy" {
  capabilities = ["read"]
}
```

### PKI Certificate Issuance

```hcl
# Issue certificates
path "pki_int/issue/web-servers" {
  capabilities = ["create", "update"]
}

# Read CA certificate
path "pki_int/ca/pem" {
  capabilities = ["read"]
}

path "pki_int/cert/ca" {
  capabilities = ["read"]
}
```

### Transit Encryption

```hcl
# Encrypt data
path "transit/encrypt/my-key" {
  capabilities = ["update"]
}

# Decrypt data
path "transit/decrypt/my-key" {
  capabilities = ["update"]
}
```

### Admin Policy

```hcl
# Full access to secrets
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage auth methods
path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage secrets engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Access audit logs
path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
```

---

## Templated Policies

Use identity information to create dynamic policies.

### Entity Templates

```hcl
# Each entity gets their own path
path "secret/data/users/{{identity.entity.id}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Use entity name
path "secret/data/teams/{{identity.entity.name}}/*" {
  capabilities = ["read", "list"]
}
```

### Entity Metadata

```hcl
# Use custom metadata
path "secret/data/projects/{{identity.entity.metadata.project}}/*" {
  capabilities = ["read"]
}
```

### Group Templates

```hcl
# Group-based access
path "secret/data/groups/{{identity.groups.names}}/*" {
  capabilities = ["read", "list"]
}
```

### Auth Method Templates

```hcl
# Access based on auth method alias
path "secret/data/{{identity.entity.aliases.auth_kubernetes.metadata.service_account_namespace}}/*" {
  capabilities = ["read"]
}
```

---

## Required Parameters

Restrict which keys can be set.

```hcl
path "secret/data/restricted/*" {
  capabilities = ["create", "update"]
  required_parameters = ["reason", "requester"]
}
```

---

## Allowed Parameters

Limit which keys can be written.

```hcl
path "secret/data/config/*" {
  capabilities = ["create", "update"]
  allowed_parameters = {
    "data" = ["username", "password", "api_key"]
  }
}
```

---

## Denied Parameters

Prevent specific keys from being set.

```hcl
path "secret/data/*" {
  capabilities = ["create", "update"]
  denied_parameters = {
    "data" = ["admin_password", "root_key"]
  }
}
```

> **Note**: Parameter constraints (`required_parameters`, `allowed_parameters`, `denied_parameters`)
> only apply to `create` and `update` operations. They cannot restrict `read` access to specific fields.

---

## Min/Max Wrapping TTL

Control response wrapping to ensure secrets are consumed securely.

```hcl
path "secret/data/sensitive/*" {
  capabilities = ["read"]
  min_wrapping_ttl = "1m"
  max_wrapping_ttl = "10m"
}
```

### Response Wrapping Best Practices

| Setting              | Purpose                     | Recommended Value |
| -------------------- | --------------------------- | ----------------- |
| `min_wrapping_ttl`   | Prevent unwrapped responses | 60s or higher     |
| `max_wrapping_ttl`   | Limit exposure window       | 10-15 minutes max |

```hcl
# Force wrapping for AppRole secret_id retrieval (Trusted Broker pattern)
path "auth/approle/role/+/secret-id" {
  capabilities = ["update"]
  min_wrapping_ttl = "60s"
  max_wrapping_ttl = "300s"
}
```

---

## CI/CD Pipeline Policies

### Trusted Broker Pattern Policies

Based on the AppRole Trusted Broker architecture pattern:

#### Controller/Orchestrator Policy

The CI/CD controller (Jenkins master, GitLab coordinator) needs:

```hcl
# Policy: cicd-controller
# Purpose: Allow CI controller to fetch wrapped secret_ids for jobs

# Read role-id (public, can be in config)
path "auth/approle/role/+/role-id" {
  capabilities = ["read"]
}

# Generate wrapped secret-id (MUST be wrapped)
path "auth/approle/role/+/secret-id" {
  capabilities = ["update"]
  min_wrapping_ttl = "60s"
  max_wrapping_ttl = "300s"
}

# Lookup wrapping token info (for validation)
path "sys/wrapping/lookup" {
  capabilities = ["update"]
}
```

#### Worker/Runner Policy

Individual build agents get limited, wrapped credentials:

```hcl
# Policy: cicd-worker
# Purpose: Application-specific access for build jobs

# Read application secrets
path "secret/data/apps/{{identity.entity.metadata.app_name}}/*" {
  capabilities = ["read"]
}

# Get dynamic database credentials for testing
path "database/creds/ci-readonly" {
  capabilities = ["read"]
}

# Manage own leases
path "sys/leases/renew-self" {
  capabilities = ["update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

#### Jenkins Integration Example

```hcl
# Policy: jenkins-master
# Jenkins master distributes credentials to agents

path "auth/approle/role/jenkins-agent-*/secret-id" {
  capabilities = ["update"]
  min_wrapping_ttl = "120s"
  max_wrapping_ttl = "300s"
}

path "auth/approle/role/jenkins-agent-*/role-id" {
  capabilities = ["read"]
}

# Token introspection for cleanup
path "auth/token/lookup-accessor" {
  capabilities = ["update"]
}

path "auth/token/revoke-accessor" {
  capabilities = ["update"]
}
```

### GitHub Actions Integration

```hcl
# Policy: github-actions
# For GitHub Actions OIDC integration

# Read secrets for the repository
path "secret/data/github/{{identity.entity.aliases.auth_jwt.metadata.repository}}/*" {
  capabilities = ["read"]
}

# Environment-specific paths
path "secret/data/github/{{identity.entity.aliases.auth_jwt.metadata.repository}}/{{identity.entity.aliases.auth_jwt.metadata.environment}}/*" {
  capabilities = ["read"]
}
```

### GitLab CI Integration

```hcl
# Policy: gitlab-ci
# For GitLab CI JWT integration

path "secret/data/gitlab/{{identity.entity.aliases.auth_jwt.metadata.project_path}}/*" {
  capabilities = ["read"]
}

# Restrict to protected branches only
# (Combine with Sentinel for branch checks)
```

---

## Policy Anti-Patterns to Avoid

| Anti-Pattern | Problem | Correct Approach |
| -------------- | --------- | ------------------ |
| `path "*"` | Too broad, security risk | Use specific paths |
| `capabilities = ["sudo"]` everywhere | Bypasses controls | Only for sys/ paths that require it |
| Sharing policies across apps | Violates least privilege | One policy per app/role |
| Hardcoded paths | Doesn't scale | Use templated policies |
| No `min_wrapping_ttl` on secret-id | Secrets in plain text | Always wrap secret-id |

---

## Policy Management Commands

```bash
# Write policy from file
vault policy write app-policy app-policy.hcl

# Write policy inline
vault policy write test-policy - <<EOF
path "secret/data/test/*" {
  capabilities = ["read"]
}
EOF

# List policies
vault policy list

# Read policy
vault policy read app-policy

# Delete policy
vault policy delete app-policy

# Format policy file
vault policy fmt app-policy.hcl
```

---

## Debugging Policies

### Check Token Capabilities

```bash
# Check what your token can do
vault token capabilities secret/data/myapp/config

# Check specific token
vault token capabilities -accessor <accessor> secret/data/myapp/config
```

### Lookup Token Policies

```bash
vault token lookup
# Shows attached policies

vault token lookup -accessor <accessor>
```

### Common Issues

**Permission denied on valid path**:

- Check KV v2 paths include `/data/` segment
- Verify policy uses correct path pattern
- Check for `deny` capability in other policies

**Can list but not read**:

- `list` and `read` are separate capabilities
- Add `read` capability to policy

**Wildcard not matching**:

- `*` matches immediate children only
- Use `+` for recursive matching

---

## Sentinel Policies (Enterprise)

Fine-grained policy-as-code using Sentinel language.

### Endpoint Governing Policies (EGP)

Applied to specific paths.

```sentinel
# Require MFA for sensitive paths
import "mfa"

main = rule {
  mfa.methods.totp.valid
}
```

### Role Governing Policies (RGP)

Applied to specific identities.

```sentinel
# Restrict access by time
import "time"

main = rule {
  time.now.hour >= 9 and time.now.hour < 17
}
```

### Sentinel Policy Management

```bash
# Write Sentinel policy
vault write sys/policies/egp/business-hours \
    policy=@policy.sentinel \
    paths="secret/data/prod/*" \
    enforcement_level="hard-mandatory"

# Enforcement levels: advisory, soft-mandatory, hard-mandatory
```

---

## Best Practices

1. **Principle of least privilege**: Grant minimum necessary access
2. **Use path patterns**: Avoid overly broad wildcards
3. **Separate policies by function**: Don't combine unrelated permissions
4. **Use templates**: Leverage identity templating for scalability
5. **Test policies**: Verify with `vault token capabilities`
6. **Version control**: Store policies in git
7. **Document policies**: Include comments explaining intent
8. **Regular audits**: Review policies periodically
9. **Use Sentinel**: Add business logic for complex requirements (Enterprise)

---

## Additional Resources

- [Policies Documentation](https://developer.hashicorp.com/vault/docs/concepts/policies)
- [Policy Tutorial](https://developer.hashicorp.com/vault/tutorials/policies)
- [Sentinel Documentation](https://developer.hashicorp.com/vault/docs/enterprise/sentinel)

---

## Related

- [Auth Methods](auth-methods.md) - Authentication methods that policies attach to
- [Secrets Engines](secrets-engines.md) - Paths that policies protect
- [Enterprise](enterprise.md) - Sentinel policies and namespaces
