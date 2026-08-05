# Agent Skills Templates

This directory contains templates, documentation, and automation for adding new HashiCorp products to the agent-skills repository.

## Quick Start

### Using the Slash Command

The fastest way to add a new product:

```
/new-product vault
```

This interactive command walks you through creating a complete product structure with plugins and skills.

### Manual Creation

Follow the step-by-step guide below to create products manually.

---

## Repository Structure

```
agent-skills/
├── .claude-plugin/
│   └── marketplace.json       # Plugin registry (update when adding products)
├── terraform/                  # Example: Terraform product
│   ├── README.md
│   ├── code-generation/        # Plugin: terraform-code-generation
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   │       ├── terraform-style-guide/
│   │       │   └── SKILL.md
│   │       └── terraform-test/
│   │           └── SKILL.md
│   └── provider-development/   # Plugin: terraform-provider-development
│       └── ...
├── packer/                     # Example: Packer product
│   └── ...
├── examples/                   # Templates and documentation (this directory)
│   ├── README.md               # This file
│   ├── spec.md                 # Specification document
│   ├── questionnaire.md        # Questions for automation
│   ├── new-product-template/   # Template files
│   └── commands/
│       └── new-product/        # Slash command
└── scripts/
    └── validate-structure.sh   # Validation script
```

---

## Adding a New Product

### Step 1: Create Product Directory

```bash
mkdir -p vault/secrets-management/.claude-plugin
mkdir -p vault/secrets-management/skills/kv-secrets-engine
```

### Step 2: Create Product README.md

Create `vault/README.md`:

```markdown
# HashiCorp Vault Skills

Agent skills for identity-based secrets and encryption management.

## Plugins

### vault-secrets-management

Skills for storing and managing secrets in Vault.

| Skill | Description |
|-------|-------------|
| `kv-secrets-engine` | Store and retrieve static secrets with KV v2 |

## Installation

### Claude Code Plugin

\`\`\`bash
claude plugin marketplace add hashicorp/agent-skills
claude plugin install vault-secrets-management@hashicorp
\`\`\`

## References

- [Vault Documentation](https://developer.hashicorp.com/vault)
```

### Step 3: Create plugin.json

Create `vault/secrets-management/.claude-plugin/plugin.json`:

```json
{
  "name": "vault-secrets-management",
  "version": "1.0.0",
  "description": "Vault secrets management skills for storing and retrieving secrets.",
  "author": {
    "name": "HashiCorp",
    "url": "https://github.com/hashicorp"
  },
  "homepage": "https://developer.hashicorp.com/vault",
  "repository": "https://github.com/hashicorp/agent-skills",
  "license": "MPL-2.0",
  "keywords": ["vault", "secrets", "kv", "hashicorp"]
}
```

### Step 4: Create SKILL.md

Create `vault/secrets-management/skills/kv-secrets-engine/SKILL.md`:

```markdown
---
name: kv-secrets-engine
description: Store and retrieve static secrets using Vault's KV v2 secrets engine. Use when working with key-value secrets, versioning, or secret metadata.
---

# KV Secrets Engine

Store and manage static secrets with versioning support.

**Reference:** [KV Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/kv)

## Basic Usage

\`\`\`bash
# Write a secret
vault kv put secret/myapp username=admin password=secret

# Read a secret
vault kv get secret/myapp

# List secrets
vault kv list secret/
\`\`\`

## References

- [KV v2 Documentation](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2)
```

### Step 5: Update marketplace.json

Add your plugins to `.claude-plugin/marketplace.json`:

```json
{
  "name": "vault-secrets-management",
  "source": "./vault/secrets-management",
  "description": "Vault secrets management skills for storing and retrieving secrets.",
  "version": "1.0.0",
  "author": {
    "name": "HashiCorp"
  },
  "keywords": ["vault", "secrets", "kv", "hashicorp"],
  "category": "integration",
  "license": "MPL-2.0",
  "strict": false
}
```

### Step 6: Validate

```bash
./scripts/validate-structure.sh
```

---

## Adding a Plugin to an Existing Product

1. Create plugin directory: `{product}/{use-case}/`
2. Create `.claude-plugin/plugin.json`
3. Create `skills/` subdirectory
4. Add at least one skill
5. Update marketplace.json
6. Update product README.md

---

## Adding a Skill to an Existing Plugin

1. Create skill directory: `{product}/{use-case}/skills/{skill-name}/`
2. Create `SKILL.md` with frontmatter
3. Update plugin's skill table in product README.md

---

## SKILL.md Frontmatter Reference

### Required Fields

```yaml
---
name: skill-name
description: When to use this skill. Claude uses this to decide when to apply it.
---
```

### Optional Fields

```yaml
---
name: skill-name
description: Skill description
disable-model-invocation: true    # Only user can invoke (for task skills)
user-invocable: false             # Only Claude can invoke (for background knowledge)
allowed-tools: Read, Grep, Bash(vault *)  # Tool restrictions
context: fork                     # Run in subagent
agent: Explore                    # Subagent type (with context: fork)
argument-hint: "[secret-path]"    # Autocomplete hint
---
```

### Custom Fields (HashiCorp)

These fields are not part of the official spec but are used in this repository:

```yaml
metadata:
  copyright: Copyright HashiCorp 2026
  version: "1.0.0"
license: MPL-2.0
```

---

## plugin.json Reference

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `name` | Plugin identifier | `vault-secrets-management` |
| `version` | Semantic version | `1.0.0` |
| `description` | What the plugin provides | `Skills for managing Vault secrets` |
| `author.name` | Author name | `HashiCorp` |
| `homepage` | Documentation URL | `https://developer.hashicorp.com/vault` |
| `repository` | Source repository | `https://github.com/hashicorp/agent-skills` |
| `license` | License identifier | `MPL-2.0` |
| `keywords` | Discoverability tags | `["vault", "secrets"]` |

### Optional Fields

| Field | Description |
|-------|-------------|
| `author.url` | Author URL |
| `mcpServers` | MCP server configuration |

### MCP Server Configuration

```json
{
  "mcpServers": {
    "vault": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "hashicorp/vault-mcp-server"],
      "env": {
        "VAULT_ADDR": "${VAULT_ADDR}",
        "VAULT_TOKEN": "${VAULT_TOKEN}"
      }
    }
  }
}
```

---

## Skill Types

### Reference Skills

Provide knowledge Claude applies to your work. No side effects.

```yaml
---
name: terraform-style-guide
description: Generate Terraform HCL following HashiCorp conventions.
---
```

### Task Skills

Perform actions like file creation or command execution. Add `disable-model-invocation: true` to prevent Claude from triggering automatically.

```yaml
---
name: new-terraform-provider
description: Scaffold a new Terraform provider project.
disable-model-invocation: true
---
```

---

## Supporting Files

Skills can include additional files:

```
my-skill/
├── SKILL.md           # Main instructions (required)
├── assets/            # Code templates, examples
│   └── main.go
├── references/        # Detailed documentation
│   └── api-reference.md
└── examples/          # Usage examples
    └── basic-usage.md
```

Reference these from SKILL.md:

```markdown
See [assets/main.go](assets/main.go) for the template.
```

---

## Validation

The repository includes validation that runs on every PR:

```bash
# Run locally before committing
./scripts/validate-structure.sh
```

### What's Validated

- marketplace.json is valid JSON with required fields
- All referenced plugin paths exist
- All plugins have plugin.json with required fields
- All plugins have skills/ directory with at least one skill
- All SKILL.md files have valid frontmatter with name and description

---

## Files in This Directory

| File | Purpose |
|------|---------|
| `README.md` | This guide |
| `spec.md` | Spec-Kit format specification with user stories |
| `questionnaire.md` | All questions needed for product creation |
| `new-product-template/` | Template files with placeholders |
| `commands/new-product/` | Slash command implementation |
| `.claude-plugin/plugin.json` | Plugin definition for templates |
