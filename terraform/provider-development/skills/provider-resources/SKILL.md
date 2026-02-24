---
name: provider-resources
description: Detect the Terraform provider SDK type and load the correct resource implementation guidance. Use when developing resources or data sources for any Terraform provider — Framework, SDKv2, or a combined mux provider.
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Terraform Provider Resources

Before implementing resources or data sources, determine which SDK the provider uses by reading its `go.mod` file.

## Provider Type Detection

Inspect the `require` block in `go.mod` for these module paths:

| If `go.mod` contains | Provider type |
|---|---|
| `github.com/hashicorp/terraform-plugin-mux` | **Combined** — Framework + SDKv2, bridged with mux |
| `github.com/hashicorp/terraform-plugin-framework` (without mux) | **Framework-only** |
| Neither of the above | **SDKv2-only** |

## Guidance by Provider Type

### Combined Provider (`terraform-plugin-mux` present)

The provider bridges SDKv2 and Plugin Framework using `terraform-plugin-mux`. Both SDKs coexist in the same binary.

- **Existing resources** — Almost always SDKv2. To confirm, check whether the resource registration function returns `*schema.Resource` (SDKv2) or implements the `resource.Resource` interface (Framework). Apply the `provider-development-with-sdk` skill.
- **New resources** — Author using Plugin Framework. Apply the `provider-development-with-framework` skill.

### Framework-only provider (`terraform-plugin-framework` present, no mux)

All resources use Plugin Framework. Apply the `provider-development-with-framework` skill.

### SDKv2-only provider (neither dependency present)

All resources use SDKv2. Apply the `provider-development-with-sdk` skill.
