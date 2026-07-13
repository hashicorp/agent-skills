---
name: tfpolicy-test
description: Expert agent for testing Terraform policies. Helps write and debug `.policytest.hcl` files, design resource mocks (`attrs` / `prior_attrs`), reason about runner behavior, and verify policy correctness before promotion to enforcement.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.1.0"
---

# tfpolicy-test

## Description
Expert agent for testing Terraform policies. Helps write `.policytest.hcl` files, design resource and module mocks, use `expect_failure` correctly, mock cross-resource lookups for `core::getresources()`, and reason about current `tfpolicy test` runner behavior.

## Use When
- The user has an existing policy and wants to write or improve tests for it.
- The user is debugging a failing or unexpectedly-passing test, or asking why a mock behaves the way it does.
- The user is writing `.policytest.hcl` files, `policytest { targets = [...] }` blocks, `resource {}` / `module {}` mocks, or using `expect_failure` / `skip`.
- The user is testing operation-aware policies and needs to mock `attrs` and/or `prior_attrs` for create/update/delete scenarios.
- The user is asking how to mock cross-resource lookups (e.g. `aws_s3_bucket_versioning` for `core::getresources` patterns).
- The user is investigating a runner caveat (mocks evaluated regardless of `operations` scope, `expect_failure` not supported on `data` blocks, etc.).

**Do not use this skill when:**
- The user is writing the policy itself rather than its test — use [`tfpolicy-author`](../tfpolicy-author/SKILL.md).
- The user is converting a Sentinel test to a `.policytest.hcl` test — start with [`tfpolicy-author`](../tfpolicy-author/SKILL.md), then return here for test-side refinements.

## Capabilities

### 1. Write `.policytest.hcl` Files from Existing Policies
Generate a focused test file that exercises the passing and failing paths of a policy, including `expect_failure = true` cases and any required `prior_attrs` mocks. For policies that use `input` blocks, generate separate test files per input scenario using `inputs {}` (plural) to override default values.

### 2. Design Mocks for Cross-Resource Lookups
Build the `resource {}` blocks needed for `core::getresources()` filters to match correctly (parent + child resources, `skip = true` on lookup-only resources, etc.).

### 3. Diagnose Runner Behavior
Explain why a mock fails, passes, or crashes. Cover the current caveats: `operations` scope is not yet honored by the runner, `expect_failure` is rejected on `data` blocks, omitted attributes crash unless wrapped in `core::try()`.

### 4. Recommend Test Organization
Decide when to split into multiple `.policytest.hcl` files (per-policy targeting) versus consolidating, and how to keep mocks aligned with the policy's actual evaluation target.

### 5. Generate Edge-Case Test Scenarios
For every generated test file, mandate test cases covering:
- **Missing attribute** — resource mock where the attribute is **entirely omitted** (most common real-world gap; crashes policies that don't use `core::try()`)
- **Empty collection** — resource with an empty list `[]` or empty map `{}` where the policy expects a non-empty value
- **Boundary conditions** — exact threshold values (e.g. port at limit, count at max)
- **Null attribute** — resource where the checked attribute is **explicitly set to `null`**. ⚠️ This case must only be included when the rules below permit it — do not add it unconditionally.

Every generated `.policytest.hcl` must include at least one `expect_failure = true` resource that exercises a missing-attribute scenario.

**Before finalizing each test case, verify polarity against the policy's `condition`.** For each `expect_failure = true` case, confirm the condition evaluates to `false` for that mock. For each pass case (no `expect_failure`), confirm it evaluates to `true`. A fail case the policy actually passes produces `Missing expected failure`; a pass case the policy actually fails produces an unexpected violation.

**🔴 Null test case decision rules:**

> **Key fact:** `core::try(attrs.field, default)` triggers the fallback **only when the attribute key is absent**. When a mock explicitly sets `attrs.field = null`, `core::try` returns `null` — not the default. This asymmetry means a `null` case and an omitted-attribute case exercise different code paths.

**For every attribute you are about to set to `null` in a test mock — regardless of attribute name, nesting level, or resource type — apply this check before adding the case:**

- **Two-step pattern** (`raw = core::try(attrs.field, null)` then `val = raw != null ? raw : []`) — `null` is explicitly normalized to a safe default. Add a `pass` case (no `expect_failure`) with the attribute set to `null` to verify this normalization works.
- **Explicit non-compliance check** (`condition = val != null && val != ""`) — `null` is intentionally treated as non-compliant. Add a `fail` case (`expect_failure = true`) with the attribute set to `null`.
- **Single-step only** (`val = core::try(attrs.field, [])`) without an explicit null guard — `null` is **not** normalized and will crash downstream expressions (`for val in null`, `core::length(null)`). **Do NOT add a `null` case.** Fix the policy to use the two-step pattern instead.

**Never add `fail_*_null` when the policy treats `null` the same as the safe default** (`false` / `[]`). A `null` case that the policy silently normalizes to compliant produces a `Missing expected failure` error — caused by the test itself, not a real policy bug.

The three rules above apply at every nesting level. For a scalar accessed as `core::try(local.list[0].attr, default)`, apply the same single-step / two-step determination at that specific access point.

### 6. Mock Cross-Resource Lookups for `core::getresources()`
When the policy under test uses `core::getresources(resource_type, filter)`, the test runner resolves the lookup against the resources declared in the same `.policytest.hcl` file. For the lookup to return the expected results:

1. **Filter attribute values must match exactly.** The companion resource mock must declare the linking attribute with the exact value that equals `attrs.<linking_attr>` of the parent resource at evaluation time. Resource names in the mock do not affect matching — only attribute values do.
2. **Use `skip = true` on companion resources.** Resources that should be visible to `core::getresources()` but must not be evaluated directly by the policy should be declared with `skip = true`. Without this, the runner evaluates them as standalone resources, which may produce unexpected results.
3. **Test the no-match case explicitly.** Include a test case where the companion resource is absent or has a non-matching filter attribute value. In this case `core::getresources()` returns an empty list — verify that the policy handles this as intended (e.g. treats the parent as non-compliant if a companion is required, or compliant if companion is optional).
4. **Test the match case explicitly.** Include a test case where the companion resource is present with matching attributes to confirm the lookup resolves correctly.
5. **`filter` on the policy affects ALL resources in the test file when companions are present.** When the policy uses a top-level `core::getresources()`-based `filter` (e.g. `filter = core::length(local.all_companions) > 0`), **every** parent resource in the test file is evaluated as soon as any companion resource is declared in that file. An unlinked parent (`is_linked = false`) then fails `is_linked && check_attr == VALUE` → violation — even if `check_attr` has the correct value. Do NOT include a "pass because not linked" case in the same file as companion resources. Omit it entirely; the meaningful cases are: (a) linked + correct attr → pass, (b) linked + wrong attr → fail. If the policy uses `filter = local.has_qualifying` (qualifying companions only), unlinked parents are not evaluated when no qualifying companions exist — but they still get evaluated when qualifying companions are present, so the same rule applies: no "unlinked pass" case in a file that also declares companion resources.

### 7. Enforce Explicit `policytest { targets }` Blocks
Best practice: every generated `.policytest.hcl` should include an explicit `policytest { targets = ["<policy-file>.policy.hcl"] }` block when multiple policies exist in the same directory. Without it, `tfpolicy test` evaluates the mock against every policy in the directory — causing a test written for one policy to run against a different policy, producing misleading pass/fail results.

### 8. Verify Default Values Match the Source Intent
When generating test cases for policies that use `core::try(attr, default)`, confirm that the default value in the policy matches the intended behavior for absent or null attributes. A wrong default silently passes resources that should fail. For each boolean flag or enum attribute, add a comment in the test explaining the expected behavior when the attribute is omitted versus explicitly set to null.

## Knowledge Base

The bulk of this skill is the testing guide:

- [`testing-guide.md`](testing-guide.md) — full reference: test syntax, mock shapes per operation, cross-resource patterns, common mistakes, advanced patterns.

Cross-cutting facts shared with the sibling skills live in:

- [`../../reference/verified-syntax.md`](../../reference/verified-syntax.md) — verified Terraform Policy syntax, function names, runtime limitations. Anything in conflict with the testing guide should defer to this file.

## See Also
- [`tfpolicy-author`](../tfpolicy-author/SKILL.md) — write the policy under test.
- [`tfpolicy-author`](../tfpolicy-author/SKILL.md) — migrate Sentinel tests alongside the policies.
