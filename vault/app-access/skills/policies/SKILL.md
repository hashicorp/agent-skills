---
name: policies
description: Write Vault HCL policies for access control. Use when asked about ACL policies, policy syntax, capabilities (read, write, list, delete, sudo), templated policies, path patterns, Sentinel policies (Enterprise), or troubleshooting permission denied errors.
---

# Vault Policies

## What Are You Trying to Solve?

### "My app needs read-only access to specific secrets"
→ Create a **scoped application policy**. [Jump to Application Policy](#application-policy)

### "I'm getting 'permission denied' errors"
→ Debug using **capabilities check and audit logs**. [Jump to Debugging](#debugging-policies)

### "Each user/team needs their own secret namespace"
→ Use **templated policies** with identity. [Jump to Templated Policies](#templated-policies)

### "I need operators to manage Vault without root access"
→ Create an **operator policy** with limited sudo. [Jump to Operator Policy](#operator-policy)

### "CI/CD needs secrets but shouldn't modify production"
→ Create a **CI/CD policy with deny rules**. [Jump to CI/CD Policy](#cicd-pipeline-policy)

---

## How Vault Policies Work

1. **Define paths** → Specify API paths the policy controls (`secret/data/myapp/*`)
2. **Grant capabilities** → What operations are allowed (read, create, update, delete, list)
3. **Attach to tokens** → Policies bind to tokens via auth methods or directly
4. **Evaluate on request** → Vault checks all attached policies; any match = allowed (except deny)

**Key insight:** Policies are *default deny*. If no policy grants access to a path, access is denied.

---

## Capability Reference

| Capability | Description | Common Use |
|------------|-------------|------------|
| `read` | Read data from path | Apps reading secrets |
| `create` | Create new data | First write to path |
| `update` | Modify existing data | Update secrets |
| `delete` | Delete data | Cleanup, rotation |
| `list` | List paths | Browse secret tree |
| `sudo` | Override deny, root paths | Operators (seal/unseal) |
| `deny` | Explicitly block (overrides all) | Protect sensitive paths |

---

## Reference

- [Vault Policies Documentation](https://developer.hashicorp.com/vault/docs/concepts/policies)
- For complete policy syntax and advanced templating patterns, see [references/policies.md](references/policies.md)

---

## Quick Reference

### Basic Policy Structure

```hcl
# Allow read access to application secrets
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

# Allow dynamic database credentials
path "database/creds/readonly" {
  capabilities = ["read"]
}

# Deny access to admin secrets
path "secret/data/admin/*" {
  capabilities = ["deny"]
}
```

### KV v2 Policy Paths

KV v2 requires `/data/` in the path:

```hcl
# Read secrets (note: /data/ prefix for actual secrets)
path "secret/data/myapp/*" {
  capabilities = ["read"]
}

# List secrets (uses /metadata/ prefix)
path "secret/metadata/myapp/*" {
  capabilities = ["list"]
}

# Full access to KV v2
path "secret/data/myapp/*" {
  capabilities = ["create", "read", "update", "delete"]
}
path "secret/metadata/myapp/*" {
  capabilities = ["list", "read", "delete"]
}
```

### Templated Policies

Use identity information for dynamic paths:

```hcl
# Each user gets their own secret namespace
path "secret/data/users/{{identity.entity.name}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Team-based access using groups
path "secret/data/teams/{{identity.groups.names}}/*" {
  capabilities = ["read", "list"]
}
```

---

## Common Patterns

### Application Policy

```hcl
# Typical application policy
path "secret/data/myapp/config" {
  capabilities = ["read"]
}

path "database/creds/myapp-readonly" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
```

### Operator Policy

```hcl
# Operations team policy
path "sys/health" {
  capabilities = ["read"]
}

path "sys/policies/*" {
  capabilities = ["read", "list"]
}

path "auth/*" {
  capabilities = ["read", "list"]
}

# Seal/unseal requires sudo
path "sys/seal" {
  capabilities = ["sudo", "update"]
}
```

### CI/CD Pipeline Policy

```hcl
# Read secrets for deployment
path "secret/data/deployment/*" {
  capabilities = ["read"]
}

# Generate cloud credentials
path "aws/creds/deploy" {
  capabilities = ["read"]
}

# No write access to production secrets
path "secret/data/production/*" {
  capabilities = ["deny"]
}
```

---

## Policy Management

```bash
# Create/update policy from file
vault policy write app-policy policy.hcl

# List policies
vault policy list

# Read policy
vault policy read app-policy

# Delete policy
vault policy delete app-policy

# Check token capabilities
vault token capabilities secret/data/myapp
```

---

## Debugging Policies

```bash
# Check current token's policies
vault token lookup

# Test capabilities for a specific path
vault token capabilities secret/data/myapp/config

# Enable audit logging to see denied requests
vault audit enable file file_path=/var/log/vault-audit.log
```

Common issues:
- **KV v2**: Policy path needs `/data/` but CLI doesn't (`vault kv get secret/myapp`)
- **Missing `list`**: Need `list` capability to see path contents
- **Glob patterns**: `*` matches within a path segment, use explicit paths when possible

---

## Best Practices

- **Least privilege**: Start with minimal permissions, add as needed
- **Use templated policies** for user/team-specific paths
- **Separate policies by use case** (app, operator, admin)
- **Test policies** before applying to production
- **Enable audit logging** to track access patterns

---

For advanced patterns including Sentinel policies (Enterprise), response wrapping policies, and CI/CD integration, see [references/policies.md](references/policies.md).
