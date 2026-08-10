# Agent Instructions

This repository contains public HashiCorp Agent Skills and the Terraform and
Packer product plugins that distribute them.

## Canonical structure

- Put Terraform Skills in `plugins/terraform/skills/<skill-name>/`.
- Put Packer Skills in `plugins/packer/skills/<skill-name>/`.
- Keep Claude Code and Codex plugin manifests at each product root.
- Keep the Claude Code and Codex marketplaces aligned to exactly the
  `terraform` and `packer` bundles.
- Keep individual Skill installation paths in `SKILLS.md` aligned with disk.

## Skill requirements

- Every Skill directory must contain `SKILL.md`.
- Every `SKILL.md` frontmatter must contain `name`, `description`, and
  `metadata.lifecycle-status`.
- Skill names must match their directory names.
- Supported lifecycle states are `active`, `deprecation-candidate`,
  `deprecated`, and `retired`.
- Keep detailed material in directly linked `references/`, `scripts/`, or
  `assets/` resources when that improves progressive disclosure.

## Ownership and review

`CODEOWNERS` is canonical. Every Skill must have an explicit Skill-level entry
that includes `@hashicorp/team-agent-skills-ecosystem`. Product-aligned owners
may be added only after their participation is confirmed. The ecosystem team
owns repository conventions, evaluation integration, distribution, supported
model consistency, and final repository decisions.

Review or reevaluate a Skill whenever the Skill changes or the supported model
matrix changes. Structural validation, Skill review, private Waza evaluation,
CODEOWNERS review, and maintainer judgment are complementary inputs.

## Contributions

The repository is in an internal-contribution-only phase. Follow
`CONTRIBUTING.md` and use the proposal template for a new Skill or substantial
rewrite. Do not add public evaluation fixtures or raw evaluation results.

## Validation

Run these checks before proposing a change:

```bash
./scripts/validate-structure.sh
git diff --check
```

Run relevant example, link, installation, and harness checks for the changed
surface. Never run infrastructure-creating examples against real credentials as
part of repository validation.
