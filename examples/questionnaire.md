# Product Template Questionnaire

This document lists all questions that must be answered to generate a new product, plugin, or skill using the template system. Use this as a checklist when adding new content.

---

## Adding a New Product

Answer these questions to create a complete product structure.

### Product Metadata

| Question | Field | Example |
|----------|-------|---------|
| What is the product identifier? (lowercase, no spaces) | `PRODUCT_NAME` | `vault` |
| What is the display name? | `PRODUCT_DISPLAY_NAME` | `HashiCorp Vault` |
| What does this product do? (one sentence) | `PRODUCT_DESCRIPTION_SHORT` | `Identity-based secrets and encryption management` |
| What is the documentation homepage? | `PRODUCT_HOMEPAGE` | `https://developer.hashicorp.com/vault` |

### Use Cases (Plugins)

For each plugin in the product:

| Question | Field | Example |
|----------|-------|---------|
| What use case does this plugin address? | `USE_CASE` | `secrets-management` |
| What is the full plugin name? | `PLUGIN_NAME` | `vault-secrets-management` |
| What do the skills in this plugin help with? | `PLUGIN_DESCRIPTION` | `Skills for storing and retrieving secrets in Vault` |
| What keywords describe this plugin? | `KEYWORDS` | `vault`, `secrets`, `kv`, `dynamic-credentials` |
| Does this plugin need an MCP server? | `MCP_SERVER` | See MCP section below |

### Skills

For each skill in a plugin:

| Question | Field | Example |
|----------|-------|---------|
| What is the skill identifier? (lowercase, hyphens) | `SKILL_NAME` | `kv-secrets-engine` |
| What is the display title? | `SKILL_TITLE` | `KV Secrets Engine` |
| When should Claude use this skill? | `SKILL_DESCRIPTION` | `Use when storing static secrets, reading KV paths, or configuring KV v2 versioning` |
| What is the primary documentation reference? | `REFERENCE_URL` | `https://developer.hashicorp.com/vault/docs/secrets/kv` |
| Is this a task skill (performs actions)? | `DISABLE_MODEL_INVOCATION` | `true` for tasks, omit for reference |
| What tools does this skill need? | `ALLOWED_TOOLS` | `Read, Grep, Bash(vault *)` |
| What are the main sections? | Content outline | See below |

---

## Skill Content Outline

For each skill, outline the main sections:

```markdown
## Section 1: [Title]
- What concepts to cover
- What commands/examples to include

## Section 2: [Title]
- Configuration examples
- Code snippets

## Common Issues
- Issue 1: [Description] → [Solution]
- Issue 2: [Description] → [Solution]

## Best Practices
- Practice 1
- Practice 2

## References
- [Title](URL)
```

---

## MCP Server Configuration (Optional)

If the plugin integrates with an MCP server:

| Question | Field | Example |
|----------|-------|---------|
| What is the MCP server name? | `MCP_SERVER_NAME` | `vault` |
| What command runs the server? | `MCP_COMMAND` | `docker` |
| What arguments does it need? | `MCP_ARGS` | `["run", "-i", "--rm", "hashicorp/vault-mcp-server"]` |
| What environment variables? | `MCP_ENV` | `VAULT_ADDR`, `VAULT_TOKEN` |

---

## Validation Checklist

Before submitting, verify:

- [ ] Product directory name matches `PRODUCT_NAME`
- [ ] All plugin directories have `.claude-plugin/plugin.json`
- [ ] All plugin directories have `skills/` subdirectory
- [ ] All skills have `SKILL.md` with valid frontmatter
- [ ] SKILL.md frontmatter includes `name` and `description`
- [ ] marketplace.json updated with all new plugins
- [ ] `scripts/validate-structure.sh` passes
- [ ] Product README.md lists all plugins and skills

---

## Quick Reference: Required vs Optional

### Required Fields

**plugin.json:**
- `name`
- `version`
- `description`
- `author.name`
- `homepage`
- `repository`
- `license`
- `keywords`

**SKILL.md frontmatter:**
- `name`
- `description`

### Optional Fields

**plugin.json:**
- `author.url`
- `mcpServers`

**SKILL.md frontmatter:**
- `disable-model-invocation`
- `user-invocable`
- `allowed-tools`
- `context`
- `agent`
- `argument-hint`
- `metadata.copyright`
- `metadata.version`

---

## Example: Vault Secrets Management

```yaml
# Product
PRODUCT_NAME: vault
PRODUCT_DISPLAY_NAME: HashiCorp Vault
PRODUCT_DESCRIPTION_SHORT: Identity-based secrets and encryption management
PRODUCT_HOMEPAGE: https://developer.hashicorp.com/vault

# Plugin
USE_CASE: secrets-management
PLUGIN_NAME: vault-secrets-management
PLUGIN_DESCRIPTION: Skills for storing and managing secrets in Vault
KEYWORDS: [vault, secrets, kv, dynamic-credentials, transit, pki]

# Skill
SKILL_NAME: kv-secrets-engine
SKILL_TITLE: KV Secrets Engine
SKILL_DESCRIPTION: Use when storing static secrets, reading KV paths, managing versions, or configuring KV v2 secret engine.
REFERENCE_URL: https://developer.hashicorp.com/vault/docs/secrets/kv
```
