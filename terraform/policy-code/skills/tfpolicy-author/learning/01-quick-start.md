# Terraform Policy - Quick Start Guide

> **Navigation:** [Common Patterns](02-common-patterns.md) | [Back to Main README](../../../README.md)

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
- [Common Patterns](02-common-patterns.md) - Common policy patterns and examples
- [SKILL.md](../SKILL.md) - Complete authoring reference for this sub-skill

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

**See [Advanced Patterns Guide](02-common-patterns.md#8--performance-optimization-verified) for detailed performance guidance**

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

**See [Verified Syntax Reference](../../../reference/verified-syntax.md#4--critical-blocks-vs-attributes-schema-distinction) for complete details**

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

> **Next:** [Advanced Patterns & Best Practices](02-common-patterns.md)
