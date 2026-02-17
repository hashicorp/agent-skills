# HashiCorp Agent Skills

A collection of Agent skills and Claude Code plugins for HashiCorp products.

| Product | Use cases |
|:--------|:----------|
| [Terraform](./terraform/) | Write HCL code, build modules, develop providers, and run tests |
| [Packer](./packer/) | Build machine images on AWS, Azure, and Windows; integrate with HCP Packer registry |

> **Legal Note:** Your use of a third party MCP Client/LLM is subject solely to the terms of use for such MCP/LLM, and IBM is not responsible for the performance of such third party tools. IBM expressly disclaims any and all warranties and liability for third party MCP Clients/LLMs, and may not be able to provide support to resolve issues which are caused by the third party tools.

## Installation

### Bob (IBM)

Install skills directly using npx. See [BOB.md](./BOB.md) for complete Bob integration guide.

```bash
# List all skills
npx skills add hashicorp/agent-skills

# Install a specific skill
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/terraform-style-guide
```

**MCP Server Configuration:** Add to Bob's MCP settings for enhanced Terraform integration:

```json
{
  "mcpServers": {
    "terraform": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "TFE_TOKEN", "-e", "TFE_ADDRESS", "hashicorp/terraform-mcp-server"],
      "env": {
        "TFE_TOKEN": "${TFE_TOKEN}",
        "TFE_ADDRESS": "${TFE_ADDRESS}"
      }
    }
  }
}
```

### Other AI Coding Assistants

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
claude plugin install packer-builders@hashicorp
claude plugin install packer-hcp@hashicorp
```

Or use the interactive interface:
```bash
/plugin
```

## Available Skills

### Terraform
- **Code Generation**: HCL style guide, testing, Azure Verified Modules
- **Module Generation**: Refactoring, Terraform Stacks orchestration
- **Provider Development**: Scaffolding, resources, actions, acceptance tests

### Packer
- **Builders**: AWS AMI, Azure images, Windows patterns
- **HCP Integration**: Registry metadata and tracking

See [BOB.md](./BOB.md) for complete skill list and usage examples for [IBM Bob](https://www.ibm.com/products/bob).

## Structure

```
agent-skills/
├── .bob/
│   └── skills.json         # Bob skill manifest
├── .claude-plugin/
│   └── marketplace.json    # Claude Code marketplace
├── terraform/              # Terraform skills
├── packer/                 # Packer skills
├── <product>/              # Future products (Vault, Consul, etc.)
├── BOB.md                  # Bob integration guide
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

## Documentation

- **[BOB.md](./BOB.md)** - Complete [IBM Bob](https://www.ibm.com/products/bob) integration guide
- **[AGENTS.md](./AGENTS.md)** - Detailed agent instructions and plugin documentation
- **[Terraform README](./terraform/README.md)** - Terraform-specific skills
- **[Packer README](./packer/README.md)** - Packer-specific skills

## License

MPL-2.0
