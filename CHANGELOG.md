# Changelog

All notable changes to the HashiCorp Agent Skills.

## Unreleased

### Changed
- Renamed Vault plugins to job-oriented names following Terraform/Packer pattern:
  - `vault-secrets-management` → `vault-credential-generation`
  - `vault-authentication` → `vault-app-access`
  - `vault-operations` → `vault-deployment`
  - `vault-enterprise` → `vault-multi-tenancy`
  - `vault-mcp-integration` → `vault-ai-workflows`
  - `vault-hashicorp-secrets-engines` → was `vault-hashicorp-integrations`
- Transformed all 16 Vault skills to include "What Are You Trying to Solve?" decision frameworks
- Updated skill headers with problem-oriented navigation (jump links)
- Added mental model sections explaining how each Vault component works
- Added decision tables mapping user problems to solutions

### Added
- Vault product with 6 plugins and 16 skills
  - `vault-credential-generation`: secrets-engines, vault-agent
  - `vault-app-access`: auth-methods, policies, token-management, identity-system, response-wrapping
  - `vault-deployment`: kubernetes-integration, production-operations, troubleshooting
  - `vault-multi-tenancy`: enterprise-features (namespaces, replication, Sentinel, MFA, HSM)
  - `vault-ai-workflows`: vault-mcp-server, mcp-secrets-workflows
  - `vault-hashicorp-secrets-engines`: consul-secrets, nomad-secrets, terraform-cloud-secrets
- Token management, identity system, and response wrapping skills for authentication workflows
- HashiCorp product integration skills for Consul, Nomad, and Terraform Cloud/Enterprise
- Vault Enterprise skills for multi-tenancy, replication, and policy-as-code
- Vault MCP Server integration skills for AI-assisted secrets management
- Enhanced SPEC.md files with comprehensive user stories and functional requirements
- Vault MCP Server integration for all Vault plugins
- Product template system in `examples/` directory
  - `examples/README.md` - Comprehensive guide for adding products, plugins, and skills
  - `examples/spec.md` - Spec-Kit format specification with user stories
  - `examples/questionnaire.md` - Questions reference for automation
  - `examples/new-product-template/` - Template files with placeholders
  - `examples/commands/new-product/` - `/new-product` slash command for interactive scaffolding
- `CONTRIBUTING.md` - Contribution guidelines
- 11 Claude Code plugins with 29 total skills
- Packer plugins:
  - `packer-builders`: aws-ami-builder, azure-image-builder, windows-builder
  - `packer-hcp`: push-to-registry
- Terraform plugins:
  - `terraform-code-generation`: terraform-style-guide, terraform-test, azure-verified-modules
  - `terraform-module-generation`: refactor-module, terraform-stacks
  - `terraform-provider-development`: new-terraform-provider, run-acceptance-tests, provider-actions, provider-resources
- Marketplace manifest for Claude Code plugin installation
- Support for `npx add-skill` installation
