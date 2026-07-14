# Terraform Policy - Verified Syntax Reference

> **Shared reference** used by all sibling skills in `references/`:
> [tfpolicy-author](../skills/tfpolicy-author/SKILL.md) | [tfpolicy-test](../skills/tfpolicy-test/SKILL.md)

**Last Updated:** 2026-02-24
**Status:** All patterns user-verified during private beta
**Purpose:** Source-of-truth quick reference. Sub-skills link here rather than duplicating facts.

---

## Critical Rules

### 1. ✅ Semantic Versioning (VERIFIED)
**Rule:** Use `core::semverconstraint()` for ALL version comparisons
```hcl
# ✅ Correct
condition = core::semverconstraint(meta.version, ">= 4.0.0, < 5.0.0")

# ❌ Wrong
condition = meta.version >= 4.0  # Don't use direct comparison
```

**Constraint syntax:**
- `"= 4.67.0"` - Exact version
- `">= 4.0.0"` - Minimum
- `"< 5.0.0"` - Maximum
- `"~> 4.67.0"` - Pessimistic patch (>= 4.67.0, < 4.68.0)
- `"~> 4.0"` - Pessimistic minor (>= 4.0.0, < 5.0.0)
- `">= 4.0.0, < 5.0.0"` - Multiple constraints (AND)
- `"!= 4.50.0"` - Exclude version

---

### 2. ✅ Core Function Prefix (VERIFIED)
**Rule:** ALL built-in Terraform functions require `core::` prefix

```hcl
# ✅ Correct
filter = core::try(attrs.encrypted, false) == true
is_allowed = core::length([for v in local.version_checks : v if v]) > 0
error_message = "Allowed: ${core::join(", ", local.allowed_versions)}"

# ❌ Wrong
filter = try(attrs.encrypted, false) == true  # Missing core:: prefix
```

**Common functions:**
- `core::try(expr, default)` - Safe access with fallback
- `core::contains(list, value)` - List membership (**lists only, NOT strings!**)
- `core::length(list_or_string)` - List/string/map length (✅ works on all!)
- `core::keys(map)` - Get map keys as list (✅ requires core:: prefix)
- `core::join(separator, list)` - Join list elements
- `core::semverconstraint(version, constraint)` - Version comparison
- `core::getresources(type, filter_map)` - Query related resources
- ❌ ~~`core::anytrue(list)`~~ — **DOES NOT EXIST** in tfpolicy runtime. Use `core::length([for b in list : b if b]) > 0` instead.
- ❌ ~~`core::alltrue(list)`~~ — **DOES NOT EXIST** in tfpolicy runtime. Use `core::length([for b in list : b if !b]) == 0` instead.

**⚠️ IMPORTANT: `core::getresources()` filter behavior with unknown attribute values.**
- The `filter_map` argument is **required by the function signature** (omitting it → "Not enough function arguments"). Passing `{}` matches everything; passing `{ attr = value }` performs equality matching.
- **Caveat:** when the target attribute on a candidate resource is **unknown at plan time** (e.g. `bucket = aws_s3_bucket.x.id` where `aws_s3_bucket.x` is being created in the same plan), the equality comparison evaluates to unknown and the engine **conservatively includes that candidate** in the result set. The filter is not "ignored" — but it cannot narrow results past any candidate whose target attribute is computed.
- Verified on terraform 1.15.0-policy20261105 / tfpolicy 0.0.2-beta20260513 / tfpolicy-plugin 0.0.2-beta20260422.
- **Production impact:** any cross-resource policy on a first-time-create plan (where related resources reference each other via `.id`) will see every candidate, not the matching one. Update plans against existing infrastructure (where target attributes are already known) filter correctly.
- **Pattern choice — constant filter vs. `attrs.*` filter:**
  - **When the filter value is a known constant AND no secondary `attrs.*` filtering is needed inside `resource_policy`**: you MAY call `core::getresources()` once in a top-level `locals` block. A valid example is a truly account-level resource with no per-parent link:
    ```hcl
    # ✅ CORRECT — aws_s3_account_public_access_block is account-level; no per-bucket link
    locals {
      account_pab = core::getresources("aws_s3_account_public_access_block", {})
    }
    resource_policy "aws_s3_bucket" "account_block_required" {
      locals {
        pab               = core::length(local.account_pab) > 0 ? local.account_pab[0] : null
        block_public_acls = local.pab != null ? core::try(local.pab.block_public_acls, false) : false
      }
    }
    ```
  - **When the filter value comes from `attrs.*`** (e.g. `attrs.id`, `attrs.name`, `attrs.arn`) OR when any secondary filtering inside `resource_policy` is by `attrs.*`: use an **inline `core::getresources()` call with the specific per-resource filter** inside `resource_policy`. The top-level cache with a `{}` empty filter plus HCL-side `attrs.*` filtering is the **wrong pattern** — see Mistake 13 CRITICAL note below.
    ```hcl
    # ✅ CORRECT — filter value "table/${attrs.name}" comes from attrs.* — must be inline
    resource_policy "aws_dynamodb_table" "autoscaling_required" {
      locals {
        table_resource_id = "table/${attrs.name}"
        scaling_targets   = core::getresources("aws_appautoscaling_target", {
          resource_id = local.table_resource_id
        })
      }
    }
    # ❌ WRONG — top-level {} cache + HCL filter by attrs.* is the anti-pattern
    # locals { all_targets = core::getresources("aws_appautoscaling_target", {}) }
    # resource_policy "aws_dynamodb_table" { locals { filtered = [for t in local.all_targets : t if t.resource_id == "table/${attrs.name}"] } }
    ```
  - > ⚠️ **DynamoDB autoscaling is ALWAYS the inline pattern (Pattern B).** Even pre-filtering at the top level by a constant `scalable_dimension` does not make it Pattern A — the secondary `resource_id == "table/${attrs.name}"` filter inside `resource_policy` is still derived from `attrs.name`, so the correct approach is an inline `core::getresources()` call filtered by `resource_id`. Pre-filtering by `scalable_dimension` at the top level forces you to add the `attrs.*`-derived `resource_id` filter inside `resource_policy`, which is the anti-pattern. Use the inline call and apply the constant `scalable_dimension` check as a simple HCL filter after the inline fetch.
- ⚠️ When the filter value is derived from `attrs.*` and that attribute is **unknown at plan time** (e.g. `bucket = aws_s3_bucket.x.id` for a newly-created resource), the equality comparison evaluates to unknown — the engine conservatively includes that candidate in the result set, so first-time-create plans with cross-references are unreliable. Most reliable on updates and existing infrastructure where target values are known.
- > ⛔ **All dependent child resources — always use the inline filter pattern, NOT the top-level `{}` cache.** This applies to `aws_s3_bucket_public_access_block`, `aws_s3_bucket_acl`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_policy`, `aws_appautoscaling_target`, `aws_appautoscaling_policy`, and any resource type that has a `(Required)` or `(Optional)` argument referencing a parent resource. Call `core::getresources()` **inline** inside the parent `resource_policy` with the specific filter (e.g. `{bucket = attrs.id}`, `{resource_id = local.table_resource_id}`). Do NOT use the top-level cache `{}` + HCL for-loop pattern for these types. See Mistake 13.

**CRITICAL: core::getresources() Attribute Access:**
- Resources returned have attributes at **top level** (NOT through `.attrs`)
- Example: `resource.name` ✅ NOT `resource.attrs.name` ❌
- This is DIFFERENT from current resource context where you use `attrs.name`
- **Pattern:** For dependent child resources (any type with a `(Required)` or `(Optional)` argument referencing a parent by `.id`, `.arn`, or `.name`): use inline `core::getresources()` inside `resource_policy` with the specific per-parent filter; access returned attributes directly at top level (NOT through `.attrs`). For truly independent/account-level resources: cache in top-level `locals` with a constant filter (if any), and access returned attributes directly.

**✅ String functions available:**
- ✅ `core::startswith(string, prefix)` - Returns bool. **Arg order: full string first, prefix second** (same as Sentinel's `strings.has_prefix`). e.g. `core::startswith(meta.version, ">")` ✅
- ✅ `core::endswith(string, suffix)` - Returns bool
- ✅ `core::contains_substring(string, substr)` - Returns bool
- ✅ **`core::regex(pattern, string)`** - Pattern/substring matching. Throws on no match — wrap with `core::try()`: `core::try(core::regex("pattern", string), null) != null`
- ✅ **`core::split(separator, string)`** - Splits a string into a list of substrings at each occurrence of `separator`. Example: `core::split("-", "1-100")` returns `["1", "100"]`; `core::split("-", "22")` returns `["22"]`. Use with `core::parseint()` to parse port ranges like `"start-end"` without regex:
  ```hcl
  # ✅ Parsing a port range "start-end" using core::split (preferred over regex)
  port_parts  = core::split("-", local.dest_port_range)
  range_start = core::length(local.port_parts) == 2 ? core::try(core::parseint(local.port_parts[0], 10), -1) : -1
  range_end   = core::length(local.port_parts) == 2 ? core::try(core::parseint(local.port_parts[1], 10), -1) : -1
  # Range covers port 22 if start < 22 AND end > 22 (exclusive, matching Sentinel logic)
  is_range_ssh = local.range_start < 22 && local.range_end > 22
  ```
  Note: ternary short-circuits, so `core::parseint` is only called when `core::length == 2`. When the port string is not a range (e.g. `"22"` or `"*"`), `range_start` and `range_end` default to `-1`, making the range check false without any index-out-of-bounds risk.
- ❌ Substring matching via `core::contains()` — only works for lists, NOT strings
  ```hcl
  # Prefix check using core::startswith()
  starts_with_open = core::startswith(local.version_value, ">")
  # Substring check using core::regex()
  has_exception = core::try(core::regex("exception", core::try(attrs.description, "")), null) != null
  ```

**Provider version constraint checks:** In `provider_policy`, `meta.version` is the **resolved provider version** (e.g. `"6.50.0"`), **not** the constraint string from `required_providers`. There is no tfpolicy surface that exposes the constraint string.

> ⚠️ **`providers-require-version`-style Sentinel policies** that check `strings.has_prefix(p.version_constraint, ">")` inspect the version constraint format string, which tfpolicy does not expose. This check is **non-convertible**. The closest tfpolicy equivalent enforces that the **resolved provider version** is within an approved range:
```hcl
# Sentinel: strings.has_prefix(p.version_constraint, ">")   →  non-convertible
# TFPolicy nearest equivalent — enforce resolved version range instead:
provider_policy "*" "provider_version_range" {
  enforce {
    condition     = core::semverconstraint(meta.version, ">= 4.0.0, < 5.0.0")
    error_message = "Provider version '${meta.version}' must satisfy '>= 4.0.0, < 5.0.0'. Pin the provider to a tested version range to prevent major version upgrades."
  }
}
```
> ⚠️ **Arg order:** `core::startswith(string, prefix)` — the full string is the **first** argument, the prefix is the **second**. Do not reverse them.

**✅ JSON functions available:**
- ✅ `core::jsondecode(string)` — parses a JSON string into an HCL object/list. Use when an attribute contains a serialised JSON value (e.g. an inline IAM policy document).
- ✅ `core::jsonencode(value)` — encodes an HCL object/list as a JSON string.
- ❌ `json::unmarshal` — **does not exist**. There is no `json::` namespace. Always use `core::jsondecode` instead.
  ```hcl
  locals {
    policy_doc = core::try(core::jsondecode(core::try(attrs.policy, "{}")), {})
    statements = core::try(local.policy_doc.Statement, [])
  }
  ```

---

### 3. ✅ Policy Type Features (VERIFIED)
**Rule:** ALL policy types support the same features

| Feature | resource_policy | module_policy | provider_policy |
|---------|----------------|---------------|-----------------|
| `locals {}` | ✅ Yes | ✅ Yes | ✅ Yes |
| `filter` clause | ✅ Yes | ✅ Yes | ✅ Yes |
| Multiple `enforce` | ✅ Yes | ✅ Yes | ✅ Yes |

**IMPORTANT:** Language server shows FALSE ERRORS for `locals` in `provider_policy`
- Error: "No declaration found for local.variable"
- **These are safe to ignore** - syntax is valid
- Runtime evaluation works correctly

---

### 4. ✅ CRITICAL: Blocks vs Attributes Schema Distinction

**Rule:** Provider schema representation determines how you access nested configuration

**Blocks vs Attributes:**
- **BLOCKS** → Represented as **lists of maps** (even if only one allowed)
  - Require array indexing: `attrs.block_name[0].field`
  - Examples: `default_tags`, `assume_role`, `lifecycle`
- **ATTRIBUTES** → Represented as **direct values** (maps, strings, numbers, etc.)
  - Direct access: `attrs.attribute_name`
  - Examples: `region`, `tags`, `instance_type`

**Examples:**

```hcl
# ✅ BLOCK access (default_tags in AWS provider)
# Schema: default_tags = [ { tags = { "Env" = "Dev" } } ]
default_tags_map = core::try(attrs.default_tags[0].tags, {})  # Need [0] index

# ✅ ATTRIBUTE access (tags on resources)
# Schema: tags = { "Env" = "Dev" }
has_tags = attrs.tags != null && core::length(attrs.tags) > 0  # Direct access, no [0]

# Note: core::length() works directly on maps, no need for core::keys()
```

**How to determine Block vs Attribute:**
1. Check provider schema documentation
2. Use `terraform console` to inspect structure
3. If accessing nested field fails without `[0]`, it's a Block

---

### 5. ✅ Input Blocks — Runtime Parameterization (VERIFIED)
**Rule:** Use `input` blocks instead of hardcoded `locals` for values that vary per policy set. Never claim Sentinel `param` cannot be replicated — `input` is the direct equivalent.

```hcl
# ✅ Correct — parameterized, overridable per policy set
input "allowed_providers" {
  type    = list(string)
  default = ["registry.terraform.io/hashicorp/aws"]
}

provider_policy "*" "providers_allowlist" {
  enforce {
    condition     = core::contains(input.allowed_providers, meta.source)
    error_message = "Provider '${meta.source}' not allowed. Permitted: ${core::join(", ", input.allowed_providers)}."
  }
}

# ❌ Wrong — hardcoding what should be configurable
locals {
  allowed_providers = ["registry.terraform.io/hashicorp/aws"]  # Never override without editing policy file
}
```

**Supported types:** `string`, `number`, `bool`, `list(string)`, `list(number)`, `map(string)`
**Override mechanism:** `.tfpolicy.metadata.json` at policy-set scope, or per-evaluation overrides.
**Use for:** allowlists, blocklists, version constraints, limits, thresholds — any value the operator may want to tune.

---

### 6. ✅ Operations Scoping + prior_attrs (VERIFIED)
**Rule:** Use `operations = [...]` to restrict when a policy fires. Use `prior_attrs` to read pre-change state on delete/update.

```hcl
# ✅ Fires only on create and update — never on destroy
resource_policy "tfe_workspace" "require_project" {
  operations = ["create", "update"]
  enforce {
    condition     = core::try(attrs.project_id, "") != ""
    error_message = "tfe_workspace must have project_id set."
  }
}

# ✅ Delete-gate: check prior state before workspace is destroyed
resource_policy "tfe_workspace" "deny_delete_without_tag" {
  operations = ["delete"]   # prior_attrs is available when "create" is NOT in operations
  locals {
    prior_tag_names = core::try(prior_attrs.tag_names, [])
    had_delete_tag  = core::contains(local.prior_tag_names, "delete")
  }
  enforce {
    condition     = local.had_delete_tag
    error_message = "Add 'delete' tag before destroying a workspace."
  }
}
```

**Key rules:**
- `operations = ["create", "update"]` — skips destroy; equivalent to Sentinel `rc.change.actions is not ["delete"]`
- `operations = ["delete"]` — fires only on destroy; `prior_attrs` holds the before-state
- `prior_attrs` is only available when `"create"` is NOT in `operations`
- Default (no `operations`) = fires on create and update

---

### 7. ✅ Time Functions (VERIFIED)
**Rule:** `core::timestamp()`, `core::formatdate()`, and `core::parseint()` exist. Never generate placeholder policies claiming time functions are unavailable.

```hcl
# ✅ Day-of-week restriction
input "restricted_weekdays_utc" {
  type    = list(string)
  default = ["Friday", "Saturday", "Sunday"]
}

resource_policy "tfe_workspace" "deny_apply_day_of_week" {
  locals {
    current_weekday = core::formatdate("EEEE", core::timestamp())  # "Monday", "Friday", etc.
    is_restricted   = core::contains(input.restricted_weekdays_utc, local.current_weekday)
  }
  enforce {
    condition     = !local.is_restricted
    error_message = "Apply blocked on ${local.current_weekday} (UTC). Restricted days: ${core::join(", ", input.restricted_weekdays_utc)}."
  }
}

# ✅ Hour-of-day restriction
input "restricted_hours_utc" {
  type    = list(number)
  default = [8, 9, 10, 11, 12]
}

resource_policy "tfe_workspace" "deny_apply_hour_of_day" {
  locals {
    current_hour = core::parseint(core::formatdate("HH", core::timestamp()), 10)
    is_restricted = core::contains(input.restricted_hours_utc, local.current_hour)
  }
  enforce {
    condition     = !local.is_restricted
    error_message = "Apply blocked during hour ${local.current_hour} UTC."
  }
}
```

**Available time functions:**
- `core::timestamp()` — current UTC time as RFC3339 string
- `core::formatdate(spec, timestamp)` — format specifiers: `"EEEE"` (weekday name), `"HH"` (hour 00-23), `"DD"` (day), `"MM"` (month), `"YYYY"` (year)
- `core::timeadd(timestamp, duration)` — add duration (e.g. `"24h"`, `"-1h"`)
- `core::timecmp(ts1, ts2)` — compare two timestamps
- `core::parseint(string, base)` — parse string to integer (e.g. `core::parseint("08", 10)` → `8`)
- **Note:** All times are UTC. Express restricted windows in UTC.

---

### 8. ✅ Naming Conventions (VERIFIED)

**`resource_policy` block names — use `snake_case` derived from the enforcement requirement:**

```hcl
# ✅ Correct — descriptive snake_case
resource_policy "aws_s3_bucket" "versioning_required" { }
resource_policy "aws_iam_policy" "no_admin_privileges" { }
resource_policy "aws_ecs_task_definition" "secure_networking_mode_and_user" { }

# ❌ Wrong — generic names that don't describe the check
resource_policy "aws_s3_bucket" "check" { }
resource_policy "aws_s3_bucket" "all_checks" { }
resource_policy "aws_s3_bucket" "policy" { }
```

**Rules:**
- Use `snake_case` (underscores, lowercase). Never use kebab-case (hyphens) in block names.
- Name should reflect the enforcement requirement, not the resource type (the type is already in the first argument).
- When a single resource type has multiple enforce blocks (the correct pattern), choose one name that describes the combined requirement rather than the individual checks.
- For IAM 4-type rules, use the same `policy_name` across all 4 blocks (e.g. `no_admin_privileges`) — the resource type in the first argument differentiates them.

---

### 9. ✅ `core::try()` Default Type Selection (VERIFIED)

Choose the default value based on the semantic type of the attribute — do NOT mix defaults for the same attribute across related checks:

| Attribute type | Correct default | Rationale |
|---|---|---|
| Boolean | `false` | Absent boolean = permissive default (fails the check correctly) |
| Required string | `""` | Absent string = empty = fails non-empty checks correctly |
| List / set | `[]` | Absent list = empty = length checks correctly return 0 |
| Map / object | `{}` | Absent map = empty = key lookups return null |
| "Must detect unset separately from empty" | `null` | When `""` and `null` must be treated differently by the condition |

```hcl
# ✅ Correct defaults by type
encrypted        = core::try(attrs.encrypted, false)          # boolean
bucket_name      = core::try(attrs.bucket, "")                 # string
tag_names        = core::try(attrs.tag_names, [])              # list
tags             = core::try(attrs.tags, {})                   # map
optional_config  = core::try(attrs.config, null) != null       # detect presence
```

**⚠️ Using the wrong default silently masks violations:**
- `core::try(attrs.encrypted, true)` — absent = treated as encrypted = violation missed
- `core::try(attrs.tag_names, ["compliant"])` — absent = treated as tagged = violation missed

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Direct Version Comparison
```hcl
# Wrong
condition = meta.version < 5.0
```
**Fix:** Use `core::semverconstraint(meta.version, "< 5.0.0")`

### ❌ Mistake 2: Direct Attribute Access Without try()
```hcl
# Wrong - Crashes when attribute doesn't exist
has_region = attrs.region != null

# Wrong - Still crashes even with double check!
condition = attrs.encrypted != null && attrs.encrypted == true
```
**Fix:** Use two-step safe access pattern:
```hcl
# Correct
region_value = core::try(attrs.region, null)
has_region = local.region_value != null
```
**Why:** Cannot test attribute existence before accessing (no `"attr" in attrs` syntax). Must use `core::try()` first.


### ❌ Mistake 4: Trusting Language Server Errors
```hcl
# Language server shows error, but syntax is valid:
provider_policy "aws" "example" {
    locals {  # ❌ False error: "No declaration found"
        version_check = ...
    }
}
```
**Fix:** Ignore language server errors for `locals` in `provider_policy` - they're false positives


### ❌ Mistake 6: Filter Without Length Check
```hcl
# Suboptimal - doesn't filter empty collections
filter = attrs.ingress != null

# Better - filters both null and empty
filter = attrs.ingress != null && core::length(attrs.ingress) > 0
```
**Fix:** Check both null and length for better performance

### ❌ Mistake 7: Multi-line Boolean Expressions
```hcl
# Wrong - causes syntax errors
is_exact = local.has_version &&
           !core::contains(meta.version, "~>") &&
           !core::contains(meta.version, ">")

# Correct - all on one line
is_exact = local.has_version && !core::contains(meta.version, "~>") && !core::contains(meta.version, ">")
```
**Fix:** Put entire boolean expression on a single line

### ❌ Mistake 8: Trying to Access Module Inputs
```hcl
# Wrong - module inputs not accessible yet
module_policy "*" "check" {
    locals {
        dns_enabled = attrs.enable_dns_hostnames  # ❌ Not supported
    }
}
```
**Fix:** Module inputs via `attrs.*` are work in progress. You can only check `meta.source`, `meta.version`, `meta.address`

### ❌ Mistake 9: Using Substring for Module Targeting
```hcl
# Wrong - substring matching doesn't work
module_policy "vpc" "check" { }  # Won't match modules with "vpc" in source

# Correct - use full source path or wildcard
module_policy "app.terraform.io/myorg/vpc/aws" "check" { }
module_policy "*" "check" { }  # For all modules
```
**Fix:** Module targeting requires FULL source path, not substring

### ❌ Mistake 10: Confusing Blocks with Attributes
```hcl
# Wrong - default_tags is a Block, needs [0]
provider_policy "aws" "check" {
    locals {
        tags = attrs.default_tags.tags  # ❌ Error: no indices
    }
}

# Correct - use [0] for Blocks
provider_policy "aws" "check" {
    locals {
        tags = attrs.default_tags[0].tags  # ✅ Works!
    }
}
```
**Fix:** Check provider schema - Blocks need `[0]` index, Attributes don't

### ❌ Mistake 11: Using Source for Provider Targeting
```hcl
# Wrong - can't use source in first label
provider_policy "hashicorp/aws" "check" { }  # Doesn't work

# Correct - use provider TYPE
provider_policy "aws" "check" {
    # meta.source available inside policy
    # Example: meta.source = "registry.terraform.io/hashicorp/aws"
}
```
**Fix:** provider_policy first label = TYPE ("aws"), not source ("hashicorp/aws")

### ❌ Mistake 12: Unnecessary core::keys() for Length
```hcl
# Unnecessarily complex
has_tags = core::try(core::length(core::keys(attrs.tags)), 0) > 0

# Simpler - core::length() works directly on maps
has_tags = core::try(core::length(attrs.tags), 0) > 0

# Most readable
has_tags = attrs.tags != null && core::length(attrs.tags) > 0
```
**Fix:** `core::length()` works directly on maps - no need for `core::keys()` wrapper

### ❌ Mistake 13: Using core::getresources()
```hcl
# ❌ WRONG — null or empty filter inside resource_policy runs for EVERY resource (O(N) cost)
resource_policy "aws_s3_bucket" "check" {
    locals {
        all_policies = core::getresources("aws_s3_bucket_policy", null)  # unscoped
    }
}
# ❌ ALSO WRONG — empty filter {} is equally unscoped inside resource_policy
resource_policy "aws_s3_bucket" "check" {
    locals {
        all_policies = core::getresources("aws_s3_bucket_policy", {})
    }
}

# ✅ CORRECT — cache at top-level locals for plan-time join (runs once total)
locals {
    all_policies = core::getresources("aws_s3_bucket_policy", {})
}
```
**Why:** Calling `core::getresources()` with an empty (`{}`) or null filter inside `resource_policy` fetches ALL resources of that type once per evaluated resource — O(N) calls for N resources. Cache in top-level `locals` to run once.

**Exception — per-resource attribute filter (parent+child pattern):** When the filter value depends on the current resource's own attribute (e.g. `attrs.id`), the call cannot be pre-computed at the top level because `attrs` is only available inside `resource_policy`. In that case, an inline `core::getresources()` call with a **specific per-resource filter** is the correct pattern. Always use a specific filter — never pass `{}` or `null` inside a `resource_policy`.

> **Dependent child resources — use inline filter, verify via Terraform Registry.** Before writing a direct `resource_policy "child_type"` block or a top-level cache for a cross-resource lookup, fetch the Terraform Registry documentation for the child resource type to determine whether it is structurally dependent on a parent resource:
> - URL pattern: `https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/{resource_name_without_aws_prefix}.html.markdown`
> - Look for a `(Required)` argument in "Argument Reference" whose description references another AWS resource (e.g. "Bucket to which to apply the ACL", "ARN of the load balancer"). Check the usage examples — if they show `some_attr = aws_parent.name.id` or `.arn`, that confirms the dependency.
> - If the child IS dependent: use `resource_policy "aws_parent_type"` with an inline `core::getresources("aws_child_type", {linking_attr = attrs.id_or_arn})` when the enforcement goal is **detecting a missing child**. The linking attribute name comes from the required argument (e.g. `bucket`); use `attrs.id` if the examples assign `.id`, `attrs.arn` if they assign `.arn`.
> - If the enforcement goal is **checking the child's own properties** and the child can exist independently (its absence is not a violation by itself), write `resource_policy "aws_child_type"` directly — do not look it up inside the parent's policy.
> - If a resource type has **no linking attribute in either direction** — neither it nor the "parent" type references the other via `.id`, `.arn`, `.name`, or similar in the Terraform config — it is a **truly independent resource**. Write a **separate `resource_policy`** block for it. Never use `core::getresources()` inside another `resource_policy` to look up independent resources.
> - Never use a top-level empty-filter cache for dependent child resource types when doing per-parent enforcement — it fetches all resources globally and requires a manual HCL for-loop to re-associate them with the parent.

**⛔ CRITICAL: This prohibition extends to ALL cases where the filter value comes from `attrs.*` — not just structurally-dependent child resources.** If you find yourself writing `[for r in local.all_X : r if r.link_attr == attrs.Y]` inside a `resource_policy`, that is the wrong pattern whenever an inline call with a specific filter would work. The top-level `{}` cache is only appropriate when the filter value is a **constant** (not derived from `attrs.*`) — for example, pre-fetching all autoscaling policies to filter by a constant `scalable_dimension` value inside `resource_policy`. For truly independent resources (no linking attribute in either direction), a top-level `{}` cache must NOT be used to implement cross-resource fallback logic between them — each independent resource type gets its own `resource_policy` block (see rule below).

**For truly independent resources — those with NO linking attribute in either direction in the Terraform config — write a separate `resource_policy` block for each type. Do NOT use `core::getresources()` to check an independent resource inside another `resource_policy`.**

The key test: look at the Terraform Registry documentation for both resource types. If neither resource has an attribute whose value is set to the other resource's `.id`, `.arn`, `.name`, or similar reference in example usage (e.g. `bucket = aws_s3_bucket.x.id`, `security_configuration = aws_emr_security_configuration.x.name`), the resources are independent — each gets its own `resource_policy` block.

```hcl
# Example of a LINKING attribute (makes inline core::getresources() correct):
# aws_emr_cluster has: security_configuration = aws_emr_security_configuration.x.name
# → The cluster references the security config by name → inline lookup is valid.

# Example of NO linking attribute (makes inline core::getresources() WRONG):
# aws_instance has NO attribute that references aws_ec2_instance_metadata_defaults.
# aws_ec2_instance_metadata_defaults has NO attribute that references aws_instance.
# → They are independent → each gets its own separate resource_policy block.
```

> **⛔ Sentinel fallback pattern between independent resources — never use core::getresources() as a fallback.**
>
> When a Sentinel policy has logic like:
> *"if resource A does not have attribute X configured, then check if independent resource B has Y as a fallback"*
> — TFPolicy **cannot express this cross-resource fallback** because A and B share no linking attribute.
>
> **Correct TFPolicy conversion:**
> 1. Use `filter` on resource A to skip instances where X is absent (they are out of scope for A's check).
> 2. Enforce Y directly on resource B via its own separate `resource_policy` block.
> 3. Document the limitation in the policy file with a `# LIMITATION:` comment.
>
> **Never** implement the fallback by calling `core::getresources("B", {})` at the top level and using the result inside A's `resource_policy` locals. That is a cross-resource check between independent resources — it is incorrect regardless of whether the filter is `{}` or a constant value.
>
> **Concrete example — aws_instance + aws_ec2_instance_metadata_defaults:**
> ```hcl
> # ❌ WRONG — top-level {} cache used to implement Sentinel fallback between independent resources
> locals {
>   all_defaults = core::getresources("aws_ec2_instance_metadata_defaults", {})
>   defaults_compliant = core::length([for d in local.all_defaults : d if core::try(d.http_tokens, "") == "required"]) > 0
> }
> resource_policy "aws_instance" "imdsv2" {
>   locals {
>     # ❌ Wrong: cross-resource fallback using independent resource
>     is_compliant = local.has_metadata_options ? (local.http_tokens == "required") : local.defaults_compliant
>   }
>   enforce { condition = local.is_compliant ... }
> }
>
> # ✅ CORRECT — filter skips instances without metadata_options; independent resource checked separately
> resource_policy "aws_instance" "imdsv2" {
>   filter = core::try(attrs.metadata_options, null) != null && core::try(core::length(attrs.metadata_options), 0) > 0
>   locals {
>     http_tokens = core::try([for m in attrs.metadata_options : m][0].http_tokens, "")
>   }
>   enforcement_level = "advisory"
>   enforce { condition = local.http_tokens == "required" ... }
> }
>
> resource_policy "aws_ec2_instance_metadata_defaults" "imdsv2" {
>   locals { http_tokens = core::try(attrs.http_tokens, "") }
>   enforcement_level = "advisory"
>   enforce { condition = local.http_tokens == "required" ... }
> }
> ```

```hcl
# ❌ WRONG — top-level {} cache, then HCL-filtered by attrs.* value inside resource_policy
locals {
  all_sec_configs = core::getresources("aws_emr_security_configuration", {})
}
resource_policy "aws_emr_cluster" "check" {
  locals {
    # ❌ Wrong pattern: fetches all globally and re-filters per cluster
    matching = [for sc in local.all_sec_configs : sc if sc.name == attrs.security_configuration]
  }
}

# ❌ ALSO WRONG — same anti-pattern restructured as a top-level lookup map.
# Building { name => value } at the top level and indexing by an attrs.*-derived key
# inside resource_policy is semantically equivalent to the {} cache + HCL for-loop above.
# The lookup key (local.security_config_name = core::try(attrs.security_configuration, ""))
# is still derived from attrs.*, so this violates the same rule.
locals {
  all_security_configs = core::getresources("aws_emr_security_configuration", {})
  security_config_map  = {
    for sc in local.all_security_configs :
    core::try(sc.name, "") => core::try(sc.configuration, "")
  }
}
resource_policy "aws_emr_cluster" "check" {
  locals {
    security_config_name = core::try(attrs.security_configuration, "")
    # ❌ Wrong: map lookup by attrs.*-derived key is an attrs.* filter in disguise
    security_config_json = core::try(local.security_config_map[local.security_config_name], "")
  }
}

# ✅ CORRECT — inline call with filter derived from attrs.*
resource_policy "aws_emr_cluster" "check" {
  locals {
    matching = core::getresources("aws_emr_security_configuration", {
      name = attrs.security_configuration
    })
  }
}

# ✅ CORRECT — inline call with per-resource filter using attrs.id
# NOTE: This policy contains a cross-resource reference that will not resolve during plan time,
# but the policy will run successfully during apply time.
resource_policy "aws_s3_bucket" "public_access_required" {
  locals {
    public_access_block     = core::getresources("aws_s3_bucket_public_access_block", {
      bucket = attrs.id  # Use attrs.id: Terraform sets child.bucket = parent.id
    })
    block_public_acls       = core::try(local.public_access_block[0].block_public_acls, false)
    block_public_policy     = core::try(local.public_access_block[0].block_public_policy, false)
    ignore_public_acls      = core::try(local.public_access_block[0].ignore_public_acls, false)
    restrict_public_buckets = core::try(local.public_access_block[0].restrict_public_buckets, false)
  }
  enforce {
    condition     = local.block_public_acls && local.block_public_policy && local.ignore_public_acls && local.restrict_public_buckets
    error_message = "S3 bucket must have all public access block settings enabled."
  }
}
```
See the `core::getresources()` decision guide in Critical Rule 2 above for the full pattern guidance.

### ❌ Mistake 14: Using core::getdatasource() Inside resource_policy
```hcl
# ❌ WRONG - Makes API calls for EVERY resource!
resource_policy "aws_s3_bucket" "check" {
    locals {
        account_id = core::getdatasource("aws_caller_identity", {})
    }
}

# ✅ CORRECT - Cache in top-level locals
locals {
    account_id = core::getdatasource("aws_caller_identity", {})
}
```
**Why:** Makes real provider API calls (not cached). Never use inside resource policies.

### ❌ Mistake 15: Using .attrs with core::getresources()
```hcl
# ❌ WRONG
locals {
    all_roles = core::getresources("aws_iam_role", {})
}
resource_policy "aws_iam_role" "check" {
    locals {
        name = local.all_roles[0].attrs.name  # ERROR!
    }
}

# ✅ CORRECT
resource_policy "aws_iam_role" "check" {
    locals {
        name = local.all_roles[0].name  # Works!
    }
}
```
**Fix:** Resources from `core::getresources()` have attributes at top level, not through `.attrs`.

### ❌ Mistake 16: Not Converting Sets to Lists for Indexing
```hcl
# ❌ WRONG - rule is a SET, cannot index
resource_policy "aws_s3_bucket_server_side_encryption_configuration" "check" {
    locals {
        sse_algo = attrs.rule[0].sse_algorithm  # ERROR!
    }
}

# ✅ CORRECT - Convert set to list using for loop
resource_policy "aws_s3_bucket_server_side_encryption_configuration" "check" {
    locals {
        sse_algo = [for rule in attrs.rule : rule][0].sse_algorithm
    }
}
```
**Fix:** Sets cannot be indexed with `[0]`. Use `[for item in set : item][0]` to convert.

### ❌ Mistake 17: Redundant Length Checks — and When to Keep Them

`core::try()` catches index-out-of-range errors, so a bare length check before `[0]` inside a `condition =` expression is technically redundant:

```hcl
# ❌ Redundant in condition = expressions (core::try catches the out-of-range error)
condition = core::length(local.list) > 0 && core::try(local.list[0].value, "") == "expected"

# ✅ Simpler — safe in condition = expressions
condition = core::try(local.list[0].value, "") == "expected"
```

**However**, when the list comes from `core::getresources()` (a child-resource lookup), always use an explicit length guard in `locals` before indexing with `[0]`. This makes the intent clear, is consistent with policies that inspect nested attribute blocks, and avoids relying on `core::try` to silently swallow a structural absence:

```hcl
# ✅ PREFERRED for core::getresources() results — explicit guard before [0]
locals {
  bucket_acl_resources = core::getresources("aws_s3_bucket_acl", { bucket = attrs.id })
  has_acl              = core::length(local.bucket_acl_resources) > 0
  acl_value            = local.has_acl ? core::try(local.bucket_acl_resources[0].acl, "") : ""
}

# ✅ PREFERRED for nested block lists from getresources() — guard each level
locals {
  sse_configs     = core::getresources("aws_s3_bucket_server_side_encryption_configuration", { bucket = attrs.id })
  has_sse_config  = core::length(local.sse_configs) > 0
  sse_rules       = local.has_sse_config ? core::try([for r in local.sse_configs[0].rule : r], []) : []
  has_sse_rule    = core::length(local.sse_rules) > 0
  sse_apply_block = local.has_sse_rule ? core::try([for a in local.sse_rules[0].apply_server_side_encryption_by_default : a], []) : []
  has_apply_block = core::length(local.sse_apply_block) > 0
  sse_algorithm   = local.has_apply_block ? core::try(local.sse_apply_block[0].sse_algorithm, "") : ""
}

# ❌ AVOID for getresources() results — relies on core::try to mask absent child resource
locals {
  sse_configs   = core::getresources("aws_s3_bucket_server_side_encryption_configuration", { bucket = attrs.id })
  sse_rules     = core::try([for r in local.sse_configs[0].rule : r], [])       # no guard: absence silently swallowed
  sse_algorithm = core::try(local.sse_rules[0].apply_server_side_encryption_by_default[0].sse_algorithm, "")
}
```

**Rule summary:**
- In a `condition =` expression: `core::try(list[0].attr, default)` without a length guard is acceptable.
- In a `locals` block with `core::getresources()` results: use `has_X = core::length(local.X) > 0` and guard each `[0]` access with `local.has_X ? ... : default`. This is the established pattern in all S3 child-resource policies and makes the "no child resource found" case explicit.

### ❌ Mistake 18: Expecting Cross-Resource References to Resolve at Plan Time
```hcl
# ❌ Won't match during initial creation
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id  # Reference not resolved at policy time
}

# ✅ For testing, use literals
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = "my-bucket"  # Literal value
}
```
**Fix:** Cross-resource references aren't resolved at policy evaluation. Works best on existing infrastructure updates.

### ❌ Mistake 19: Using meta.address in resource_policy
```hcl
# ❌ WRONG — meta.address is UNDEFINED in resource_policy real-plan evaluation
resource_policy "aws_s3_bucket" "check" {
    enforce {
        condition = !local.has_public_acl
        error_message = "S3 bucket '${meta.address}' has a public ACL."  # ERROR!
    }
}

# ✅ CORRECT — use static strings or safe attrs interpolation
resource_policy "aws_s3_bucket" "check" {
    enforce {
        condition = !local.has_public_acl
        error_message = "S3 bucket has a prohibited public ACL. Set acl to 'private' or remove it."
        # Or with dynamic context using a known attribute:
        # error_message = "S3 bucket '${attrs.bucket}' has a prohibited public ACL."
    }
}
```
**Fix:** `meta.address` is UNDEFINED for `resource_policy` in real plan evaluation. It throws `Error: Unsupported attribute` for **every resource evaluated**, including compliant ones. `tfpolicy test` silently passes this bug — only `terraform plan --policies=` catches it.

### ❌ Mistake 20: Incomplete Security Group Resource Coverage
```hcl
# ❌ WRONG — Only covers 2 of 4 SG resource types; misses modern VPC API
resource_policy "aws_security_group" "check" { ... }
resource_policy "aws_security_group_rule" "check" { ... }

# ✅ CORRECT — Cover all 4 AWS security group resource types
resource_policy "aws_security_group" "check" {
    # inline ingress/egress blocks; cidr_blocks in rule.cidr_blocks
}
resource_policy "aws_security_group_rule" "check" {
    # standalone rules; cidr_blocks in attrs.cidr_blocks, type in attrs.type
}
resource_policy "aws_vpc_security_group_ingress_rule" "check" {
    # modern VPC API (recommended); uses attrs.cidr_ipv4 NOT cidr_blocks
    locals {
        has_public_cidr = core::try(attrs.cidr_ipv4, "") == "0.0.0.0/0"
    }
}
resource_policy "aws_default_security_group" "check" {
    # default SG; same inline structure as aws_security_group
}
```
**Key difference:** `aws_vpc_security_group_ingress_rule` uses `cidr_ipv4` (string) and `cidr_ipv6` (string), NOT `cidr_blocks` (list). Always include all 4 types for complete SG enforcement.

**ELB family — 3 resource types required for complete listener/SSL enforcement:**
```hcl
# ❌ WRONG — Only covers Classic ELB; ALB/NLB (the modern standard) are silently skipped
resource_policy "aws_elb" "ssl_policy_check" { ... }

# ✅ CORRECT — Cover all 3 ELB resource types
resource_policy "aws_elb" "ssl_policy_check" {
    # Classic ELB: check aws_load_balancer_policy + aws_load_balancer_listener_policy
    # listeners use attrs.listener[*].lb_protocol
}
resource_policy "aws_lb_listener" "ssl_policy_check" {
    # ALB/NLB: ssl_policy is a direct attribute on the listener
    filter = core::contains(["HTTPS", "TLS"], core::try(attrs.protocol, ""))
    locals {
        ssl_policy = core::try(attrs.ssl_policy, "")
    }
    enforce {
        condition     = core::contains(local.allowed_policies, local.ssl_policy)
        error_message = "ALB/NLB listener must use an approved SSL/TLS security policy."
    }
}
resource_policy "aws_alb_listener" "ssl_policy_check" {
    # aws_alb_listener is an alias for aws_lb_listener — same attributes, same checks
    filter = core::contains(["HTTPS", "TLS"], core::try(attrs.protocol, ""))
    locals {
        ssl_policy = core::try(attrs.ssl_policy, "")
    }
    enforce {
        condition     = core::contains(local.allowed_policies, local.ssl_policy)
        error_message = "ALB/NLB listener must use an approved SSL/TLS security policy."
    }
}
```
**Key difference:** `aws_lb_listener`/`aws_alb_listener` has `ssl_policy` as a direct attribute; `aws_elb` requires cross-resource checks via `aws_load_balancer_policy`. Always cover all 3 types for complete ELB enforcement.

### ❌ Mistake 21: Using core::try Default to Mask Missing Attributes
```hcl
# ❌ WRONG — resources where acl is NOT SET get defaulted to "private" and silently pass.
# This does NOT affect resources where acl IS set to "public-read" — those still fail correctly.
# The problem is resources with no acl configured are treated as compliant when they may not be.
resource_policy "aws_s3_bucket" "check" {
    locals {
        acl_value = core::try(attrs.acl, "private")  # missing acl → "private" → passes silently
        is_violation = core::contains(["public-read", "public-read-write"], local.acl_value)
    }
    enforce {
        condition = !local.is_violation
    }
}

# ✅ CORRECT — use filter to only evaluate resources that have the attribute set
resource_policy "aws_s3_bucket" "check" {
    filter = core::try(attrs.acl, null) != null  # skip resources with no acl configured

    locals {
        acl_value = attrs.acl  # safe after filter
        is_violation = core::contains(["public-read", "public-read-write"], local.acl_value)
    }
    enforce {
        condition = !local.is_violation
    }
}
```
**Fix — two cases:**
- *Attribute absent = resource out of scope* (resource doesn't configure the feature at all → skip it): use `filter = core::try(attrs.field, null) != null` to exclude those resources.
- *Attribute absent = AWS provider default applies* (e.g. `encrypted` absent → AWS defaults to `false`, `enabled` absent → AWS defaults to `true`): the resource **is** in scope and should be evaluated. Do **not** filter on null — use `core::try(attrs.field, <aws_default>)` in the `condition` so the effective default is checked. Filtering out these resources would silently pass non-compliant configurations.

> **Deciding which case applies:** check the Terraform provider documentation for the attribute. If it says "Default: `false`" or "Default: `true`", the absence carries a meaningful value → use `core::try` with the provider default in condition. If the attribute is truly optional with no provider default (its absence means "this block is not configured"), use `filter` to exclude it.

### ❌ Mistake 22: Using expect_failure on data source blocks
```hcl
# ❌ WRONG — tfpolicy test does not support expect_failure on data blocks
data "aws_iam_policy_document" "test" {
    expect_failure = true  # ERROR: unsupported argument
    attrs = { ... }
}

# ✅ CORRECT — expect_failure is only valid on resource blocks
resource "aws_s3_bucket" "test_violation" {
    expect_failure = true
    attrs = { acl = "public-read" }
}
```
**Fix:** `expect_failure` is only supported on `resource` test blocks, not `data` blocks.

### ❌ Mistake 23: Assuming TFPolicy Cannot Check Integer Port Ranges
```hcl
# ❌ WRONG — Adds a false limitation and requires from_port == to_port,
# which incorrectly rejects valid port-range rules.
locals {
  # LIMITATION: TF Policy cannot dynamically iterate integer ranges.
  # This implementation requires from_port == to_port (single-port rule only).
  is_single_port  = local.from_port == local.to_port
  port_authorized = core::contains(local.authorized_ports, local.from_port)
  is_compliant    = local.is_single_port && local.port_authorized
}

# ❌ ALSO WRONG — core::range() with dynamic attrs.* values silently returns
# an empty list in the policytest framework (policytest limitation only).
# Do not use core::range() with dynamic port attributes.
locals {
  ports_in_range   = core::range(local.from_port, local.to_port + 1)  # empty in policytest!
  all_authorized   = core::alltrue([for p in local.ports_in_range : core::contains(local.authorized_ports, p)])
}

# ✅ CORRECT — count how many authorized ports fall inside [from_port, to_port].
# If the count equals the total number of ports in the range, all are authorized.
# Works with dynamic attrs.* values at both plan time and in policytest.
locals {
  authorized_ports     = [80, 443]   # or from input block
  from_port            = core::try(attrs.from_port, 0)
  to_port              = core::try(attrs.to_port, 0)
  authorized_in_range  = [for p in local.authorized_ports : p if p >= local.from_port && p <= local.to_port]
  all_ports_authorized = core::length(local.authorized_in_range) == (local.to_port - local.from_port + 1)
}
```
**Rule:** TFPolicy CAN check whether all ports within a dynamic integer range `[from_port, to_port]` are authorized. Never add a "cannot iterate integer ranges" limitation — it is false.

**Why the count approach works:**
- Filter `authorized_ports` to those within `[from_port, to_port]`
- If every port in the range is authorized, the filtered count equals `to_port - from_port + 1`
- No range iteration needed — avoids the `core::range()` + dynamic value policytest issue entirely
- Verified working with dynamic `attrs.from_port` / `attrs.to_port` values

**Caution with `core::range()`:** `core::range(start, end)` works correctly with hardcoded literals. With dynamic `attrs.*` integer values, it silently returns an empty list in the **policytest** framework (policytest limitation). Prefer the count approach for port-range policies to guarantee consistent behaviour in both tests and runtime.

---

### ❌ Mistake 24: Accessing Optional Nested Blocks Without Null Safety ("unknown condition" error)
```hcl
# ❌ WRONG — ebs_block_device is optional; absent on instances without EBS.
# If the block is missing, attrs.ebs_block_device[0] is null,
# local.ebs.encrypted is unknown, and condition = unknown throws:
#   Error: unknown condition
resource_policy "aws_instance" "ebs_encrypted" {
  locals {
    ebs          = attrs.ebs_block_device[0]     # ❌ null if block absent
    is_encrypted = local.ebs.encrypted           # ❌ unknown propagation
  }
  enforce {
    condition     = local.is_encrypted == true   # ❌ "unknown condition" ERROR
    error_message = "EBS block devices must be encrypted."
  }
}

# ❌ ALSO WRONG — Multiple optional nested blocks combined without null guards.
# If either block is absent, the condition evaluates to unknown.
resource_policy "aws_instance" "check" {
  locals {
    ebs_encrypted = attrs.ebs_block_device[0].encrypted        # ❌ crashes if absent
    nic_sg        = attrs.network_interface[0].security_groups  # ❌ crashes if absent
  }
  enforce {
    condition = local.ebs_encrypted == true && core::length(local.nic_sg) > 0
  }
}

# ✅ CORRECT — Use filter to scope to resources with the block,
# convert set to list, then use core::try for safe attribute access.
resource_policy "aws_instance" "ebs_encrypted" {
  # Only evaluate instances that have at least one EBS block device configured
  filter = core::try(attrs.ebs_block_device, null) != null && core::try(core::length(attrs.ebs_block_device), 0) > 0

  locals {
    ebs_devices   = [for d in attrs.ebs_block_device : d]  # set → list
    # Count devices that are NOT encrypted; if zero, all are encrypted
    unencrypted   = [for d in local.ebs_devices : d if !core::try(d.encrypted, false)]
    all_encrypted = core::length(local.unencrypted) == 0
  }

  enforce {
    condition     = local.all_encrypted
    error_message = "All EBS block devices on the instance must have encryption enabled."
  }
}

# ✅ CORRECT — Multiple optional nested blocks: guard each independently.
resource_policy "aws_instance" "check" {
  locals {
    ebs_raw       = core::try(attrs.ebs_block_device, null)
    has_ebs       = local.ebs_raw != null ? core::length(local.ebs_raw) > 0 : false
    ebs_devices   = local.has_ebs ? [for d in local.ebs_raw : d] : []
    # ✅ Use "no unencrypted devices" pattern — core::alltrue() does NOT exist
    unencrypted   = [for d in local.ebs_devices : d if core::try(d.encrypted, false) != true]
    all_encrypted = !local.has_ebs || core::length(local.unencrypted) == 0
  }

  enforce {
    condition     = local.all_encrypted
    error_message = "All EBS block devices must be encrypted."
  }
}
```
**Rule:** Optional nested blocks (those that may be absent on some resource instances) must always be guarded with `filter` or `core::try` before indexing. Accessing `attrs.block[0]` on an absent block propagates `null` through every dependent local, eventually reaching the `condition` expression as an unknown value — which tfpolicy cannot reduce to a boolean, causing `Error: unknown condition` at runtime. This error does **not** appear in `tfpolicy test` (mocked data always has the block present) — it only surfaces against real plans.

**Pattern summary:**
1. Add `filter = core::try(attrs.block, null) != null && core::try(core::length(attrs.block), 0) > 0` to skip resources without the block. The double-`core::try` form is safe in both real plan evaluation and policytest mocks that omit the attribute.
2. Convert the block set to a list: `[for item in attrs.block : item]`.
3. Use `core::try(item.attr, <safe_default>)` on individual attributes inside the loop.
4. When a block is truly optional and its absence means "compliant", use `!local.has_block || <check>` so resources without the block pass automatically.

---

### ❌ Mistake 25: `core::anytrue()` and `core::alltrue()` Do Not Exist

**CRITICAL:** `core::anytrue()` and `core::alltrue()` are **not available** in the tfpolicy runtime. Using them anywhere — including in `locals`, in `for...if` filter expressions, or in `enforce` conditions — will produce:

```
Error: Call to unknown function
There is no function named "anytrue" in namespace core::.
```

or

```
Error: Call to unknown function
There is no function named "alltrue" in namespace core::.
```

```hcl
# ❌ WRONG — core::alltrue() does NOT exist in tfpolicy runtime
locals {
  all_encrypted = core::alltrue([for d in local.devices : core::try(d.encrypted, false)])
}

# ❌ WRONG — core::anytrue() does NOT exist in tfpolicy runtime
locals {
  any_public = core::anytrue([for r in local.rules : r.cidr == "0.0.0.0/0"])
}

# ✅ CORRECT — use core::length() with list comprehension instead of core::alltrue()
locals {
  # "all encrypted" = no unencrypted devices exist
  unencrypted   = [for d in local.devices : d if !core::try(d.encrypted, false)]
  all_encrypted = core::length(local.unencrypted) == 0
}

# ✅ CORRECT — use core::length() instead of core::anytrue()
locals {
  # "any public" = at least one public rule exists
  public_rules = [for r in local.rules : r if r.cidr == "0.0.0.0/0"]
  any_public   = core::length(local.public_rules) > 0
}

# ✅ CORRECT — boolean conditions in for...if: use plain && / || operators
locals {
  bad_rules = [
    for rule in attrs.ingress : rule
    if (rule.protocol == "tcp" && rule.from_port == 22)  # ✅ plain boolean — safe
  ]

  wide_open_rules = [
    for rule in attrs.ingress : rule
    if (rule.cidr_blocks == ["0.0.0.0/0"] || rule.ipv6_cidr_blocks == ["::/0"])  # ✅ safe
  ]
}

# ✅ ALSO CORRECT — two-pass pattern for complex conditions
locals {
  ingress_with_flags = [
    for rule in attrs.ingress : {
      rule        = rule
      is_ssh_tcp  = rule.protocol == "tcp" && rule.from_port == 22
    }
  ]
  ssh_tcp_rules = [for r in local.ingress_with_flags : r.rule if r.is_ssh_tcp]  # ✅ safe
}
```

**Rule:** `core::anytrue()` and `core::alltrue()` do not exist. Replace them with `core::length()` patterns:
- Instead of `core::anytrue(list_of_bools)` → `core::length([for b in list_of_bools : b if b]) > 0`
- Instead of `core::alltrue(list_of_bools)` → `core::length([for b in list_of_bools : b if !b]) == 0`
- For filtering: use plain `&&` / `||` boolean operators in `for...if` clauses instead.

---

### ❌ Mistake 26: Assuming core::try() Returns the Default When an Attribute Is Explicitly null

```hcl
# ❌ WRONG — destination_ranges exists but is null; core::try() does NOT catch null values.
# core::try() only catches attribute-access errors (missing attributes / index-out-of-bounds).
# When the attribute is present but set to null, core::try() returns null — NOT the default [].
# Passing null to core::length(), core::contains(), or a for-loop then causes:
#   "Invalid value for "list" parameter: argument must not be null"
resource_policy "google_compute_firewall" "check" {
  locals {
    dest_ranges = core::try(attrs.destination_ranges, [])            # ❌ returns null, not []
    bad_ranges  = [for r in local.dest_ranges : r if r == "0.0.0.0/0"]  # ❌ crashes
  }
}

# ❌ ALSO WRONG — looks safe but crashes in `locals`! TFPolicy does NOT short-circuit `&&` in locals.
# Both sides of `&&` are always evaluated, so core::length(null) is called even when
# logging_raw is null, causing: "Invalid value for 'collection': argument must not be null"
resource_policy "google_storage_bucket" "check" {
  locals {
    logging_raw     = core::try(attrs.logging, null)
    logging_present = local.logging_raw != null && core::length(local.logging_raw) > 0  # ❌ crashes when null!
  }
}

# ✅ CORRECT — explicitly check for null after core::try(), then fall back to [].
resource_policy "google_compute_firewall" "check" {
  locals {
    dest_ranges_raw = core::try(attrs.destination_ranges, null)
    dest_ranges     = local.dest_ranges_raw != null ? local.dest_ranges_raw : []
    bad_ranges      = [for r in local.dest_ranges : r if r == "0.0.0.0/0"]
  }
}

# ✅ CORRECT — use ternary to guard core::length() call; ternary DOES short-circuit.
resource_policy "google_storage_bucket" "check" {
  locals {
    logging_raw      = core::try(attrs.logging, null)
    logging_not_null = local.logging_raw != null
    logging_length   = local.logging_not_null ? core::length(local.logging_raw) : 0  # ✅ ternary safe
    logging_present  = local.logging_not_null && local.logging_length > 0
  }
}

# ✅ ALSO CORRECT — inline ternary in one line (equivalent to above).
locals {
  dest_ranges = core::try(attrs.destination_ranges, null) != null ? attrs.destination_ranges : []
}
```

**Rule:** `core::try(expr, default)` catches **attribute-access errors** (e.g. missing attribute, index out of range) and returns `default` in that case. It does **NOT** substitute `default` when the attribute exists but its value is `null`. Always use the two-step pattern:
1. `core::try(attrs.field, null)` — safe access; returns `null` on missing attribute OR on null value
2. `!= null ? attrs.field : <safe_default>` — explicit null guard before passing to list functions

**CRITICAL: `&&` does NOT short-circuit in TFPolicy `locals` blocks, `condition =` expressions inside `enforce {}` blocks, or `for...if` predicates.** Even if the left side `local.var != null` is false, the right side (e.g. `core::length(local.var)` or `core::contains([...], local.var)`) will still be evaluated and crash. Always use the ternary operator (`condition ? value_if_true : value_if_false`) to conditionally call functions on potentially-null values.

```hcl
# ❌ WRONG — condition = also does NOT short-circuit; crashes when local.X is null
enforce {
  condition = local.X != null && core::contains(["a", "b"], local.X)  # ❌ crashes!
}

# ✅ CORRECT — use ternary inside the locals block, then reference in condition
locals {
  is_allowed = local.X != null ? core::contains(["a", "b"], local.X) : false
}
enforce {
  condition = local.is_allowed
}

# ❌ WRONG — for...if predicate also does NOT short-circuit; crashes when r.field is absent
violating = [
  for r in local.rules : r
  if core::try(r.field, null) != null && core::contains(["a", "b"], r.field)  # ❌ crashes!
]

# ✅ CORRECT — use ternary in for...if predicate; also wrap the second access with core::try
violating = [
  for r in local.rules : r
  if (core::try(r.field, null) != null ? core::contains(["a", "b"], core::try(r.field, "")) : false)
]
```

(Note: `&&` in `filter =` **does** short-circuit for null values in real plan evaluation — optional absent attributes are treated as `null` in the Terraform resource schema, so `local.raw != null && core::length(local.raw) > 0` (where `local.raw = core::try(attrs.field, null)`) is safe. However, **in policytest mocks**, if the mock completely omits an optional block attribute (rather than including it as `null`), the `attrs` object is a strict HCL literal that truly lacks that attribute. In that case, `core::try(attrs.field, null) != null && core::length(attrs.field) > 0` fails: `core::try` catches the error on the first access and returns null, but the second bare `attrs.field` still throws "does not have attribute named 'field'" because `&&` does not protect against the independent evaluation error. **Safe patterns that work in both real plans and policytest:**
- Pre-capture: `local.raw = core::try(attrs.field, null)` then `filter = local.raw != null && core::length(local.raw) > 0`
- Double-wrap: `filter = core::try(attrs.field, null) != null && core::try(core::length(attrs.field), 0) > 0`)

**String interpolation + null:** `core::try()` catches **errors** (missing attributes, index out of range), NOT null values. `${core::try(local.X, "default")}` returns `null` — not `"default"` — when `local.X` is null, causing: `"The expression result is null. Cannot include a null value in a string template."`. Fix: use ternary in the string template: `${local.X != null ? local.X : "default"}`.

**Affected functions:** `core::length()`, `core::contains()`, `core::join()`, `for` loops, and any function that requires a non-null list/map argument will crash if passed `null`. Apply the pattern wherever a list/set attribute may be absent **or** explicitly null in the provider schema.

---

### ❌ Mistake 27: Duplicating Common Values Across Multiple Policy Blocks

```hcl
# ❌ WRONG — The same allowlist is copied into every resource_policy block.
# Changing the list requires editing multiple blocks, which is error-prone.
resource_policy "azurerm_linux_virtual_machine" "allowed_sizes" {
  locals {
    allowed_sizes = ["Standard_D2s_v3", "Standard_D4s_v3"]
  }
  enforce {
    condition     = core::contains(local.allowed_sizes, core::try(attrs.size, ""))
    error_message = "VM size is not in the allowed list."
  }
}

resource_policy "azurerm_windows_virtual_machine" "allowed_sizes" {
  locals {
    allowed_sizes = ["Standard_D2s_v3", "Standard_D4s_v3"]  # ❌ duplicated value
  }
  enforce {
    condition     = core::contains(local.allowed_sizes, core::try(attrs.size, ""))
    error_message = "VM size is not in the allowed list."
  }
}

# ✅ CORRECT — Extract the shared value to a top-level locals block.
# All policy blocks reference it via local.<name>. One change updates every policy.
locals {
  allowed_sizes = ["Standard_D2s_v3", "Standard_D4s_v3"]
}

resource_policy "azurerm_linux_virtual_machine" "allowed_sizes" {
  enforce {
    condition     = core::contains(local.allowed_sizes, core::try(attrs.size, ""))
    error_message = "VM size is not in the allowed list."
  }
}

resource_policy "azurerm_windows_virtual_machine" "allowed_sizes" {
  enforce {
    condition     = core::contains(local.allowed_sizes, core::try(attrs.size, ""))
    error_message = "VM size is not in the allowed list."
  }
}
```

**Rule:** When two or more `resource_policy`, `module_policy`, or `provider_policy` blocks share a local variable that holds the **same constant value** (e.g. an allowlist, blocklist, threshold, or configuration string), extract it to a **top-level `locals {}` block** and reference it as `local.<name>` in each policy. This follows the DRY principle — the value has a single source of truth.

**When to extract:**
- Any literal list, map, string, or number used identically in two or more policy blocks
- Computed values derived from the same constant inputs across multiple blocks (e.g. a formatted string built from shared constants)

**When NOT to extract:**
- A value specific to exactly one resource type with no meaning outside that block
- Any value that depends on `attrs.*` — those are resource-scoped and must stay inside the policy block (top-level `locals` cannot access `attrs`)

### ❌ Mistake 28: String Concatenation with `+` Is Not Supported

**Error:** `Invalid operand — Unsuitable value for left operand: a number is required.`

```hcl
# ❌ WRONG — The + operator does not concatenate strings in tfpolicy
locals {
  pattern = "^com\\.amazonaws\\..+\\." + input.service_name  # ❌ runtime error
}

# ✅ CORRECT — Use ${ } interpolation for dynamic string building
locals {
  pattern        = "^com\\.amazonaws\\..+\\.${input.service_name}"
  error_msg      = "Service name must match pattern com.amazonaws.<region>.${input.service_name}."
}

# ✅ ALSO CORRECT — Avoid dynamic regex patterns entirely; use core::contains_substring
locals {
  service_ok = core::startswith(local.svc, "com.amazonaws.") &&
               core::contains_substring(local.svc, input.service_name)
}
```

**Rule:** String concatenation using `+` is **not supported** in tfpolicy HCL. Use `"${expr}"` interpolation syntax for all dynamic string construction.

---

### ❌ Mistake 29: `enforcement_level` Defined Multiple Times

**Error:** `Attribute redefined — The argument "enforcement_level" was already set at line X.`

```hcl
# ❌ WRONG — enforcement_level appears twice, once before each enforce block
resource_policy "aws_vpc_endpoint" "check" {
  locals { ... }

  enforcement_level = "advisory"
  enforce {
    condition     = local.is_interface
    error_message = "..."
  }

  enforcement_level = "advisory"   # ❌ ERROR: already defined above
  enforce {
    condition     = local.service_matches
    error_message = "..."
  }
}

# ✅ CORRECT — enforcement_level appears exactly once for the whole block
resource_policy "aws_vpc_endpoint" "check" {
  locals { ... }

  enforcement_level = "advisory"   # ✅ declared once

  enforce {
    condition     = local.is_interface
    error_message = "..."
  }

  enforce {
    condition     = local.service_matches
    error_message = "..."
  }
}
```

**Rule:** `enforcement_level` is an attribute of the policy block itself, not of each `enforce` block. Declare it **exactly once** per `resource_policy`/`module_policy`/`provider_policy` block, at the same level as `locals` and `enforce`. Multiple `enforce` blocks within one policy block all share the same `enforcement_level`.

---

### ❌ Mistake 30: Referencing `local.*` Inside a For-Object Comprehension

**Error:** `Undefined Reference — The reference "local.origin_domain" is not defined.`

```hcl
# ❌ WRONG — keys defined inside the for-object literal are NOT in local scope
locals {
  origin_checks = [
    for origin in local.origins : {
      origin_domain  = core::try(origin.domain_name, "")
      is_s3_origin   = core::contains_substring(local.origin_domain, ".s3.")  # ❌ local.origin_domain is unknown here
      is_compliant   = !local.is_s3_origin || local.has_oac_id                # ❌ local.is_s3_origin is unknown here
    }
  ]
}

# ✅ CORRECT — repeat the expression inline; each key is independent
locals {
  origin_checks = [
    for origin in local.origins : {
      origin_domain  = core::try(origin.domain_name, "")
      is_s3_origin   = core::contains_substring(core::try(origin.domain_name, ""), ".s3.")
      is_compliant   = !core::contains_substring(core::try(origin.domain_name, ""), ".s3.") ||
                       (core::try(origin.oac_id, null) != null && core::try(origin.oac_id, "") != "")
    }
  ]
}

# ✅ ALSO CORRECT — two-pass pattern: compute properties first, then combine
locals {
  origins_with_props = [
    for origin in local.origins : {
      domain       = core::try(origin.domain_name, "")
      has_oac      = core::try(origin.origin_access_control_id, null) != null
    }
  ]
  # Now the second pass can reference the object's own keys by iterating:
  origin_checks = [
    for o in local.origins_with_props : {
      is_s3        = core::contains_substring(o.domain, ".s3.")
      is_compliant = !core::contains_substring(o.domain, ".s3.") || o.has_oac
    }
  ]
}
```

**Rule:** Inside a `for ... : { ... }` object comprehension, keys defined within the same object literal **cannot** be referenced via `local.key_name`. The `local.*` scope only contains entries from the surrounding `locals {}` block. Either:
1. Inline the expression wherever needed (repeat it), or
2. Use a two-pass approach: compute intermediate values in one for-comprehension, then reference them by the iteration variable in a second for-comprehension.

---

### ❌ Mistake 31: Ternary Branches with Inconsistent Object Types

**Error:** `The true and false result expressions must have consistent types. The 'true' value includes object attribute "X", which is absent in the 'false' value.`

```hcl
# ❌ WRONG — the true branch produces an object with "Statement" key,
# but the false branch is an empty object {} without that key
locals {
  policy_doc = local.appears_inline ? core::try(core::jsondecode(local.policy_value), {}) : {}
  statements = core::try(local.policy_doc.Statement, [])
}

# ✅ CORRECT — both branches must produce objects with the SAME set of keys
locals {
  policy_doc = local.appears_inline
    ? core::try(core::jsondecode(local.policy_value), { Statement = [] })
    : { Statement = [] }
  statements = core::try(local.policy_doc.Statement, [])
}

# ✅ ALSO CORRECT — avoid the ternary entirely; use core::try for the safe path
locals {
  # Always parse; core::try returns empty-statement fallback if decoding fails or is not applicable
  policy_doc = core::try(core::jsondecode(local.policy_value), { Statement = [] })
  statements = core::try(local.policy_doc.Statement, [])
}
```

**Rule:** In tfpolicy HCL, both branches of `cond ? a : b` must return values of **identical type and shape**. This is especially important for objects: if the true branch returns an object with key `K`, the false branch must also include key `K` with a compatible type. Mismatched object shapes cause a compile-time type error. Use a consistent fallback object (e.g. `{ Statement = [] }`) or avoid the ternary by using `core::try` directly on the full expression.

---

### ❌ Mistake 32: `inputs` Block Inside a Resource Test Block

**Error:** `An argument named "inputs" is not expected here. Did you mean to define a block of type "inputs"?`

```hcl
# ❌ WRONG — inputs block placed INSIDE a resource test block
resource "aws_db_instance" "pass_instance" {
  inputs = {            # ❌ inputs is not valid inside resource {}
    resource_type = "aws_db_instance"
    source_type   = "db-instance"
  }
  attrs = { ... }
}

# ✅ CORRECT — inputs is a TOP-LEVEL block in the policytest file,
# and it applies to ALL test cases in that file
policytest {
  targets = ["my-policy.policy.hcl"]
}

inputs {                # ✅ top-level block, applies to all resources below
  resource_type = "aws_db_instance"
  source_type   = "db-instance"
}

resource "aws_db_instance" "pass_instance" {
  attrs = { ... }
}
```

**Rule:** The `inputs {}` block is a **top-level** construct in a `.policytest.hcl` file. It overrides `input` block defaults for every test case in that file. It is **not** an attribute or a nested block inside `resource`, `data`, or `module` test blocks. If you need different input values for different test resources, put them in **separate `.policytest.hcl` files**, each with its own top-level `inputs {}` block.

---

### ❌ Mistake 33: `data_policy` Block Type Does Not Exist

**Error:** `Blocks of type "data_policy" are not expected here.`

```hcl
# ❌ WRONG — data_policy is NOT a valid policy block type
data_policy "aws_iam_policy_document" "permissive_actions_denied" {
  enforce {
    condition     = local.no_star_actions
    error_message = "IAM policy documents must not use wildcard actions."
  }
}

# ✅ CORRECT — use resource_policy for actual Terraform resources
# To check IAM policy content, parse the inline_policy or the policy document
# that is attached to an actual resource (aws_iam_policy, aws_iam_role, etc.)
resource_policy "aws_iam_policy" "permissive_actions_denied" {
  locals {
    policy_doc = core::try(core::jsondecode(core::try(attrs.policy, "{}")), { Statement = [] })
    statements = core::try(local.policy_doc.Statement, [])
    star_stmts = [for s in local.statements : s if core::contains(core::try(s.Action, []), "*")]
    no_star_actions = core::length(local.star_stmts) == 0
  }
  enforce {
    condition     = local.no_star_actions
    error_message = "IAM managed policies must not use wildcard (*) actions."
  }
}
```

**Rule:** The only valid top-level policy block types are:
- `resource_policy "<resource_type>" "<name>"` — evaluates Terraform-managed resources
- `module_policy "<source_path>" "<name>"` — evaluates Terraform modules
- `provider_policy "<provider_type>" "<name>"` — evaluates provider configuration

`data_policy` **does not exist**. Data sources (e.g. `aws_iam_policy_document`, `aws_caller_identity`) are not evaluated via policy blocks. To enforce content constraints on IAM documents, write a `resource_policy` that targets the resource (`aws_iam_policy`, `aws_iam_role`, etc.) and parses the policy attribute using `core::jsondecode`.

---

### ❌ Mistake 34: Duplicate Local Variable or Policy Block Definitions

**Error (duplicate local):** `The local expression "..." is already defined. Each local expression must have a unique name.`
**Error (duplicate policy block):** `The resource block "..." is already defined. Each resource_policy block must have a unique resource type + name combination.`

```hcl
# ❌ WRONG — same local variable name defined twice in the same locals {} block
resource_policy "aws_vpc" "flow_logging_enabled" {
  locals {
    flow_logs      = core::getresources("aws_flow_log", {})
    matching_logs  = [for fl in local.flow_logs : fl if fl.vpc_id == attrs.id]
    flow_logs      = core::try(attrs.enable_dns_support, false)  # ❌ duplicate name!
  }
  enforce { ... }
}

# ❌ WRONG — same resource_policy block defined twice (same type + name)
resource_policy "aws_vpc" "flow_logging_enabled" {
  locals { ... }
  enforce { condition = ... }
}

resource_policy "aws_vpc" "flow_logging_enabled" {  # ❌ duplicate!
  locals { ... }
  enforce { condition = ... }
}

# ✅ CORRECT — unique local names + all checks in a single resource_policy block
# Fixes both mistakes above:
#   1. Each local has a distinct name (flow_logs vs dns_support) — no duplicate-name error.
#   2. Both checks live in one "aws_vpc" / "flow_logging_enabled" block with two enforce
#      blocks — no duplicate-policy-block error.
# NOTE: aws_flow_log.vpc_id links to the parent VPC — filter inline by attrs.id; never use
# a top-level core::getresources("aws_flow_log", {}) + HCL for-loop filter (Mistake 13).
resource_policy "aws_vpc" "flow_logging_enabled" {
  locals {
    flow_logs    = core::getresources("aws_flow_log", { vpc_id = attrs.id })
    dns_support  = core::try(attrs.enable_dns_support, false)  # unique name — no conflict
    has_flow_log = core::length(local.flow_logs) > 0
  }
  enforce {
    condition     = local.has_flow_log
    error_message = "VPC must have at least one flow log configured."
  }
  enforce {
    condition     = local.dns_support
    error_message = "VPC must have DNS support enabled."
  }
}
```

**Rules:**
1. Within a single `locals {}` block, every local variable name must be **unique**. If you copy-paste or refactor, check for accidental name reuse.
2. Within a single policy file, every `resource_policy "type" "name"` combination must be **unique**. To add multiple checks on the same resource type, either add more `enforce` blocks to the existing policy block, or use a different `name` label (e.g. `"flow_logging_enabled"` vs `"flow_logging_destination"`).

---

### ❌ Mistake 35: Using `||` Chains for Enum/Allowlist Checks Instead of `core::contains()`

**Problem:** When checking if an attribute value belongs to a set of allowed values, chaining `||` comparisons is verbose, harder to maintain, and doesn't match idiomatic TF Policy style.

```hcl
# ❌ WRONG — verbose chain, hard to maintain
locals {
  ssl_mode   = core::try(attrs.ssl_mode, null)
  is_valid   = local.ssl_mode == "require" || local.ssl_mode == "verify-ca" || local.ssl_mode == "verify-full"
}

# ✅ CORRECT — core::contains() with a named list local
locals {
  ssl_mode     = core::try(attrs.ssl_mode, "none")
  valid_modes  = ["require", "verify-ca", "verify-full"]
  is_valid     = core::contains(local.valid_modes, local.ssl_mode)
}
enforce {
  condition     = local.is_valid
  error_message = "Attribute 'ssl_mode' must be one of: require, verify-ca, verify-full."
}
```

**Rules:**
1. Whenever a Sentinel policy uses `value in [list]` or `value in set([...])`, always translate to `core::contains(allowed_list, value)` in TF Policy.
2. Store the allowed list in a named local variable (e.g., `valid_modes`) for readability.
3. **`core::contains(list, null)` is safe** — it returns `false` when value is `null`. No extra null guard is needed before calling `core::contains()`.
4. Use a non-null default in `core::try()` (e.g., `core::try(attrs.ssl_mode, "none")`) so `null` attribute values map to a clearly non-compliant default.

---

### ❌ Mistake 36: Using Multiple `core::startswith()` Calls for Version Range Matching Instead of `core::regex()`

**Problem:** When a Sentinel policy checks a version string with `>=` or `<` (e.g., `engine_version < "6.0"`), HCL does not support string comparison operators. Using multiple `core::startswith()` calls for each major version is verbose and brittle — it will break if a new major version prefix appears (e.g., `"0.x"` or `"10.x"`).

```hcl
# ❌ WRONG — 5 separate startswith calls for versions 1.x through 5.x
locals {
  is_version_lt_6 = (
    core::startswith(local.engine_version, "1.") ||
    core::startswith(local.engine_version, "2.") ||
    core::startswith(local.engine_version, "3.") ||
    core::startswith(local.engine_version, "4.") ||
    core::startswith(local.engine_version, "5.")
  )
}

# ✅ CORRECT — core::regex() matches all versions with major version 1–5 in one expression
# Use in filter to skip resources where engine_version is >= 6.0 or unset
filter = core::try(attrs.engine_version, "") != "" &&
         core::try(core::regex("^[1-5]\\.", core::try(attrs.engine_version, "")), null) != null

locals {
  auth_token = core::try(attrs.auth_token, "")
}
enforce {
  condition     = local.auth_token != null && local.auth_token != ""
  error_message = "Attribute 'auth_token' must be set when 'engine_version' < 6.0."
}
```

**Rules:**
1. When a Sentinel policy compares a version string with `<` or `>=`, identify the version boundary and translate to `core::regex()`.
2. **Always wrap in `core::try(..., null)`** — `core::regex()` returns `null` on no match (not `false`), and calling it on a null input causes an error.
3. Common patterns:
   - Versions `< 6.0` (major 1–5): `core::regex("^[1-5]\\.", version)`
   - Versions `>= 2.x` and `< 10.x`: `core::regex("^[2-9]\\.", version)`
   - Patch versions like `"5.0.6"` or `"6.x"` are handled correctly by the major-version prefix pattern.
4. **Prefer `core::semverconstraint()`** if the version string is a proper SemVer (e.g., `"6.2.0"`); use `core::regex()` only for non-standard version strings (e.g., `"6.x"`, `"5.0.6"` from AWS ElastiCache engine versions).
5. **Never use `>`, `<`, `>=`, `<=` on strings in HCL** — HCL string comparison is lexicographic and unreliable for version ordering.

---

### ❌ Mistake 37: Anchoring `resource_policy` on an Optional Companion Resource Instead of the Parent

**Problem:** When a Sentinel policy checks an S3 companion resource (e.g., `aws_s3_bucket_public_access_block`), it is tempting to write `resource_policy "aws_s3_bucket_public_access_block"`. However, this companion resource is **optional** — a bucket can exist in a Terraform plan with no `aws_s3_bucket_public_access_block` at all. Anchoring on the companion means **buckets with no companion resource silently pass the policy**.

```hcl
# ❌ WRONG — anchored on the companion type; buckets with no public_access_block resource silently pass
resource_policy "aws_s3_bucket_public_access_block" "block_public_access" {
  locals {
    block_public_acls = core::try(attrs.block_public_acls, false)
  }
  enforce {
    condition     = local.block_public_acls == true
    error_message = "S3 bucket must block public ACLs."
  }
}

# ✅ CORRECT — anchored on the parent; a missing companion resource = false → violation is caught
# NOTE: apply-time cross-resource reference; resolves correctly at apply time.
resource_policy "aws_s3_bucket" "block_public_access" {
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
    error_message = "S3 bucket '${attrs.bucket}' must have all four public access block settings enabled."
  }
}
```

**Rules:**
1. Always ask: "Can the parent (`aws_s3_bucket`) exist in a Terraform plan WITHOUT this companion?" If YES → anchor on the **parent**, not the companion.
2. The following S3 companions MUST always be checked via `resource_policy "aws_s3_bucket"`:
   - `aws_s3_bucket_public_access_block` — lookup: `{ bucket = attrs.id }` (apply-time inline)
   - `aws_s3_bucket_acl` — use parent anchor when enforcing that every bucket has a compliant ACL; use direct `resource_policy "aws_s3_bucket_acl"` only when checking ACL's own attribute values on ACLs that already exist
   - `aws_s3_bucket_logging` — lookup: `{ bucket = attrs.id }` (apply-time inline)
   - `aws_s3_bucket_server_side_encryption_configuration` — lookup: `{ bucket = attrs.id }` (apply-time inline)
   - `aws_s3_bucket_versioning` — plan-time: top-level `core::getresources`, filter by `v.bucket == attrs.bucket`
3. **The Sentinel source pattern does not matter.** Even if the original Sentinel iterates over companion resource types, the TFPolicy MUST anchor on the parent.
4. **Requirement translation:** If requirement.txt says "every `aws_s3_bucket_public_access_block` must have X = true", reframe it as "every `aws_s3_bucket` must have a companion `aws_s3_bucket_public_access_block` with X = true; a missing companion is a violation." This reframing is mandatory before writing HCL.
5. Use apply-time inline `core::getresources("companion", { bucket = attrs.id })` inside the `resource_policy "aws_s3_bucket"` block.

---

### ❌ Mistake 38: Checking Only `aws_iam_policy` for IAM Content Rules — Missing Inline Policy Resource Types

**Symptom:** Policy only checks `aws_iam_policy` for privilege conditions (e.g. "no admin `*:*`") but misses inline policies attached directly to roles, users, and groups.

```hcl
# ❌ INCOMPLETE — only catches standalone managed policies
resource_policy "aws_iam_policy" "no_admin_privileges" {
  locals {
    statements    = core::try(core::jsondecode(core::try(attrs.policy, "{}")).Statement, [])
    admin_stmts   = [for s in local.statements : s if ...]
  }
  enforce { condition = core::length(local.admin_stmts) == 0 ... }
}
# Missing: aws_iam_role_policy, aws_iam_user_policy, aws_iam_group_policy

# ✅ CORRECT — cover all 4 inline policy resource types; each has attrs.policy (JSON string)
# Each resource_policy block is fully self-contained — attrs is only available inside a
# resource_policy, module_policy, or provider_policy block, not in top-level locals.

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

**Rule:** Any IAM content enforcement (wildcard actions, admin privileges, etc.) MUST cover all 4 inline policy resource types:
| Resource type | When it's used | `policy` attribute |
|---|---|---|
| `aws_iam_policy` | Standalone managed policy | JSON string |
| `aws_iam_role_policy` | Inline policy attached to a role | JSON string |
| `aws_iam_user_policy` | Inline policy attached to a user | JSON string |
| `aws_iam_group_policy` | Inline policy attached to a group | JSON string |

All 4 have the same `attrs.policy` JSON string — use `core::jsondecode(core::try(attrs.policy, "{}"))` on each.

**Note on `aws_iam_policy_document`:** This is a Terraform DATA SOURCE. `data_policy` does not exist in tfpolicy (see Mistake 31). Do NOT write a `resource_policy "aws_iam_policy_document"` to enforce IAM content — use the 4 managed/inline resource types above instead.

---

### ❌ Mistake 39: Repeating `core::try()` Calls in Complex For-Loop Predicates

**Problem:** When a `for...if` list comprehension has a complex filter predicate that references the same attribute multiple times via `core::try()` (e.g. `core::try(rule.from_port, 0)`, `core::try(rule.to_port, 0)`, `core::try(rule.protocol, "")` each appearing 3–5 times), the expression becomes an unreadable single line that is hard to maintain and verify.

```hcl
# ❌ WRONG — core::try(rule.from_port, 0) appears 4 times; core::try(rule.to_port, 0) appears
# 4 times; core::try(rule.protocol, "") appears 5 times in one predicate.
violating_rules = [for rule in local.ingress_rules : rule if (core::contains(core::try(rule.cidr_blocks, []), "0.0.0.0/0") || core::contains(core::try(rule.ipv6_cidr_blocks, []), "::/0")) && (core::try(rule.protocol, "") == "all" || core::try(rule.protocol, "") == "-1" || (core::try(rule.protocol, "") == "tcp" && core::length([for p in input.authorized_tcp_ports : p if p >= core::try(rule.from_port, 0) && p <= core::try(rule.to_port, 0)]) != (core::try(rule.to_port, 0) - core::try(rule.from_port, 0) + 1)) || (core::try(rule.protocol, "") == "udp" && core::length([for p in input.authorized_udp_ports : p if p >= core::try(rule.from_port, 0) && p <= core::try(rule.to_port, 0)]) != (core::try(rule.to_port, 0) - core::try(rule.from_port, 0) + 1)))]
```

```hcl
# ✅ CORRECT — two-phase approach: map items to enriched objects (extract sub-expressions
# into named fields), then filter on those named fields.
locals {
  enriched_rules = [for rule in local.ingress_rules : {
    rule          = rule
    has_public_ip = core::contains(core::try(rule.cidr_blocks, []), "0.0.0.0/0") || core::contains(core::try(rule.ipv6_cidr_blocks, []), "::/0")
    protocol      = core::try(rule.protocol, "")
    from_port     = core::try(rule.from_port, 0)
    to_port       = core::try(rule.to_port, 0)
  }]

  violating_rules = [for r in local.enriched_rules : r.rule if r.has_public_ip && (r.protocol == "all" || r.protocol == "-1" || (r.protocol != "tcp" && r.protocol != "udp") || (r.protocol == "tcp" && core::length([for p in input.authorized_tcp_ports : p if p >= r.from_port && p <= r.to_port]) != (r.to_port - r.from_port + 1)) || (r.protocol == "udp" && core::length([for p in input.authorized_udp_ports : p if p >= r.from_port && p <= r.to_port]) != (r.to_port - r.from_port + 1)))]
}
```

**When to use the two-phase pattern:**
1. A single field is referenced 3 or more times in the predicate via `core::try()` (each call is a repeated sub-expression).
2. The predicate contains a nested for-loop that re-accesses the same outer-loop variable.
3. The resulting predicate is too long to comfortably fit on a single line (required by Mistake 7).

**Benefits:**
- Each `core::try()` call is written exactly once — no repeated accesses.
- Named fields (`r.from_port`, `r.protocol`) are self-documenting.
- The filter predicate is shorter and the structure matches the original Sentinel logic.
- Easier to debug: inspect `local.enriched_rules` directly to see computed intermediate values.

**Rule summary:** When a for-loop predicate repeats the same `core::try(rule.field, default)` call more than twice, split into two steps: (1) map items to enriched objects with computed fields, (2) filter on those fields. See also the "Multi-Stage Filtering for Readability" best practice below.

---

## Best Practices

### ✅ Provider Schema Awareness
**Rule:** tfpolicy exposes raw provider schemas without transformation

**Implication:** You need to understand the actual provider schema:
- Sets remain sets (not converted to lists)
- Know whether attributes are optional
- Understand nested object structures

**Example:**
```hcl
# attrs.ingress is a SET (per AWS provider), but iteration works the same
for rule in attrs.ingress : rule.from_port
```

**Tip:** Use `terraform console` or provider docs to inspect schemas

---

### ✅ Filter Pattern: Null + Length Check
**Rule:** Always check both null and length for collection filters; wrap both accesses when the attribute may be absent from policytest mocks

```hcl
# ✅ Best practice — safe in real plans AND policytest mocks that omit the attribute
filter = core::try(attrs.ingress, null) != null && core::try(core::length(attrs.ingress), 0) > 0

# ✅ Also correct — pre-capture ensures the second operand references a local (never absent)
# local.ingress_raw = core::try(attrs.ingress, null)
# filter = local.ingress_raw != null && core::length(local.ingress_raw) > 0

# ⚠️ Works but less efficient (doesn't filter empty collections)
filter = core::try(attrs.ingress, null) != null

# ❌ RISKY — second attrs.ingress access is not wrapped; fails in policytest mocks
# that completely omit the attribute (where attrs is a strict HCL object without the key)
filter = core::try(attrs.ingress, null) != null && core::length(attrs.ingress) > 0
```

**Why:** In real Terraform plan evaluation, absent optional attributes are represented as `null` in the resource schema, and filter `&&` short-circuits after `null != null = false`. In policytest mocks however, if the mock omits an attribute, `attrs` is a strict HCL literal — the attribute genuinely does not exist, and the bare second access throws an error that `&&` does not protect against. Always wrap the second access with `core::try`.

---

### ✅ Multi-Stage Filtering for Readability
**Rule:** Break complex logic into multiple local variables

```hcl
# ✅ Good: Multi-stage filtering
locals {
    # Stage 1: Filter to relevant items
    ssh_rules = [
        for rule in attrs.ingress :
        rule if rule.from_port <= 22 && rule.to_port >= 22
    ]

    # Stage 2: Filter to violations
    public_ssh_rules = [
        for rule in local.ssh_rules :
        rule if core::contains(core::try(rule.cidr_blocks, []), "0.0.0.0/0")
    ]

    # Stage 3: Check compliance
    is_compliant = core::length(local.public_ssh_rules) == 0
}

```

**Benefits:**
- More readable and maintainable
- Easier to debug (inspect intermediate lists)
- Can reuse filtered lists for multiple checks
- Better error messages possible

---

### ✅ Multiple Focused Policies
**Rule:** Use multiple `enforce` blocks within a single `resource_policy` block to separate concerns — do NOT split checks on the same resource type into multiple `resource_policy` blocks (SKILL.md Output Structure Rule 1).

```hcl
# ✅ Correct — separate concerns via multiple enforce blocks in one block
resource_policy "aws_security_group" "security_group_checks" {
    enforce {
        condition     = !local.has_public_ssh
        error_message = "Security group must not allow public SSH ingress."
    }
    enforce {
        condition     = !local.has_public_rdp
        error_message = "Security group must not allow public RDP ingress."
    }
    enforce {
        condition     = local.has_required_tags
        error_message = "Security group must have required tags."
    }
}

# ❌ Wrong — same resource type split across multiple resource_policy blocks
resource_policy "aws_security_group" "ingress_check" {
    # Check ingress rules only
}
resource_policy "aws_security_group" "egress_check" {
    # Check egress rules only
}
```

**Benefits:**
- All checks on the same resource type are co-located and consistent
- Each `enforce` block reports independently — user sees all failures at once
- Easier to maintain and test

---

---

### ✅ All Errors Shown Pattern
**Rule:** Multiple enforce blocks show all failures, not just first

```hcl
resource_policy "aws_security_group" "comprehensive_check" {
    enforce {
        condition = !local.has_public_ssh
        error_message = "SSH violation: ..."
    }

    enforce {
        condition = !local.has_public_rdp
        error_message = "RDP violation: ..."
    }

    enforce {
        condition = local.has_description
        error_message = "Description required: ..."
    }
}
```

**Behavior:** User sees **all** failing messages in encounter order

**Benefit:** Comprehensive feedback - users can fix all issues at once

---

## Verified Capabilities by Policy Type

### resource_policy
- ✅ Full `attrs.*` access, nested attributes via dot notation
- ✅ `meta.provider_type`, `meta.tfe_workspace`
- ❌ **`meta.address` is UNDEFINED in real plan evaluation** — do not use in `filter`, `locals`, `condition`, or `error_message`; it causes `Error: Unsupported attribute` at runtime. Note: `tfpolicy test` will NOT catch this error — only `terraform plan --policies=` will.
- ✅ `filter`, `locals`, multiple `enforce` blocks

### module_policy
- ✅ `meta.source`, `meta.version`, `meta.address`
- ✅ `filter`, `locals`, multiple `enforce` blocks
- ❌ `attrs.*` (inputs) - work in progress
- ❌ `meta.tfe_workspace` - resource_policy only

### provider_policy
- ✅ Full `attrs.*` (config), `meta.alias`, `meta.version`, `meta.source`
- ✅ `filter`, `locals`, multiple `enforce` blocks
- ❌ `meta.tfe_workspace` - resource_policy only

**⚠️ `meta.version` is the resolved version (e.g. `"6.50.0"`), not the constraint string (e.g. `">= 4.0"`).** Use `core::semverconstraint(meta.version, "~> 5.0")` to enforce an approved range. Test mocks should use realistic resolved version numbers, not constraint strings. Verified on tfpolicy 0.0.2-beta20260513.

**Targeting Pattern:**
| Policy Type | First Label | Example |
|-------------|-------------|---------|
| resource_policy | Resource TYPE | `"aws_instance"` |
| module_policy | Full SOURCE path | `"app.terraform.io/myorg/vpc/aws"` |
| provider_policy | Provider TYPE | `"aws"` (not `"hashicorp/aws"`) |

---

---

## Testing

See the [tfpolicy-test skill](../skills/tfpolicy-test/SKILL.md) for comprehensive testing guidance.

### Module mock syntax (two labels required)

`module_policy` test mocks take **two labels** — source and a mock name — matching the policy block's own two-label signature:

```hcl
# ✅ CORRECT — two labels: source pattern, then mock name
module "registry.terraform.io/hashicorp/consul/aws" "approved" {
  meta = {
    source  = "registry.terraform.io/hashicorp/consul/aws"
    version = "0.1.0"
    address = "module.consul"
  }
}

# ❌ WRONG — one label causes parse error
module "registry.terraform.io/hashicorp/consul/aws" {
  ...
}
```

The same applies to the policy block itself:

```hcl
# ✅ CORRECT
module_policy "*" "require_private_registry" { ... }

# ❌ WRONG — "Only 1 labels (source) are expected" error (misleading message; two ARE required)
module_policy "*" { ... }
```

Verified on tfpolicy 0.0.2-beta20260513.

---

## Quick Decision Tree

**Need to compare versions?**
→ SemVer strings (e.g. `"6.2.0"`): Use `core::semverconstraint()`. Non-SemVer strings (e.g. AWS `"6.x"`, `"5.0.6"`): Use `core::try(core::regex("^[1-5]\\.", version), null) != null` — see Mistake 36.

**Checking if a value is one of several allowed values?**
→ Use `core::contains(allowed_list, value)` — NOT chained `||`. Store the list in a named local — see Mistake 35.

**Enforcing a rule on an S3 companion resource (e.g. `public_access_block`, `acl`, `versioning`, `logging`)?**
→ ALWAYS anchor on `resource_policy "aws_s3_bucket"` with `core::getresources("companion", { bucket = attrs.id })` inside — NEVER anchor on the companion type directly — see Mistake 37.

**Enforcing IAM content rules (no admin privileges, no wildcard actions, etc.)?**
→ Write 4 separate `resource_policy` blocks: `aws_iam_policy`, `aws_iam_role_policy`, `aws_iam_user_policy`, `aws_iam_group_policy`. All use `core::jsondecode(core::try(attrs.policy, "{}"))`. Do NOT use `aws_iam_policy_document` (`data_policy` does not exist) — see Mistake 38.

**Need built-in Terraform function?**
→ Add `core::` prefix

**Want to use locals in provider_policy?**
→ Go ahead! Language server errors are false

**Need string pattern matching?**
→ ✅ `core::startswith(str, prefix)` and `core::endswith(str, suffix)` are available directly. For regex/substring use `core::try(core::regex("pattern", string), null) != null`.

**Need to handle null values?**
→ Use `core::try(value, default)`

**Testing policies?**
→ Create `.policytest.hcl` files and run `tfpolicy test`

---

## Version Requirements

- **Terraform**: >= 1.13.0-policyYYYYMMDD (private beta builds)
- **tfpolicy CLI**: >= 0.0.1-alphaYYYYMMDD
- **HCP Terraform**: Organization with policy feature enabled

---

## Contact

- **Questions:** team-tf-policy@wwpdl.vnet.ibm.com
- **Documentation:** See terraform-policy-agent-skill/ directory
- **Examples:** See the reusable patterns in [`tfpolicy-author.md`](../skills/tfpolicy-author/SKILL.md) and any companion example directories that may exist in your broader beta workspace

---

**Status:** ✅ All behaviors verified with user
**Ready for:** Agent skill usage, documentation generation, policy creation
**Last Review:** 2026-02-20

> **See Also:** [Authoring Reference](../skills/tfpolicy-author/SKILL.md)
