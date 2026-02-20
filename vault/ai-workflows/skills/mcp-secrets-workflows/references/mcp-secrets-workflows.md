---
name: mcp-secrets-workflows-reference
description: Detailed reference for Vault MCP Server tool usage patterns and common secrets management workflows
---

# MCP Secrets Workflows Reference

This reference provides detailed patterns for using Vault MCP Server tools.

---

## MCP Tools Reference

### Mount Management Tools

#### create_mount

Creates a new secrets engine mount in Vault.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | Yes | Mount type: `kv`, `kv2`, `pki` |
| `path` | string | Yes | Mount path (no leading/trailing slashes) |
| `description` | string | No | Human-readable description |

**Examples:**

```
Create a KV v2 mount:
  type: "kv2"
  path: "myapp"
  description: "Application secrets for MyApp"

Create a KV v1 mount:
  type: "kv"
  path: "legacy-app"

Create a PKI mount:
  type: "pki"
  path: "pki-internal"
```

**Notes:**
- Mount paths must be unique
- Cannot create mounts at reserved paths (sys/, auth/, etc.)
- Type `kv2` is recommended over `kv` for versioning

---

#### list_mounts

Lists all secrets engine mounts in Vault.

**Parameters:** None

**Response includes:**
- Mount path
- Type
- Description
- Configuration

**Usage:**
```
"What secrets engines are available?"
"List all mounts"
"Show me the secrets engines"
```

---

#### delete_mount

Deletes a secrets engine mount.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | Mount path to delete |

**Warning:** This permanently deletes all secrets stored in the mount!

**Examples:**

```
Delete a mount:
  path: "old-app"
```

**Notes:**
- Requires appropriate permissions
- Cannot be undone
- All secrets in mount are permanently deleted

---

### Key-Value Tools

#### write_secret

Writes a key-value pair to a secret path.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `mount` | string | Yes | Mount path |
| `path` | string | Yes | Secret path within mount |
| `key` | string | Yes | Key name |
| `value` | string | Yes | Value to store |

**Examples:**

```
Write a single key:
  mount: "myapp"
  path: "config"
  key: "api_key"
  value: "sk_live_abc123"

Write to nested path:
  mount: "myapp"
  path: "databases/postgres"
  key: "password"
  value: "secretpassword"
```

**Notes:**
- KV v2: Creates new version, preserves history
- KV v1: Overwrites existing value
- Multiple keys require multiple write_secret calls

---

#### read_secret

Reads a secret from a path.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `mount` | string | Yes | Mount path |
| `path` | string | Yes | Secret path within mount |

**Examples:**

```
Read a secret:
  mount: "myapp"
  path: "config"

Read nested path:
  mount: "myapp"
  path: "databases/postgres"
```

**Response includes:**
- All key-value pairs at the path
- Metadata (KV v2): version, created_time, etc.

---

#### list_secrets

Lists secret paths under a given path.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `mount` | string | Yes | Mount path |
| `path` | string | No | Path to list (defaults to root) |

**Examples:**

```
List all secrets in mount:
  mount: "myapp"

List under specific path:
  mount: "myapp"
  path: "databases"
```

**Notes:**
- Returns paths, not secret values
- Paths ending with `/` are directories
- Useful for discovery

---

#### delete_secret

Deletes a secret or specific key.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `mount` | string | Yes | Mount path |
| `path` | string | Yes | Secret path |
| `key` | string | No | Specific key to delete |

**Examples:**

```
Delete entire secret:
  mount: "myapp"
  path: "old-config"

Delete specific key:
  mount: "myapp"
  path: "config"
  key: "deprecated_key"
```

**Notes:**
- KV v2: Soft delete (can be undeleted via Vault CLI)
- KV v1: Permanent delete
- Without `key`: deletes entire secret
- With `key`: deletes only that key

---

## Complete Workflow Examples

### Example 1: New Application Setup

Complete workflow for bootstrapping secrets for a new application.

**Goal:** Set up secrets infrastructure for "payments-service"

**Step-by-step:**

```
Step 1: Create dedicated mount
  Tool: create_mount
  Parameters:
    type: "kv2"
    path: "payments-service"
    description: "Secrets for payments microservice"

Step 2: Write database credentials
  Tool: write_secret
  Parameters:
    mount: "payments-service"
    path: "database/postgres"
    key: "host"
    value: "postgres.internal.example.com"

  Tool: write_secret
  Parameters:
    mount: "payments-service"
    path: "database/postgres"
    key: "username"
    value: "payments_app"

  Tool: write_secret
  Parameters:
    mount: "payments-service"
    path: "database/postgres"
    key: "password"
    value: "generated-secure-password"

Step 3: Write API keys
  Tool: write_secret
  Parameters:
    mount: "payments-service"
    path: "integrations/stripe"
    key: "secret_key"
    value: "sk_live_xxx"

  Tool: write_secret
  Parameters:
    mount: "payments-service"
    path: "integrations/stripe"
    key: "webhook_secret"
    value: "whsec_xxx"

Step 4: Verify setup
  Tool: list_secrets
  Parameters:
    mount: "payments-service"
```

---

### Example 2: Secret Rotation

Update existing secrets while maintaining audit trail.

**Goal:** Rotate database password for an application

**Step-by-step:**

```
Step 1: Read current secret (verify path)
  Tool: read_secret
  Parameters:
    mount: "myapp"
    path: "database"

Step 2: Write new password (KV v2 creates new version)
  Tool: write_secret
  Parameters:
    mount: "myapp"
    path: "database"
    key: "password"
    value: "new-secure-password-2024"

Step 3: Verify update
  Tool: read_secret
  Parameters:
    mount: "myapp"
    path: "database"
```

**Note:** Previous version remains accessible via Vault CLI for rollback.

---

### Example 3: Secrets Discovery and Audit

Explore existing secrets structure.

**Goal:** Understand what secrets exist in a mount

**Step-by-step:**

```
Step 1: List all mounts
  Tool: list_mounts

Step 2: List top-level secrets
  Tool: list_secrets
  Parameters:
    mount: "myapp"

Step 3: Explore subdirectories
  Tool: list_secrets
  Parameters:
    mount: "myapp"
    path: "databases"

Step 4: Read specific secrets
  Tool: read_secret
  Parameters:
    mount: "myapp"
    path: "databases/postgres"
```

---

### Example 4: Cleanup Deprecated Secrets

Remove old secrets systematically.

**Goal:** Clean up secrets for decommissioned application

**Step-by-step:**

```
Step 1: Audit existing secrets
  Tool: list_secrets
  Parameters:
    mount: "old-app"

Step 2: Document secrets (for backup purposes)
  Tool: read_secret (for each path)

Step 3: Delete individual secrets
  Tool: delete_secret
  Parameters:
    mount: "old-app"
    path: "config"

  Tool: delete_secret
  Parameters:
    mount: "old-app"
    path: "database"

Step 4: Delete the mount
  Tool: delete_mount
  Parameters:
    path: "old-app"
```

**Warning:** Ensure secrets are no longer needed before deletion!

---

## KV v1 vs KV v2 Behavior

### Write Behavior

| Aspect | KV v1 | KV v2 |
|--------|-------|-------|
| Write same path | Overwrites | Creates new version |
| History | None | Full version history |
| Rollback | Not possible | Restore previous version |

### Delete Behavior

| Aspect | KV v1 | KV v2 |
|--------|-------|-------|
| Default delete | Permanent | Soft delete |
| Recovery | Not possible | Undelete via CLI |
| Permanent delete | Same as delete | Requires "destroy" |

### Path Differences

```
KV v1 API path: secret/myapp/config
KV v2 API path: secret/data/myapp/config

MCP tools abstract this difference - use:
  mount: "secret"
  path: "myapp/config"
```

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "permission denied" | Token lacks policy | Update token policy |
| "no route to host" | Vault unreachable | Check VAULT_ADDR |
| "mount does not exist" | Invalid mount path | Use list_mounts to find |
| "secret not found" | Path doesn't exist | Use list_secrets to explore |

### Required Policies

```hcl
# Policy for full MCP access
path "sys/mounts" {
  capabilities = ["read", "list"]
}

path "sys/mounts/*" {
  capabilities = ["create", "delete", "read", "list"]
}

# For KV v2 secrets
path "+/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "+/metadata/*" {
  capabilities = ["read", "list", "delete"]
}
```

---

## Best Practices

### Security

1. **Minimal permissions**: Use tokens with only required capabilities
2. **Sensitive awareness**: Remember LLM can see secret values
3. **Audit logging**: All operations are logged in Vault audit log
4. **Short TTLs**: Use short-lived tokens for MCP sessions

### Organization

1. **Consistent naming**: Use pattern like `app/environment/type`
2. **Logical grouping**: Group related secrets under same path
3. **Documentation**: Use mount descriptions for discoverability
4. **KV v2 preferred**: Enable versioning for recoverability

### Workflow

1. **Verify before delete**: Always list/read before deleting
2. **Test in dev**: Practice workflows in development first
3. **Backup sensitive**: Document critical secrets before changes
4. **Incremental changes**: Make small, verifiable changes

---

## Additional Resources

- [Vault MCP Server GitHub](https://github.com/hashicorp/vault-mcp-server)
- [KV Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/kv)
- [Vault Policies](https://developer.hashicorp.com/vault/docs/concepts/policies)

---

## Related

- [vault-mcp-server.md](../vault-mcp-server/references/vault-mcp-server.md) - MCP server configuration
- [secrets-engines.md](../../../secrets-management/skills/secrets-engines/references/secrets-engines.md) - Secrets engine configuration
- [policies.md](../../../authentication/skills/policies/references/policies.md) - Policy syntax
