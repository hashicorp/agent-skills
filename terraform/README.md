# Terraform Skills

Agent skills for Terraform infrastructure-as-code development.

## Plugins

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

## Installation

### Claude Code Plugin

```bash
claude plugin marketplace add hashicorp/agent-skills

claude plugin install terraform-code-generation@hashicorp
claude plugin install terraform-module-generation@hashicorp
claude plugin install terraform-provider-development@hashicorp
```

### Individual Skills

```bash
# Code generation
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/terraform-style-guide
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/terraform-test
npx skills add hashicorp/agent-skills/terraform/code-generation/skills/azure-verified-modules

# Module generation
npx skills add hashicorp/agent-skills/terraform/module-generation/skills/refactor-module
npx skills add hashicorp/agent-skills/terraform/module-generation/skills/terraform-stacks

# Provider development
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/new-terraform-provider
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/run-acceptance-tests
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/provider-actions
npx skills add hashicorp/agent-skills/terraform/provider-development/skills/provider-resources
```

## MCP Server

Relevant Terraform plugins include the `terraform-mcp-server` which provides access to Terraform Cloud/Enterprise APIs. Set the following environment variables:

```bash
export TFE_TOKEN="your-terraform-cloud-token"
export TFE_ADDRESS="https://app.terraform.io"  # or your TFE instance
```

## Structure

```
terraform/
├── code-generation/
│   ├── .claude-plugin/plugin.json
│   └── skills/
│       ├── terraform-style-guide/
│       ├── terraform-test/
│       └── azure-verified-modules/
├── module-generation/
│   ├── .claude-plugin/plugin.json
│   └── skills/
│       ├── terraform-stacks/
│       └── refactor-module/
└── provider-development/
    ├── .claude-plugin/plugin.json
    └── skills/
        ├── new-terraform-provider/
        ├── provider-actions/
        ├── provider-resources/
        └── run-acceptance-tests/
```

## References

- [Terraform Documentation](https://developer.hashicorp.com/terraform)
- [Terraform Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
- [Terraform MCP Server](https://github.com/hashicorp/terraform-mcp-server)
