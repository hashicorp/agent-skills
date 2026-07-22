# Changelog

All notable changes to the HashiCorp Agent Skills.

## Unreleased

### Added
- `provider-framework-migration` skill for migrating SDKv2 resources to the Plugin Framework
- `terraform-search-import` skill for discovering existing resources with Terraform Search and bulk import
- `terraform-policy-code` plugin with `tfpolicy-author` and `tfpolicy-test` skills for HCP Terraform's native policy-as-code engine; includes waza-compliant SKILL.md, consolidated references, conversion examples, and eval suite

## 0.1.0

### Added
- 3 Claude Code plugins with 9 total skills
- `terraform-code-generation`: terraform-style-guide, terraform-test, azure-verified-modules
- `terraform-module-generation`: refactor-module, terraform-stacks
- `terraform-provider-development`: new-terraform-provider, run-acceptance-tests, provider-actions, provider-resources
- Marketplace manifest for Claude Code plugin installation
- Support for `npx add-skill` installation
