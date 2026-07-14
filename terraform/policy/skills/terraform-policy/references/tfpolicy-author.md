---
name: tfpolicy-author
description: Expert agent for authoring Terraform Policies — from natural-language requirements or Sentinel source. Covers the full workflow write new policies, convert existing Sentinel policies, parameterize with inputs, structure cross-resource checks, apply operation scoping, and produce remediation-focused error messages.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.2.0"
---

# tfpolicy-author

## Description
Expert agent for writing Terraform Policies — from either a natural-language requirement or an existing Sentinel `.sentinel` source. Covers the full authoring and conversion workflow: translate requirements or Sentinel logic into `resource_policy`, `module_policy`, or `provider_policy` HCL with correct cross-resource patterns, operation scoping, `core::` functions, parameterized inputs, and remediation-focused error messages.

> **Note:** This skill supersedes `sentinel-to-tfpolicy`. All Sentinel conversion knowledge is now consolidated here to ensure consistent behaviour when generating policies from Sentinel sources.

## Use When
- The user describes an enforcement rule and wants a `.policy.hcl` file ("block public RDS", "require encryption", "deny instance types outside an allowlist").
- The user has a Sentinel `.sentinel` file (or snippet) and wants the Terraform Policy equivalent.
- The user is migrating a Sentinel policy library to tfpolicy and needs per-policy assessment.
- The user is writing a new `resource_policy`, `module_policy`, or `provider_policy` block.
- The user is asking about tfpolicy *language* features — `filter`, `locals`, `enforce`, `input`, `operations`, `prior_attrs`, `core::*` functions, list comprehensions, version constraints, time/date functions.
- The user is asking how to structure a policy that depends on related resources via `core::getresources()` or `core::getdatasource()`.
- The user is comparing Sentinel and tfpolicy capabilities ("can I express X in tfpolicy?").

**Do not use this skill when:**
- The user is writing or debugging a `.policytest.hcl` test file — use [`tfpolicy-test`](tfpolicy-test.md).

## Capabilities

### 1. Write Policies from User Intent
Turn natural-language requirements into `resource_policy`, `module_policy`, or `provider_policy` blocks with appropriate filters, locals, enforce blocks, and remediation-focused error messages.

### 2. Convert Sentinel Policies to Terraform Policy
Translate Sentinel constructs into tfpolicy equivalents, flag non-convertible patterns with practical alternatives, produce idiomatic `.policy.hcl` from existing Sentinel sources, and apply a quality label to each conversion.

### 3. Apply Operation Scoping Correctly
Use `operations = ["create", "update", "delete"]` and `prior_attrs.<name>` to scope policies to the right plan actions and read pre-change state when relevant.

### 4. Parameterize with `input` Blocks
Replace hardcoded allowlists, version constraints, and thresholds with `input` blocks so policy sets can override values per environment.

### 5. Structure Cross-Resource Checks Safely
Use `core::getresources()` at the **top level** for plan-time joins, with value-based filters when the filter is a known literal or existing ID. Use inline `core::getresources()` inside `resource_policy` for apply-time parent+child lookups, when the filter depends on the current resource's own attribute (e.g. `{bucket = attrs.id}`). Consult the decision table (line 232) to choose the correct pattern; both top-level and inline are first-class options for their respective scenarios. Understand when cross-references will be unresolved at plan time.

### 6. Surface Runtime Pitfalls Up Front
Steer the user away from documented runtime hazards — `meta.address` is undefined in `resource_policy`, `core::try()` defaults can silently mask non-compliant resources, sets must be converted to lists for indexing, multi-line boolean expressions break the parser, etc.

## Knowledge Base

### Policy Types
```hcl
resource_policy "<resource_type>" "<policy_name>" { }
module_policy   "<module_pattern>" "<policy_name>" { }
provider_policy "<provider_pattern>" "<policy_name>" { }
```

### Core Structure
```hcl
resource_policy "aws_ebs_volume" "encryption_check" {
  # Optional: pre-filter resources before evaluation
  filter = attrs.encrypted != null

  # Optional: locals for readable logic
  locals {
    encrypted = core::try(attrs.encrypted, false)
  }

  # One or more enforce blocks
  enforce {
    condition     = local.encrypted == true
    error_message = "EBS volumes must have encryption enabled."
  }
}
```

### Available Attribute Surfaces

| Surface | Available in | Notes |
| --- | --- | --- |
| `attrs.*` | resource / module / provider | Planned values for the current target. Wrap optional fields in `core::try()`. |
| `prior_attrs.*` | resource_policy with `operations` ⊉ `["create"]` | Pre-change values. Use for `delete` and `update` scopes. |
| `meta.provider_type` | resource_policy | e.g. `"aws"`. Useful for cross-provider wildcard rules. |
| `meta.tfe_workspace.tags["<name>"]` | resource_policy only | Workspace-scoped routing (env, team, etc.). ❌ Not available in module_policy or provider_policy. |
| `meta.address` | ❌ | **UNDEFINED** in `resource_policy` real-plan evaluation. Never interpolate it into `error_message`. |
| `input.<name>` | all | Values from `input {}` blocks; overridable per policy set. |

### Operation Scoping and `prior_attrs`

```hcl
# Skip destroy
resource_policy "tfe_workspace" "require_tags" {
  operations = ["create", "update"]
  enforce {
    condition     = core::length(core::try(attrs.tag_names, [])) > 0
    error_message = "Workspace must have at least one tag."
  }
}

# Delete-gate
resource_policy "tfe_workspace" "deny_delete_without_tag" {
  operations = ["delete"]   # prior_attrs available when "create" not in operations
  locals {
    prior_tag_names = core::try(prior_attrs.tag_names, [])
  }
  enforce {
    condition     = core::contains(local.prior_tag_names, "delete")
    error_message = "Add 'delete' tag before destroying the workspace."
  }
}
```

**Rules:**
- `operations = ["create", "update"]` — fires on create/update, skips destroy.
- `operations = ["delete"]` — fires only on destroy; `prior_attrs` holds pre-change state.
- `operations = ["update"]` — fires only on updates; `prior_attrs` available.
- Default (no `operations`) = create and update (never destroy).
- `prior_attrs` is only accessible when `"create"` is NOT in `operations`.

### `input` Blocks — Parameterization

```hcl
input "allowed_instance_types" {
  type    = list(string)
  default = ["t3.micro", "t3.small", "t3.medium"]
}

resource_policy "aws_instance" "allowed_types" {
  enforce {
    condition     = core::contains(input.allowed_instance_types, attrs.instance_type)
    error_message = "Instance type '${attrs.instance_type}' is not in the allowed list."
  }
}
```

Policy sets can override `input` defaults without editing the policy file. Use `input` for: allowlists, blocklists, version constraints, numeric thresholds — values an operator may need to tune per environment.

**Rule — `input` vs hardcoded `locals`:**
- Use `input {}` **only** for operator-tunable values: allowlists, blocklists, thresholds, time windows. If a value varies per environment or policy set, it belongs in `input`.
- Use `locals` or inline literals for invariant enforcement constants — values that are part of the policy logic itself and should NOT be overridden (e.g. a fixed list of well-known dangerous ports defined by a security standard, a required protocol name).
- Do NOT promote fixed enforcement constants to `input` unless the requirement explicitly says they are configurable.

### `core::` Functions — Common Idioms

- **Null safety:** `core::try(attrs.field, default)` — single layer; don't nest. **🔴 MANDATORY: always use the two-step pattern below when the attribute may be explicitly `null`.**
- **Membership:** `core::contains(list, value)` — for lists. For string substring use `core::contains_substring`.
- **Strings:** `core::startswith`, `core::endswith`, `core::contains_substring`, `core::regex` (throws on no match — wrap in `core::try`), `core::split(separator, string)` (use with `core::parseint()` for numeric decomposition — see `verified-syntax.md` Section 2 for full examples). ❌ **Never use `+` for string concatenation** — `+` is numeric addition only; using it with strings throws `Error: Unsuitable value for left operand: a number is required`. ✅ Use `"${local.var}"` string interpolation instead: e.g. `"table/${local.table_name}"` not `"table/" + local.table_name`.
- **Aggregates:** `core::length(list_or_map)`.❌ `core::alltrue()` and `core::anytrue()` **DO NOT EXIST** in tfpolicy runtime — use `core::length()` with list comprehension: `core::length([for b in list : b if b]) > 0` instead of `anytrue`, `core::length([for b in list : b if !b]) == 0` instead of `alltrue`.
- **Ranges:** `core::range(limit)` → `[0, 1, …, limit-1]`; `core::range(lower, upper)` → `[lower, lower+1, …, upper-1]`; `core::range(lower, upper, step)` → step-incremented list from `lower` up to (but not including) `upper`. Works with hardcoded integer literals. ⚠️ With dynamic `attrs.*` integer values (e.g. `attrs.from_port`, `attrs.to_port`) `core::range()` silently returns an empty list in the policytest framework — prefer the count approach for port-range policies (see `verified-syntax.md` Mistake 23).
- **Time:** `core::timestamp()`, `core::formatdate("EEEE", core::timestamp())` (weekday, UTC), `core::parseint(core::formatdate("HH", core::timestamp()), 10)` (hour, UTC).
- **Semver:** `core::semverconstraint(version, "~> 4.67.0")` — supports `=`, `>=`, `<`, `~>`, range, `!=`. Always wrap in `core::try(..., false)` to handle non-semver or unparseable version strings gracefully. ⚠️ Prefer this over `core::split` + `core::parseint` for all version range checks converted from Sentinel string comparisons — manual integer parsing fails silently for non-numeric version suffixes and null/empty inputs.

  **🔴 NEVER place `core::semverconstraint` directly in a `filter =` expression.** Even with `!= null` and `!= ""` guards in the same expression, `semverconstraint` is evaluated regardless of short-circuit ordering in the `filter` context and throws a parse error when the version string is malformed (e.g. a non-semver string like `"x.y"`) or `null`/empty. Always move it into `locals` and wrap with `core::try(..., false)`:

  ```hcl
  # ❌ Wrong — crashes when version string is non-semver, null, or empty:
  filter = core::try(attrs.version, null) != null &&
           core::try(attrs.version, "") != "" &&
           core::semverconstraint(core::try(attrs.version, "0.0"), "< 2.0")

  # ✅ Correct — filter guards null/empty only; semverconstraint lives in locals:
  filter = core::try(attrs.version, null) != null &&
           core::try(attrs.version, "") != ""
  locals {
    version      = core::try(attrs.version, "")
    # core::try wraps semverconstraint to safely handle non-semver strings → false
    is_old       = core::try(core::semverconstraint(local.version, "< 2.0"), false)
    # When version is old, enforce the required attribute; when version >= 2.0, always compliant
    is_compliant = !local.is_old || local.required_attr_set
  }
  ```
- **Null safety — two-step pattern (MANDATORY for any attribute that may be explicitly `null`):** `core::try(attrs.field, default)` triggers the fallback **only when the attribute access throws an error** (key absent). When an attribute is **explicitly set to `null`**, `core::try` returns `null` — not the default. **This is a silent pitfall:** `core::length(null)` crashes with `Invalid value for "collection" parameter`; `null == false` evaluates as `null` (not `true`), causing enforce to trigger unexpectedly.

  Always use the explicit two-step pattern:

  ```hcl
  # Collection attribute (list/map) — safe pattern:
  field_raw = core::try(attrs.field, null)
  field     = local.field_raw != null ? local.field_raw : []
  # ✅ Safe to pass to: core::length(), core::contains(), for expressions

  # Scalar boolean attribute — safe pattern:
  flag_raw  = core::try(attrs.flag, null)
  flag      = local.flag_raw == null ? false : local.flag_raw
  # ✅ Safe to use in: condition = !local.flag, condition = local.flag == false
  ```

  For `filter` expressions that must exclude both `null` and empty-string values: `filter = core::try(attrs.field, null) != null && core::try(attrs.field, "") != ""`.
  The two-step rule applies at every nesting level. When a scalar is accessed through a nested path (e.g. `core::try(local.list[0].scalar_attr, default)`), apply the same pattern: if the attribute may be `null`, use `core::try(..., null)` and normalize explicitly.
- **JSON:** `core::jsondecode(string)` — parses a JSON string into an object/list. `core::jsonencode(value)` — encodes a value as a JSON string. ❌ `json::unmarshal` does not exist — use `core::jsondecode` instead.
- **Nested block attribute schema — object vs list:** Terraform provider schemas define nested blocks as either a **list of objects** (`[{ ... }]`) or a single **object** (`{ ... }`). Always check the provider schema before accessing nested attributes:
  - **List block** (e.g. `encryption_config = [{ provider = [{ key_arn = "..." }] }]`): access via index `attrs.encryption_config[0].provider[0].key_arn`. Use `core::try(attrs.field, [])` and `field[0].subattr`.
  - **Object block** (e.g. `redirect = { port = "443", protocol = "HTTPS" }`): access directly `attrs.redirect.port`. Use `core::try(attrs.redirect.port, "")`.
  - ❌ **Never call `core::length()` on an object** — `core::length` requires a list, map, or tuple. Calling `core::length(attrs.redirect)` when `redirect` is an object crashes with `collection must be a list, a map or a tuple`. To check presence of an object block, use `core::try(attrs.redirect, null) != null` instead.
  - ❌ **Never iterate over an object block with a `for` expression.** `for r in core::try(attrs.block, [])` — when `attrs.block` is an object, this iterates over the object's **scalar values**, not the object as an element. `core::try(r.sub_attr, "")` on a string silently returns `""`. Use direct attribute access instead: `core::try(attrs.block.sub_attr, "")`.
  - When Sentinel mocks use `redirect = { ... }` (object), the TFPolicy test mock and policy must treat it as an object. When Sentinel mocks use `redirect = [{ ... }]` (list), use list indexing. Mismatching the shape causes either runtime crashes or silent wrong results.

### IAM Policy Checks

When enforcing IAM content rules (e.g. "no admin `*:*` allowed", "no wildcard actions"), you MUST cover **all 4 inline policy resource types** — not just `aws_iam_policy`.

**🔴 Always write 4 `resource_policy` blocks for IAM content enforcement:**

| Resource type | When it's used | `policy` attribute |
|---|---|---|
| `aws_iam_policy` | Standalone managed policy | JSON string — `core::jsondecode(core::try(attrs.policy, "{}"))` |
| `aws_iam_role_policy` | Inline policy attached to a role | JSON string — same pattern |
| `aws_iam_user_policy` | Inline policy attached to a user | JSON string — same pattern |
| `aws_iam_group_policy` | Inline policy attached to a group | JSON string — same pattern |

**Rule:** A policy that only checks `aws_iam_policy` misses inline policies on roles/users/groups. An admin could bypass it by using `aws_iam_role_policy` instead of `aws_iam_policy`.

**Note on `aws_iam_policy_document`:** This resource type requires careful distinction between two different use cases:

- **As a Terraform `data` block** (the common case in real Terraform configurations) — `data_policy` does not exist in tfpolicy (Mistake 31). Do NOT write `data_policy "aws_iam_policy_document"`. In this scenario, the policy document content is consumed by one of the 4 inline/managed policy resource types above, and enforcement should target those resource types.
- **As a `resource` in `.policytest.hcl` mocks and when the Sentinel source reads it via `tfstate/v2`** — `resource_policy "aws_iam_policy_document"` is valid and directly targets the document's `statement` attribute (lowercase `actions`, not `Action`). When a Sentinel policy reads `aws_iam_policy_document` from `tfstate`, the correct TFPolicy conversion is `resource_policy "aws_iam_policy_document"` — do NOT substitute inline/managed policy resource types.

**Decision rule:** Check the Sentinel `import` statement. If the Sentinel uses `tfstate/v2` to read `aws_iam_policy_document` resources, convert to `resource_policy "aws_iam_policy_document"`. If the Sentinel reads the consuming resource (`aws_iam_role_policy`, etc.), target those 4 types instead.

```hcl
# ✅ CORRECT — define the check logic once, repeat for all 4 resource types
# (Each resource_policy block is independent; locals are block-scoped)

resource_policy "aws_iam_policy" "no_admin_privileges" {
  locals {
    statements  = core::try(core::jsondecode(core::try(attrs.policy, "{}")).Statement, [])
    admin_stmts = [for s in local.statements : s if core::lower(core::try(s.Effect, "Allow")) == "allow" && core::contains(core::try(s.Action, []), "*") && core::contains(core::try(s.Resource, []), "*")]
  }
  enforce {
    condition     = core::length(local.admin_stmts) == 0
    error_message = "IAM policies must not grant full admin privileges (*:* on *)."
  }
}

resource_policy "aws_iam_role_policy" "no_admin_privileges" {
  locals {
    statements  = core::try(core::jsondecode(core::try(attrs.policy, "{}")).Statement, [])
    admin_stmts = [for s in local.statements : s if core::lower(core::try(s.Effect, "Allow")) == "allow" && core::contains(core::try(s.Action, []), "*") && core::contains(core::try(s.Resource, []), "*")]
  }
  enforce {
    condition     = core::length(local.admin_stmts) == 0
    error_message = "IAM role inline policies must not grant full admin privileges (*:* on *)."
  }
}

resource_policy "aws_iam_user_policy" "no_admin_privileges" {
  locals {
    statements  = core::try(core::jsondecode(core::try(attrs.policy, "{}")).Statement, [])
    admin_stmts = [for s in local.statements : s if core::lower(core::try(s.Effect, "Allow")) == "allow" && core::contains(core::try(s.Action, []), "*") && core::contains(core::try(s.Resource, []), "*")]
  }
  enforce {
    condition     = core::length(local.admin_stmts) == 0
    error_message = "IAM user inline policies must not grant full admin privileges (*:* on *)."
  }
}

resource_policy "aws_iam_group_policy" "no_admin_privileges" {
  locals {
    statements  = core::try(core::jsondecode(core::try(attrs.policy, "{}")).Statement, [])
    admin_stmts = [for s in local.statements : s if core::lower(core::try(s.Effect, "Allow")) == "allow" && core::contains(core::try(s.Action, []), "*") && core::contains(core::try(s.Resource, []), "*")]
  }
  enforce {
    condition     = core::length(local.admin_stmts) == 0
    error_message = "IAM group inline policies must not grant full admin privileges (*:* on *)."
  }
}
```

### Cross-Resource Lookups

**🛑 Self-check — run this BEFORE writing any `resource_policy` involving a companion/child resource:**

> "What is the enforcement goal?"
> - **"Every existing instance of `<child_type>` must have correct attributes"** (e.g., "every `aws_lb_listener` must use HTTPS") → anchor `resource_policy` directly on the child type
> - **"Every parent must have at least one compliant child"** (e.g., "every S3 bucket must have a `public_access_block` with all four flags set") → anchor `resource_policy` on the **parent**; a child-only policy silently misses parents with no child in the plan

**Decision table — choose the correct pattern first:**

| Enforcement goal | Who gets the `resource_policy`? | Pattern |
|---|---|---|
| "Every existing instance of `<child_type>` must have correct attributes" (e.g., "every `aws_lb_listener` must use HTTPS") | Child type directly | Direct child `resource_policy` |
| "Every parent must have at least one compliant child" (e.g., "every S3 bucket must have a `public_access_block` with all four flags set") | **Parent** resource | Apply-time: inline `core::getresources("child", {bucket = attrs.id})` inside `resource_policy` |
| "Parent has a companion identified by a known literal / stable attribute" (e.g., versioning bucket name matches `attrs.bucket`) | Parent resource | Plan-time: top-level `core::getresources("companion", {})` + HCL for-loop filter inside `resource_policy` |

**⚠️ Critical:** Never write a `resource_policy "child_type"` to enforce "every parent must have a child" — if the child resource is absent entirely, the policy never fires for that parent and the violation is silently missed.

**🔴 Named companion resources — ALWAYS use the parent as `resource_policy` anchor when the goal is presence enforcement:**

The following Terraform resource types are **companion-only** — a parent resource can exist in a plan without them. NEVER anchor a standalone `resource_policy` on these types when checking for their presence:

| ❌ Never use as standalone `resource_policy` anchor (for presence) | ✅ Always anchor on | Lookup key |
|---|---|---|
| `aws_s3_bucket_public_access_block` | `aws_s3_bucket` | `{ bucket = attrs.id }` (apply-time inline) |
| `aws_s3_bucket_acl` | `aws_s3_bucket` | `{ bucket = attrs.id }` (apply-time inline) |
| `aws_s3_bucket_logging` | `aws_s3_bucket` | `{ bucket = attrs.id }` (apply-time inline) |
| `aws_s3_bucket_server_side_encryption_configuration` | `aws_s3_bucket` | `{ bucket = attrs.id }` (apply-time inline) |
| `aws_s3_bucket_versioning` | `aws_s3_bucket` | plan-time top-level + `v.bucket == attrs.bucket` filter |
| `aws_s3_bucket_policy` | `aws_s3_bucket` | `{ bucket = attrs.id }` (apply-time inline) — even for content enforcement (e.g., checking `Principal: "*"`), inspect the child's `policy` attr via `core::jsondecode()` inside the parent block |

> This pattern applies to all resource families, not just S3. Non-S3 examples: when checking "every VPC has a flow log" → anchor on `aws_vpc` with inline `core::getresources("aws_flow_log", {vpc_id = attrs.id})`; when checking "every LB has at least one compliant listener" → anchor on `aws_lb` with inline `core::getresources("aws_lb_listener", {load_balancer_arn = attrs.arn})`.

> **Why this matters:** Even if the Sentinel source iterates over the companion type, TFPolicy must anchor on the parent. A Terraform plan can declare an `aws_s3_bucket` with NO companion resource — anchoring on the companion silently misses that bucket entirely.

**⚠️ Parent-anchor means parent-ONLY:** Once the decision table says "parent resource" is the anchor, generate `resource_policy` blocks **exclusively** on the parent type. Do NOT also generate standalone `resource_policy` blocks for companion types alongside the parent blocks. Adding companion blocks in parallel:
- still silently misses parents that have no companion
- double-reports violations

All enforcement logic — including every companion check — must live inside the parent `resource_policy` block, using inline or top-level lookups.

---

**Plan-time pattern** — use `core::getresources()` at the **top level** only when the filter value is a **known constant** (not derived from `attrs.*`). When the filter depends on the current resource's own attribute, use the inline pattern below instead. ❌ Top-level `{}` (empty filter) + for-loop or lookup map filtered by `attrs.*` inside `resource_policy` is the prohibited anti-pattern — see verified-syntax.md Mistake 13 for both variants.

**⚠️ Exception — "companion absence is itself a violation":** When the goal is to enforce that a companion resource **exists AND has matching attributes** (e.g. a parent resource must have a linked companion with a specific qualifying attribute set), the inline filter pattern produces false negatives: if the companion is absent or has a mismatching linking key, `core::getresources()` returns `[]`, and `!has_companion` is `true` → a condition like `!has_companion || check_attr == "VALUE"` incorrectly passes. Use the **top-level collect-then-filter pattern** instead:

```hcl
# Top-level: collect ALL companions globally, filter to those with the qualifying attribute,
# then check membership inside resource_policy.
locals {
  all_companions      = core::getresources("aws_companion_resource", {})
  # Filter to companions that have the qualifying attribute set (e.g. non-empty elb)
  qualifying_companions = [for c in local.all_companions : c
    if core::try(c.qualifying_attr, null) != null && core::try(c.qualifying_attr, "") != ""]
  # Collect the linking attribute values from qualifying companions only
  companion_names     = [for c in local.qualifying_companions : core::try(c.linking_attr, "")]
  # Use qualifying companions (not all) to decide whether to evaluate
  has_qualifying      = core::length(local.qualifying_companions) > 0
}

resource_policy "aws_parent_resource" "example" {
  # Only evaluate when qualifying companions exist in the plan
  filter = local.has_qualifying

  locals {
    parent_name   = core::try(attrs.name, "")
    is_linked     = core::length([for n in local.companion_names : n if n == local.parent_name]) > 0
    # 🔴 Condition must be POSITIVE: both linked AND check_attr correct
    # Do NOT use: !is_linked || check_attr == "EXPECTED"  ← this passes when companion absent
    is_compliant  = local.is_linked && core::try(attrs.check_attr, "") == "EXPECTED"
  }

  enforce {
    condition     = local.is_compliant
    error_message = "..."
  }
}
```

This pattern correctly detects:
- Companion absent entirely → `has_qualifying = false` → `filter = false` → parent skipped ✓
- Companion present but with no qualifying attribute → `qualifying_companions = []` → `has_qualifying = false` → parent skipped ✓
- Companion with wrong `linking_attr` value → `is_linked = false` → `is_compliant = false` → violation ✓
- Companion with correct linking and correct `check_attr` → `is_compliant = true` → passes ✓

**⚠️ Choose `filter` scope carefully:** `filter = local.has_qualifying` (qualifying companions only) skips all parents when no qualifying companions exist — this matches a Sentinel that returns early when no qualifying companions are found. If the Sentinel does NOT skip when non-qualifying companions exist (e.g. it evaluates parents even when only ALB/NLB attachments are present), use `filter = core::length(local.all_companions) > 0` instead. With this broader filter, unlinked parents (`is_linked = false`) are evaluated and correctly fail `is_linked && check_attr == VALUE`.

**🔴 Condition polarity rule:** When using the top-level collect-then-filter pattern, always use a **positive** condition (`is_linked && check_attr == VALUE`), not a negative condition (`!is_linked || check_attr == VALUE`). The negative form silently passes any parent that is not linked — which is the opposite of the intended enforcement. With the positive form: unlinked parent → `is_linked = false` → `is_compliant = false` → violation (correct). With the negative form: unlinked parent → `!false || any` = `true` → `is_compliant = true` → passes (incorrect).

**Apply-time pattern** — when the filter value is the current resource's own attribute (e.g. `bucket = attrs.id`, or `event_bus_name = attrs.name`), use an **inline `core::getresources()` call with the direct filter inside `resource_policy`**. The filter cannot resolve at plan time (the attribute value is unknown until apply), but fully resolves once the resource is provisioned. The linking attribute may reference `attrs.id`, `attrs.arn`, or `attrs.name` — check the child resource's Terraform Registry docs to determine which one.

> **S3 cross-resource note:** Always use `attrs.id` (not `attrs.bucket`) when filtering S3 child resources such as `aws_s3_bucket_public_access_block`, `aws_s3_bucket_acl`, `aws_s3_bucket_server_side_encryption_configuration`, and `aws_s3_bucket_policy`. Terraform providers set the child resource's linking attribute (`bucket`) to the parent bucket's `.id`. Using `attrs.id` ensures the filter matches the actual value stored in the child resource's plan.

```hcl
# NOTE: This policy contains a cross-resource reference that will not resolve during plan time,
# but the policy will run successfully during apply time.
resource_policy "aws_s3_bucket" "s3_block_public_access" {
  locals {
    public_access_block     = core::getresources("aws_s3_bucket_public_access_block", {
      bucket = attrs.id
    })
    block_public_acls       = core::try(local.public_access_block[0].block_public_acls, false)
    block_public_policy     = core::try(local.public_access_block[0].block_public_policy, false)
    ignore_public_acls      = core::try(local.public_access_block[0].ignore_public_acls, false)
    restrict_public_buckets = core::try(local.public_access_block[0].restrict_public_buckets, false)
  }

  enforce {
    condition     = local.block_public_acls && local.block_public_policy && local.ignore_public_acls && local.restrict_public_buckets
    error_message = "S3 bucket does not have all public access block settings enabled."
  }
}
```

### Error Message Rules

- ✅ Static strings: `"S3 buckets must enable versioning."`
- ✅ Safe interpolation: `"Instance type '${attrs.instance_type}' is not allowed."`
- ❌ **Never** interpolate `${meta.address}` — it is UNDEFINED in `resource_policy` and crashes at runtime. `tfpolicy test` will NOT catch this; only a real `terraform plan` will.
- Use `error_message` for all enforceable violations (condition can be false).
- Use `info_message` **only** in non-convertible stub blocks where `condition = true` and no real enforcement is possible. Never use `info_message` in a block that can actually fail a resource.

### Comment Conventions — `# LIMITATION:` vs `# NOTE:`

These two markers have distinct meanings — do not interchange them:

- **`# LIMITATION:`** — tfpolicy **cannot fully express or enforce** the requirement. Part of the original Sentinel logic had to be omitted or approximated. Always accompanies a `Simplify` or `Not convertible` quality label.
  - Example: *"LIMITATION: The bucket policy IAM document check is non-convertible — tfpolicy does not expose reference metadata."*
- **`# NOTE:`** — The enforcement is complete but has a **runtime caveat** that does not reduce coverage.
  - Example: *"NOTE: This policy contains a cross-resource reference that will not resolve during plan time, but will run successfully during apply time."*

### Output Structure Rules — Consistency-Critical

These rules eliminate the most common sources of non-deterministic output between runs:

**Rule 1 — One `resource_policy` block per resource type.**
Multiple checks on the same resource type MUST be combined into a single `resource_policy` block using separate `locals` and multiple `enforce` blocks. Never split checks into two `resource_policy` blocks for the same type.

```hcl
# ✅ Correct — two checks, one block
resource_policy "aws_ecs_task_definition" "secure_networking" {
  filter = core::try(attrs.network_mode, "") == "host"
  locals {
    containers           = core::try(core::jsondecode(attrs.container_definitions), [])
    non_privileged       = [for c in local.containers : c if core::try(c.privileged, false) != true]
    insecure_user        = [for c in local.containers : c if core::try(c.user, "") == "" || core::try(c.user, "") == "root"]
  }
  enforcement_level = "advisory"
  enforce {
    condition     = core::length(local.non_privileged) == core::length(local.containers)
    error_message = "ECS task definition containers must not run as privileged."
  }
  enforce {
    condition     = core::length(local.insecure_user) == 0
    error_message = "ECS task definition containers must define a non-root user."
  }
}

# ❌ Wrong — same resource type split across two blocks
resource_policy "aws_ecs_task_definition" "check_privileged" { ... }
resource_policy "aws_ecs_task_definition" "check_user" { ... }
```

**Rule 2 — Non-convertible checks are comments, not stub blocks.**
When a specific check cannot be converted (reference metadata, etc.), document it as a `# LIMITATION:` comment inside the existing `resource_policy` block — do NOT create a separate `resource_policy` block of the same type as a stub. A dedicated stub block (with `condition = true`) is only appropriate when the **entire** policy has no convertible checks at all.

**Rule 3 — Per-resource enforcement for all checks.**
Do NOT aggregate across all resources of a type at the plan level (e.g. "at least one trail in the whole plan is compliant = pass all"). Each `resource_policy` must evaluate each individual resource independently. tfpolicy's evaluation model is per-resource — plan-level aggregation via top-level `core::getresources()` to pass/fail based on a count across all resources is not idiomatic and produces non-deterministic results.

```hcl
# ✅ Correct — each aws_cloudtrail resource evaluated independently
resource_policy "aws_cloudtrail" "s3_dataevents_enabled" {
  locals { ... }
  enforce {
    condition     = local.is_compliant
    error_message = "This CloudTrail trail must log S3 data events."
  }
}

# ❌ Wrong — plan-level aggregation ("at least one compliant trail")
locals {
  all_trails     = core::getresources("aws_cloudtrail", {})
  num_compliant  = core::length([for t in local.all_trails : t if ...])
  any_compliant  = local.num_compliant > 0
}
resource_policy "aws_cloudtrail" "s3_dataevents_enabled" {
  enforce {
    condition     = local.any_compliant  # Wrong: passes every trail if any one trail is compliant
    error_message = "..."
  }
}
```

---

## Sentinel → Terraform Policy Conversion

Use this section when the input is an existing Sentinel `.sentinel` file. Follow Steps 1–5 below; apply the authoring guidance above when generating the policy HCL.

### Sentinel → Terraform Policy construct mapping

| Sentinel | Terraform Policy |
|----------|-----------------|
| `import "tfplan/v2"` | Native policy context — no import needed |
| `tfplan.resource_changes` loops | Usually one `resource_policy` per resource type; split multi-type Sentinel rules when needed |
| `filter tfplan.resource_changes` | Resource type in the policy declaration plus optional `filter` for attribute-based preconditions |
| `as address, rc` | `attrs.*` and `meta.provider_type` for the current resource. **⚠️ `meta.address` is UNDEFINED — do not use it.** |
| `rc.change.after.<attr>` | `attrs.<attr>` |
| `rc.change.before.<attr>` | `prior_attrs.<attr>` — available when `operations` does NOT include `"create"` |
| `rc.change.actions is ["delete"]` | `operations = ["delete"]` — fires only on destroy |
| `rc.change.actions is not ["delete"]` | `operations = ["create", "update"]` — skips destroy |
| `param allowed_list default [...]` | `input "allowed_list" { type = list(string); default = [...] }` |
| `time.now.weekday_name` | `core::formatdate("EEEE", core::timestamp())` — UTC weekday name |
| `time.now.hour` | `core::parseint(core::formatdate("HH", core::timestamp()), 10)` — UTC hour as int |
| `strings.has_prefix(s, p)` | `core::startswith(s, p)` — arg order: **full string first, prefix second** (same as Sentinel). **Note:** `meta.version` in `provider_policy` is the **resolved version** (e.g. `"6.50.0"`), NOT the constraint string. Sentinel's `strings.has_prefix(p.version_constraint, ">")` is **non-convertible** — tfpolicy does not expose the constraint string. Use `core::semverconstraint(meta.version, ...)` instead. |
| `strings.has_suffix(s, suffix)` | `core::endswith(s, suffix)` |
| `rc.provider_name` | `meta.provider_type` |
| `all/any expressions` | List comprehensions with filtered counts — **neither `core::alltrue()` nor `core::anytrue()` exist**. Use `core::length([for x in list : x if !x]) == 0` for "all true" and `core::length([for x in list : x if x]) > 0` for "any true". |
| `else` clause | Multiple `enforce` blocks |
| `maps.get(obj, key, default)` | `core::try(obj.key, default)` |
| `collection.reject(items, predicate)` | List comprehension with `if` — `[for item in items : item if !<predicate>]` |
| `collection.reject(items, predicate) is empty` | **🔴 ALL condition** — every element satisfies the predicate. ⚠️ **Do NOT convert this to an ANY condition** (`length([for item in items : item if <predicate>]) > 0`) — that inverts the semantics. The correct pattern is: `non_compliant = [for item in items : item if !<predicate>]` / `is_compliant = core::length(local.non_compliant) == 0`. Example: `collection.reject(log_opts, func(o) { o.enabled and o.log_type is "AUDIT_LOGS" }) is empty` → `non_compliant = [for o in local.log_opts : o if !(core::try(o.enabled, false) && core::try(o.log_type,"") == "AUDIT_LOGS")]` / `condition = core::length(local.log_opts) > 0 && core::length(local.non_compliant) == 0`. When the predicate tests a boolean flag, verify the Sentinel default value and match it in `core::try(attr, <same_default>)`. |
| `collection.filter(items, predicate)` | List comprehension with `if` — `[for item in items : item if <predicate>]` |
| `strings.split(sep, str)` | `core::split(separator, string)` — splits a string into a list of substrings at each occurrence of `separator`. Example: `core::split("-", "80-443")` → `["80","443"]`. ⚠️ For **version range checks**, prefer `core::semverconstraint()` over `core::split` + `core::parseint` — see the Semver note in the `core::` Functions section. |

> When converting Sentinel `summary {}` output or `print()` statements, **do not** reproduce address-listing behavior. Terraform Policy diagnostics already identify the failing resource — prefer remediation-focused messages instead.

### Sentinel features that ARE convertible

1. **Time-based rules** — `core::timestamp()` + `core::formatdate()` + `core::parseint()` cover Sentinel's `time` import. All values are UTC; document that assumption in policy comments.
2. **`param` blocks** — direct equivalent: `input` blocks with `type` and `default`.
3. **`rc.change.before` for update/delete** — `prior_attrs` is available when `operations` does NOT include `"create"`.
4. **Integer range checks** — Sentinel policies that check whether all ports within `[from_port, to_port]` are authorized CAN be converted. Use the count approach: filter `authorized_ports` to those within the range and compare the count to `to_port - from_port + 1`. Do not use `core::range()` with dynamic `attrs.*` values. See `verified-syntax.md` Mistake 23.
5. **`tfconfig/v2` reference count** — each resource reference is stored **twice** in `.references` (once as `resource.name`, once as `resource.name.id`). When simplifying a reference-count check to a direct `core::length(attrs.attribute)` check, **halve the threshold**: `references > 2` → `core::length(attrs.attribute) >= 2`.

### Plan-Time vs Apply-Time Policies

Terraform Policy can enforce controls at **plan time** (before `terraform apply`) or **apply time** (during `terraform apply`). Most policies are plan-time, but cross-resource lookups that depend on newly-created resource IDs only fully resolve at apply time.

| Scenario | Enforcement time | Quality label |
|----------|-----------------|---------------|
| Single-resource attribute checks | Plan time | Perfect / Good |
| Cross-resource lookup where the filter value is a **known literal or existing resource ID** | Plan time | Good |
| Cross-resource lookup where the filter value is a **newly-created resource ID** (e.g. `bucket = attrs.id` for a bucket created in the same plan) | Apply time | Good |
| Reference metadata / graph traversal (`res.config.attribute["references"]`) | Not convertible | — |

**When a Sentinel policy uses cross-resource references with a value-based filter from a newly-created resource:**
- Generate the policy using an **inline `core::getresources()` call with the direct filter** inside `resource_policy`.
- Add this note in the conversion report (not a limitation label): *"This policy contains a cross-resource reference that will not resolve during plan time, but the policy will run successfully during apply time."*
- Do **not** label this as Simplify or Not convertible — it is a valid **Good** conversion.

**For cross-resource patterns, apply the registry check (Steps A and B) described in "Cross-Resource Lookups" above.** The registry check fully determines the policy structure, regardless of whether the Sentinel's `violations` iterated the parent or the child type. Dependent child resource types must never have a standalone `resource_policy` block.

### Cannot Convert (Explain the Alternative)

1. **Mocking/testing infrastructure** (`import "tfconfig-functions"`) — tfpolicy uses `.policytest.hcl`. See the [tfpolicy-test skill](tfpolicy-test.md).
2. **Custom Sentinel imports** — limited plugin support; use HTTP plugins or native functions if available.
3. **Sentinel simulator / built-in test framework** — replace with `.policytest.hcl` test files.
4. **Cross-workspace data access** — tfpolicy evaluates a single plan. Use workspace tags (`meta.tfe_workspace.tags`) or external plugins.
5. **`print()` / debug statements** — no debug output mechanism; rely on concise `error_message` / `info_message` text only when it adds remediation context.
6. **Stateful logic across evaluations** — policies are stateless; use external systems via plugins if state is required.
7. **`rc.change.before` outside delete/update** — for first-time creates there is no pre-state.
8. **Cross-resource reference navigation via reference metadata** (`res.config.attribute["references"]`, `res.config.to`) — tfpolicy does not expose which Terraform resource a value *points to*. When the Sentinel policy uses the *resolved value* of an attribute (not the reference path itself), convert using `core::getresources()` with a value-based filter — see "Plan-Time vs Apply-Time Policies" above.
9. **Data source content inspection by address** — `core::getdatasource()` requires filter attributes and cannot query by Terraform address.
10. **Complex resource-graph traversal via reference metadata** — cannot traverse the Terraform resource graph by reference (e.g. "find all subnets that reference this VPC"). Only resolved attribute values are available. If the Sentinel policy traverses by *resolved attribute value* (e.g. `bucket = attrs.id`), convert using `core::getresources()` with a value-based filter and mark as an apply-time policy — see "Plan-Time vs Apply-Time Policies" above.

> ⚠️ **Partial reference dependence — do not skip the whole policy.** Items 8 and 10 apply to the *specific check* that uses reference metadata, not the entire policy. If only some checks in a Sentinel policy rely on `res.config.attribute["references"]` or graph traversal, convert the remaining checks as normal, apply the **Simplify** label to the overall policy, and document each skipped check in the report with: *"This check was omitted — tfpolicy does not expose reference metadata (`res.config.attribute["references"]`)."* Only label the entire policy as **Not convertible** if its core enforcement logic is wholly dependent on reference metadata with no convertible remainder.

> ❌ **Do not approximate reference-metadata checks with cross-resource JSON value matching.** A common workaround is to retrieve all instances of a related resource via `core::getresources()` and compare their serialized attribute values (e.g. `attrs.policy == doc.json`) as a proxy for "this resource references that data source." This is **not a faithful conversion** — it produces false negatives when the referenced resource is already deployed and absent from the current plan, and enforces a different semantic (value equality) than the original (structural reference). When the only check IS reference metadata, generate a stub policy instead:
> ```hcl
> # <policy_name> — Non-Convertible (Reference Metadata)
> resource_policy "<resource_type>" "<policy_name>_stub" {
>   enforce {
>     condition     = true
>     info_message  = "Automated enforcement not available: this policy requires reference metadata inspection which tfpolicy does not support. Manual compliance review required."
>   }
> }
> ```

> ⚠️ **Partial exception — direct content inspection via the parent bucket.** The cross-resource approximation prohibition applies to comparing JSON *across* resources (e.g. fetching all `aws_iam_policy_document` outputs and matching against a bucket policy). It does **not** prohibit inspecting a bucket's own policy content. When the Sentinel reference-metadata check is really enforcing *content* (e.g. "the bucket policy must not grant public read access"), convert it by anchoring on `resource_policy "aws_s3_bucket"`, fetching the child `aws_s3_bucket_policy` via `core::getresources("aws_s3_bucket_policy", { bucket = attrs.id })`, and inspecting its `policy` attribute via `core::jsondecode()` inside the parent block. This follows the standard dependent-child pattern — `aws_s3_bucket_policy` always requires a parent bucket. Label the overall policy **Simplify** (because the reference-path check is omitted) and add a `# NOTE:` that the content-based check achieves a similar security outcome.
>
> ```hcl
> # ✅ Content-based alternative to reference-metadata check on bucket policies
> # NOTE: This policy contains a cross-resource reference that will not resolve during plan time,
> # but the policy will run successfully during apply time.
> resource_policy "aws_s3_bucket" "no_public_read_policy" {
>   locals {
>     bucket_policy       = core::getresources("aws_s3_bucket_policy", { bucket = attrs.id })
>     policy_doc          = core::try(core::jsondecode(core::try(local.bucket_policy[0].policy, "{}")), { Statement = [] })
>     statements_enriched = [for s in core::try(local.policy_doc.Statement, []) : { effect = core::lower(core::try(s.Effect, "Allow")), action = core::try(s.Action, []), principal_str = core::try(s.Principal, ""), principal_aws = core::try(core::try(s.Principal, {}).AWS, "") }]
>     public_read_stmts   = [for s in local.statements_enriched : s if s.effect == "allow" && (core::contains(s.action, "s3:GetObject") || core::contains(s.action, "s3:*") || core::contains(s.action, "*")) && (s.principal_str == "*" || s.principal_aws == "*")]
>   }
>   enforce {
>     condition     = core::length(local.public_read_stmts) == 0
>     error_message = "S3 bucket policy must not grant public read access (Principal: * with s3:GetObject or s3:*)."
>   }
> }
> ```

### Conversion quality labels

- **Perfect** — Same enforcement intent and behavior expressed directly in tfpolicy with no known semantic gap.
- **Good** — Preserves the important enforcement outcome using idiomatic tfpolicy structure (not a one-to-one translation).
- **Simplify** — Only part of the original Sentinel behavior can be reproduced; document the missing checks explicitly.
- **Not convertible** — tfpolicy lacks the runtime data or language features required for a safe translation.


### Conversion Strategy

| Tier | Pattern | Examples | Approach |
| --- | --- | --- | --- |
| ✅ **Easy** | Single resource, direct attribute check | EBS encryption, RDS public access, ECS container insights, EKS audit logging, Lambda runtime, CloudTrail logging | Direct 1:1 conversion |
| ✅ **Good** | Cross-resource value-based lookup (resolved attribute IDs) | S3 + public-access-block, S3 + versioning, EventBridge + resource policy | Use inline `core::getresources()` with direct filter inside `resource_policy`; mark as apply-time policy if filter value is a newly-created resource ID |
| ⚠️ **Simplify** | Cross-resource logic with partial reference dependence | EC2 IMDSv2, security group coverage | Check explicit configuration only; document what is not checked; prefer known literal attributes over inferred relationships |
| ❌ **Avoid** | `rc.change.before` outside update/delete; reference-metadata navigation; data-source content inspection by address; complex graph traversal; mutable external state; `strings.split()` decomposition | — | Recommend a redesign or treat as non-convertible |

### Steps to Convert a Sentinel Policy

#### Step 1 — Parse the Sentinel Structure
Identify imports (tfplan, tfconfig, tfstate, custom), filter logic and resource selection, main and sub-rules, and enforcement level (advisory vs mandatory). Ask: What resources are being checked? Which attributes are validated? Does the policy depend on before/after diff? Are there cross-resource dependencies? Are data sources inspected? Does it rely on reference metadata or graph traversal?

**Identify the enforcement target and the parent type:** For any policy involving cross-resource dependencies, first perform the registry check (Steps A and B in "Cross-Resource Lookups" above) to identify which resource types are dependent children and which are parent types. Then use the Sentinel's `violations` expression to confirm the parent type — this is the type your `resource_policy` targets. Write `resource_policy` on the parent type. Every dependent child type is accessed exclusively via `core::getresources()` inside that parent block; all conditions on child resources are evaluated there, and all violations are reported on the parent. Do **not** write a standalone `resource_policy` on any resource type that the registry identifies as a dependent child — this rule holds regardless of whether the Sentinel's `violations` iterated the child or the parent, and regardless of whether the check is about a missing child or a misconfigured one.

> **Cross-resource policies — use the Terraform Registry to identify the parent, linking attribute, and filter value.** For any child resource type involved in a cross-resource lookup, fetch its documentation at `https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/{resource_name_without_aws_prefix}.html.markdown`. Look for a `(Required)` argument referencing a parent resource in "Argument Reference" and confirm with the usage examples (`.id` vs `.arn`). The required argument name is the linking attribute; use the corresponding `attrs.id` or `attrs.arn` in the `core::getresources()` filter. This applies to all resource families — not just S3.

**Do not over-constrain the enforcement condition beyond the Sentinel intent.** When the Sentinel checks "at least one item in a collection satisfies condition X", the correct tfpolicy translation is `core::length([for item in local.items : item if <condition>]) > 0`. Do NOT translate this to "every item must satisfy X" (i.e. `core::length([for item in local.items : item if !<condition>]) == 0`) unless the Sentinel explicitly enforces ALL items. Over-constraining the condition creates false violations for valid configurations that the Sentinel would pass.

**Distinguish enforcement intent from Sentinel implementation detail.** Sentinel code often accesses a collection element by index (e.g. `origins[0]`) as a traversal shortcut rather than an intentional "only check the first item" rule. Before encoding an index access as a scope restriction, ask:

- Is the indexed access repeated for all resources in a filter loop? (If so, it is a loop artifact, not a one-item intent.)
- Does the policy name or comment indicate intent that applies to "all" items?
- Would checking only the first item leave a real security gap?
- Is this collection a **structurally singleton block** in the provider schema (e.g. `max_items = 1`) — in which case `[0]` is intentional?

When the answer to any of the first three questions is "yes" **and** the fourth is "no", convert the check to iterate **all** items in the collection, not just `[0]`. Document the interpretation in the requirements as: *"Sentinel source accesses `collection[0]`; interpreted as checking all items to preserve full enforcement intent."*

#### Step 2 — Assess Convertibility
Check for non-convertible patterns above. Document what cannot be converted and assign a quality label.

#### Step 3 — Map to tfpolicy Constructs
Use the mapping table above. In practice, focus on (in order): matching resource scope, translating attribute access and null handling, replacing collection helpers with list comprehensions, and splitting compound logic into `locals` + multiple `enforce` blocks.

#### Step 4 — Generate the policy
Follow the authoring guidance in the Knowledge Base sections above. Apply the cross-resource decision table and companion-anchor rules.

**Error-message rules:**
- ✅ Static strings, or safe `${attrs.fieldname}` interpolation.
- ❌ **Never** interpolate `${meta.address}` — it is UNDEFINED in `resource_policy` and throws `Error: Unsupported attribute` at runtime for every evaluated resource. `tfpolicy test` will not catch this; only a real `terraform plan --policies=` run will.

#### Step 5 — Document the Conversion
Include the quality label, test success rate (if tests written), any limitations or simplifications made, behavioral differences from Sentinel, and references to related documentation.

---

- [`tfpolicy-author.md`](tfpolicy-author.md) — guided first-policy walkthrough.
- [`tfpolicy-author.md`](tfpolicy-author.md) — reusable patterns (attribute checks, allowlists, cross-resource enforcement, etc.).
- [`verified-syntax.md`](verified-syntax.md) — verified syntax tables, runtime limitations, common-mistake corrections. **Source of truth — defer to this file when this SKILL.md disagrees.**

## Usage Instructions — Write a New Policy from User Intent

### Step 1 — Clarify requirements
- Which resources / modules / providers to target.
- The specific condition to enforce.
- Whether create, update, and/or destroy should be in scope (`operations`).
- Whether any value should be tunable per policy set (→ `input` block).
- The desired error message and whether `attrs.*` interpolation is helpful.

### Step 2 — Design the structure
- Choose the policy type (resource / module / provider).
- Decide whether a wildcard label (`"*"`) is appropriate.
- Plan the `filter` for performance and to exclude resources where the attribute is meaningfully absent. **Two cases:**
  - *Attribute absent = resource out of scope* (e.g. no `acl` block set at all → resource doesn't configure ACLs → skip it): use `filter = core::try(attrs.field, null) != null`.
  - *Attribute absent = AWS provider default applies* (e.g. `encrypted` absent → AWS defaults to `false` → resource is still in scope and may violate the policy): do **not** filter on null. Use `core::try(attrs.field, <aws_provider_default>)` in the `condition` instead so absent resources are evaluated against the effective default.
- Move complex predicates into `locals` for readability.

### Step 3 — Generate the policy
- Wrap optional attributes in `core::try()`.
- Keep each boolean expression on a single line.
- Use multiple `enforce` blocks when you want independent diagnostics.
- Never interpolate `${meta.address}` in `error_message`.

### Step 4 — Document the policy
- Header comment with description, resources checked, and any compliance reference.
- Note operation scope and any parameterization.

### Worked Example

User request: *"Ensure all S3 buckets have versioning enabled."*

```hcl
# Ensure S3 Bucket Versioning is Enabled
#
# Enforces that all AWS S3 buckets have versioning enabled to protect
# against accidental deletion and enable recovery.
#
# Resources checked:
# - aws_s3_bucket with inline versioning configuration
# - aws_s3_bucket_versioning (standalone resource pattern)

resource_policy "aws_s3_bucket" "versioning_enabled" {
  filter = attrs.versioning != null

  locals {
    versioning_enabled = core::try(attrs.versioning[0].enabled, false)
  }

  enforce {
    condition     = local.versioning_enabled == true
    error_message = "S3 buckets must set versioning.enabled = true to protect against accidental deletion."
  }
}

resource_policy "aws_s3_bucket_versioning" "versioning_enabled" {
  locals {
    versioning_status = core::try(attrs.versioning_configuration[0].status, "Disabled")
  }

  enforce {
    condition     = local.versioning_status == "Enabled"
    error_message = "S3 bucket versioning resources must have status 'Enabled'. Current status: '${local.versioning_status}'."
  }
}
```

## Best Practices

### Policy Writing
1. Use descriptive policy names.
2. Add a comprehensive header comment with description, resources checked, and compliance references.
3. Always use `core::try()` for optional attributes.
4. Break down complex logic with `locals`.
5. Provide actionable, remediation-focused error messages.
6. Cover all variations of a resource family (e.g. AWS security groups: `aws_security_group`, `aws_security_group_rule`, `aws_vpc_security_group_ingress_rule`, `aws_default_security_group`).
7. Use `filter` to skip resources that don't apply (saves work and avoids false positives).
8. **Cache `core::getresources()` results in top-level locals** when the filter is a known literal or an existing resource ID — this avoids O(N) overhead per resource. **Exception:** when the filter depends on the current resource's own attribute (e.g. `{bucket = attrs.id}`, `{event_bus_name = attrs.name}`), the call cannot be pre-computed at top level because `attrs` is only available inside `resource_policy` — use the inline pattern instead (see item 15). ❌ Do NOT work around this by fetching all child resources at the top level with `{}` and building a lookup map — that is the same anti-pattern restructured.
9. **Avoid `core::getdatasource()` inside `resource_policy`** — it calls provider APIs.
10. Build lookup maps once for O(1) matching when iterating many resources.
11. Keep each boolean expression on a single line (HCL parser limitation in beta).
12. Use clear variable names (`scanning_config`, not `sc`).
13. Convert sets to lists before indexing: `[for item in set : item][0]`.
14. Don't use `core::try()` defaults to mask missing values that should fail the policy — use `filter` instead.
15. For cross-resource lookups where the filter value is the current resource's own attribute: use an inline `core::getresources()` with the direct filter inside `resource_policy`. To find the correct linking attribute name and filter value, fetch the child resource's Terraform Registry documentation at `https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/{resource_name_without_aws_prefix}.html.markdown` and look for the `(Required)` **or `(Optional)`** argument that references the parent resource. Check whether the usage examples assign it `.id`, `.arn`, or `.name` — use `attrs.id`, `attrs.arn`, or `attrs.name` accordingly. ⚠️ Some linking attributes are `(Optional)` in the schema (e.g. `event_bus_name` on `aws_cloudwatch_event_bus_policy` defaults to the default bus) but still represent a parent-child link — treat them the same way. Always add this comment in the policy: *"This policy contains a cross-resource reference that will not resolve during plan time, but the policy will run successfully during apply time."* Do not use a top-level cache + for-loop for this pattern.
16. **Cross-resource enforcement — registry check determines the structure unconditionally:**
    - **First, verify every resource type via the Terraform Registry.** For any resource type involved in a cross-resource check, fetch `https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/{resource_name_without_aws_prefix}.html.markdown`. A resource is a **dependent child** if it has a `(Required)` argument whose description or usage examples reference another AWS resource by `.id`, `.arn`, or `.name`. The argument name is the **linking attribute**; the assignment in examples tells you whether to use `attrs.id`, `attrs.arn`, or `attrs.name`. The resource that the linking attribute points to is the **parent type**.
    - **When the enforcement goal is to ensure every parent has a compliant child, the dependent child must NEVER have a standalone `resource_policy` block.** Write the `resource_policy` block on the **parent type**. Fetch the dependent child inside the parent block via `core::getresources("<child_type>", {<linking_attr> = attrs.id_or_arn_or_name})`. Evaluate all attribute checks on those lookup results. Report all violations on the parent. When the goal is only to check every existing child's own attributes, a standalone `resource_policy` on the child type is valid — see Self-check above.
    - Concrete examples: `aws_s3_bucket_public_access_block`, `aws_s3_bucket_policy`, `aws_s3_bucket_acl` (all require `bucket`) → never standalone for any enforcement goal; always fetched inside `resource_policy "aws_s3_bucket"`. `aws_lb_listener` → standalone `resource_policy "aws_lb_listener"` is valid when checking every listener's own attributes (e.g., protocol, ssl_policy); use `resource_policy "aws_lb"` with inline lookup only when the goal is "every LB must have at least one compliant listener".
    - Always add this comment when using this pattern: *"This policy contains a cross-resource reference that will not resolve during plan time, but the policy will run successfully during apply time."*

### Communication
1. Ask clarifying questions; don't assume requirements.
2. Show sample passing and failing resources alongside the policy.
3. Explain enforcement-level trade-offs.
4. Offer simplifications when an exact rule isn't expressible.

## See Also
- [`tfpolicy-test`](tfpolicy-test.md) — write `.policytest.hcl` files to validate the policies authored here.
- [`../../examples/README.md`](../examples/README.md) — side-by-side Sentinel + `.policy.hcl` examples with quality labels and per-example READMEs.
- [`verified-syntax.md`](verified-syntax.md) — shared source-of-truth syntax reference.

---

**Purpose:** Quick reference for AI agents to start writing Terraform Policy (tfpolicy)
**Status:** All behaviors verified during private beta (2026-02-19)
**Compatible with:** Any AI system capable of reading markdown and generating HCL code

---

## Quick Start for AI Agents

When a user asks you to write a Terraform Policy:

1. **Identify the policy type:** resource_policy, module_policy, or provider_policy
2. **Use the correct structure:** filter (optional), locals (optional), enforce (required)
3. **Remember:** ALL built-in functions need `core::` prefix
4. **For versions:** Always use `core::semverconstraint()`, never direct comparison
5. **Validate:** Check examples in this guide for patterns

---

## Table of Contents

1. [Critical Rules](#critical-rules)
2. [Policy Structure](#policy-structure)
3. [Policy Types](#policy-types)
4. [Core Functions Reference](#core-functions-reference)
5. [Semantic Versioning](#semantic-versioning)

**See Also:**
- [Common Patterns](tfpolicy-author.md) - Common policy patterns and examples
- [tfpolicy-author](tfpolicy-author.md) - Complete authoring reference for this sub-skill

---

## Critical Rules

### ✅ Rule 1: ALL Functions Need core:: Prefix

**ALWAYS use `core::` prefix for built-in Terraform functions**

```hcl
# ✅ CORRECT
filter = core::try(attrs.encrypted, false) == true
is_valid = core::length([for b in local.checks : b if b]) > 0
message = "Allowed: ${core::join(", ", local.versions)}"

# ❌ WRONG - Will fail with "Unknown function" error
filter = try(attrs.encrypted, false) == true  # Missing core:: prefix
# ❌ WRONG - core::anytrue does NOT EXIST in tfpolicy runtime
# is_valid = anytrue(local.checks)     # Missing core:: prefix AND function doesn't exist
# is_valid = core::anytrue(local.checks)  # Function does not exist — use core::length() instead
```

### ✅ Rule 2: Use Semantic Versioning for ALL Version Comparisons

**NEVER use direct comparison operators for versions**

```hcl
# ✅ CORRECT
condition = core::semverconstraint(meta.version, ">= 4.0.0, < 5.0.0")

# ❌ WRONG - Direct comparison doesn't work properly
condition = meta.version >= 4.0 && meta.version < 5.0
```

### ✅ Rule 3: ALL Policy Types Support locals and filter

**Don't avoid using locals or filter - they work in all policy types**

```hcl
# ✅ All three policy types support this structure
resource_policy "aws_s3_bucket" "example" {
    filter = <condition>     # ✅ Supported
    locals { ... }           # ✅ Supported
    enforce { ... }          # ✅ Required
}

module_policy "example" "check" {
    filter = <condition>     # ✅ Supported
    locals { ... }           # ✅ Supported
    enforce { ... }          # ✅ Required
}

provider_policy "aws" "check" {
    filter = <condition>     # ✅ Supported
    locals { ... }           # ✅ Supported
    enforce { ... }          # ✅ Required
}
```

**Note:** Language servers during private beta may show false errors for `locals` in `provider_policy`. These are safe to ignore.

---

## Policy Structure

### Basic Template

```hcl
<policy_type> "<target>" "<policy_name>" {
    # Optional: Pre-filter resources/modules/providers
    filter = <boolean_expression>

    # Optional: Local variables for complex logic
    locals {
        variable_name = <expression>
    }

    # Required: One or more enforcement rules
    enforce {
        condition = <boolean_expression>
        error_message = "<user-facing message>"
    }

    # Optional: Additional enforce blocks
    enforce {
        condition = <another_condition>
        error_message = "<another message>"
    }
}
```

### Execution Flow

1. **filter** - Applied first, determines which resources/modules/providers to evaluate
2. **locals** - Computed once per filtered item
3. **enforce** - Each block evaluated; all must pass for policy to pass

### Performance Best Practices

**Critical for large configurations — choose the pattern based on what the filter depends on:**

1. **Top-level `core::getresources()` only when the filter is a known literal/constant**
   - Use when the filter value is a hardcoded string, a fixed ID, or another stable literal — not derived from `attrs.*`
   - Executes once for the entire policy evaluation; result is reused by every `resource_policy` block
   - ❌ Do **not** use a top-level empty-filter call (`{}`) and then filter by `attrs.*` inside `resource_policy` — that is the prohibited anti-pattern (O(N²) with silent correctness bugs)
   ```hcl
   locals {
       # OK — filter is a known literal, cached once for all resources
       all_buckets = core::getresources("aws_s3_bucket", {})
   }

   resource_policy "aws_s3_bucket" "example" {
       locals {
           bucket_count = core::length(local.all_buckets)  # Reuse cached value
       }
   }
   ```

2. **Inline `core::getresources()` inside `resource_policy` when the filter depends on the resource's own attribute**
   - Use when "every parent must have at least one compliant child" and the linking key is `attrs.id`, `attrs.arn`, or `attrs.name`
   - The filter value is unknown at plan time (it's the current resource's own attribute), so a top-level cache is impossible
   - Executes once per evaluated resource (apply-time); the lookup fully resolves once the resource is provisioned
   - This is **not** a performance compromise — it is the **correct and required** pattern for parent+child presence enforcement
   ```hcl
   # NOTE: This policy contains a cross-resource reference that will not resolve during
   # plan time, but the policy will run successfully during apply time.
   resource_policy "aws_s3_bucket" "s3_block_public_access" {
       locals {
           public_access_block = core::getresources("aws_s3_bucket_public_access_block", {
               bucket = attrs.id   # filter depends on current resource — must be inline
           })
       }
       enforce {
           condition     = core::length(local.public_access_block) > 0
           error_message = "S3 bucket must have a public access block resource."
       }
   }
   ```

3. **Use `filter` to reduce evaluation scope**
   - Skip resources that don't need checking
   - Significantly improves performance

**See [Advanced Patterns Guide](tfpolicy-author.md#8--performance-optimization-verified) for detailed performance guidance**

---

## Policy Types

### 1. resource_policy

**Purpose:** Validate Terraform resource configurations

```hcl
resource_policy "aws_s3_bucket" "encryption_check" {
    enforce {
        condition = attrs.server_side_encryption_configuration != null
        error_message = "S3 buckets must have encryption enabled"
    }
}
```

**Available attributes:**
- `attrs.<attribute_name>` - Resource attributes from configuration
- `meta.provider_type` - Provider type (e.g., `aws`)
- **⚠️ `meta.address` is UNDEFINED** for `resource_policy` in real plan evaluation — do not use it

**⚠️ Understanding Provider Schema (Blocks vs Attributes):**

Terraform providers expose their raw schema, where some attributes are **blocks** that require special handling:

```hcl
# ❌ Wrong - blocks cannot be accessed directly
attrs.server_side_encryption_configuration.rules

# ✅ Correct - blocks are lists, use [0] index
attrs.server_side_encryption_configuration[0].rules
```

**Common AWS provider blocks requiring `[0]` index:**
- `default_tags[0].*` (AWS provider configuration)
- `assume_role[0].*` (AWS provider configuration)
- `versioning[0].enabled` (S3 bucket)
- `server_side_encryption_configuration[0].*` (S3 bucket)
- `metadata_options[0].*` (EC2 instance)

**Best practice:** Always use `core::length()` checks before accessing blocks:
```hcl
locals {
    versioning_blocks = core::try(attrs.versioning, [])
    versioning_enabled = core::length(local.versioning_blocks) > 0 ?
        core::try(local.versioning_blocks[0].enabled, false) : false
}
```

**See [Verified Syntax Reference](verified-syntax.md#4--critical-blocks-vs-attributes-schema-distinction) for complete details**

**Wildcards:**
```hcl
resource_policy "*" "all_resources" {
    # Matches ALL resource types
}
```

### 2. module_policy

**Purpose:** Validate Terraform module sources and versions

```hcl
# Check all modules use approved registry (prefix-based using core::regex)
module_policy "*" "module_source_check" {
    filter = meta.source != null

    locals {
        # Prefix match: does source start with the approved namespace?
        # core::contains() only does exact full-string matching — use core::regex() for prefix checks
        is_approved = core::try(core::regex("^app\\.terraform\\.io/myorg/", meta.source), null) != null
    }

    enforce {
        condition = local.is_approved
        error_message = "Modules must use an approved registry source. Current source: ${meta.source}"
    }
}

# Check specific module version with semver
module_policy "app.terraform.io/myorg/vpc/aws" "vpc_version" {
    locals {
        has_version = meta.version != null
        meets_minimum = core::semverconstraint(meta.version, ">= 1.0.0")
    }

    enforce {
        condition = local.meets_minimum
        error_message = "VPC module must be >= 1.0.0, got ${meta.version}"
    }
}
```

**Available attributes:**
- `meta.source` - Module source (e.g., `app.terraform.io/org/module/provider`)
- `meta.version` - Module version (works with `core::semverconstraint()`)
- `meta.address` - Module address (e.g., `module.vpc`)

**⚠️ Current Limitations (Private Beta):**
- ❌ `attrs.*` (module inputs) NOT accessible yet - work in progress
- ❌ `meta.tfe_workspace` NOT available - only in resource_policy

**Targeting:**
- Use **full module source** to target specific module: `module_policy "app.terraform.io/myorg/vpc/aws"`
- Use `"*"` wildcard to match all modules: `module_policy "*"`
- ❌ Substring matching does NOT work: `module_policy "vpc"` won't match modules with "vpc" in source

### 3. provider_policy

**Purpose:** Validate provider versions and configurations

```hcl
provider_policy "aws" "version_check" {
    locals {
        minimum_version = "4.0.0"
    }

    enforce {
        condition = core::semverconstraint(meta.version, ">= ${local.minimum_version}")
        error_message = "AWS provider must be >= ${local.minimum_version}, got ${meta.version}"
    }
}
```

**Available attributes:**
- `meta.source` - Full provider source (e.g., `registry.terraform.io/hashicorp/aws`)
- `meta.version` - Provider version (e.g., `4.67.0`)
- `meta.alias` - Provider alias (if configured)
- `attrs.*` - Provider configuration attributes (region, profile, etc.)

> **Note:** `meta.name` and `meta.type` are NOT confirmed available in `reference/verified-syntax.md`. Do not rely on them — use `meta.source` to identify a provider and `meta.version` for version checks.

**Accessing provider configuration with `attrs`:**

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "production"
}

provider_policy "aws" "region_check" {
    locals {
        aws_region = core::try(attrs.region, "")
        allowed_regions = ["us-east-1", "us-west-2", "eu-west-1"]
    }

    enforce {
        condition = core::contains(local.allowed_regions, local.aws_region)
        error_message = "AWS provider must use approved region. Got: ${local.aws_region}"
    }
}
```

**⚠️ Provider configuration blocks require `[0]` index:**
```hcl
# AWS provider blocks (need [0] index)
attrs.default_tags[0].tags
attrs.assume_role[0].role_arn
attrs.endpoints[0].s3
```

**Wildcards:**
```hcl
provider_policy "*" "all_providers" {
    # Evaluates once per provider in configuration
}
```

---

## Core Functions Reference

### ⚠️ String Function Limitations

**Terraform Policy has VERY LIMITED string functions:**

```hcl
# ✅ Get string length
core::length(string)
# Example: core::length(attrs.description) > 0

# ✅ Join list into string
core::join(separator, list)
# Example: core::join(", ", local.allowed_versions)
```

**✅ String functions available:**
- ✅ `core::startswith(string, prefix)` - Returns bool; e.g. `core::startswith(meta.version, ">")` ✅
- ✅ `core::endswith(string, suffix)` - Returns bool
- ✅ `core::contains_substring(string, substr)` - Returns bool
- ❌ `core::contains(string, substring)` - Does NOT work for strings (only lists!)
- ✅ `core::split(separator, string)` - Splits string into list; e.g. `core::split("-", "80-443")` → `["80", "443"]`

**✅ What IS Also Available — `core::regex(pattern, string)`:**
- Pattern and substring matching via `core::regex()`
- **Important:** `core::regex()` **throws** on no match (does NOT return null) — always wrap with `core::try()`

```hcl
# Safe boolean pattern — use this idiom everywhere
locals {
    # Substring check: does description contain "exception"?
    has_exception = core::try(core::regex("NET-8 = exception", core::try(attrs.description, "")), null) != null

    # Prefix check: does source start with approved namespace?
    is_approved_source = core::try(core::regex("^app\\.terraform\\.io/myorg/", meta.source), null) != null

    # Exact membership: still use core::contains() for lists
    approved_types = ["gp3", "io1"]
    is_approved_type = core::contains(local.approved_types, core::try(attrs.volume_type, ""))
}
```

**Note:** For prefix/suffix checking, prefer `core::startswith()` / `core::endswith()` over `core::regex()`. Use `core::split()` with `core::parseint()` for numeric string decomposition (e.g. port-range strings like `"80-443"`).

### List Functions

```hcl
# Check if list contains value
core::contains(list, value)
# Example: core::contains(["dev", "staging", "prod"], attrs.environment)

# Get collection or string length (works on strings, lists, sets, maps!)
core::length(list_or_string_or_map)
# Example: core::length(local.violations) == 0
# Example: core::length(attrs.description) > 0  # String length!
# Example: core::length(attrs.tags) > 0  # Map key count

# Get map keys as list
core::keys(map)
# Example: core::keys(attrs.tags)
# Example: core::contains(core::keys(attrs.tags), "Environment")

# Check if any element is true — ❌ core::anytrue() does NOT exist
# Use: core::length([for b in list_of_booleans : b if b]) > 0

# Check if all elements are true — ❌ core::alltrue() does NOT exist
# Use: core::length([for b in list_of_booleans : b if !b]) == 0
```

### Safe Access

```hcl
# Try expression with fallback
core::try(expression, default_value)
# Example: core::try(attrs.encrypted, false)
# Example: core::try(meta.version, "0.0.0")
```

**⚠️ CRITICAL: Cannot Check Attribute Existence Without try()**

Direct attribute access fails when attributes don't exist, **even with null checks:**

```hcl
# ❌ WRONG - Crashes with "This object does not have an attribute named 'region'"
has_region = attrs.region != null

# ✅ CORRECT - Two-step safe access pattern
region_value = core::try(attrs.region, null)
has_region = local.region_value != null
```

**Why:** Terraform Policy cannot test attribute existence before accessing (no `"attr" in attrs` syntax). Always use `core::try()` first, then check the result.

### Semantic Versioning

```hcl
# Compare version against constraint
core::semverconstraint(version, constraint_string)
# Example: core::semverconstraint(meta.version, ">= 4.0.0, < 5.0.0")
```

### Resource Queries

```hcl
# Query related resources
core::getresources(resource_type, filter_map)
# filter_map is REQUIRED. Pass {} to match everything, or { attr = value }
# for equality filtering. Caveat: candidates with unknown target
# attributes at plan time (e.g. references to to-be-created resource IDs)
# are conservatively included regardless of the filter value.
# Example: core::getresources("aws_security_group_rule", {})
```

**⚠️ Filter caveat:** `core::getresources(type, { attr = value })` performs equality matching, but candidates whose target attribute is unknown at plan time (e.g. `bucket = aws_s3_bucket.x.id` for a resource being created in the same plan) are conservatively included. On first-time-create plans with cross-references you'll get every candidate back. Most reliable on update plans against existing infrastructure. See `reference/verified-syntax.md`.

**CRITICAL: core::getresources() Attribute Access**

Resources returned by `core::getresources()` have attributes **at the top level** (NOT through `.attrs`):

```hcl
locals {
    all_roles = core::getresources("aws_iam_role", {})
}

# ✅ CORRECT - Access attributes directly
role_names = [for role in local.all_roles : role.name]
filtered = [for role in local.all_roles : role if role.path == "/service/"]

# ❌ WRONG - Do NOT use .attrs
role_names = [for role in local.all_roles : role.attrs.name]  # ERROR!
```

**Why:** This is DIFFERENT from current resource context where you use `attrs.name`. Returned resources have a different structure.

**Pattern for Cross-Resource Validation:**
```hcl
resource_policy "aws_iam_role" "check" {
    locals {
        role_attachments = core::getresources("aws_iam_role_policy_attachment", {
            role = attrs.name  # filter depends on current resource — must be inline
        })
        has_attachment = core::length(local.role_attachments) > 0
    }
}
```

---

## Semantic Versioning

### Constraint Operators

| Operator | Meaning | Example | Matches |
|----------|---------|---------|---------|
| `=` | Exact version | `"= 4.67.0"` | 4.67.0 only |
| `!=` | Not equal | `"!= 4.50.0"` | Any except 4.50.0 |
| `>` | Greater than | `"> 4.0.0"` | 4.0.1, 4.1.0, 5.0.0, etc. |
| `>=` | Greater or equal | `">= 4.0.0"` | 4.0.0, 4.0.1, 5.0.0, etc. |
| `<` | Less than | `"< 5.0.0"` | 4.99.99, 3.0.0, etc. |
| `<=` | Less or equal | `"<= 5.0.0"` | 5.0.0, 4.99.99, etc. |
| `~>` | Pessimistic (patch) | `"~> 4.67.0"` | >= 4.67.0, < 4.68.0 |
| `~>` | Pessimistic (minor) | `"~> 4.0"` | >= 4.0.0, < 5.0.0 |

### Multiple Constraints (AND logic)

```hcl
# Both constraints must be satisfied
core::semverconstraint(meta.version, ">= 4.0.0, < 5.0.0")
core::semverconstraint(meta.version, ">= 4.0.0, != 4.50.0")
```

### OR Logic

```hcl
locals {
    # Version 4.x OR 5.x allowed
    version_ok = core::semverconstraint(meta.version, "~> 4.0") ||
                 core::semverconstraint(meta.version, "~> 5.0")
}
```

### Version Allowlist Pattern

```hcl
locals {
    allowed_versions = ["3.75.0", "3.80.0", "3.85.0"]

    # Check if current version matches any allowed version
    version_checks = [
        for v in local.allowed_versions :
        core::semverconstraint(meta.version, "= ${v}")
    ]

    is_allowed = core::length([for b in local.version_checks : b if b]) > 0
}

enforce {
    condition = local.is_allowed
    error_message = "Version ${meta.version} not approved. Allowed: ${core::join(", ", local.allowed_versions)}"
}
```

---

> **Next:** [Advanced Patterns & Best Practices](tfpolicy-author.md)

---

**Purpose:** Common patterns for writing Terraform policies
**Status:** All patterns verified during private beta (Updated: 2026-02-24)

---

## Pattern 1: Required Attribute

```hcl
resource_policy "aws_s3_bucket" "require_encryption" {
    enforce {
        condition = attrs.server_side_encryption_configuration != null
        error_message = "S3 buckets must have encryption configured"
    }
}
```

---

## Pattern 2: Attribute Must Match Value

```hcl
resource_policy "aws_ebs_volume" "encryption" {
    enforce {
        condition = core::try(attrs.encrypted, false) == true
        error_message = "EBS volumes must be encrypted"
    }
}
```

---

## Pattern 3: Allowlist Check

```hcl
resource_policy "aws_instance" "instance_type" {
    locals {
        allowed_types = ["t3.micro", "t3.small", "t3.medium"]
        is_allowed = core::contains(local.allowed_types, attrs.instance_type)
    }

    enforce {
        condition = local.is_allowed
        error_message = "Instance type ${attrs.instance_type} not allowed. Use: ${core::join(", ", local.allowed_types)}"
    }
}
```

---

## Pattern 4: Tag Validation

```hcl
resource_policy "*" "required_tags" {
    filter = attrs.tags != null

    locals {
        required_tags = ["Environment", "Owner", "CostCenter"]
        # Count tags that are MISSING; if zero, all required tags are present
        missing_tags = [
            for tag in local.required_tags :
            tag if !core::contains(core::keys(attrs.tags), tag)
        ]
        has_all_tags = core::length(local.missing_tags) == 0
    }

    enforce {
        condition = local.has_all_tags
        error_message = "Resources are missing required tags: ${core::join(", ", local.required_tags)}"
    }
}
```

---

## Pattern 5: Module Source Restriction

```hcl
module_policy "*" "approved_sources" {
    filter = meta.source != null

    locals {
        # Exact allowlist: use core::contains() for explicit full-source matching.
        # For prefix matching use core::startswith(), for pattern matching use core::regex().
        approved_sources = [
            "app.terraform.io/myorg/vpc/aws",
            "app.terraform.io/myorg/database/aws",
            "app.terraform.io/myorg/network/aws",
            "registry.terraform.io/hashicorp/vpc",
            "registry.terraform.io/hashicorp/s3-bucket"
        ]

        is_approved = core::contains(local.approved_sources, meta.source)
    }

    enforce {
        condition = local.is_approved
        error_message = "Module source not approved: ${meta.source}. Must be one of the explicitly allowed modules."
    }
}
```

**Note:** `core::contains()` only supports exact full-string matching. For prefix or namespace matching, use `core::regex()`:
```hcl
# Prefix matching with core::regex() — matches any source under the approved namespace
locals {
    is_approved_namespace = core::try(core::regex("^app\\.terraform\\.io/myorg/", meta.source), null) != null
}
enforce {
    condition = local.is_approved_namespace
    error_message = "Module source must be from app.terraform.io/myorg/ namespace. Got: ${meta.source}"
}
```

---

## Pattern 6: Provider Version Range

```hcl
provider_policy "aws" "version_range" {
    locals {
        min_version = "4.0.0"
        max_version = "5.0.0"
        version_ok = core::semverconstraint(meta.version, ">= ${local.min_version}, < ${local.max_version}")
    }

    enforce {
        condition = local.version_ok
        error_message = "AWS provider version ${meta.version} outside allowed range: >= ${local.min_version}, < ${local.max_version}"
    }
}
```

---

## Pattern 7: Conditional Enforcement

```hcl
resource_policy "aws_s3_bucket" "conditional_encryption" {
    locals {
        # Only enforce encryption for production buckets
        is_production = core::contains(core::keys(attrs.tags), "Environment") &&
                       attrs.tags["Environment"] == "production"

        has_encryption = attrs.server_side_encryption_configuration != null
    }

    enforce {
        # Skip check for non-production or enforce for production
        condition = !local.is_production || local.has_encryption
        error_message = "Production S3 buckets must have encryption enabled"
    }
}
```

---

## Pattern 8: Multiple Checks with Detailed Errors

```hcl
resource_policy "aws_security_group" "security_checks" {
    locals {
        # ✅ Use core::length() instead of core::anytrue() (which does NOT exist)
        # Filter to SSH rules from internet; if list is non-empty, there's a violation
        ssh_from_internet = [
            for rule in core::try(attrs.ingress, []) :
            rule if (rule.from_port == 22 && core::contains(core::try(rule.cidr_blocks, []), "0.0.0.0/0"))
        ]
        has_ssh_ingress = core::length(local.ssh_from_internet) > 0

        # Check for proper description
        has_description = attrs.description != null && core::length(attrs.description) > 0
    }

    enforce {
        condition = !local.has_ssh_ingress
        error_message = "Security groups must not allow SSH from the internet (0.0.0.0/0)"
    }

    enforce {
        condition = local.has_description
        error_message = "Security groups must have a description"
    }
}
```

---

## Pattern 9: Provider Configuration Policies

**Validate provider configuration attributes and blocks:**

```hcl
# Check provider region
provider_policy "aws" "approved_regions" {
    locals {
        aws_region = core::try(attrs.region, "")
        allowed_regions = ["us-east-1", "us-west-2", "eu-west-1"]
    }

    enforce {
        condition = core::contains(local.allowed_regions, local.aws_region)
        error_message = "AWS provider must use approved region. Got: ${local.aws_region}"
    }
}

# Check provider blocks (need [0] index)
provider_policy "aws" "enforce_default_tags" {
    locals {
        # Provider blocks are lists
        default_tags = core::try(attrs.default_tags, [])
        has_default_tags = core::length(local.default_tags) > 0

        # Access block attributes with [0] index
        tags = local.has_default_tags ?
            core::try(local.default_tags[0].tags, {}) : {}

        required_tags = ["Environment", "Owner", "CostCenter"]
        tag_keys = core::keys(local.tags)

        # ✅ Use core::length() instead of core::alltrue() (which does NOT exist)
        # Count required tags that are MISSING; if zero, all required tags are present
        missing_required_tags = [
            for tag in local.required_tags :
            tag if !core::contains(local.tag_keys, tag)
        ]
        has_all_required = core::length(local.missing_required_tags) == 0
    }

    enforce {
        condition = local.has_default_tags
        error_message = "AWS provider must configure default_tags block"
    }

    enforce {
        condition = local.has_all_required
        error_message = "AWS provider default_tags must include: ${core::join(", ", local.required_tags)}"
    }
}

# Prevent hardcoded credentials
provider_policy "aws" "no_hardcoded_credentials" {
    locals {
        has_access_key = attrs.access_key != null
        has_secret_key = attrs.secret_key != null
    }

    enforce {
        condition = !local.has_access_key && !local.has_secret_key
        error_message = "AWS provider must NOT use hardcoded credentials (access_key/secret_key). Use environment variables or IAM roles instead."
    }
}
```

**Key points:**
- `attrs.*` provides access to provider configuration
- Provider blocks (default_tags, assume_role) require `[0]` index
- Version checking uses `meta.version` with `core::semverconstraint()`
- Security checks (no hardcoded credentials) are important

---

## Pattern 10: Cross-Resource Enforcement

**Enforce that one resource type has a corresponding companion resource:**

`aws_s3_bucket_server_side_encryption_configuration` is a dependent child of `aws_s3_bucket` — its `bucket` argument always references `attrs.id`. The filter value is derived from `attrs.*`, so the top-level cache pattern is prohibited (Mistake 13 in verified-syntax.md). Always use the inline filter pattern for S3 companion resources.

```hcl
# NOTE: This policy contains a cross-resource reference that will not resolve
# during plan time, but the policy will run successfully during apply time.
resource_policy "aws_s3_bucket" "require_encryption_config" {
    locals {
        sse_configs     = core::getresources("aws_s3_bucket_server_side_encryption_configuration", {
            bucket = attrs.id  # filter derived from current resource's own attr — must be inline
        })
        has_sse_config  = core::length(local.sse_configs) > 0
        # rule is a Set — convert to list before indexing; guard first
        sse_rules       = local.has_sse_config ? core::try([for r in local.sse_configs[0].rule : r], []) : []
        has_sse_rule    = core::length(local.sse_rules) > 0
        sse_apply_block = local.has_sse_rule ? core::try([for a in local.sse_rules[0].apply_server_side_encryption_by_default : a], []) : []
        has_apply_block = core::length(local.sse_apply_block) > 0
        sse_algorithm   = local.has_apply_block ? core::try(local.sse_apply_block[0].sse_algorithm, "") : ""
    }

    enforcement_level = "advisory"

    enforce {
        condition = local.has_sse_config
        error_message = "S3 bucket must have an aws_s3_bucket_server_side_encryption_configuration resource."
    }

    enforce {
        condition = local.sse_algorithm == "aws:kms"
        error_message = "S3 bucket encryption must use aws:kms (found: ${local.sse_algorithm != "" ? local.sse_algorithm : "(none configured)"})"
    }
}
```

**Key points:**
- The filter value (`attrs.id`) is the current resource's own attribute — a top-level cache is impossible; use the inline call
- Both checks (presence and KMS algorithm) live in one `resource_policy` block with multiple `enforce` blocks — never split checks on the same resource type into two blocks (SKILL.md Output Structure Rule 1)
- Always include the apply-time `# NOTE:` comment

---

## Pattern 11: Resource Count Limits

**Limit the total number of resources of a specific type:**

```hcl
locals {
    all_nat_gateways = core::getresources("aws_nat_gateway", {})
    nat_gateway_count = core::length(local.all_nat_gateways)
    max_allowed = 3
}

resource_policy "aws_nat_gateway" "limit_count" {
    enforce {
        condition = local.nat_gateway_count <= local.max_allowed
        error_message = "Maximum ${local.max_allowed} NAT gateways allowed (found: ${local.nat_gateway_count})"
    }
}
```

**Key points:**
- Policy runs for each resource but references global count
- All resources will fail if limit is exceeded
- Use top-level locals to count once

---

## Pattern 12: Cross-Resource Attribute Validation

**Validate that one resource's attribute matches another resource's attribute:**

```hcl
resource_policy "aws_subnet" "vpc_tag_match" {
    filter = attrs.vpc_id != null

    locals {
        # NOTE: This policy contains a cross-resource reference that will not resolve
        # during plan time, but the policy will run successfully during apply time.
        matching_vpcs  = core::getresources("aws_vpc", { id = attrs.vpc_id })
        vpc            = core::length(local.matching_vpcs) > 0 ? local.matching_vpcs[0] : null
        vpc_env_tag    = core::try(local.vpc.tags["Environment"], "")
        subnet_env_tag = core::try(attrs.tags["Environment"], "")
        tags_match     = local.vpc_env_tag == local.subnet_env_tag
    }

    enforce {
        condition = local.tags_match
        error_message = "Subnet Environment tag (${local.subnet_env_tag}) must match VPC Environment tag (${local.vpc_env_tag})"
    }
}
```

**Key points:**
- `aws_vpc.id` is the linking attribute referenced by `attrs.vpc_id` — this is an attrs.*-derived key so the top-level cache + map-index pattern is prohibited (Mistake 13 in verified-syntax.md); always use inline `core::getresources`
- Use `core::try()` for safe attribute access
- Check both existence and value matching

---

## Pattern 13: Sentinel Conversion - DMS Endpoint SSL Mode

**Source policy:** HashiCorp PCI DSS library - `dms-endpoints-should-use-ssl.sentinel`

**Conversion quality:** Perfect

```hcl
resource_policy "aws_dms_endpoint" "require_ssl_mode" {
    locals {
        ssl_mode = core::try(attrs.ssl_mode, "")
        valid_ssl_modes = ["require", "verify-ca", "verify-full"]
    }

    enforce {
        condition = core::contains(local.valid_ssl_modes, local.ssl_mode)
        error_message = "DMS endpoints must set ssl_mode to one of: require, verify-ca, verify-full"
    }
}
```

**Why this converts cleanly:**
- Single resource type
- Direct attribute check on planned values
- No cross-resource dependency or reference metadata
- Sentinel `collection.reject()` becomes one focused `enforce` condition

---

## Pattern 14: Sentinel Conversion - Elasticsearch HTTPS Required

**Source policy:** HashiCorp PCI DSS library - `elasticsearch-https-required.sentinel`

**Conversion quality:** Good

```hcl
resource_policy "aws_elasticsearch_domain" "https_required" {
    locals {
        endpoint_options = core::try(attrs.domain_endpoint_options, [])
        endpoint_options_present = core::length(local.endpoint_options) > 0
        enforce_https = core::try(local.endpoint_options[0].enforce_https, false)
        tls_security_policy = core::try(local.endpoint_options[0].tls_security_policy, "")
    }

    enforce {
        condition = local.endpoint_options_present
        error_message = "Elasticsearch domains must define domain_endpoint_options"
    }

    enforce {
        condition = local.enforce_https == true
        error_message = "Elasticsearch domains must set domain_endpoint_options.enforce_https = true"
    }

    enforce {
        condition = local.tls_security_policy == "Policy-Min-TLS-1-2-PFS-2023-10"
        error_message = "Elasticsearch domains must use tls_security_policy 'Policy-Min-TLS-1-2-PFS-2023-10'"
    }
}
```

**Why this is `Good` instead of `Perfect`:**
- The Sentinel policy uses helper functions and nested map lookups; tfpolicy rewrites that logic into direct block access with `core::try()`
- The enforcement intent is preserved, but the structure is idiomatic tfpolicy rather than one-to-one

---

## Pattern 15: Sentinel Conversion - EventBridge Bus Must Have Attached Policy

**Source policy:** HashiCorp PCI DSS library - `eventbridge-custom-event-bus-should-have-attached-policy.sentinel`

**Conversion quality:** Limited

```hcl
locals {
    all_event_bus_policies = core::getresources("aws_cloudwatch_event_bus_policy", {})
    event_bus_policy_map = {
        for policy in local.all_event_bus_policies :
        policy.event_bus_name => true
    }
}

resource_policy "aws_cloudwatch_event_bus" "require_attached_policy" {
    locals {
        bus_name = core::try(attrs.name, "")
        has_attached_policy = core::try(local.event_bus_policy_map[local.bus_name], false)
    }

    enforce {
        condition = local.has_attached_policy
        error_message = "EventBridge buses must have a matching aws_cloudwatch_event_bus_policy resource"
    }
}
```

**Why this is only `Limited`:**
- This relies on value matching through `core::getresources()`, not Terraform graph/reference metadata
- It works best when `event_bus_name` is explicit and already resolved
- New resources with unresolved references can produce different behavior from Sentinel or fail to match on first creation

---


> **Previous:** [Quick Start Guide](tfpolicy-author.md)
> **Back to:** [Main README](../README.md)
