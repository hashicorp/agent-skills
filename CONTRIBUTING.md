# Contributing to HashiCorp Agent Skills

Thanks for contributing! This guide covers the skill format, local
validation, and the pull request process.

## Repository Layout

Skills are grouped by product and plugin:

```
<product>/                      # terraform/, packer/, ...
└── <plugin>/                   # e.g. provider-development/
    ├── .claude-plugin/
    │   └── plugin.json         # plugin manifest
    └── skills/
        └── <skill-name>/
            ├── SKILL.md        # required
            ├── references/     # optional: deep material, loaded on demand
            ├── assets/         # optional: file templates copied into projects
            └── scripts/        # optional: executable helpers
```

## Skill Format

Every `SKILL.md` starts with YAML frontmatter. `name` and `description` are
required (CI-enforced); the house style also includes license and metadata:

```yaml
---
name: skill-name
description: >-
  What the skill does and — importantly — when to use it. This is the
  trigger: name the tasks, phrases, and problems that should activate the
  skill, not just its topic.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---
```

Writing guidance:

- **Description is the trigger.** Agents decide whether to load a skill
  from the description alone. Cover what it does *and* the situations that
  should activate it (including error messages users might paste).
- **Keep `SKILL.md` lean** (aim well under 500 lines); move deep material
  into `references/*.md` and tell the reader when to load each reference.
- Include at least one fenced code example — CI review checks for examples
  and body structure.
- Use the imperative voice; explain *why* a rule exists, not just the rule.
- Cross-reference sibling skills by name in prose ("use the
  `provider-test-patterns` skill, if available") — never by relative path.
  Skills are installable individually, so each must stand alone.
- Code in `assets/` should compile/run after following the skill's own
  setup steps — verify before submitting.

## Adding a New Skill: Checklist

- [ ] `skills/<name>/SKILL.md` with valid frontmatter
- [ ] Registered in the product README table, `npx skills add` list, and structure tree (e.g. `terraform/README.md`)
- [ ] Registered in `AGENTS.md` (structure tree, plugin table, install list)
- [ ] `CHANGELOG.md` entry under Unreleased
- [ ] Local validation passes (below)

## Local Validation

Run the same checks CI runs:

```bash
# Structure, manifests, frontmatter (mirrors the Validate Structure workflow)
bash scripts/validate-structure.sh

# Any JSON you touched must parse
jq . path/to/file.json
```

### Tessl skill review (optional locally, runs in CI)

CI scores changed skills with the [Tessl](https://tessl.io) CLI on two
dimensions (description, content). Validation problems (frontmatter, body
structure, missing examples, excessive length) fail the check; the scores
themselves are informational. To preview locally:

```bash
npm install -g @tessl/cli
tessl login                       # or export TESSL_TOKEN=<api key> for non-interactive use
tessl skill review path/to/skills/<skill-name>
```

Note: `tessl skill review` is deprecated upstream in favor of
`tessl review run`; check the workflow in
`.github/workflows/tessl-skill-review.yml` for the currently pinned CLI
version and invocation.

**Fork PRs:** GitHub withholds repository secrets from workflows triggered
by fork pull requests, so the Tessl review job cannot score fork PRs; it is
expected to skip (not fail) in that case. All other validation runs
normally.

## Pull Requests

- Branch from `main`; PRs target `main`.
- Keep PRs atomic — one skill or one logical change per PR. Multi-skill
  PRs are harder to review and will usually be asked to split.
- Commit and PR titles follow conventional-commit style
  (`feat: ...`, `fix(ci): ...`) or `skill-name: description`.
- Sign the CLA when prompted by the bot on your first PR.
- New Go/HCL example code should be verified (compile it in a scratch
  module where practical) — reviewers will ask how examples were tested.
