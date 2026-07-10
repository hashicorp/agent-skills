# Terraform Policy - Common Patterns

> **Navigation:** [Quick Start](01-quick-start.md) | [Back to Main README](../../../README.md)

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


> **Previous:** [Quick Start Guide](01-quick-start.md)
> **Back to:** [Main README](../../../README.md)
