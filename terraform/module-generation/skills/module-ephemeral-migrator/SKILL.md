---
name: module-ephemeral-migrator
description: >
  Run when removing secrets from Terraform module state for ALL users — new and existing.
  Triggers: "ephemeral migration", "remove secrets from state for everyone", "full migration
  to ephemeral". Existing users do a one-time manual step. Not for partial migrations that
  preserve existing user secrets in state.
compatibility:
  terraform: "1.11 or later"
  tools: git, gh CLI, tfctl, jq
---

# Terraform Ephemeral Migration

Remove secrets from state for all users. Single breaking change; existing users perform a
one-time manual step.

## Step 1: Fetch Resource Lists

Fetch: `https://raw.githubusercontent.com/drewmullen/policy-library-ephemerality/refs/heads/main/data/ephemerality.json`

`ephemeral[]` → retrieves candidates · `resources[]` → creates candidates · `write_only{}` → write-only attribute names.

## Step 2: Scan Module Code

Scan `.tf` in root and `./modules/*`. Skip `.terraform/` and remote submodules. Match `resource` in `resources[]` (ephemeral-creates), `data` in `ephemeral[]` (ephemeral-retrieves), `resource` in `write_only{}` (write-only). Record: type, file, attributes, count/for_each. **If nothing found: stop and inform user.**

Report findings to user; confirm before writing code.

## Step 3: Apply Migration Patterns

Load [references/patterns.md](references/patterns.md) and apply only the section(s) matching your findings.

**Key reminders:** single conditional on consumer · `secret_version` once per module · no `moved` blocks.

## Step 4: Generate Docs and Create PR

Detect version first (script in [references/git-workflow.md](references/git-workflow.md)). Create both:

- `docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md` → [references/upgrade-guide-template.md](references/upgrade-guide-template.md)
- `docs/skills/tf-ephemeral-upgrade-<module>.md` → [references/upgrade-skill-template.md](references/upgrade-skill-template.md)

Then follow [references/git-workflow.md](references/git-workflow.md) for branch, commit, PR description, and `gh` commands.
