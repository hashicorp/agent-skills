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
- `docs/actions/<name>.md.tmpl`
- `docs/guides/<name>.md.tmpl`

The Registry renders action pages from `docs/actions/<action>.md`, and
`tfplugindocs` generates action documentation (including missing template
scaffolds) with Terraform v1.14.0+. Action example files follow the
convention `examples/actions/<action_type>/action*.tf`.

## Example File Conventions

Keep example HCL in the `examples/` directory and pull it into templates,
instead of inlining HCL in `.tmpl` files:

```
examples/
├── provider/provider.tf                      # provider block for the index page only
├── resources/<type>/resource.tf              # picked up by generated templates
├── data-sources/<type>/data-source.tf
└── actions/<type>/action.tf
```

- **One example per file**, referenced from templates with
  `{{ tffile "examples/resources/examplecloud_widget/resource.tf" }}` —
  named variants get their own files (`resource-with-tags.tf`), each behind
  its own heading in the template.
- **No `terraform`, `provider`, or `output` blocks** in resource, data
  source, or action examples. Version constraints and provider
  configuration belong on the provider index page only; outputs distract
  from the object being documented. (The one exception is
  `examples/provider/provider.tf`, which exists to show provider
  configuration.)
- Keep each example minimal, runnable, and formatted with
  `terraform fmt` — generated docs render the file verbatim.

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

## Action Pages

Structure modeled on the largest production example, terraform-provider-aws
(`website/docs/actions/` — hand-written there because that provider predates
`tfplugindocs` action support; new providers should generate instead):

- One page per action. H1 uses an `Action:` prefix — `# Action: examplecloud_restart_widget` —
  parallel to `# Resource:` / `# Data Source:` on sibling pages.
- Intro paragraph states what the action does and whether it is synchronous
  or asynchronous, then links to the upstream service documentation for the
  operation it invokes.
- `## Example Usage` starts with `### Basic Usage` and must show **both**
  halves of using an action: the `action` block and the resource-side
  `lifecycle { action_trigger { ... } }` wiring — an action example without a
  trigger is not runnable:

  ```terraform
  action "examplecloud_restart_widget" "example" {
    config {
      widget_id = examplecloud_widget.example.id
    }
  }

  resource "terraform_data" "trigger" {
    lifecycle {
      action_trigger {
        events  = [after_create, after_update]
        actions = [action.examplecloud_restart_widget.example]
      }
    }
  }
  ```

- `## Argument Reference` lists `config` arguments (either flat, or split
  into required/optional groups). **No attribute/output reference section** —
  actions produce no state, and including one misleads readers.
- Callout conventions (while actions remain experimental):
  - `~> **Note:**` for the preview disclaimer, e.g. "`<action>` is in alpha.
    Its interface and behavior may change as the feature evolves, and
    breaking changes are possible."
  - `!> **Warning:**` when the action causes changes Terraform does not
    reconcile (e.g. it mutates a resource whose state attributes will be
    stale until the next refresh) — name the affected attribute and the
    consequence.
- If the repo tracks release notes with go-changelog, new actions use the
  `release-note:new-action` entry type.

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
