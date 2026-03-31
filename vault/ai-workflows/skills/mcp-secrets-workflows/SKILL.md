---
name: mcp-secrets-workflows
description: Use Vault MCP Server tools for secrets workflows. Use when asked to create mounts, read/write KV secrets, list existing secrets, rotate values, or clean up deprecated paths through an AI assistant. Covers create_mount, list_mounts, write_secret, read_secret, list_secrets, delete_secret, and delete_mount.
---

# MCP Secrets Workflows

## What Are You Trying to Solve?

### "I need a new secrets mount for an app"
Use `create_mount`, then verify with `list_mounts`.

### "I need to store or retrieve secrets"
Use `write_secret`, `read_secret`, and `list_secrets`.

### "I need to rotate a credential safely"
Use read -> write -> verify sequence.

### "I need to remove deprecated secrets"
Use explicit pre-delete checks before `delete_secret` or `delete_mount`.

## Quick Tool Map

| Goal | Primary tools |
|------|---------------|
| Create mount | `create_mount`, `list_mounts` |
| Read/write values | `write_secret`, `read_secret` |
| Discover paths | `list_secrets`, `list_mounts` |
| Rotate value | `read_secret`, `write_secret`, `read_secret` |
| Delete key/path | `delete_secret` |
| Delete entire mount | `delete_mount` |

## Workflow Patterns

### Pattern 1: Bootstrap New App Secrets

1. Create mount: `create_mount(type=kv2, path=<app>)`
2. Write initial values with `write_secret`
3. Verify written paths with `list_secrets`

Use `kv2` by default for versioning and recovery options.

### Pattern 2: Audit Existing Secrets

1. Enumerate mounts with `list_mounts`
2. Enumerate paths with `list_secrets`
3. Read selected paths with `read_secret`

Prefer listing before reading to avoid guessing paths.

### Pattern 3: Rotate a Secret

1. Read current secret (`read_secret`) to confirm path and key names
2. Write new value (`write_secret`)
3. Re-read (`read_secret`) to verify update

For production rotation, coordinate with downstream consumers before write.

### Pattern 4: Cleanup Deprecated Secrets (Destructive)

1. Verify target scope with `list_secrets`
2. Confirm no active consumers
3. Delete specific values (`delete_secret`) first
4. Delete mount (`delete_mount`) only when fully unused

Do not run `delete_mount` until steps 1-3 are complete and acknowledged.

## Safety Checklist for Destructive Operations

Before `delete_secret` or `delete_mount`, confirm:

- Target path is correct and explicitly listed
- Secret or mount is no longer used by applications or jobs
- Recovery plan exists (for KV v1, deletion is permanent)
- Caller explicitly approved deletion

## Output Expectations

When assisting users, return:

- What changed (mount/path/key)
- What was verified
- Any follow-up action required by operators or apps

## References

- For full parameter tables, examples, and advanced scenarios, see [references/mcp-secrets-workflows.md](references/mcp-secrets-workflows.md)
- For MCP server setup and transport/security configuration, see [../vault-mcp-server/SKILL.md](../vault-mcp-server/SKILL.md)
