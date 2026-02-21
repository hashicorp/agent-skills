---
name: provider-docs
description: Create, update, and review Terraform provider documentation for Terraform Registry using HashiCorp-recommended patterns, tfplugindocs templates, and schema descriptions. Use when adding or changing provider configuration, resources, data sources, ephemeral resources, list resources, functions, or guides; when validating generated docs; and when troubleshooting missing or incorrect Registry documentation.
---

# Terraform Provider Docs

## Follow This Workflow

1. Confirm scope and documentation targets.
- Map code changes to the exact doc targets: provider index, resources, data sources, ephemeral resources, list resources, functions, or guides.
- Decide whether content should come from schema descriptions, templates, or both.

2. Write schema descriptions first.
- Add precise user-facing descriptions to schema fields so generated docs stay aligned with behavior.
- Keep wording specific to argument purpose, constraints, defaults, and computed behavior.

3. Add or update template files in `docs/`.
- Create only files that map to implemented provider objects.
- Use HashiCorp-recommended template paths:
  - `docs/index.md.tmpl`
  - `docs/data-sources/<name>.md.tmpl`
  - `docs/resources/<name>.md.tmpl`
  - `docs/ephemeral-resources/<name>.md.tmpl`
  - `docs/list-resources/<name>.md.tmpl`
  - `docs/functions/<name>.md.tmpl`
  - `docs/guides/<name>.md.tmpl`
- Keep templates focused on overview and examples; rely on generated sections for field-by-field details.

4. Generate documentation with `tfplugindocs`.
- Prefer repository defaults when configured:
```bash
go generate ./...
```
- Otherwise run the generator directly:
```bash
go run github.com/hashicorp/terraform-plugin-docs/cmd/tfplugindocs generate --provider-name <provider_name>
```
- Re-run generation after every schema or template edit.

5. Validate the generated markdown.
- Verify files in `docs/` match the current provider implementation.
- Verify examples are valid HCL and reflect current argument/attribute names.
- Verify required/optional/computed semantics in docs match schema behavior.

6. Apply Registry publication rules before release.
- Use semantic version tags prefixed with `v` (for example `v1.2.3`).
- Create release tags from the default branch.
- Keep `terraform-registry-manifest.json` in the repository root.
- Expect docs to be versioned in Registry and switchable with the version selector.

7. Preview or troubleshoot publication when needed.
- Use the HashiCorp preview process to inspect rendered docs before release when accuracy risk is high.
- If docs are missing in Registry, check tag format, tag source branch, manifest file presence, and provider publication status.

## Enforce Quality Bar

- Keep documentation behaviorally accurate; never describe unsupported arguments or attributes.
- Keep examples minimal, realistic, and runnable.
- Keep terminology and naming consistent across provider, resources, and data sources.
- Avoid duplicating generated argument/attribute blocks in manual templates.
- Keep doc changes tied to the same PR as schema/API changes whenever possible.

## Load References On Demand

- Read `references/hashicorp-provider-docs.md` for source-backed rules and official links.
- Load only the sections needed for the current change to keep context lean.
