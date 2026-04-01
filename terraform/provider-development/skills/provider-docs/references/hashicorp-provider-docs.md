# HashiCorp Provider Documentation Reference

Source of truth for this skill:
- https://developer.hashicorp.com/terraform/registry/providers/docs

## Core Rules

- Publish provider docs through Terraform Registry using `tfplugindocs`.
- Generate provider docs from schema descriptions and markdown templates.
- Store templates under the repository `docs/` directory with expected naming conventions.
- Keep release tags and manifest metadata valid so Registry can render and display docs.

## Template Paths

Use these template paths when the corresponding provider objects exist:

- `docs/index.md.tmpl`
- `docs/data-sources/<name>.md.tmpl`
- `docs/resources/<name>.md.tmpl`
- `docs/ephemeral-resources/<name>.md.tmpl`
- `docs/list-resources/<name>.md.tmpl`
- `docs/functions/<name>.md.tmpl`
- `docs/guides/<name>.md.tmpl`

## Generation Workflow

HashiCorp recommends wiring generator execution through `go generate`:

```go
//go:generate go run github.com/hashicorp/terraform-plugin-docs/cmd/tfplugindocs generate --provider-name <provider_name>
```

Run from repository root:

```bash
go generate ./...
```

Alternative direct execution:

```bash
go run github.com/hashicorp/terraform-plugin-docs/cmd/tfplugindocs generate --provider-name <provider_name>
```

## Release and Publication Constraints

- Use semantic version tags prefixed with `v`.
- Create tags from the default branch.
- Keep `terraform-registry-manifest.json` in the repository root.
- Understand docs appear by provider version in Registry once the provider release is published.

## Preview and Troubleshooting

- Use HashiCorp's preview process to verify rendering before release when needed.
- If docs are missing or stale in Registry, verify:
  - tag naming and tag branch source
  - manifest file presence and validity
  - provider version publication state

## Related Canonical Pages

- Provider docs guidance:
  - https://developer.hashicorp.com/terraform/registry/providers/docs
- Terraform Plugin Docs (`tfplugindocs`) source and usage:
  - https://github.com/hashicorp/terraform-plugin-docs
