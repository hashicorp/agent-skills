# HashiCorp Agent Skills

A collection of Agent skills and Claude Code plugins for HashiCorp products.

> **Legal Note:** Your use of a third party MCP Client/LLM is subject solely to the terms of use for such MCP/LLM, and IBM is not responsible for the performance of such third party tools. IBM expressly disclaims any and all warranties and liability for third party MCP Clients/LLMs, and may not be able to provide support to resolve issues which are caused by the third party tools.

- **[Terraform](./terraform/)**
  - Code generation skills
  - Module development skills
  - Provider development skills

## Installation

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

### Individual Skills

Install Agent Skills in GitHub Copilot, Claude Code, Opencode, Cursor, and more:

```bash
# List all skills
npx add-skill hashicorp/agent-skills

# Install a specific skill
npx add-skill hashicorp/agent-skills/terraform/code-generation/skills/terraform-style-guide
```

## Terraform Plugins

### terraform-code-generation

Skills for generating and validating Terraform HCL code.

| Skill | Description |
|-------|-------------|
| terraform-style-guide  | Generate Terraform HCL code following HashiCorp style conventions |
| terraform-test         | Writing and running `.tftest.hcl` test files |
| azure-verified-modules | Azure Verified Modules (AVM) requirements and certification |

### terraform-module-generation

Skills for creating and refactoring Terraform modules.

| Skill | Description |
|-------|-------------|
| refactor-module  | Transform monolithic configs into reusable modules |
| terraform-stacks | Multi-region/environment orchestration with Terraform Stacks |

### terraform-provider-development

Skills for developing Terraform providers.

| Skill | Description |
|-------|-------------|
| new-terraform-provider | Scaffold a new Terraform provider |
| run-acceptance-tests   | Run and debug provider acceptance tests |
| provider-actions       | Implement provider actions (lifecycle operations) |
| provider-resources     | Implement resources and data sources |

## MCP Server

All Terraform plugins include the `terraform-mcp-server` which provides access to Terraform Cloud/Enterprise APIs. Set the following environment variables:

```bash
export TFE_TOKEN="your-terraform-cloud-token"
export TFE_ADDRESS="https://app.terraform.io"  # or your TFE instance
```

## Structure

```
agent-skills/
├── .claude-plugin/
│   └── marketplace.json
├── terraform/                          # Terraform product
│   ├── code-generation/                # Plugin
│   │   ├── .claude-plugin/plugin.json
│   │   └── skills/
│   │       ├── terraform-style-guide/
│   │       ├── terraform-test/
│   │       └── azure-verified-modules/
│   ├── module-generation/              # Plugin
│   │   ├── .claude-plugin/plugin.json
│   │   └── skills/
│   │       ├── terraform-stacks/
│   │       └── refactor-module/
│   └── provider-development/           # Plugin
│       ├── .claude-plugin/plugin.json
│       └── skills/
│           ├── new-terraform-provider/
│           ├── provider-actions/
│           ├── provider-resources/
│           └── run-acceptance-tests/
├── AGENTS.md
├── README.md
└── LICENSE
```

Each skill contains:
- `SKILL.md` - Agent instructions with YAML frontmatter
- Optional `references/` directory for supporting documentation

## License

MPL-2.0
