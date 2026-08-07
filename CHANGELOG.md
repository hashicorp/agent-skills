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

### Removed

- The `terraform-code-generation`, `terraform-module-generation`,
  `terraform-provider-development`, `terraform-policy-code`, `packer-builders`,
  and `packer-hcp` Plugin identifiers and manifests.

## 1.0.0 - 2026-08-04

### Added

- `terraform-search-import` skill for discovering existing resources with
  Terraform Search and bulk import.
- `terraform-policy-code` plugin with `tfpolicy-author` and `tfpolicy-test`
  skills for HCP Terraform's native policy-as-code engine.

## 0.1.0

### Added

- Initial Terraform and Packer Skill catalog.
- Claude Code marketplace installation.
- Individual `npx skills` installation.
