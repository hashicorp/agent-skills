# HashiCorp Agent Skills

A collection of Agent skills and Claude Code plugins for HashiCorp products.

| Product | Use cases |
|:--------|:----------|
| [Terraform](./terraform/) | Write HCL code, build modules, develop providers, and run tests |

> **Legal Note:** Your use of a third party MCP Client/LLM is subject solely to the terms of use for such MCP/LLM, and IBM is not responsible for the performance of such third party tools. IBM expressly disclaims any and all warranties and liability for third party MCP Clients/LLMs, and may not be able to provide support to resolve issues which are caused by the third party tools.

## Installation

### Individual Skills

Install Agent Skills in GitHub Copilot, Claude Code, Opencode, Cursor, and more:

```bash
# List all skills
npx skills add hashicorp/agent-skills

# Install a specific skill
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/terraform-style-guide
```

### Claude Code Plugin

First, add the marketplace, then install plugins:

```bash
# Add the HashiCorp marketplace
claude plugin marketplace add hashicorp/agent-skills

# Install plugins
claude plugin install terraform-code-generation@hashicorp
claude plugin install terraform-module-generation@hashicorp
claude plugin install terraform-provider-development@hashicorp
```

Or use the interactive interface:
```bash
/plugin
```

## Structure

```
agent-skills/
├── .claude-plugin/
│   └── marketplace.json
├── terraform/              # Terraform skills
├── <product>/              # Future products (Vault, Consul, etc.)
└── README.md
```

Each product folder contains plugins, and each plugin contains skills:

```
<product>/
└── <plugin>/
    ├── .claude-plugin/plugin.json
    └── skills/
        └── <skill>/
            └── SKILL.md
```

## License

MPL-2.0
