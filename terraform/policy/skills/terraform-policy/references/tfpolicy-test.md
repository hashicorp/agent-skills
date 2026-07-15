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
- The user is writing the policy itself rather than its test — use [`tfpolicy-author`](tfpolicy-author.md).
- The user is converting a Sentinel test to a `.policytest.hcl` test — start with [`tfpolicy-author`](tfpolicy-author.md), then return here for test-side refinements.

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

Cross-cutting facts shared with the sibling skills live in:

- [`verified-syntax.md`](verified-syntax.md) — verified Terraform Policy syntax, function names, runtime limitations. Anything in conflict with the testing guide should defer to this file.

## See Also
- [`tfpolicy-author`](tfpolicy-author.md) — write the policy under test.
- [`tfpolicy-author`](tfpolicy-author.md) — migrate Sentinel tests alongside the policies.

---


## Table of Contents

1. [Testing Basics](#testing-basics)
2. [Resource Policy Testing](#resource-policy-testing)
3. [Module Policy Testing](#module-policy-testing)
4. [Provider Policy Testing](#provider-policy-testing)
5. [Advanced Techniques](#advanced-techniques)
6. [Best Practices](#best-practices)

---

## Testing Basics

### Test File Structure

```hcl
# Optional: specify which policy files to test
policytest {
  targets = ["policy-file-1.policy.hcl", "policy-file-2.policy.hcl"]
}

# Mock resources with expected outcomes
resource "aws_s3_bucket" "passing_bucket" {
  attrs = {
    bucket = "my-secure-bucket"
    versioning = [{ enabled = true }]
  }
}

resource "aws_s3_bucket" "failing_bucket" {
  expect_failure = true
  attrs = {
    bucket = "my-insecure-bucket"
    versioning = [{ enabled = false }]
  }
}
```

**Full test file structure with all supported blocks:**
```hcl
policytest {
  targets = ["policy-file.policy.hcl"]
}

# Override input defaults for this test file
inputs {
  port = 90
}

resource "aws_security_group_rule" "should_fail_port_90" {
  expect_failure = true
  attrs = {
    type        = "ingress"
    from_port   = 80
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Key Points:**
- **Best practice: include `policytest { targets = ["<policy-file>.policy.hcl"] }` when multiple policies exist in the same directory.** Without it, `tfpolicy test` evaluates the mock against every policy in the directory — a test resource intended for one policy will silently run against others, producing misleading results. `expect_failure = true` on such a resource can pass for the wrong reason.
- `expect_failure = true` applies to ALL policies evaluating the resource
- **`expect_failure` is ONLY valid on `resource {}` blocks** — using it on `data {}` blocks causes `Unsupported argument` error

> **⚠️ Critical: `tfpolicy test` does NOT evaluate `error_message`**
>
> `tfpolicy test` only evaluates the `condition` expression. It **never** evaluates or interpolates the `error_message` string. This means:
> - A policy with `error_message = "Failed: ${meta.address}"` will pass all `tfpolicy test` runs even though `meta.address` is UNDEFINED and will crash every resource at runtime.
> - **Only `terraform plan --policies=` evaluates `error_message`** — always validate generated policies against a real Terraform plan to catch this class of bug.
- **CRITICAL:** Omitted attributes cause evaluation errors if accessed directly. Always use `core::try()` to handle missing attributes

### Test Execution Behavior

1. **Multiple policies evaluate same resources** - All matching policies run against all matching test resources
2. **Tests continue on failure** - All tests run to completion, not stopping at first failure
3. **Exit codes for CI/CD**:
   - Exit 0: All tests pass (including expected failures)
   - Exit 1: Unexpected failures or errors

**CI/CD Usage:**
```bash
tfpolicy test --policies=./policies --tests=./tests
if [ $? -eq 0 ]; then echo "Passed"; else echo "Failed"; exit 1; fi
```

---

## Resource Policy Testing

### Basic Syntax

```hcl
resource "resource_type" "test_name" {
  expect_failure = true/false  # Optional — ONLY valid on resource blocks, NOT data blocks
  skip = true/false            # Optional
  attrs = {
    # All resource attributes
  }
}
```

> **⚠️ `expect_failure` is NOT supported on `data {}` blocks.** Using it on a data block causes `Unsupported argument "expect_failure"`. Only mock `resource {}` blocks support this attribute.

### Omitted Attributes Behavior

**CRITICAL:** Attributes accessed by policies MUST be provided in test mocks or wrapped with `core::try()`.

**Direct Access (Causes Error):**
```hcl
# Policy
resource_policy "aws_ebs_volume" "check" {
  enforce {
    condition = attrs.encrypted == true  # Direct access
  }
}

# Test - ERROR if encrypted is omitted
resource "aws_ebs_volume" "test" {
  attrs = {
    size = 100
    # encrypted omitted - causes "This object does not have an attribute named 'encrypted'"
  }
}
```

**Safe Access with core::try():**
```hcl
# Policy
resource_policy "aws_ebs_volume" "check" {
  locals {
    encrypted = core::try(attrs.encrypted, false)  # Safe access
  }
  enforce {
    condition = local.encrypted == true
  }
}

# Test - Works even if encrypted is omitted
resource "aws_ebs_volume" "test" {
  attrs = {
    size = 100
    # encrypted omitted - core::try() returns false (default value)
  }
}
```

**Rule:** Only attributes NOT accessed by the policy can be safely omitted. All accessed attributes must either:
1. Be provided in the mock's `attrs = {}` block, OR
2. Be accessed via `core::try()` in the policy

### Testing Operation-Aware Policies

Policies can scope themselves to specific plan operations via `operations = ["create", "update", "delete"]`. Test mocks support a matching `prior_attrs = { ... }` block alongside `attrs = { ... }`, so create, update, and delete-gate policies are all fully testable.

**Mock shape per operation:**

| Operation being tested | Provide `attrs` | Provide `prior_attrs` |
| --- | --- | --- |
| `create` | ✅ planned values | — |
| `update` | ✅ planned values | ✅ pre-change values |
| `delete` | — | ✅ pre-change values |

**Create / update policy (planned values only):**

```hcl
# Policy
resource_policy "tfe_workspace" "require_project" {
  operations = ["create", "update"]
  enforce {
    condition     = core::try(attrs.project_id, "") != ""
    error_message = "tfe_workspace must have project_id set."
  }
}
```

```hcl
# Test
policytest { targets = ["workspace-require-project.policy.hcl"] }

resource "tfe_workspace" "with_project" {
  attrs = { project_id = "prj-123" }
}

resource "tfe_workspace" "missing_project" {
  expect_failure = true
  attrs          = {}
}
```

**Update policy (reads both `attrs` and `prior_attrs`):**

```hcl
# Policy — block downgrades
resource_policy "tfe_workspace" "no_downgrade" {
  operations = ["update"]
  enforce {
    condition     = core::try(attrs.terraform_version, "") == core::try(prior_attrs.terraform_version, "")
                 || core::try(attrs.terraform_version, "") > core::try(prior_attrs.terraform_version, "")
    error_message = "terraform_version downgrade is not allowed."
  }
}
```

```hcl
# Test
policytest { targets = ["workspace-no-downgrade.policy.hcl"] }

resource "tfe_workspace" "upgrade_ok" {
  attrs       = { terraform_version = "1.10.0" }
  prior_attrs = { terraform_version = "1.9.0" }
}

resource "tfe_workspace" "downgrade_blocked" {
  expect_failure = true
  attrs          = { terraform_version = "1.5.0" }
  prior_attrs    = { terraform_version = "1.9.0" }
}
```

**Delete-gate policy (pre-change state only):**

```hcl
# Policy
resource_policy "tfe_workspace" "deny_delete_without_tag" {
  operations = ["delete"]
  locals {
    prior_tag_names = core::try(prior_attrs.tag_names, [])
  }
  enforce {
    condition     = core::contains(local.prior_tag_names, "delete")
    error_message = "Add 'delete' tag before destroying a workspace."
  }
}
```

```hcl
# Test
policytest { targets = ["workspace-deny-delete-without-tag.policy.hcl"] }

resource "tfe_workspace" "has_delete_tag" {
  prior_attrs = { tag_names = ["delete", "prod"] }
}

resource "tfe_workspace" "missing_delete_tag" {
  expect_failure = true
  prior_attrs    = { tag_names = ["prod"] }
}
```

> **Note:** The runner currently evaluates each mock against every policy listed in `targets` regardless of the policy's `operations` scope. Keep your `.policytest.hcl` file targeted at a single policy (or a set of policies that share the same operation scope), and only supply the `attrs` / `prior_attrs` fields that policy actually reads.

### Provider Schema Awareness

The structure of `attrs = {}` depends on provider schema. Consult provider docs to determine if attributes are blocks or direct values.

**Example - Blocks vs Attributes:**
```hcl
resource "aws_instance" "test" {
  attrs = {
    instance_type = "t2.micro"  # Direct attribute

    # Block (requires array of maps)
    default_tags = [{
      tags = {
        Environment = "Production"
      }
    }]
  }
}
```

**In test files:** Use `=` for blocks (not `{}` syntax used in policy files)

### Cross-Resource References

Reference other test resources within the SAME file using `resource_type.name.attrs.attribute`:

```hcl
resource "aws_security_group" "app_sg" {
  attrs = {
    name = "app-security-group"
  }
}

resource "aws_instance" "app_server" {
  attrs = {
    vpc_security_group_ids = [aws_security_group.app_sg.attrs.name]
  }
}
```

**Limitation:** References cannot span across test files.

### The skip Attribute

Resources with `skip = true`:
- Are added to resource graph
- Are NOT evaluated by policies
- CAN be referenced by other resources
- ARE included in `core::getresources()` results

```hcl
resource "aws_ebs_volume" "available_for_reference" {
  skip = true
  attrs = {
    volume_id = "vol-12345"
  }
}

resource "aws_instance" "server" {
  attrs = {
    ebs_block_device = [{
      volume_id = aws_ebs_volume.available_for_reference.attrs.volume_id
    }]
  }
}
```

**Use skip only when:** Resource is referenced or needed in getresources() counts.

### Testing Filters

If a resource doesn't match the filter, it's NOT evaluated (test passes):

```hcl
# Policy with filter
resource_policy "aws_s3_bucket" {
  filter = attrs.bucket_prefix == "secure-"
  enforce {
    condition = attrs.versioning[0].enabled == true
  }
}

# Test - doesn't match filter, so passes
resource "aws_s3_bucket" "filtered_out" {
  attrs = {
    bucket_prefix = "public-"  # Doesn't match filter
    versioning = [{ enabled = false }]
  }
}
```

**Best Practice:** Test both resources that match and don't match the filter.

### Resource Policy Meta Attributes

**IMPORTANT:** Meta attributes for `resource_policy` behave differently in mock tests vs real terraform plan evaluation.

**Available Meta Attributes by Evaluation Mode:**

| Meta Attribute | Mock Tests (`tfpolicy test`) | Real Plans (`terraform plan --policies=`) |
|----------------|------------------------------|------------------------------------------|
| `meta.provider_type` | ❌ UNDEFINED | ✅ Available (e.g., "aws", "azurerm") |
| `meta.type` | ❌ UNDEFINED | ❌ UNDEFINED |
| `meta.address` | ❌ UNDEFINED | ❌ UNDEFINED |

**Example:**
```hcl
# Policy using meta.provider_type
resource_policy "aws_ebs_volume" "check_provider" {
  enforce {
    condition = core::try(meta.provider_type, "UNDEFINED") == "aws"
    error_message = "Provider type: ${core::try(meta.provider_type, "UNDEFINED")}"
  }
}
```

**Test behavior:**
- With `tfpolicy test`: `meta.provider_type` returns UNDEFINED (test may fail)
- With `terraform plan --policies=`: `meta.provider_type` returns "aws" (test passes)

**Best Practice:** When using `meta.provider_type` in policies, always wrap with `core::try()` and note that mock tests cannot fully validate this behavior. Test with real terraform plans for complete validation.

---

## Module Policy Testing

### Module Test Syntax

```hcl
module "source" "test_name" {
  expect_failure = true/false  # Optional
  meta = {
    source  = "registry.terraform.io/namespace/name"
    address = "module.name"
    version = "1.0.0"
  }
}
```

**Available meta attributes:**
- `source` - Module source
- `address` - Module address (e.g., "module.database")
- `version` - Module version

**Note:** Modules use `meta` only (no `attrs`)

### Example: Module Source Allowlist

**Policy:**
```hcl
locals {
  allowed_sources = [
    "registry.terraform.io/hashicorp/aws",
    "registry.terraform.io/terraform-aws-modules/vpc/aws"
  ]
}

module_policy "*" "approved_sources" {
  filter = meta.source != null
  enforce {
    condition = core::contains(local.allowed_sources, meta.source)
    error_message = "Unauthorized module source: ${meta.source}"
  }
}
```

**Test:**
```hcl
# Passing
module "registry.terraform.io/hashicorp/aws" "approved" {
  meta = {
    source  = "registry.terraform.io/hashicorp/aws"
    address = "module.database"
    version = "1.0.0"
  }
}

# Failing
module "registry.terraform.io/acme-corp/database" "unauthorized" {
  expect_failure = true
  meta = {
    source  = "registry.terraform.io/acme-corp/database"
    address = "module.db"
    version = "2.0.0"
  }
}
```

### Example: Module Version Enforcement

**Policy:**
```hcl
module_policy "registry.terraform.io/hashicorp/aws" "version_check" {
  filter = meta.source == "registry.terraform.io/hashicorp/aws"
  enforce {
    condition = core::semverconstraint(meta.version, ">= 4.0.0")
    error_message = "Module must use version >= 4.0.0, found ${meta.version}"
  }
}
```

---

## Provider Policy Testing

### Provider Test Syntax

```hcl
provider "type" "test_name" {
  expect_failure = true/false  # Optional
  meta = {
    source = "registry.terraform.io/namespace/name"
  }
}
```

**Available meta attributes:**
- `source` - Provider source (e.g., "registry.terraform.io/hashicorp/aws")

**Note:** Provider type (e.g., "aws") goes in block declaration, not meta.

### Example: Provider Source Allowlist

**Policy:**
```hcl
locals {
  allowed_provider_sources = [
    "registry.terraform.io/hashicorp/aws",
    "registry.terraform.io/hashicorp/azurerm"
  ]
}

provider_policy "aws" {
  enforce {
    condition = core::contains(local.allowed_provider_sources, meta.source)
    error_message = "Provider source '${meta.source}' is not approved"
  }
}
```

**Test:**
```hcl
# Passing
provider "aws" "official" {
  meta = {
    source = "registry.terraform.io/hashicorp/aws"
  }
}

# Failing
provider "aws" "unofficial" {
  expect_failure = true
  meta = {
    source = "registry.terraform.io/acme-corp/aws"
  }
}
```

### Common Provider Patterns

1. **Official providers only**: Check `meta.source == "registry.terraform.io/hashicorp/aws"`
2. **Version constraints**: Use `core::semverconstraint(meta.version, ">= 4.0.0, < 6.0.0")`
3. **Allowlist by type**: Create separate provider_policy for each allowed type

---

## Advanced Techniques

### Data Source Mocking

```hcl
data "aws_ami" "ubuntu" {
  attrs = {
    id = "ami-12345"
    name = "ubuntu-20.04"
  }
}

# Policy can reference it
resource_policy "aws_instance" {
  enforce {
    condition = attrs.ami == data.aws_ami.ubuntu.attrs.id
  }
}
```

### Workspace Context Limitations

❌ **Not Available:** `terraform.workspace` or workspace context

**Valid traversal roots:**
- `input` - Input variables
- `local` - Local variables
- `attrs` - Resource/data source attributes
- `meta` - Metadata

**Workarounds:**
1. Use resource tags for environment-based logic
2. Separate policy sets per environment in HCP Terraform
3. CI/CD-level enforcement based on workspace name
4. Tag-based validation

### Testing Collections

```hcl
resource "aws_security_group" "multiple_rules" {
  attrs = {
    ingress = [
      {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
      },
      {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }
    ]
  }
}
```

### Testing Null/Missing Attributes

**Only works if policy uses `core::try()`:**

```hcl
# Policy must use core::try() to handle missing attributes
resource_policy "aws_s3_bucket" "check" {
  locals {
    encryption = core::try(attrs.server_side_encryption_configuration, null)
  }
  enforce {
    condition = local.encryption != null
    error_message = "Encryption required"
  }
}

# Test - omitted attribute handled by core::try()
resource "aws_s3_bucket" "no_encryption" {
  expect_failure = true
  attrs = {
    bucket = "my-bucket"
    # server_side_encryption_configuration omitted - handled by core::try()
  }
}
```

**Without `core::try()`, omitting accessed attributes causes evaluation errors.**

---

### Testing Policies with `input` Blocks

Policies that use `input` blocks can have their input values overridden per test file using an **`inputs {}`** block (plural). This allows you to test the policy behaviour under different configurations without changing the policy itself.

> ⚠️ The block is `inputs {}` (plural) — using `input {}` (singular) throws `Unsupported block type` error.

```hcl
# Policy (test.policy.hcl)
input "port" {
  type    = number
  default = 22
}

resource_policy "aws_security_group_rule" "no_open_ingress" {
  filter = core::try(attrs.type, "") == "ingress"
  locals {
    covers_port = core::try(attrs.from_port <= input.port && attrs.to_port >= input.port, false)
  }
  enforce {
    condition     = !local.covers_port
    error_message = "Ingress rule covers restricted port ${input.port}."
  }
}
```

```hcl
# Test file 1: test with default port (22)
policytest {
  targets = ["test.policy.hcl"]
}
# No inputs block — uses input.port default = 22

# PASS: port range 80-443 does not cover default port 22
resource "aws_security_group_rule" "pass_default_port" {
  attrs = {
    type      = "ingress"
    from_port = 80
    to_port   = 443
    protocol  = "tcp"
  }
}

# FAIL: port range 1-1024 covers default port 22
resource "aws_security_group_rule" "fail_default_port" {
  expect_failure = true
  attrs = {
    type      = "ingress"
    from_port = 1
    to_port   = 1024
    protocol  = "tcp"
  }
}
```

```hcl
# Test file 2: test with custom port (90)
policytest {
  targets = ["test.policy.hcl"]
}

inputs {
  port = 90   # override default of 22
}

# FAIL: port range 80-443 DOES cover custom port 90
resource "aws_security_group_rule" "fail_custom_port" {
  expect_failure = true
  attrs = {
    type      = "ingress"
    from_port = 80
    to_port   = 443
    protocol  = "tcp"
  }
}
```

**Key points:**
- Each test file can have its own `inputs {}` block with different values — use separate `.policytest.hcl` files per input scenario
- When no `inputs {}` block is present, the policy's `default` values are used
- Always add a comment to each test file stating which input values it assumes — prevents confusion when the same resource mock produces different results under different inputs
- **Note:** input values can only be overridden at policy-set level in HCP Terraform for live enforcement — `inputs {}` in test files is for test-time validation only

Every generated `.policytest.hcl` **must** include test cases for the following scenarios. Missing any of these is a test coverage gap:

| Scenario | Mock pattern | Why it matters |
|----------|-------------|----------------|
| **Missing attribute** (omitted entirely) | `attrs = { bucket = "x" }` — target attribute not present | Crashes policies that don't use `core::try()`; most common real-world gap |
| **Null attribute** | `attrs = { ..., field = null }` | Tests `core::try()` default handling |
| **Empty list** | `attrs = { ..., items = [] }` | Policies expecting non-empty collections must handle `[]` |
| **Empty string** | `attrs = { ..., value = "" }` | String-check policies must not treat `""` as compliant |
| **Boundary value** | Exact threshold (e.g. port = 443, count = max_allowed) | Off-by-one errors in range/count checks |

```hcl
# ✅ Missing attribute — must fail (tests core::try() default)
resource "aws_s3_bucket" "missing_encryption" {
  expect_failure = true
  attrs = {
    bucket = "test-bucket"
    # server_side_encryption_configuration intentionally omitted
  }
}

# ✅ Empty list — must fail
resource "aws_s3_bucket" "empty_encryption_rules" {
  expect_failure = true
  attrs = {
    bucket = "test-bucket"
    server_side_encryption_configuration = []
  }
}
```

---

## Best Practices

### General Guidelines

1. **Use descriptive names**: `encrypted_volume_passes` not `test1`
2. **Organize by scenario**: Group passing/failing tests with comments
3. **Test edge cases**: Always include missing-attribute, null, empty-collection, and boundary-value scenarios — see [Mandatory Edge-Case Checklist](#mandatory-edge-case-checklist) above
4. **Consult provider schemas**: Match provider's block/attribute structure

### Testing Strategy

1. **Separate concerns**: One test file per policy file
2. **Use skip strategically**: Only when resource is referenced or in getresources() counts
3. **Test both sides of filters**: Resources that match and don't match
4. **Document complex references**: Add comments explaining relationships

### File Organization

```
policies/
├── cis-4.1-deny-public-ssh.policy.hcl
├── cis-4.1-deny-public-ssh.policytest.hcl
├── cis-4.2-deny-public-rdp.policy.hcl
└── cis-4.2-deny-public-rdp.policytest.hcl
```

---

## Quick Reference Table

| Policy Type | Test Block | Available Attributes |
|-------------|------------|---------------------|
| resource_policy | `resource "type" "name" { attrs = {...} }` | `attrs.*`, `meta.provider_type` (real plans only) |
| module_policy | `module "source" "name" { meta = {...} }` | `meta.source`, `meta.address`, `meta.version` |
| provider_policy | `provider "type" "name" { meta = {...} }` | `meta.source` |
| data source | `data "type" "name" { attrs = {...} }` | `attrs.*` |

### Common Features

| Feature | Syntax | Scope |
|---------|--------|-------|
| Test target | `policytest { targets = ["file.policy.hcl"] }` | Optional (best practice when multiple policies in dir) |
| Override input values | `inputs { key = value }` | Per test file — uses policy `default` if omitted |
| Expected failure | `expect_failure = true` | All policies |
| Skip evaluation | `skip = true` | Resources only |
| Cross-resource ref | `resource_type.name.attrs.attribute` | Same file only |
| Omitted attributes | Don't specify in `attrs = {}` | Causes error unless policy uses `core::try()` |

---

## Advanced Testing Patterns (Real-World Learnings)

### Cross-Resource Lookup Pattern

**Problem:** Need to enforce that every S3 bucket has a corresponding encryption configuration.

**Solution:** Evaluate buckets, look up encryption configs via `core::getresources()`.

```hcl
# Top-level: Get all encryption configs once
locals {
    all_encryption_configs = core::getresources("aws_s3_bucket_server_side_encryption_configuration", {})
}

# Resource-level: Find matching config for each bucket
resource_policy "aws_s3_bucket" "require_encryption" {
    locals {
        matching_configs = [
            for config in local.all_encryption_configs :
            config if config.bucket == attrs.bucket
        ]
    }
    enforce {
        condition = core::try(local.matching_configs[0], null) != null
        error_message = "Bucket must have encryption config"
    }
}
```

**Test Structure:**
```hcl
# Evaluated resource - NO skip
resource "aws_s3_bucket" "test" {
    attrs = { bucket = "test" }
}

# Looked-up resource - YES skip (but still visible to core::getresources)
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
    skip = true
    attrs = {
        bucket = aws_s3_bucket.test.bucket
        rule = [{ ... }]  # Must be array!
    }
}
```

**Key Points:**
- ✅ Resources with `skip = true` ARE visible to `core::getresources()`
- ✅ Use top-level `locals` for `core::getresources()` (performance)
- ✅ Always evaluate the resource that must exist, look up optional ones

### The Two-Check Pattern

**Problem:** Need to check two related attributes to determine compliance.

**Example:** S3 must use customer-managed KMS keys (not AWS-managed or AES256).

AWS encryption types:
- SSE-S3 (AES256) - S3-managed keys ❌
- SSE-KMS without key ID - AWS-managed "aws/s3" key ❌
- SSE-KMS with key ID - Customer-managed key ✅

**Why one check fails:**
```hcl
# ❌ Only checks algorithm
condition = attrs.sse_algorithm == "aws:kms"
# PASSES even without kms_master_key_id (uses AWS-managed key!)

# ❌ Only checks key ID
condition = attrs.kms_master_key_id != ""
# PASSES even with "AES256" algorithm (not using KMS!)
```

**Correct: Check both**
```hcl
locals {
    sse_algorithm = core::try(attrs.encryption[0].sse_algorithm, "")
    kms_key_id = core::try(attrs.encryption[0].kms_master_key_id, "")
}
enforce {
    condition = local.sse_algorithm == "aws:kms" && local.kms_key_id != ""
    error_message = "Must use customer-managed KMS. Found algorithm: '${local.sse_algorithm}', key specified: ${local.kms_key_id != ""}"
}
```

### Test File Size Limitation

**Discovery:** With two-policy approach (one policy for buckets, another for encryption configs), test files fail when they contain 5+ buckets.

**Workaround 1:** Use single-policy approach (no limit observed)
```hcl
# ✅ One policy evaluates buckets, looks up configs
resource_policy "aws_s3_bucket" "require_encryption" {
    # Can test 6+ buckets in single file
}
```

**Workaround 2:** Split tests across multiple files (max 4 buckets each)
```
tests/
├── test-scenario-1.policytest.hcl  # 4 buckets
├── test-scenario-2.policytest.hcl  # 4 buckets
└── test-scenario-3.policytest.hcl  # 4 buckets
```

### Common Test Mistakes

**Mistake:** Wrong resource has `skip` or `expect_failure`
```hcl
# ❌ WRONG - Policy evaluates buckets but test skips them
resource "aws_s3_bucket" "test" {
    skip = true  # Policy can't evaluate this!
}
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
    expect_failure = true  # Policy doesn't evaluate this!
}

# ✅ CORRECT - Match policy evaluation target
resource "aws_s3_bucket" "test" {
    expect_failure = true  # Policy evaluates buckets
}
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
    skip = true  # Policy looks this up via core::getresources()
}
```

**Mistake:** Using objects instead of arrays
```hcl
# ❌ WRONG
attrs = {
    rule = { key = "value" }  # Object
}

# ✅ CORRECT
attrs = {
    rule = [{ key = "value" }]  # Array
}
```

**Reason:** Terraform resources use arrays. Policies access `attrs.rule[0]`.

---

## Known Policytest Framework Limitations

These are behaviors where `tfpolicy test` passes silently but a real `terraform plan --policies=` run fails or behaves differently. Always verify port-range and integer-arithmetic policies against a real plan.

### `core::range()` with dynamic integer attributes returns empty in policytest

`core::range(start, end)` works correctly when called with hardcoded integer literals. However, when `start` or `end` come from mocked `attrs.*` integer values (e.g. `attrs.from_port`, `attrs.to_port`), the policytest framework treats those values as unknown/unevaluated at test time and `core::range()` silently returns an empty list `[]`.

**Impact:** A policy that uses `core::range()` with dynamic port attributes will appear to pass all tests — including `expect_failure` cases — because the range is always empty. The bug only surfaces against a real plan.

> ⚠️ **`core::alltrue()` and `core::anytrue()` do NOT exist in tfpolicy runtime.** Using them will produce `Error: Call to unknown function / There is no function named "alltrue" in namespace core::.`. The examples below show the **problem pattern** (❌) and the **correct alternative** (✅).

```hcl
# ❌ WRONG — core::range() + core::alltrue() — both problematic
locals {
  ports_in_range = core::range(core::try(attrs.from_port, 0), core::try(attrs.to_port, 0) + 1)
  # ↑ returns [] in policytest because attrs.from_port/to_port are unknown at test time
  all_authorized = core::alltrue([for p in local.ports_in_range : core::contains(local.authorized_ports, p)])
  # ↑ core::alltrue does NOT exist — will error; also core::range() returns [] here
}
```

**Fix:** Use the count approach instead — it works correctly with dynamic `attrs.*` values in both policytest and real plans:
```hcl
# ✅ Count approach — consistent in policytest and real plan evaluation
locals {
  authorized_ports     = [80, 443]
  from_port            = core::try(attrs.from_port, 0)
  to_port              = core::try(attrs.to_port, 0)
  authorized_in_range  = [for p in local.authorized_ports : p if p >= local.from_port && p <= local.to_port]
  all_ports_authorized = core::length(local.authorized_in_range) == (local.to_port - local.from_port + 1)
}
```

See `verified-syntax.md` Mistake 23 for the full pattern.

### `core::getresources()` sees ALL resources in the test file — isolate conflicting scenarios into separate files

In `tfpolicy test`, when a policy calls `core::getresources("some_type", filter)`, the lookup searches **all mock resources of that type in the entire test file** — including resources marked `expect_failure = true` and resources marked `skip = true`.

**Impact:** A test scenario that requires `core::getresources()` to return zero results (or no compliant results) will silently produce the wrong outcome if any other scenario in the same file defines a resource of that type that satisfies the filter.

```hcl
# ❌ PROBLEMATIC — both scenarios in the same test file
# "fail_no_defaults" incorrectly passes because core::getresources() picks up
# the compliant_defaults resource from the other scenario.

resource "aws_ec2_instance_metadata_defaults" "compliant_defaults" {
  skip = true  # skip = true is still visible to core::getresources()!
  attrs = { http_tokens = "required" }
}

resource "aws_instance" "pass_with_defaults" {
  attrs = { instance_type = "t3.micro" }
}

resource "aws_instance" "fail_no_defaults" {
  expect_failure = true
  attrs = { instance_type = "t3.micro" }
  # WRONG: core::getresources("aws_ec2_instance_metadata_defaults", ...) still sees
  # "compliant_defaults" above → policy evaluates as compliant → expect_failure passes incorrectly.
}
```

**Fix:** Place scenarios with conflicting `core::getresources()` context into separate `.policytest.hcl` files. Each file is an independent resource graph.

```hcl
# ✅ File 1: test-with-compliant-defaults.policytest.hcl
resource "aws_ec2_instance_metadata_defaults" "compliant_defaults" {
  skip = true
  attrs = { http_tokens = "required" }
}
resource "aws_instance" "pass_with_defaults" {
  attrs = { instance_type = "t3.micro" }
}

# ✅ File 2: test-no-defaults.policytest.hcl
# No aws_ec2_instance_metadata_defaults defined — core::getresources() returns empty list.
resource "aws_instance" "fail_no_defaults" {
  expect_failure = true
  attrs = { instance_type = "t3.micro" }
}
```

**Rule:** Whenever a test scenario relies on `core::getresources()` returning zero results (or no compliant results) for a given type, that scenario must be in its own `.policytest.hcl` file, completely isolated from any scenario that defines resources of that same type.

---

## Related

- [Verified Syntax Reference](verified-syntax.md) | [tfpolicy-author skill](tfpolicy-author.md) | [tfpolicy-test skill](tfpolicy-test.md)

---


## Table of Contents

1. [Testing Basics](#testing-basics)
2. [Resource Policy Testing](#resource-policy-testing)
3. [Module Policy Testing](#module-policy-testing)
4. [Provider Policy Testing](#provider-policy-testing)
5. [Advanced Techniques](#advanced-techniques)
6. [Best Practices](#best-practices)

---

## Testing Basics

### Test File Structure

```hcl
# Optional: specify which policy files to test
policytest {
  targets = ["policy-file-1.policy.hcl", "policy-file-2.policy.hcl"]
}

# Mock resources with expected outcomes
resource "aws_s3_bucket" "passing_bucket" {
  attrs = {
    bucket = "my-secure-bucket"
    versioning = [{ enabled = true }]
  }
}

resource "aws_s3_bucket" "failing_bucket" {
  expect_failure = true
  attrs = {
    bucket = "my-insecure-bucket"
    versioning = [{ enabled = false }]
  }
}
```

**Full test file structure with all supported blocks:**
```hcl
policytest {
  targets = ["policy-file.policy.hcl"]
}

# Override input defaults for this test file
inputs {
  port = 90
}

resource "aws_security_group_rule" "should_fail_port_90" {
  expect_failure = true
  attrs = {
    type        = "ingress"
    from_port   = 80
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Key Points:**
- **Best practice: include `policytest { targets = ["<policy-file>.policy.hcl"] }` when multiple policies exist in the same directory.** Without it, `tfpolicy test` evaluates the mock against every policy in the directory — a test resource intended for one policy will silently run against others, producing misleading results. `expect_failure = true` on such a resource can pass for the wrong reason.
- `expect_failure = true` applies to ALL policies evaluating the resource
- **`expect_failure` is ONLY valid on `resource {}` blocks** — using it on `data {}` blocks causes `Unsupported argument` error

> **⚠️ Critical: `tfpolicy test` does NOT evaluate `error_message`**
>
> `tfpolicy test` only evaluates the `condition` expression. It **never** evaluates or interpolates the `error_message` string. This means:
> - A policy with `error_message = "Failed: ${meta.address}"` will pass all `tfpolicy test` runs even though `meta.address` is UNDEFINED and will crash every resource at runtime.
> - **Only `terraform plan --policies=` evaluates `error_message`** — always validate generated policies against a real Terraform plan to catch this class of bug.
- **CRITICAL:** Omitted attributes cause evaluation errors if accessed directly. Always use `core::try()` to handle missing attributes

### Test Execution Behavior

1. **Multiple policies evaluate same resources** - All matching policies run against all matching test resources
2. **Tests continue on failure** - All tests run to completion, not stopping at first failure
3. **Exit codes for CI/CD**:
   - Exit 0: All tests pass (including expected failures)
   - Exit 1: Unexpected failures or errors

**CI/CD Usage:**
```bash
tfpolicy test --policies=./policies --tests=./tests
if [ $? -eq 0 ]; then echo "Passed"; else echo "Failed"; exit 1; fi
```

---

## Resource Policy Testing

### Basic Syntax

```hcl
resource "resource_type" "test_name" {
  expect_failure = true/false  # Optional — ONLY valid on resource blocks, NOT data blocks
  skip = true/false            # Optional
  attrs = {
    # All resource attributes
  }
}
```

> **⚠️ `expect_failure` is NOT supported on `data {}` blocks.** Using it on a data block causes `Unsupported argument "expect_failure"`. Only mock `resource {}` blocks support this attribute.

### Omitted Attributes Behavior

**CRITICAL:** Attributes accessed by policies MUST be provided in test mocks or wrapped with `core::try()`.

**Direct Access (Causes Error):**
```hcl
# Policy
resource_policy "aws_ebs_volume" "check" {
  enforce {
    condition = attrs.encrypted == true  # Direct access
  }
}

# Test - ERROR if encrypted is omitted
resource "aws_ebs_volume" "test" {
  attrs = {
    size = 100
    # encrypted omitted - causes "This object does not have an attribute named 'encrypted'"
  }
}
```

**Safe Access with core::try():**
```hcl
# Policy
resource_policy "aws_ebs_volume" "check" {
  locals {
    encrypted = core::try(attrs.encrypted, false)  # Safe access
  }
  enforce {
    condition = local.encrypted == true
  }
}

# Test - Works even if encrypted is omitted
resource "aws_ebs_volume" "test" {
  attrs = {
    size = 100
    # encrypted omitted - core::try() returns false (default value)
  }
}
```

**Rule:** Only attributes NOT accessed by the policy can be safely omitted. All accessed attributes must either:
1. Be provided in the mock's `attrs = {}` block, OR
2. Be accessed via `core::try()` in the policy

### Testing Operation-Aware Policies

Policies can scope themselves to specific plan operations via `operations = ["create", "update", "delete"]`. Test mocks support a matching `prior_attrs = { ... }` block alongside `attrs = { ... }`, so create, update, and delete-gate policies are all fully testable.

**Mock shape per operation:**

| Operation being tested | Provide `attrs` | Provide `prior_attrs` |
| --- | --- | --- |
| `create` | ✅ planned values | — |
| `update` | ✅ planned values | ✅ pre-change values |
| `delete` | — | ✅ pre-change values |

**Create / update policy (planned values only):**

```hcl
# Policy
resource_policy "tfe_workspace" "require_project" {
  operations = ["create", "update"]
  enforce {
    condition     = core::try(attrs.project_id, "") != ""
    error_message = "tfe_workspace must have project_id set."
  }
}
```

```hcl
# Test
policytest { targets = ["workspace-require-project.policy.hcl"] }

resource "tfe_workspace" "with_project" {
  attrs = { project_id = "prj-123" }
}

resource "tfe_workspace" "missing_project" {
  expect_failure = true
  attrs          = {}
}
```

**Update policy (reads both `attrs` and `prior_attrs`):**

```hcl
# Policy — block downgrades
resource_policy "tfe_workspace" "no_downgrade" {
  operations = ["update"]
  enforce {
    condition     = core::try(attrs.terraform_version, "") == core::try(prior_attrs.terraform_version, "")
                 || core::try(attrs.terraform_version, "") > core::try(prior_attrs.terraform_version, "")
    error_message = "terraform_version downgrade is not allowed."
  }
}
```

```hcl
# Test
policytest { targets = ["workspace-no-downgrade.policy.hcl"] }

resource "tfe_workspace" "upgrade_ok" {
  attrs       = { terraform_version = "1.10.0" }
  prior_attrs = { terraform_version = "1.9.0" }
}

resource "tfe_workspace" "downgrade_blocked" {
  expect_failure = true
  attrs          = { terraform_version = "1.5.0" }
  prior_attrs    = { terraform_version = "1.9.0" }
}
```

**Delete-gate policy (pre-change state only):**

```hcl
# Policy
resource_policy "tfe_workspace" "deny_delete_without_tag" {
  operations = ["delete"]
  locals {
    prior_tag_names = core::try(prior_attrs.tag_names, [])
  }
  enforce {
    condition     = core::contains(local.prior_tag_names, "delete")
    error_message = "Add 'delete' tag before destroying a workspace."
  }
}
```

```hcl
# Test
policytest { targets = ["workspace-deny-delete-without-tag.policy.hcl"] }

resource "tfe_workspace" "has_delete_tag" {
  prior_attrs = { tag_names = ["delete", "prod"] }
}

resource "tfe_workspace" "missing_delete_tag" {
  expect_failure = true
  prior_attrs    = { tag_names = ["prod"] }
}
```

> **Note:** The runner currently evaluates each mock against every policy listed in `targets` regardless of the policy's `operations` scope. Keep your `.policytest.hcl` file targeted at a single policy (or a set of policies that share the same operation scope), and only supply the `attrs` / `prior_attrs` fields that policy actually reads.

### Provider Schema Awareness

The structure of `attrs = {}` depends on provider schema. Consult provider docs to determine if attributes are blocks or direct values.

**Example - Blocks vs Attributes:**
```hcl
resource "aws_instance" "test" {
  attrs = {
    instance_type = "t2.micro"  # Direct attribute

    # Block (requires array of maps)
    default_tags = [{
      tags = {
        Environment = "Production"
      }
    }]
  }
}
```

**In test files:** Use `=` for blocks (not `{}` syntax used in policy files)

### Cross-Resource References

Reference other test resources within the SAME file using `resource_type.name.attrs.attribute`:

```hcl
resource "aws_security_group" "app_sg" {
  attrs = {
    name = "app-security-group"
  }
}

resource "aws_instance" "app_server" {
  attrs = {
    vpc_security_group_ids = [aws_security_group.app_sg.attrs.name]
  }
}
```

**Limitation:** References cannot span across test files.

### The skip Attribute

Resources with `skip = true`:
- Are added to resource graph
- Are NOT evaluated by policies
- CAN be referenced by other resources
- ARE included in `core::getresources()` results

```hcl
resource "aws_ebs_volume" "available_for_reference" {
  skip = true
  attrs = {
    volume_id = "vol-12345"
  }
}

resource "aws_instance" "server" {
  attrs = {
    ebs_block_device = [{
      volume_id = aws_ebs_volume.available_for_reference.attrs.volume_id
    }]
  }
}
```

**Use skip only when:** Resource is referenced or needed in getresources() counts.

### Testing Filters

If a resource doesn't match the filter, it's NOT evaluated (test passes):

```hcl
# Policy with filter
resource_policy "aws_s3_bucket" {
  filter = attrs.bucket_prefix == "secure-"
  enforce {
    condition = attrs.versioning[0].enabled == true
  }
}

# Test - doesn't match filter, so passes
resource "aws_s3_bucket" "filtered_out" {
  attrs = {
    bucket_prefix = "public-"  # Doesn't match filter
    versioning = [{ enabled = false }]
  }
}
```

**Best Practice:** Test both resources that match and don't match the filter.

### Resource Policy Meta Attributes

**IMPORTANT:** Meta attributes for `resource_policy` behave differently in mock tests vs real terraform plan evaluation.

**Available Meta Attributes by Evaluation Mode:**

| Meta Attribute | Mock Tests (`tfpolicy test`) | Real Plans (`terraform plan --policies=`) |
|----------------|------------------------------|------------------------------------------|
| `meta.provider_type` | ❌ UNDEFINED | ✅ Available (e.g., "aws", "azurerm") |
| `meta.type` | ❌ UNDEFINED | ❌ UNDEFINED |
| `meta.address` | ❌ UNDEFINED | ❌ UNDEFINED |

**Example:**
```hcl
# Policy using meta.provider_type
resource_policy "aws_ebs_volume" "check_provider" {
  enforce {
    condition = core::try(meta.provider_type, "UNDEFINED") == "aws"
    error_message = "Provider type: ${core::try(meta.provider_type, "UNDEFINED")}"
  }
}
```

**Test behavior:**
- With `tfpolicy test`: `meta.provider_type` returns UNDEFINED (test may fail)
- With `terraform plan --policies=`: `meta.provider_type` returns "aws" (test passes)

**Best Practice:** When using `meta.provider_type` in policies, always wrap with `core::try()` and note that mock tests cannot fully validate this behavior. Test with real terraform plans for complete validation.

---

## Module Policy Testing

### Module Test Syntax

```hcl
module "source" "test_name" {
  expect_failure = true/false  # Optional
  meta = {
    source  = "registry.terraform.io/namespace/name"
    address = "module.name"
    version = "1.0.0"
  }
}
```

**Available meta attributes:**
- `source` - Module source
- `address` - Module address (e.g., "module.database")
- `version` - Module version

**Note:** Modules use `meta` only (no `attrs`)

### Example: Module Source Allowlist

**Policy:**
```hcl
locals {
  allowed_sources = [
    "registry.terraform.io/hashicorp/aws",
    "registry.terraform.io/terraform-aws-modules/vpc/aws"
  ]
}

module_policy "*" "approved_sources" {
  filter = meta.source != null
  enforce {
    condition = core::contains(local.allowed_sources, meta.source)
    error_message = "Unauthorized module source: ${meta.source}"
  }
}
```

**Test:**
```hcl
# Passing
module "registry.terraform.io/hashicorp/aws" "approved" {
  meta = {
    source  = "registry.terraform.io/hashicorp/aws"
    address = "module.database"
    version = "1.0.0"
  }
}

# Failing
module "registry.terraform.io/acme-corp/database" "unauthorized" {
  expect_failure = true
  meta = {
    source  = "registry.terraform.io/acme-corp/database"
    address = "module.db"
    version = "2.0.0"
  }
}
```

### Example: Module Version Enforcement

**Policy:**
```hcl
module_policy "registry.terraform.io/hashicorp/aws" "version_check" {
  filter = meta.source == "registry.terraform.io/hashicorp/aws"
  enforce {
    condition = core::semverconstraint(meta.version, ">= 4.0.0")
    error_message = "Module must use version >= 4.0.0, found ${meta.version}"
  }
}
```

---

## Provider Policy Testing

### Provider Test Syntax

```hcl
provider "type" "test_name" {
  expect_failure = true/false  # Optional
  meta = {
    source = "registry.terraform.io/namespace/name"
  }
}
```

**Available meta attributes:**
- `source` - Provider source (e.g., "registry.terraform.io/hashicorp/aws")

**Note:** Provider type (e.g., "aws") goes in block declaration, not meta.

### Example: Provider Source Allowlist

**Policy:**
```hcl
locals {
  allowed_provider_sources = [
    "registry.terraform.io/hashicorp/aws",
    "registry.terraform.io/hashicorp/azurerm"
  ]
}

provider_policy "aws" {
  enforce {
    condition = core::contains(local.allowed_provider_sources, meta.source)
    error_message = "Provider source '${meta.source}' is not approved"
  }
}
```

**Test:**
```hcl
# Passing
provider "aws" "official" {
  meta = {
    source = "registry.terraform.io/hashicorp/aws"
  }
}

# Failing
provider "aws" "unofficial" {
  expect_failure = true
  meta = {
    source = "registry.terraform.io/acme-corp/aws"
  }
}
```

### Common Provider Patterns

1. **Official providers only**: Check `meta.source == "registry.terraform.io/hashicorp/aws"`
2. **Version constraints**: Use `core::semverconstraint(meta.version, ">= 4.0.0, < 6.0.0")`
3. **Allowlist by type**: Create separate provider_policy for each allowed type

---

## Advanced Techniques

### Data Source Mocking

```hcl
data "aws_ami" "ubuntu" {
  attrs = {
    id = "ami-12345"
    name = "ubuntu-20.04"
  }
}

# Policy can reference it
resource_policy "aws_instance" {
  enforce {
    condition = attrs.ami == data.aws_ami.ubuntu.attrs.id
  }
}
```

### Workspace Context Limitations

❌ **Not Available:** `terraform.workspace` or workspace context

**Valid traversal roots:**
- `input` - Input variables
- `local` - Local variables
- `attrs` - Resource/data source attributes
- `meta` - Metadata

**Workarounds:**
1. Use resource tags for environment-based logic
2. Separate policy sets per environment in HCP Terraform
3. CI/CD-level enforcement based on workspace name
4. Tag-based validation

### Testing Collections

```hcl
resource "aws_security_group" "multiple_rules" {
  attrs = {
    ingress = [
      {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
      },
      {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }
    ]
  }
}
```

### Testing Null/Missing Attributes

**Only works if policy uses `core::try()`:**

```hcl
# Policy must use core::try() to handle missing attributes
resource_policy "aws_s3_bucket" "check" {
  locals {
    encryption = core::try(attrs.server_side_encryption_configuration, null)
  }
  enforce {
    condition = local.encryption != null
    error_message = "Encryption required"
  }
}

# Test - omitted attribute handled by core::try()
resource "aws_s3_bucket" "no_encryption" {
  expect_failure = true
  attrs = {
    bucket = "my-bucket"
    # server_side_encryption_configuration omitted - handled by core::try()
  }
}
```

**Without `core::try()`, omitting accessed attributes causes evaluation errors.**

---

### Testing Policies with `input` Blocks

Policies that use `input` blocks can have their input values overridden per test file using an **`inputs {}`** block (plural). This allows you to test the policy behaviour under different configurations without changing the policy itself.

> ⚠️ The block is `inputs {}` (plural) — using `input {}` (singular) throws `Unsupported block type` error.

```hcl
# Policy (test.policy.hcl)
input "port" {
  type    = number
  default = 22
}

resource_policy "aws_security_group_rule" "no_open_ingress" {
  filter = core::try(attrs.type, "") == "ingress"
  locals {
    covers_port = core::try(attrs.from_port <= input.port && attrs.to_port >= input.port, false)
  }
  enforce {
    condition     = !local.covers_port
    error_message = "Ingress rule covers restricted port ${input.port}."
  }
}
```

```hcl
# Test file 1: test with default port (22)
policytest {
  targets = ["test.policy.hcl"]
}
# No inputs block — uses input.port default = 22

# PASS: port range 80-443 does not cover default port 22
resource "aws_security_group_rule" "pass_default_port" {
  attrs = {
    type      = "ingress"
    from_port = 80
    to_port   = 443
    protocol  = "tcp"
  }
}

# FAIL: port range 1-1024 covers default port 22
resource "aws_security_group_rule" "fail_default_port" {
  expect_failure = true
  attrs = {
    type      = "ingress"
    from_port = 1
    to_port   = 1024
    protocol  = "tcp"
  }
}
```

```hcl
# Test file 2: test with custom port (90)
policytest {
  targets = ["test.policy.hcl"]
}

inputs {
  port = 90   # override default of 22
}

# FAIL: port range 80-443 DOES cover custom port 90
resource "aws_security_group_rule" "fail_custom_port" {
  expect_failure = true
  attrs = {
    type      = "ingress"
    from_port = 80
    to_port   = 443
    protocol  = "tcp"
  }
}
```

**Key points:**
- Each test file can have its own `inputs {}` block with different values — use separate `.policytest.hcl` files per input scenario
- When no `inputs {}` block is present, the policy's `default` values are used
- Always add a comment to each test file stating which input values it assumes — prevents confusion when the same resource mock produces different results under different inputs
- **Note:** input values can only be overridden at policy-set level in HCP Terraform for live enforcement — `inputs {}` in test files is for test-time validation only

Every generated `.policytest.hcl` **must** include test cases for the following scenarios. Missing any of these is a test coverage gap:

| Scenario | Mock pattern | Why it matters |
|----------|-------------|----------------|
| **Missing attribute** (omitted entirely) | `attrs = { bucket = "x" }` — target attribute not present | Crashes policies that don't use `core::try()`; most common real-world gap |
| **Null attribute** | `attrs = { ..., field = null }` | Tests `core::try()` default handling |
| **Empty list** | `attrs = { ..., items = [] }` | Policies expecting non-empty collections must handle `[]` |
| **Empty string** | `attrs = { ..., value = "" }` | String-check policies must not treat `""` as compliant |
| **Boundary value** | Exact threshold (e.g. port = 443, count = max_allowed) | Off-by-one errors in range/count checks |

```hcl
# ✅ Missing attribute — must fail (tests core::try() default)
resource "aws_s3_bucket" "missing_encryption" {
  expect_failure = true
  attrs = {
    bucket = "test-bucket"
    # server_side_encryption_configuration intentionally omitted
  }
}

# ✅ Empty list — must fail
resource "aws_s3_bucket" "empty_encryption_rules" {
  expect_failure = true
  attrs = {
    bucket = "test-bucket"
    server_side_encryption_configuration = []
  }
}
```

---

## Best Practices

### General Guidelines

1. **Use descriptive names**: `encrypted_volume_passes` not `test1`
2. **Organize by scenario**: Group passing/failing tests with comments
3. **Test edge cases**: Always include missing-attribute, null, empty-collection, and boundary-value scenarios — see [Mandatory Edge-Case Checklist](#mandatory-edge-case-checklist) above
4. **Consult provider schemas**: Match provider's block/attribute structure

### Testing Strategy

1. **Separate concerns**: One test file per policy file
2. **Use skip strategically**: Only when resource is referenced or in getresources() counts
3. **Test both sides of filters**: Resources that match and don't match
4. **Document complex references**: Add comments explaining relationships

### File Organization

```
policies/
├── cis-4.1-deny-public-ssh.policy.hcl
├── cis-4.1-deny-public-ssh.policytest.hcl
├── cis-4.2-deny-public-rdp.policy.hcl
└── cis-4.2-deny-public-rdp.policytest.hcl
```

---

## Quick Reference Table

| Policy Type | Test Block | Available Attributes |
|-------------|------------|---------------------|
| resource_policy | `resource "type" "name" { attrs = {...} }` | `attrs.*`, `meta.provider_type` (real plans only) |
| module_policy | `module "source" "name" { meta = {...} }` | `meta.source`, `meta.address`, `meta.version` |
| provider_policy | `provider "type" "name" { meta = {...} }` | `meta.source` |
| data source | `data "type" "name" { attrs = {...} }` | `attrs.*` |

### Common Features

| Feature | Syntax | Scope |
|---------|--------|-------|
| Test target | `policytest { targets = ["file.policy.hcl"] }` | Optional (best practice when multiple policies in dir) |
| Override input values | `inputs { key = value }` | Per test file — uses policy `default` if omitted |
| Expected failure | `expect_failure = true` | All policies |
| Skip evaluation | `skip = true` | Resources only |
| Cross-resource ref | `resource_type.name.attrs.attribute` | Same file only |
| Omitted attributes | Don't specify in `attrs = {}` | Causes error unless policy uses `core::try()` |

---

## Advanced Testing Patterns (Real-World Learnings)

### Cross-Resource Lookup Pattern

**Problem:** Need to enforce that every S3 bucket has a corresponding encryption configuration.

**Solution:** Evaluate buckets, look up encryption configs via `core::getresources()`.

```hcl
# Top-level: Get all encryption configs once
locals {
    all_encryption_configs = core::getresources("aws_s3_bucket_server_side_encryption_configuration", {})
}

# Resource-level: Find matching config for each bucket
resource_policy "aws_s3_bucket" "require_encryption" {
    locals {
        matching_configs = [
            for config in local.all_encryption_configs :
            config if config.bucket == attrs.bucket
        ]
    }
    enforce {
        condition = core::try(local.matching_configs[0], null) != null
        error_message = "Bucket must have encryption config"
    }
}
```

**Test Structure:**
```hcl
# Evaluated resource - NO skip
resource "aws_s3_bucket" "test" {
    attrs = { bucket = "test" }
}

# Looked-up resource - YES skip (but still visible to core::getresources)
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
    skip = true
    attrs = {
        bucket = aws_s3_bucket.test.bucket
        rule = [{ ... }]  # Must be array!
    }
}
```

**Key Points:**
- ✅ Resources with `skip = true` ARE visible to `core::getresources()`
- ✅ Use top-level `locals` for `core::getresources()` (performance)
- ✅ Always evaluate the resource that must exist, look up optional ones

### The Two-Check Pattern

**Problem:** Need to check two related attributes to determine compliance.

**Example:** S3 must use customer-managed KMS keys (not AWS-managed or AES256).

AWS encryption types:
- SSE-S3 (AES256) - S3-managed keys ❌
- SSE-KMS without key ID - AWS-managed "aws/s3" key ❌
- SSE-KMS with key ID - Customer-managed key ✅

**Why one check fails:**
```hcl
# ❌ Only checks algorithm
condition = attrs.sse_algorithm == "aws:kms"
# PASSES even without kms_master_key_id (uses AWS-managed key!)

# ❌ Only checks key ID
condition = attrs.kms_master_key_id != ""
# PASSES even with "AES256" algorithm (not using KMS!)
```

**Correct: Check both**
```hcl
locals {
    sse_algorithm = core::try(attrs.encryption[0].sse_algorithm, "")
    kms_key_id = core::try(attrs.encryption[0].kms_master_key_id, "")
}
enforce {
    condition = local.sse_algorithm == "aws:kms" && local.kms_key_id != ""
    error_message = "Must use customer-managed KMS. Found algorithm: '${local.sse_algorithm}', key specified: ${local.kms_key_id != ""}"
}
```

### Test File Size Limitation

**Discovery:** With two-policy approach (one policy for buckets, another for encryption configs), test files fail when they contain 5+ buckets.

**Workaround 1:** Use single-policy approach (no limit observed)
```hcl
# ✅ One policy evaluates buckets, looks up configs
resource_policy "aws_s3_bucket" "require_encryption" {
    # Can test 6+ buckets in single file
}
```

**Workaround 2:** Split tests across multiple files (max 4 buckets each)
```
tests/
├── test-scenario-1.policytest.hcl  # 4 buckets
├── test-scenario-2.policytest.hcl  # 4 buckets
└── test-scenario-3.policytest.hcl  # 4 buckets
```

### Common Test Mistakes

**Mistake:** Wrong resource has `skip` or `expect_failure`
```hcl
# ❌ WRONG - Policy evaluates buckets but test skips them
resource "aws_s3_bucket" "test" {
    skip = true  # Policy can't evaluate this!
}
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
    expect_failure = true  # Policy doesn't evaluate this!
}

# ✅ CORRECT - Match policy evaluation target
resource "aws_s3_bucket" "test" {
    expect_failure = true  # Policy evaluates buckets
}
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
    skip = true  # Policy looks this up via core::getresources()
}
```

**Mistake:** Using objects instead of arrays
```hcl
# ❌ WRONG
attrs = {
    rule = { key = "value" }  # Object
}

# ✅ CORRECT
attrs = {
    rule = [{ key = "value" }]  # Array
}
```

**Reason:** Terraform resources use arrays. Policies access `attrs.rule[0]`.

---

## Known Policytest Framework Limitations

These are behaviors where `tfpolicy test` passes silently but a real `terraform plan --policies=` run fails or behaves differently. Always verify port-range and integer-arithmetic policies against a real plan.

### `core::range()` with dynamic integer attributes returns empty in policytest

`core::range(start, end)` works correctly when called with hardcoded integer literals. However, when `start` or `end` come from mocked `attrs.*` integer values (e.g. `attrs.from_port`, `attrs.to_port`), the policytest framework treats those values as unknown/unevaluated at test time and `core::range()` silently returns an empty list `[]`.

**Impact:** A policy that uses `core::range()` with dynamic port attributes will appear to pass all tests — including `expect_failure` cases — because the range is always empty. The bug only surfaces against a real plan.

> ⚠️ **`core::alltrue()` and `core::anytrue()` do NOT exist in tfpolicy runtime.** Using them will produce `Error: Call to unknown function / There is no function named "alltrue" in namespace core::.`. The examples below show the **problem pattern** (❌) and the **correct alternative** (✅).

```hcl
# ❌ WRONG — core::range() + core::alltrue() — both problematic
locals {
  ports_in_range = core::range(core::try(attrs.from_port, 0), core::try(attrs.to_port, 0) + 1)
  # ↑ returns [] in policytest because attrs.from_port/to_port are unknown at test time
  all_authorized = core::alltrue([for p in local.ports_in_range : core::contains(local.authorized_ports, p)])
  # ↑ core::alltrue does NOT exist — will error; also core::range() returns [] here
}
```

**Fix:** Use the count approach instead — it works correctly with dynamic `attrs.*` values in both policytest and real plans:
```hcl
# ✅ Count approach — consistent in policytest and real plan evaluation
locals {
  authorized_ports     = [80, 443]
  from_port            = core::try(attrs.from_port, 0)
  to_port              = core::try(attrs.to_port, 0)
  authorized_in_range  = [for p in local.authorized_ports : p if p >= local.from_port && p <= local.to_port]
  all_ports_authorized = core::length(local.authorized_in_range) == (local.to_port - local.from_port + 1)
}
```

See `verified-syntax.md` Mistake 23 for the full pattern.

### `core::getresources()` sees ALL resources in the test file — isolate conflicting scenarios into separate files

In `tfpolicy test`, when a policy calls `core::getresources("some_type", filter)`, the lookup searches **all mock resources of that type in the entire test file** — including resources marked `expect_failure = true` and resources marked `skip = true`.

**Impact:** A test scenario that requires `core::getresources()` to return zero results (or no compliant results) will silently produce the wrong outcome if any other scenario in the same file defines a resource of that type that satisfies the filter.

```hcl
# ❌ PROBLEMATIC — both scenarios in the same test file
# "fail_no_defaults" incorrectly passes because core::getresources() picks up
# the compliant_defaults resource from the other scenario.

resource "aws_ec2_instance_metadata_defaults" "compliant_defaults" {
  skip = true  # skip = true is still visible to core::getresources()!
  attrs = { http_tokens = "required" }
}

resource "aws_instance" "pass_with_defaults" {
  attrs = { instance_type = "t3.micro" }
}

resource "aws_instance" "fail_no_defaults" {
  expect_failure = true
  attrs = { instance_type = "t3.micro" }
  # WRONG: core::getresources("aws_ec2_instance_metadata_defaults", ...) still sees
  # "compliant_defaults" above → policy evaluates as compliant → expect_failure passes incorrectly.
}
```

**Fix:** Place scenarios with conflicting `core::getresources()` context into separate `.policytest.hcl` files. Each file is an independent resource graph.

```hcl
# ✅ File 1: test-with-compliant-defaults.policytest.hcl
resource "aws_ec2_instance_metadata_defaults" "compliant_defaults" {
  skip = true
  attrs = { http_tokens = "required" }
}
resource "aws_instance" "pass_with_defaults" {
  attrs = { instance_type = "t3.micro" }
}

# ✅ File 2: test-no-defaults.policytest.hcl
# No aws_ec2_instance_metadata_defaults defined — core::getresources() returns empty list.
resource "aws_instance" "fail_no_defaults" {
  expect_failure = true
  attrs = { instance_type = "t3.micro" }
}
```

**Rule:** Whenever a test scenario relies on `core::getresources()` returning zero results (or no compliant results) for a given type, that scenario must be in its own `.policytest.hcl` file, completely isolated from any scenario that defines resources of that same type.

---

## Related

- [Verified Syntax Reference](verified-syntax.md) | [tfpolicy-author skill](tfpolicy-author.md) | [tfpolicy-test skill](tfpolicy-test.md)
