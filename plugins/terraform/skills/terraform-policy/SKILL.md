---
name: terraform-policy
description: "Write, test, or convert Terraform Policy files (.policy.hcl, .policytest.hcl, Sentinel→tfpolicy). Triggers: policy.hcl, policytest, convert sentinel, tfpolicy, write a policy."
license: MPL-2.0
metadata:
  lifecycle-status: active
  copyright: Copyright IBM Corp. 2026
  version: "0.1.0"
---

# terraform-policy

**UTILITY SKILL** — INVOKES: [tfpolicy-author](references/tfpolicy-author.md) | [tfpolicy-test](references/tfpolicy-test.md)

## USE FOR:

- Writing a new `.policy.hcl` policy from a description or requirement
- Converting a `.sentinel` policy to Terraform Policy
- Writing or debugging a `.policytest.hcl` test file
- Migrating a Sentinel policy library to Terraform Policy

Before giving authoring or testing instructions, check the installed `tfpolicy` CLI version and tailor guidance accordingly. This skill maintains guidance for the two most recent minor lines, `0.3.x` and `0.4.x`; when a new minor ships, drop the oldest line and add the new one. Inline notes for versions earlier than `0.3.0` are retained only for older CLIs.
- If the CLI is `0.3.x` (baseline), include a top-level `policy { required_providers { ... } }` block when authoring `.policy.hcl` files containing resource or provider policies. It is mandatory for `tfpolicy validate`; version-range validation is best effort, and wildcard targets such as `resource_policy "*"` are not schema-validated. Every mock `resource {}` block in `.policytest.hcl` files must declare `attrs` or `prior_attrs`; if both evaluate to empty, the test case is skipped (`provider {}` and `module {}` mocks are unaffected) (see [tfpolicy-test](references/tfpolicy-test.md#every-resource--mock-must-declare-a-non-empty-state-block-tfpolicy-030)). `tfpolicy test` reuses the target `.policy.hcl`'s existing top-level `policy { required_providers { ... } }` block (there is no separate `.policytest.hcl`-level declaration) to validate provider, resource, and data-source policies and `core::getdatasource()`/`core::getresources()` arguments against resolved provider schemas before any test runs, failing the whole run on a schema mismatch (see [tfpolicy-test](references/tfpolicy-test.md#test-execution-behavior)). `core::alltrue(list)` and `core::anytrue(list)` are available — prefer them over the `core::length()` list-comprehension workaround (see [tfpolicy-author](references/tfpolicy-author.md#core-functions--common-idioms)). `meta.tfe_stack` and `meta.tfe_workspace.tags` are available to resource, provider, and module policies; Stack fields are empty outside Stack evaluations. The `no-op` operation does not exist: resource policies evaluate only resources that the run creates, updates, or deletes, and the default `operations` is `["create", "update"]`.
- If the CLI is `0.4.x` or newer, all `0.3.x` guidance still applies, plus the `no-op` operation, which evaluates resources that the run leaves unchanged (the entire state). `operations` accepts `"create"`, `"update"`, `"delete"`, and `"no-op"`. For policies that do not reference `prior_attrs`, the default `operations` is now `["create", "update", "no-op"]`, so omitting it evaluates every resource in state. Use `operations = ["create", "update"]` to evaluate only changed resources. `no-op` exposes the existing values through `attrs`, and `prior_attrs` is unavailable. A list cannot mix operations that expose `attrs` (`create`, `update`, `no-op`) with `delete`, and `prior_attrs` policies must set `operations` explicitly. Policies calling `core::getresources` whose `operations` omit `no-op` load with a warning. In tests, set `meta.operation = "no-op"` explicitly because it is never inferred (see [tfpolicy-author](references/tfpolicy-author.md#operation-scoping-and-prior_attrs) and [tfpolicy-test](references/tfpolicy-test.md#testing-operation-aware-policies)).
- If the CLI version is unknown, ask the user to check it first or provide guidance that clearly distinguishes the `0.3.x` and `0.4.x` paths.

## DO NOT USE FOR:

- Writing `.tftest.hcl` files for Terraform modules — use `terraform-test`
- General Terraform HCL authoring — use `terraform-style-guide`

## Routing

| Task | Sub-skill |
|------|-----------|
| Write or convert a `.policy.hcl` policy | [tfpolicy-author](references/tfpolicy-author.md) |
| Write or debug a `.policytest.hcl` test | [tfpolicy-test](references/tfpolicy-test.md) |

## Examples

- "Block EC2 instances without encryption" → [tfpolicy-author](references/tfpolicy-author.md)
- "Convert this Sentinel policy to tfpolicy" → [tfpolicy-author](references/tfpolicy-author.md)
- "Write a policytest for my EBS policy" → [tfpolicy-test](references/tfpolicy-test.md)

## Troubleshooting

- **Wrong skill triggered?** Load the sub-skill directly from the routing table above.

```bash
npx skills add hashicorp/agent-skills/terraform/terraform-policy/skills/tfpolicy-author
npx skills add hashicorp/agent-skills/terraform/terraform-policy/skills/tfpolicy-test
```
