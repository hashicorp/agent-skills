# Agent Instructions

This repository contains agent skills and Claude Code plugins for HashiCorp products, including Terraform and Packer for infrastructure-as-code development.

## Repository Structure

```
agent-skills/
├── terraform/
│   ├── code-generation/
│   │   ├── .claude-plugin/plugin.json
│   │   └── skills/
│   │       ├── azure-verified-modules/
│   │       ├── terraform-style-guide/
│   │       └── terraform-test/
│   ├── module-generation/
│   │   ├── .claude-plugin/plugin.json
│   │   └── skills/
│   │       ├── refactor-module/
│   │       └── terraform-stacks/
│   └── provider-development/
│       ├── .claude-plugin/plugin.json
│       └── skills/
│           ├── new-terraform-provider/
│           ├── run-acceptance-tests/
│           ├── provider-actions/
│           └── provider-resources/
├── packer/
│   ├── builders/
│   │   ├── .claude-plugin/plugin.json
│   │   └── skills/
│   │       ├── aws-ami-builder/
│   │       ├── azure-image-builder/
│   │       └── windows-builder/
│   └── hcp/
│       ├── .claude-plugin/plugin.json
│       └── skills/
│           └── push-to-registry/
├── .claude-plugin/marketplace.json
├── README.md
└── AGENTS.md
```

## Installation Methods

### Method 1: Claude Code Plugin Installation

Install plugins using Claude Code CLI. First add the marketplace, then install plugins:

```bash
# Add the agent-skills marketplace
claude plugin marketplace add hashicorp/agent-skills

# Install plugins
claude plugin install terraform-code-generation@hashicorp
claude plugin install terraform-module-generation@hashicorp
claude plugin install terraform-provider-development@hashicorp
claude plugin install packer-builders@hashicorp
claude plugin install packer-hcp@hashicorp
```

Or use the interactive interface within Claude Code:
```
/plugin
```

This opens a tabbed interface where you can:
- **Discover**: Browse available plugins from all marketplaces
- **Installed**: View and manage installed plugins
- **Marketplaces**: Add, remove, or update marketplaces

Additional plugin management commands:
```bash
# Disable a plugin
claude plugin disable terraform-code-generation@hashicorp

# Re-enable a plugin
claude plugin enable terraform-code-generation@hashicorp

# Uninstall a plugin
claude plugin uninstall terraform-code-generation@hashicorp

# Update a plugin
claude plugin update terraform-code-generation@hashicorp
```

Installation scopes (use `--scope` flag):
- `user` (default): Available across all projects
- `project`: Shared with team via `.claude/settings.json`
- `local`: Project-specific, gitignored

### Method 2: Individual Skill Installation

Install individual skills using `npx skills add`:

```bash
# List all available skills
npx skills add hashicorp/agent-skills

# Code generation skills
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/terraform-style-guide
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/terraform-test
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/azure-verified-modules

# Module generation skills
npx skills add hashicorp/agent-skills/terraform/module-generation/skills/refactor-module
npx skills add hashicorp/agent-skills/terraform/module-generation/skills/terraform-stacks

# Provider development skills
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/new-terraform-provider
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/run-acceptance-tests
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/provider-actions
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/provider-resources

# Packer builder skills
npx skills add hashicorp/agent-skills/packer/builders/skills/aws-ami-builder
npx skills add hashicorp/agent-skills/packer/builders/skills/azure-image-builder
npx skills add hashicorp/agent-skills/packer/builders/skills/windows-builder

# Packer HCP skills
npx skills add hashicorp/agent-skills/packer/hcp/skills/push-to-registry
```

Skills are installed to `~/.claude/skills/` or project `.claude/skills/` directory.

### Method 3: Manual Installation

Copy skills directly to your Claude Code configuration:

```bash
# Clone the repository
git clone https://github.com/hashicorp/agent-skills.git

# Copy a plugin to Claude Code plugins directory
cp -r agent-skills/terraform/code-generation ~/.claude/plugins/

# Or copy individual skills
cp -r agent-skills/terraform/code-generation/skills/terraform-style-guide ~/.claude/skills/
```

## Plugin Contents

### terraform-code-generation

Skills for generating and validating Terraform HCL code:

| Skill | Description |
|-------|-------------|
| `terraform-style-guide` | Generate Terraform HCL code following HashiCorp style conventions and best practices |
| `terraform-test` | Writing and running `.tftest.hcl` test files |
| `azure-verified-modules` | Azure Verified Modules (AVM) requirements and certification |

### terraform-module-generation

Skills for creating and refactoring Terraform modules:

| Skill | Description |
|-------|-------------|
| `refactor-module` | Transform monolithic configs into reusable modules |
| `terraform-stacks` | Multi-region/environment orchestration with Terraform Stacks |

### terraform-provider-development

Skills for developing Terraform providers:

| Skill | Description |
|-------|-------------|
| `new-terraform-provider` | Scaffold a new Terraform provider |
| `run-acceptance-tests` | Run and debug provider acceptance tests |
| `provider-actions` | Implement provider actions (lifecycle operations) |
| `provider-resources` | Implement resources and data sources |

### packer-builders

Skills for building images on AWS, Azure, and Windows:

| Skill | Description |
|-------|-------------|
| `aws-ami-builder`     | Build Amazon Machine Images (AMIs) with amazon-ebs builder |
| `azure-image-builder` | Build Azure managed images and Azure Compute Gallery images |
| `windows-builder`     | Platform-agnostic Windows image patterns with WinRM and PowerShell |

### packer-hcp

Skills for HCP Packer registry integration:

| Skill | Description |
|-------|-------------|
| `push-to-registry` | Configure hcp_packer_registry to push build metadata to HCP Packer |

## Skill Format

Each skill directory contains:
- `SKILL.md` - Main skill definition with YAML frontmatter (`name`, `description`)
- Optional `assets/`, `references/`, or `resources/` directories

### SKILL.md Frontmatter

```yaml
---
name: skill-name
description: Brief description of when to use this skill.
---
```

## When to Use Each Plugin

### terraform-code-generation
Use when:
- Writing new Terraform configurations
- Reviewing Terraform code for style compliance
- Creating test files for Terraform modules
- Generating HCL for specific providers

### terraform-module-generation
Use when:
- Refactoring existing Terraform code into modules
- Working with Terraform Stacks
- Designing module interfaces and outputs
- Managing multi-environment deployments

### terraform-provider-development
Use when:
- Creating a new Terraform provider
- Adding resources or data sources to an existing provider
- Implementing provider actions
- Running or debugging acceptance tests

### packer-builders
Use when:
- Building AWS AMIs with amazon-ebs builder
- Creating Azure managed images or Azure Compute Gallery images
- Building Windows images (AWS, Azure, VMware, etc.)
- Setting up WinRM and PowerShell provisioners
- Troubleshooting Windows-specific image build issues

### packer-hcp
Use when:
- Integrating Packer builds with HCP Packer registry
- Tracking image metadata and versions
- Setting up hcp_packer_registry block
- Configuring CI/CD to push to HCP Packer
- Querying HCP Packer images in Terraform

## MCP Server Configuration

All Terraform plugins include MCP server configuration for the Terraform MCP Server:

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

Set environment variables for HCP Terraform integration:
- `TFE_TOKEN` - HCP Terraform API token
- `TFE_ADDRESS` - HCP Terraform address (optional, defaults to app.terraform.io)

## References

- [Terraform Documentation](https://developer.hashicorp.com/terraform)
- [Terraform Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
- [Terraform MCP Server](https://github.com/hashicorp/terraform-mcp-server)
- [Packer Documentation](https://developer.hashicorp.com/packer)
- [HCP Packer](https://developer.hashicorp.com/hcp/docs/packer)
- [Packer HCL2 Configuration](https://developer.hashicorp.com/packer/guides/hcl)
- [Claude Code Plugins](https://docs.anthropic.com/claude-code/plugins)
