---
name: new-product
description: Scaffold a new HashiCorp product with plugins and skills in the agent-skills repository. Use when adding a new product like Vault, Consul, Nomad, or Boundary.
disable-model-invocation: true
argument-hint: "[product-name]"
---

# New Product Generator

Generate a complete product structure for the agent-skills repository.

## Prerequisites

- You are in the agent-skills repository root
- You have write access to create directories and files
- You know the product details (name, use cases, skills)

## Process

Follow these steps to create a new product. Ask the user for each piece of information.

### Step 1: Gather Product Information

Ask the user:

1. **Product name** (lowercase, no spaces): e.g., `vault`, `consul`, `nomad`
2. **Display name**: e.g., `HashiCorp Vault`
3. **Short description**: One sentence describing the product
4. **Documentation homepage**: URL to developer.hashicorp.com

### Step 2: Define Use Cases (Plugins)

For each plugin the user wants to create, ask:

1. **Use case name** (lowercase, hyphens): e.g., `secrets-management`
2. **Plugin description**: What skills in this plugin help with
3. **Keywords**: Tags for discoverability (comma-separated)
4. **MCP server needed?**: If yes, gather command, args, env vars

Repeat until user says they're done adding plugins.

### Step 3: Define Skills

For each plugin, ask about skills:

1. **Skill name** (lowercase, hyphens): e.g., `kv-secrets-engine`
2. **Display title**: e.g., `KV Secrets Engine`
3. **Description**: When Claude should use this skill
4. **Primary reference URL**: Link to official documentation
5. **Is this a task skill?**: If yes, add `disable-model-invocation: true`

Repeat until user says they're done adding skills to this plugin.

### Step 4: Generate Structure

Create the following structure:

```
{product}/
├── README.md
├── {use-case-1}/
│   ├── .claude-plugin/
│   │   └── plugin.json
│   └── skills/
│       ├── {skill-1}/
│       │   └── SKILL.md
│       └── {skill-2}/
│           └── SKILL.md
└── {use-case-2}/
    └── ...
```

#### 4.1 Create Product README.md

```markdown
# {Display Name} Skills

Agent skills for {short description}.

## Plugins

### {plugin-name}

{plugin description}

| Skill | Description |
|-------|-------------|
| `{skill-name}` | {skill description} |

## Installation

### Claude Code Plugin

\`\`\`bash
claude plugin marketplace add hashicorp/agent-skills

claude plugin install {plugin-name}@hashicorp
\`\`\`

### Individual Skills

\`\`\`bash
npx skills add hashicorp/agent-skills/{product}/{use-case}/skills/{skill-name}
\`\`\`

## References

- [{Display Name} Documentation]({homepage})
```

#### 4.2 Create plugin.json for Each Plugin

```json
{
  "name": "{product}-{use-case}",
  "version": "1.0.0",
  "description": "{plugin description}",
  "author": {
    "name": "HashiCorp",
    "url": "https://github.com/hashicorp"
  },
  "homepage": "{product homepage}",
  "repository": "https://github.com/hashicorp/agent-skills",
  "license": "MPL-2.0",
  "keywords": [{keywords as JSON array}]
}
```

#### 4.3 Create SKILL.md for Each Skill

```markdown
---
name: {skill-name}
description: {skill description}
---

# {Skill Title}

{Brief introduction based on description}

**Reference:** [{Reference Title}]({reference URL})

## Overview

TODO: Add overview content

## Usage

TODO: Add usage examples

## Common Issues

TODO: Add troubleshooting

## References

- [{Reference Title}]({reference URL})
```

### Step 5: Update marketplace.json

Add entries for each new plugin to `.claude-plugin/marketplace.json`:

```json
{
  "name": "{product}-{use-case}",
  "source": "./{product}/{use-case}",
  "description": "{plugin description}",
  "version": "1.0.0",
  "author": {
    "name": "HashiCorp"
  },
  "keywords": [{keywords}],
  "category": "integration",
  "license": "MPL-2.0",
  "strict": false
}
```

### Step 6: Validate

Run validation to ensure structure is correct:

```bash
./scripts/validate-structure.sh
```

Fix any errors before committing.

### Step 7: Update Documentation

1. Add product to root README.md product table
2. Update CHANGELOG.md with new plugins and skills

## Output Summary

After completion, report:

- Number of plugins created
- Number of skills created
- Files created (list)
- Validation status
- Next steps (fill in TODO sections, run tests)

## Reference

See [examples/questionnaire.md](../questionnaire.md) for the complete list of questions.
See [examples/spec.md](../spec.md) for acceptance criteria.
