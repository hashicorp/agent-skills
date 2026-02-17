# Bob (IBM) Integration Guide

This guide explains how to use HashiCorp Agent Skills with Bob, IBM's AI coding assistant.

## Overview

All skills in this repository are **fully compatible with Bob** out of the box. Bob uses the same skill format as other AI coding assistants, making installation straightforward.

## Quick Start

### Install All Skills

List all available skills from this repository:

```bash
npx skills add hashicorp/agent-skills
```

This displays an interactive menu where you can select which skills to install.

### Install Individual Skills

Install specific skills directly:

```bash
# Terraform Code Generation
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/terraform-style-guide
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/terraform-test
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/azure-verified-modules

# Terraform Module Generation
npx skills add hashicorp/agent-skills/terraform/module-generation/skills/refactor-module
npx skills add hashicorp/agent-skills/terraform/module-generation/skills/terraform-stacks

# Terraform Provider Development
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/new-terraform-provider
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/run-acceptance-tests
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/provider-actions
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/provider-resources

# Packer Builders
npx skills add hashicorp/agent-skills/packer/builders/skills/aws-ami-builder
npx skills add hashicorp/agent-skills/packer/builders/skills/azure-image-builder
npx skills add hashicorp/agent-skills/packer/builders/skills/windows-builder

# Packer HCP Integration
npx skills add hashicorp/agent-skills/packer/hcp/skills/push-to-registry
```

## Available Skills

### Terraform Skills

#### Code Generation
- **terraform-style-guide**: Generate HCL code following HashiCorp style conventions
- **terraform-test**: Write and run `.tftest.hcl` test files
- **azure-verified-modules**: Azure Verified Modules (AVM) requirements

#### Module Generation
- **refactor-module**: Transform monolithic configs into reusable modules
- **terraform-stacks**: Multi-region/environment orchestration

#### Provider Development
- **new-terraform-provider**: Scaffold new Terraform providers
- **run-acceptance-tests**: Run and debug provider acceptance tests
- **provider-actions**: Implement provider actions (lifecycle operations)
- **provider-resources**: Implement resources and data sources

### Packer Skills

#### Builders
- **aws-ami-builder**: Build Amazon Machine Images (AMIs)
- **azure-image-builder**: Build Azure managed images
- **windows-builder**: Platform-agnostic Windows image patterns

#### HCP Integration
- **push-to-registry**: Push build metadata to HCP Packer registry

## MCP Server Configuration

For enhanced Terraform integration, configure the Terraform MCP Server in Bob's settings.

### Prerequisites

1. Docker installed and running
2. HCP Terraform account (optional, for HCP Terraform features)
3. HCP Terraform API token (if using HCP Terraform)

### Configuration Steps

1. **Set Environment Variables**

   Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

   ```bash
   export TFE_TOKEN="your-hcp-terraform-token"
   export TFE_ADDRESS="app.terraform.io"  # Optional, defaults to app.terraform.io
   ```

   Or create a `.env` file in your project:

   ```bash
   TFE_TOKEN=your-hcp-terraform-token
   TFE_ADDRESS=app.terraform.io
   ```

2. **Configure Bob MCP Settings**

   Add to Bob's MCP configuration file (location varies by Bob installation):

   ```json
   {
     "mcpServers": {
       "terraform": {
         "command": "docker",
         "args": [
           "run",
           "-i",
           "--rm",
           "-e",
           "TFE_TOKEN",
           "-e",
           "TFE_ADDRESS",
           "hashicorp/terraform-mcp-server"
         ],
         "env": {
           "TFE_TOKEN": "${TFE_TOKEN}",
           "TFE_ADDRESS": "${TFE_ADDRESS}"
         }
       }
     }
   }
   ```

3. **Verify Configuration**

   Test the MCP server connection:

   ```bash
   docker run -i --rm \
     -e TFE_TOKEN="${TFE_TOKEN}" \
     -e TFE_ADDRESS="${TFE_ADDRESS}" \
     hashicorp/terraform-mcp-server
   ```

### MCP Server Features

When configured, the Terraform MCP Server provides:

- **Workspace Management**: List, create, and manage HCP Terraform workspaces
- **Run Operations**: Trigger and monitor Terraform runs
- **State Management**: Query and manage Terraform state
- **Variable Management**: Set and retrieve workspace variables
- **Policy Checks**: View policy check results
- **Cost Estimates**: Access cost estimation data

### Troubleshooting MCP

**Docker not found:**
```bash
# Install Docker Desktop or Docker Engine
# macOS: brew install --cask docker
# Linux: Follow Docker installation guide
```

**Token authentication failed:**
```bash
# Verify token is set
echo $TFE_TOKEN

# Generate new token at https://app.terraform.io/app/settings/tokens
```

**Connection timeout:**
```bash
# Check Docker is running
docker ps

# Test network connectivity
curl https://app.terraform.io
```

## Usage Examples

### Example 1: Generate Terraform Configuration

Ask Bob:
```
Using the terraform-style-guide skill, create a Terraform configuration for an AWS VPC with public and private subnets.
```

Bob will generate properly formatted HCL code following HashiCorp conventions.

### Example 2: Refactor to Module

Ask Bob:
```
Using the refactor-module skill, convert this main.tf into a reusable module with proper variables and outputs.
```

Bob will restructure your code into a well-organized module.

### Example 3: Build Packer Image

Ask Bob:
```
Using the aws-ami-builder skill, create a Packer template to build an Ubuntu 22.04 AMI with nginx installed.
```

Bob will generate a complete Packer HCL template.

### Example 4: Provider Development

Ask Bob:
```
Using the new-terraform-provider skill, scaffold a new Terraform provider for the Acme API.
```

Bob will create the complete provider structure with Plugin Framework.

## Skill Management

### List Installed Skills

```bash
npx skills list
```

### Update Skills

```bash
npx skills update hashicorp/agent-skills
```

### Remove Skills

```bash
npx skills remove terraform-style-guide
```

## Best Practices

1. **Install Relevant Skills**: Only install skills you need to reduce context size
2. **Use Specific Skill Names**: Reference skills explicitly in prompts for better results
3. **Combine Skills**: Use multiple skills together for complex tasks
4. **Keep Skills Updated**: Regularly update to get latest improvements
5. **Configure MCP**: Set up MCP server for enhanced Terraform capabilities

## Differences from Claude Code

| Feature | Claude Code | Bob |
|---------|-------------|-----|
| Installation | Plugin marketplace + individual skills | Individual skills only |
| Plugin System | Yes (`.claude-plugin/`) | No (direct skill installation) |
| MCP Configuration | In plugin.json | In Bob's MCP settings |
| Skill Format | SKILL.md with YAML frontmatter | Same |
| Skill Discovery | Plugin marketplace | `npx skills add` or `.bob/skills.json` |

## Support

- **Repository**: https://github.com/hashicorp/agent-skills
- **Issues**: https://github.com/hashicorp/agent-skills/issues
- **Terraform Docs**: https://developer.hashicorp.com/terraform
- **Packer Docs**: https://developer.hashicorp.com/packer
- **Bob Documentation**: Refer to IBM's Bob documentation

## Legal Notice

> Your use of a third party MCP Client/LLM is subject solely to the terms of use for such MCP/LLM, and IBM is not responsible for the performance of such third party tools. IBM expressly disclaims any and all warranties and liability for third party MCP Clients/LLMs, and may not be able to provide support to resolve issues which are caused by the third party tools.

## License

MPL-2.0 - See [LICENSE](LICENSE) file for details.