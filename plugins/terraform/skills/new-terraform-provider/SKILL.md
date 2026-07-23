---
name: new-terraform-provider
description: >-
  Use this when scaffolding a new Terraform provider with the Plugin
  Framework: workspace layout, go module setup, provider server main.go,
  and a provider.go with schema and Configure. Also use when a user wants
  to start building a provider for a new API or asks how to begin a
  terraform-provider-* project.
license: MPL-2.0
metadata:
  lifecycle-status: active
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

To scaffold a new Terraform provider with Plugin Framework:

1. If I am already in a Terraform provider workspace, then confirm that I want
   to create a new workspace. If I do not want to create a new workspace, then
   skip all remaining steps.
1. Create a new workspace root directory. The root directory name should be
   prefixed with "terraform-provider-". Perform all subsequent steps in this
   new workspace.
1. Initialize a new Go module.
1. Run `go get -u github.com/hashicorp/terraform-plugin-framework@latest`.
1. Write a main.go file that follows [the example](assets/main.go).
1. Write an `internal/provider/provider.go` file that follows
   [the example](assets/provider.go). Rename the `demo` provider, the
   `DEMO_*` environment variables, and the authentication attributes to
   match the target API.
1. Remove TODO comments from `main.go` and `provider.go`.
1. Run `go mod tidy`
1. Run `go build -o /dev/null`
1. Run `go test ./...`
The scaffold resolves credentials as explicit config with environment
variable fallback. To grow that into a full credential provider chain
(shared credentials files, profiles, platform identity, configure-time
validation), use the `provider-configuration` skill (if available). To add
the first resource or data source, use the `provider-resources` skill (if
available).
