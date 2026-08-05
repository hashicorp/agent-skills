# Feature Specification: New Product Template System

**Feature Branch**: `add-product-templates`  
**Created**: 2026-02-02  
**Status**: Implementation  

---

## Executive Summary

This specification defines a reusable template system for adding new HashiCorp product agent skills to the agent-skills repository. The system includes template files, a Claude Code slash command for interactive generation, comprehensive documentation, and validation integration.

---

## User Scenarios & Acceptance Criteria

### User Story 1 - Contributor Adds New Product (Priority: P1)

A HashiCorp employee or community contributor wants to add agent skills for a new HashiCorp product (e.g., Vault, Consul, Nomad) to the repository.

**Why this priority**: This is the primary use case - enabling contributors to add products consistently.

**Acceptance Scenarios**:

1. **Given** a contributor runs `/new-product`, **When** they provide product details, **Then** the command generates a complete directory structure matching existing patterns.

2. **Given** generated files exist, **When** `scripts/validate-structure.sh` runs, **Then** all validations pass without errors.

3. **Given** a contributor follows the template, **When** they submit a PR, **Then** CI workflows validate the structure automatically.

---

### User Story 2 - Contributor Adds Plugin to Existing Product (Priority: P1)

A contributor wants to add a new use-case plugin (e.g., `vault-pki`) to an existing product directory.

**Acceptance Scenarios**:

1. **Given** an existing product directory, **When** contributor uses templates to add a plugin, **Then** the new plugin integrates with existing structure.

2. **Given** a new plugin is added, **When** marketplace.json is updated, **Then** the plugin is discoverable via `claude plugin install`.

---

### User Story 3 - Contributor Adds Skill to Existing Plugin (Priority: P1)

A contributor wants to add a new skill to an existing plugin.

**Acceptance Scenarios**:

1. **Given** an existing plugin, **When** contributor creates a skill directory with SKILL.md, **Then** the skill passes frontmatter validation.

2. **Given** a SKILL.md file, **When** it includes required fields (name, description), **Then** Claude Code loads it correctly.

---

### User Story 4 - Maintainer Reviews Contribution (Priority: P2)

A repository maintainer reviews a PR adding a new product or skills.

**Acceptance Scenarios**:

1. **Given** a PR with new product files, **When** CI runs, **Then** structure validation, JSON validation, and SKILL.md validation all pass.

2. **Given** contribution follows template, **When** maintainer reviews, **Then** structure is consistent with Terraform/Packer patterns.

---

## Functional Requirements

### FR-1: Template Files

| Requirement | Description |
|-------------|-------------|
| FR-1.1 | Product README.md template with placeholders for product metadata |
| FR-1.2 | plugin.json template with all required and optional fields |
| FR-1.3 | SKILL.md template with standard and optional frontmatter |
| FR-1.4 | Templates use Mustache-style `{{VARIABLE}}` syntax |

### FR-2: Slash Command

| Requirement | Description |
|-------------|-------------|
| FR-2.1 | `/new-product` command prompts for product metadata |
| FR-2.2 | Command prompts for use cases (plugins) iteratively |
| FR-2.3 | Command prompts for skills per plugin |
| FR-2.4 | Command generates complete directory structure |
| FR-2.5 | Command updates marketplace.json with new plugins |
| FR-2.6 | Command validates generated structure |

### FR-3: Documentation

| Requirement | Description |
|-------------|-------------|
| FR-3.1 | examples/README.md explains how to add products, plugins, skills |
| FR-3.2 | CONTRIBUTING.md provides general contribution guidelines |
| FR-3.3 | Questionnaire documents all required information |
| FR-3.4 | Template variable reference explains all placeholders |

### FR-4: Validation Integration

| Requirement | Description |
|-------------|-------------|
| FR-4.1 | Generated products pass validate-structure.sh |
| FR-4.2 | Generated JSON passes jq validation |
| FR-4.3 | Generated SKILL.md passes frontmatter validation |

---

## Non-Functional Requirements

### NFR-1: Consistency

Generated products must be structurally identical to existing Terraform and Packer products.

### NFR-2: Compatibility

Templates must work with Claude Code's skill and plugin discovery mechanisms.

### NFR-3: Maintainability

Templates should be easy to update when patterns evolve.

### NFR-4: Self-Documentation

Templates should include comments explaining each section.

---

## Template Variables Reference

### Product Level

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `PRODUCT_NAME` | Yes | Lowercase identifier | `vault` |
| `PRODUCT_DISPLAY_NAME` | Yes | Human-readable name | `HashiCorp Vault` |
| `PRODUCT_DESCRIPTION_SHORT` | Yes | One-line description | `Identity-based secrets management` |
| `PRODUCT_HOMEPAGE` | Yes | Documentation URL | `https://developer.hashicorp.com/vault` |

### Plugin Level

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `PLUGIN_NAME` | Yes | Plugin identifier | `vault-secrets-management` |
| `USE_CASE` | Yes | Use case directory name | `secrets-management` |
| `PLUGIN_DESCRIPTION` | Yes | What the plugin provides | `Skills for managing secrets in Vault` |
| `KEYWORDS` | Yes | Array of tags | `["vault", "secrets", "kv"]` |
| `MCP_SERVER` | No | MCP server configuration | See template |

### Skill Level

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `SKILL_NAME` | Yes | Skill identifier | `kv-secrets-engine` |
| `SKILL_DESCRIPTION` | Yes | When to use this skill | `Use when storing static secrets...` |
| `SKILL_TITLE` | Yes | Display title | `KV Secrets Engine` |
| `REFERENCE_URL` | Yes | Primary documentation link | `https://developer.hashicorp.com/vault/docs/secrets/kv` |
| `DISABLE_MODEL_INVOCATION` | No | Set true for task skills | `true` |
| `ALLOWED_TOOLS` | No | Tool restrictions | `Read, Grep, Bash(vault *)` |

---

## Out of Scope

- Automated content generation (templates provide structure, not content)
- Skill content quality validation (beyond structural checks)
- Cross-product dependency management
- Version migration tooling

---

## Success Metrics

1. New products can be added in < 30 minutes using templates
2. 100% of generated structures pass validation
3. Zero structural inconsistencies between products
4. Contributors report templates as "helpful" in PR feedback
