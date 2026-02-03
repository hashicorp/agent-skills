---
name: mcp-secrets-workflows
description: Use Vault MCP Server tools for secrets management workflows. Use when asked about managing secrets with Claude, creating KV mounts via MCP, reading/writing secrets through AI assistants, or automating Vault operations with MCP tools. Covers create_mount, list_mounts, write_secret, read_secret, list_secrets, and delete_secret tool patterns.
---

# MCP Secrets Workflows

This skill covers common secrets management workflows using the Vault MCP Server tools with Claude or other AI assistants.

## Reference

- [Vault MCP Server GitHub](https://github.com/hashicorp/vault-mcp-server)
- [Detailed Workflows Reference](references/mcp-secrets-workflows.md)

---

## When to Use This Skill

- **Mount management**: Creating, listing, and deleting secrets engine mounts
- **Secret operations**: Writing, reading, listing, and deleting secrets
- **Workflow patterns**: Common multi-step operations with MCP tools
- **KV patterns**: Understanding KV v1 vs v2 differences with MCP

---

## Prerequisites

Before using these workflows, ensure:
1. Vault MCP Server is running and connected
2. Your Vault token has appropriate policies
3. Required secrets engines are enabled

---

## Mount Management Tools

### create_mount

Create a new secrets engine mount.

**Parameters:**
- `type` (required): Mount type - `kv`, `kv2`, `pki`
- `path` (required): Mount path
- `description` (optional): Description for the mount

**Example Prompts:**
```
"Create a KV v2 secrets engine at path 'myapp'"
"Set up a new KV mount called 'team-secrets' with description 'Team A secrets'"
```

**Workflow:**
```
1. Tool: create_mount
   - type: "kv2"
   - path: "myapp"
   - description: "Application secrets for MyApp"
```

### list_mounts

List all secrets engine mounts.

**Parameters:** None

**Example Prompts:**
```
"Show me all the secrets engines in Vault"
"What mounts are available?"
```

### delete_mount

Delete a secrets engine mount.

**Parameters:**
- `path` (required): Path of mount to delete

> **Warning**: This permanently deletes all secrets in the mount!

**Example Prompts:**
```
"Delete the secrets engine at path 'old-app'"
"Remove the mount called 'deprecated'"
```

---

## Key-Value Secret Tools

### write_secret

Write a secret to a KV mount.

**Parameters:**
- `mount` (required): Mount path
- `path` (required): Secret path within mount
- `key` (required): Key name
- `value` (required): Value to store

**Example Prompts:**
```
"Store API key 'abc123' at myapp/config"
"Write database password 'secret' to myapp/db-creds"
```

**Workflow:**
```
1. Tool: write_secret
   - mount: "myapp"
   - path: "config"
   - key: "api_key"
   - value: "abc123"
```

### read_secret

Read a secret from a KV mount.

**Parameters:**
- `mount` (required): Mount path
- `path` (required): Secret path within mount

**Example Prompts:**
```
"Read the secrets at myapp/config"
"Get the database credentials from myapp/db-creds"
```

### list_secrets

List secrets under a path.

**Parameters:**
- `mount` (required): Mount path
- `path` (optional): Path to list (defaults to root)

**Example Prompts:**
```
"List all secrets in myapp"
"Show what's under myapp/databases/"
```

### delete_secret

Delete a secret or specific key.

**Parameters:**
- `mount` (required): Mount path
- `path` (required): Secret path
- `key` (optional): Specific key to delete (if omitted, deletes entire secret)

**Example Prompts:**
```
"Delete the secret at myapp/old-config"
"Remove the 'deprecated_key' from myapp/config"
```

---

## Common Workflow Patterns

### Pattern 1: Bootstrap New Application

Complete workflow for setting up secrets for a new application:

```
Step 1: Create a dedicated KV mount
  Tool: create_mount
  - type: "kv2"
  - path: "newapp"
  - description: "NewApp production secrets"

Step 2: Write initial secrets
  Tool: write_secret (multiple calls)
  - mount: "newapp", path: "config", key: "api_key", value: "<key>"
  - mount: "newapp", path: "config", key: "secret_key", value: "<secret>"
  - mount: "newapp", path: "database", key: "connection_string", value: "<conn>"

Step 3: Verify secrets were written
  Tool: list_secrets
  - mount: "newapp"
```

### Pattern 2: Audit Existing Secrets

Discover and review secrets in a mount:

```
Step 1: List all mounts to find target
  Tool: list_mounts

Step 2: List secrets in target mount
  Tool: list_secrets
  - mount: "myapp"

Step 3: Read specific secrets (iterate through paths)
  Tool: read_secret
  - mount: "myapp", path: "config"
  - mount: "myapp", path: "database"
```

### Pattern 3: Rotate a Secret

Update an existing secret value:

```
Step 1: Read current secret to verify path
  Tool: read_secret
  - mount: "myapp"
  - path: "config"

Step 2: Write new value (KV v2 creates new version)
  Tool: write_secret
  - mount: "myapp"
  - path: "config"
  - key: "api_key"
  - value: "<new-value>"

Step 3: Verify update
  Tool: read_secret
  - mount: "myapp"
  - path: "config"
```

### Pattern 4: Clean Up Deprecated Secrets

Remove old secrets systematically:

```
Step 1: List secrets to identify targets
  Tool: list_secrets
  - mount: "legacy-app"

Step 2: Delete individual secrets
  Tool: delete_secret
  - mount: "legacy-app"
  - path: "old-config"

Step 3: Optionally delete entire mount
  Tool: delete_mount
  - path: "legacy-app"
```

---

## KV v1 vs KV v2 Differences

| Aspect | KV v1 | KV v2 |
|--------|-------|-------|
| Versioning | No | Yes (keeps history) |
| Delete behavior | Permanent | Soft delete (can undelete) |
| Metadata | No | Yes (custom_metadata) |
| Check-and-set | No | Yes (cas parameter) |

When using MCP tools:
- Both versions use the same tool parameters
- KV v2 automatically versions writes
- Delete on KV v2 is recoverable via Vault CLI

---

## Required Policies

Ensure your Vault token has appropriate permissions:

```hcl
# Mount management
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# KV v2 secrets
path "myapp/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "myapp/metadata/*" {
  capabilities = ["list", "read", "delete"]
}
```

---

## Best Practices

- **Least privilege**: Use tokens with minimal required permissions
- **Audit trail**: All MCP operations are logged in Vault audit log
- **KV v2 preferred**: Use versioned secrets for recoverability
- **Path conventions**: Use consistent naming (e.g., `app/environment/type`)
- **Sensitive data**: Remember LLM can see secret values - use carefully

---

For detailed workflow examples and advanced patterns, see [references/mcp-secrets-workflows.md](references/mcp-secrets-workflows.md).
