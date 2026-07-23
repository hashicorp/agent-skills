# Changelog

All notable changes to HashiCorp Agent Skills.

## Unreleased

### Added

- Provider configuration, framework migration, ephemeral resource, provider
  documentation, and provider test-pattern guidance.
- Token-efficient state access, provider scaffold, acceptance-test environment,
  provider action, and provider resource improvements.
- Claude Code and Codex marketplace support for the `terraform` and `packer`
  product bundles.
- Lifecycle metadata, the Skill catalog, explicit Skill ownership, supported
  model documentation, governance artifacts, and expanded validation.

### Changed

- Consolidated all 20 Skills under `plugins/<product>/skills/<skill-name>`.
- Moved Waza evaluation assets to the private project context repository.

### Migration

The integration removes `terraform-code-generation`,
`terraform-module-generation`, `terraform-provider-development`,
`terraform-policy-code`, `packer-builders`, and `packer-hcp` without aliases.
Install `terraform@hashicorp` or `packer@hashicorp`, and replace old individual
Skill paths with `plugins/<product>/skills/<skill-name>`.

This migration guidance must remain until three calendar months after the
product-bundle integration PR merges. Record the merge date and calculated
removal date here when the PR merges.

## 0.1.0

### Added

- Initial Terraform and Packer Skill catalog.
- Claude Code marketplace installation.
- Individual `npx skills` installation.
