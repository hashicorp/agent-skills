# Terraform Modernize Skill - Implementation Plan

## Overview

Create a skill that analyzes Terraform configurations and suggests modernization opportunities for:
1. **Ephemeral Resources** - Replace data sources with ephemeral resources for transient, sensitive data
2. **Write-only Arguments** - Pass sensitive values to resources without storing in state

**Key Requirements:**
- All transformations must pass `terraform validate`
- Ephemeral values can only be used in ephemeral contexts (write-only arguments, other ephemeral blocks, ephemeral outputs)
- Write-only arguments use `_wo` suffix with corresponding `_wo_version` tracking

## Skill Metadata

**Location:** `terraform/code-generation/skills/terraform-modernize/`

**Frontmatter:**
```yaml
---
name: terraform-modernize
description: Modernize Terraform configurations to use ephemeral resources and write-only arguments. Use when upgrading code to leverage newer Terraform 1.10+ features for better security and state management.
compatibility: Requires Terraform >= 1.10 (ephemeral) or >= 1.11 (write-only), latest provider versions recommended. For version upgrades, use the version-upgrades skill first.
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.1.0"
---
```

## Target Structure

```
terraform-modernize/
├── SKILL.md                           # Main skill documentation
├── scripts/
│   ├── check_ephemeral_support.sh     # Check provider ephemeral resource support
│   └── check_writeonly_support.sh     # Check provider write-only attribute support
├── references/
│   ├── ephemeral-resources.md         # Detailed ephemeral resource guide
│   ├── write-only-arguments.md        # Detailed write-only arguments guide
│   ├── ephemeral-contexts.md          # Where ephemeral values can be used
│   ├── migration-patterns.md          # Common migration patterns
│   └── provider-support.md            # Provider feature compatibility matrix
└── assets/
    └── decision-tree.md               # Visual decision tree for modernization
```

## SKILL.md Structure

### 1. Frontmatter (see above)

### 2. Main Body Sections

#### Overview (100-150 words)
- Brief introduction to modernization opportunities
- Why these features matter (security, state management)
- Link to version-upgrades skill for prerequisites

#### Prerequisites
- Terraform >= 1.10.0 (for ephemeral resources) or >= 1.11.0 (for write-only arguments)
- Provider versions that support these features
- Reference to version-upgrades skill: `https://github.com/thrashr888/hcptf-cli/tree/main/.skills/version-upgrades`
- Understanding of ephemeral contexts and restrictions

#### When to Use
- Migrating sensitive data sources to ephemeral
- Removing secrets from state files
- Improving security posture
- Modernizing legacy configurations

#### Decision Tree
```
1. Check Terraform version:
   - For ephemeral: >= 1.10?
   - For write-only: >= 1.11?
   - NO → Use version-upgrades skill first
   - YES → Continue

2. Check provider version: Latest?
   - NO → Use version-upgrades skill first
   - YES → Continue

3. Identify modernization opportunities:
   - Data sources with sensitive values → Ephemeral resources
   - Resources with passwords/keys in state → Write-only arguments

4. Verify provider support:
   - Run ./scripts/check_ephemeral_support.sh <provider>
   - Run ./scripts/check_writeonly_support.sh <provider>

5. Apply transformations (see workflows below)

6. Validate transformations:
   - Run terraform validate
   - Ensure ephemeral values only used in ephemeral contexts
   - Verify write-only arguments paired with _wo_version
```

#### Quick Start
```bash
# 1. Check versions
terraform version  # Should be >= 1.10.0 (ephemeral) or >= 1.11.0 (write-only)

# 2. Check what's supported
./scripts/check_ephemeral_support.sh aws
./scripts/check_writeonly_support.sh aws

# 3. Identify opportunities (manual code review)
grep -r "data \".*secret" .
grep -r "password.*=" . | grep -v "_wo"

# 4. Apply transformations (see examples below)

# 5. Validate changes
terraform validate
terraform plan
```

### 3. Ephemeral Resources Section

#### What are Ephemeral Resources?
- Brief explanation
- Available since Terraform 1.10
- Link to [references/ephemeral-resources.md]

#### Detection Pattern
```hcl
# OLD: Data source stores sensitive value in state
data "aws_secretsmanager_secret_version" "api_key" {
  secret_id = "my-api-key"
}

resource "aws_instance" "app" {
  user_data = data.aws_secretsmanager_secret_version.api_key.secret_string
}
```

#### Modernization
```hcl
# NEW: Ephemeral resource - not stored in state
ephemeral "aws_secretsmanager_secret_version" "api_key" {
  secret_id = "my-api-key"
}

resource "aws_instance" "app" {
  user_data = ephemeral.aws_secretsmanager_secret_version.api_key.secret_string
}
```

#### When to Use Ephemeral
- [ ] Data contains secrets/credentials
- [ ] Data only needed during apply
- [ ] Data changes frequently
- [ ] Provider supports ephemeral version
- [ ] Terraform >= 1.10

#### When NOT to Use Ephemeral
- [ ] Need to reference in non-ephemeral outputs (must use `ephemeral = true` in output)
- [ ] Need to use in depends_on
- [ ] Data needs to persist across applies
- [ ] Provider doesn't support ephemeral type
- [ ] Value used in non-ephemeral context

#### Naming Convention
Provider typically uses same name as managed resource/data source:
- Data: `data.aws_secretsmanager_secret_version`
- Ephemeral: `ephemeral.aws_secretsmanager_secret_version`
- Resource: `aws_secretsmanager_secret_version`

#### Ephemeral Contexts (Where Ephemeral Values Can Be Used)

**Valid ephemeral contexts:**
```hcl
# 1. Write-only arguments (most common)
resource "aws_db_instance" "db" {
  password_wo = ephemeral.random_password.db.result  # ✅ Valid
}

# 2. Other ephemeral blocks
ephemeral "vault_generic_secret" "combined" {
  path = ephemeral.vault_generic_secret.api.path  # ✅ Valid
}

# 3. Ephemeral outputs
output "temp_password" {
  value     = ephemeral.random_password.db.result  # ✅ Valid
  ephemeral = true  # REQUIRED for ephemeral values
}
```

**Invalid (non-ephemeral) contexts:**
```hcl
# ❌ Regular resource arguments
resource "aws_db_instance" "db" {
  password = ephemeral.random_password.db.result  # ❌ ERROR
}

# ❌ Regular outputs
output "temp_password" {
  value = ephemeral.random_password.db.result  # ❌ ERROR
}

# ❌ Data sources
data "aws_instance" "app" {
  filter {
    name   = "tag:Password"
    values = [ephemeral.random_password.db.result]  # ❌ ERROR
  }
}

# ❌ depends_on
resource "aws_instance" "app" {
  depends_on = [ephemeral.random_password.db]  # ❌ ERROR
}
```

### 4. Write-only Arguments Section

#### What are Write-only Arguments?
- Brief explanation
- Available since Terraform 1.11
- Link to [references/write-only-arguments.md]

#### Detection Pattern
```hcl
# OLD: Password stored in state file
resource "aws_db_instance" "main" {
  password = var.db_password  # Stored in state
}
```

#### Modernization
```hcl
# NEW: Password not stored in state using write-only arguments
# Step 1: Generate ephemeral password
ephemeral "random_password" "db_password" {
  length           = 16
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Step 2: Use write-only argument (note _wo suffix and _wo_version)
resource "aws_db_instance" "main" {
  password_wo         = ephemeral.random_password.db_password.result
  password_wo_version = 1  # Increment to trigger updates
}

# Or with existing variable:
resource "aws_db_instance" "main" {
  password_wo         = var.db_password  # Can use non-ephemeral values too
  password_wo_version = 1
}
```

**Important:** Write-only arguments require both `_wo` suffix AND corresponding `_wo_version` argument.

#### When to Use Write-only Arguments
- [ ] Attribute contains password/key/token
- [ ] Value should not be stored in state
- [ ] Don't need to read value after creation
- [ ] Provider supports write-only arguments (check schema)
- [ ] Terraform >= 1.11

#### Common Write-only Argument Candidates
- Database passwords (`password_wo`)
- API keys (`api_key_wo`)
- Authentication tokens (`token_wo`)
- Private keys (`private_key_wo`)
- Encryption keys (`encryption_key_wo`)

#### Write-only Argument Requirements
1. **Naming:** Attribute name MUST end with `_wo` suffix
2. **Version tracking:** MUST include corresponding `_wo_version` argument
3. **Version updates:** Increment `_wo_version` to trigger updates (Terraform can't detect changes to write-only values)
4. **Provider support:** Check provider schema for `_wo` argument support

### 5. Workflows

#### Workflow 1: Migrate Data Source to Ephemeral

```bash
# Step 1: Verify support
./scripts/check_ephemeral_support.sh aws

# Step 2: Check provider version
terraform providers

# Step 3: Update code
# Change: data "TYPE" "NAME"
# To:     ephemeral "TYPE" "NAME"

# Step 4: Update references (IMPORTANT: verify ephemeral context)
# Change: data.TYPE.NAME
# To:     ephemeral.TYPE.NAME
# Only in: write-only arguments, other ephemeral blocks, ephemeral outputs

# Step 5: Validate
terraform validate  # Must pass!

# Step 6: Test
terraform plan

# Step 7: Apply
terraform apply
```

#### Workflow 2: Migrate to Write-only Arguments

```bash
# Step 1: Verify support
./scripts/check_writeonly_support.sh aws

# Step 2: Check provider schema for write-only argument names
terraform providers schema -json | jq '.provider_schemas' | grep "_wo"

# Step 3: Update code to use write-only argument
# Change: password = var.db_password
# To:     password_wo = var.db_password
#         password_wo_version = 1

# Step 4: (Optional) Create ephemeral source for value
# ephemeral "random_password" "db" {
#   length = 16
# }
# password_wo = ephemeral.random_password.db.result

# Step 5: Validate
terraform validate  # Must pass!

# Step 6: Test plan
terraform plan

# Step 7: Apply (will update resource with write-only argument)
terraform apply

# Step 8: Verify state doesn't contain sensitive value
terraform state show <resource> | grep -i password_wo
# Should show password_wo_version but NOT password_wo value
```

### 6. Provider Support Reference

Link to [references/provider-support.md] with table:

| Provider | Ephemeral Support | Write-only Arguments | Minimum Version | Notes |
|----------|-------------------|---------------------|-----------------|-------|
| AWS      | Yes (select)      | Yes                 | 5.70+           | Growing list of ephemeral resources |
| Azure    | Yes (select)      | Yes                 | 4.0+            | Limited ephemeral support |
| GCP      | Limited           | Yes                 | 6.0+            | Check schema for support |
| Random   | Yes               | Yes                 | 3.6+            | random_password common use case |

### 7. Common Patterns

Link to [references/migration-patterns.md] for detailed examples.

**Pattern 1: Secrets Manager to Ephemeral + Write-only**
```hcl
# BEFORE
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod-db-password"
}
resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}

# AFTER
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod-db-password"
}
resource "aws_db_instance" "main" {
  password_wo         = ephemeral.aws_secretsmanager_secret_version.db_password.secret_string
  password_wo_version = 1
}
```

**Pattern 2: Generated Password with Write-only**
```hcl
# BEFORE
resource "random_password" "db" {
  length = 16
}
resource "aws_db_instance" "main" {
  password = random_password.db.result  # Stored in state
}

# AFTER
ephemeral "random_password" "db" {
  length = 16
}
resource "aws_db_instance" "main" {
  password_wo         = ephemeral.random_password.db.result  # Not stored
  password_wo_version = 1
}
```

**Pattern 3: Variable to Write-only**
```hcl
# BEFORE
variable "api_key" {
  type      = string
  sensitive = true
}
resource "datadog_api_key" "api" {
  key = var.api_key  # Stored in state
}

# AFTER
variable "api_key" {
  type      = string
  sensitive = true
}
resource "datadog_api_key" "api" {
  key_wo         = var.api_key  # Not stored
  key_wo_version = 1
}
```

**Pattern 4: Ephemeral TLS Certificate**
```hcl
# BEFORE
data "tls_certificate" "vault" {
  url = "https://vault.example.com:8200"
}

# AFTER
ephemeral "tls_certificate" "vault" {
  url = "https://vault.example.com:8200"
}
# Use in write-only contexts only
```

**Pattern 5: SSH Key with Write-only**
```hcl
# BEFORE
resource "aws_instance" "app" {
  key_name = "my-key"
  # Key visible in state
}

# AFTER (if provider supports)
ephemeral "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "deployer" {
  key_name_wo         = "deployer-key"
  key_name_wo_version = 1
  public_key_wo       = ephemeral.tls_private_key.ssh.public_key_openssh
  public_key_wo_version = 1
}
```

### 8. Troubleshooting

#### Error: "ephemeral resource type not supported"
- Check provider version (may be too old)
- Check Terraform version (< 1.10)
- Verify resource type supports ephemeral
- Run: `./scripts/check_ephemeral_support.sh <provider>`

#### Error: "write-only argument not recognized" or "unknown argument password_wo"
- Check Terraform version (< 1.11)
- Check provider supports write-only arguments
- Verify argument name ends with `_wo` suffix
- Run: `./scripts/check_writeonly_support.sh <provider>`

#### Error: "ephemeral values cannot be used in this context"
- Ephemeral values can ONLY be used in:
  - Write-only arguments (attributes ending in `_wo`)
  - Other ephemeral resource blocks
  - Outputs marked with `ephemeral = true`
- **Cannot** be used in:
  - Regular resource arguments
  - Regular (non-ephemeral) outputs
  - Module outputs (unless ephemeral)
  - Data sources
  - depends_on

#### Error: "write-only argument missing corresponding _wo_version"
- Every `_wo` argument requires a `_wo_version` argument
- Add: `password_wo_version = 1`
- Increment version number to trigger updates

#### Validation fails after transformation
- Run `terraform validate` to see specific error
- Verify all ephemeral references are in ephemeral contexts
- Check that write-only arguments are paired with version arguments
- Review provider schema for correct argument names

### 9. Safety Considerations

⚠️ **Important Notes:**

1. **Ephemeral context restrictions**: Ephemeral values can ONLY be used in ephemeral contexts:
   - Write-only arguments (`_wo` suffix)
   - Other ephemeral blocks
   - Outputs marked `ephemeral = true`

2. **Ephemeral cannot be in depends_on**: Use implicit dependencies instead

3. **Write-only requires version tracking**: Always pair `_wo` with `_wo_version`
   - Increment version to trigger updates
   - Terraform can't detect changes to write-only values

4. **Write-only removes from state**: You cannot read these values after apply
   - Once written, values are not retrievable
   - Plan accordingly for recovery/rotation

5. **Validation is mandatory**: Always run `terraform validate` after transformations
   - Catches ephemeral context violations
   - Verifies write-only argument pairing
   - Ensures provider support

6. **Test in non-prod first**: Always test migrations in dev/staging
   - Transformations affect state structure
   - May require resource replacement

7. **Backup state files**: Keep state backups before major changes
   - Use remote state with versioning
   - Test rollback procedures

### 10. Related Skills

- [version-upgrades](https://github.com/thrashr888/hcptf-cli/tree/main/.skills/version-upgrades) - Upgrade Terraform and provider versions first
- [terraform-style-guide](../terraform-style-guide/SKILL.md) - Format modernized code
- [terraform-test](../terraform-test/SKILL.md) - Test modernized configurations

### 11. References

**Official Documentation:**
- [Ephemeral Resources](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral)
- [Write-only Arguments](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/write-only)
- [Ephemeral Resources (Block Reference)](https://developer.hashicorp.com/terraform/language/resources/ephemeral)
- [AWS Provider Ephemeral Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/ephemeral-resources)

**Blog Posts:**
- [Introducing Ephemeral Resources (Terraform 1.10)](https://www.hashicorp.com/blog/terraform-1-10-adds-ephemeral-resources)
- [Write-only Arguments (Terraform 1.11)](https://www.hashicorp.com/blog/terraform-1-11-write-only-arguments)

---

## Implementation Details

### Script: check_ephemeral_support.sh

Similar to `list_resources.sh` pattern:

```bash
#!/bin/bash
# Extract ephemeral resources supported by Terraform providers
# Usage: ./check_ephemeral_support.sh [provider_name]
# Requires: terraform, jq

set -e

PROVIDER=$1

if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..." >&2
    terraform init -upgrade > /dev/null 2>&1
fi

if [ -n "$PROVIDER" ]; then
    # Specific provider
    provider_key=$(terraform providers schema -json 2>/dev/null | \
        jq -r '.provider_schemas | keys[]' | grep "/${PROVIDER}$" || true)
    if [ -n "$provider_key" ]; then
        terraform providers schema -json 2>/dev/null | jq -r \
            "{\"$PROVIDER\": (.provider_schemas.\"${provider_key}\" | .ephemeral_resource_schemas // {} | keys | sort)}"
    else
        echo "{\"$PROVIDER\": []}"
    fi
else
    # All providers
    terraform providers schema -json 2>/dev/null | jq -r '
        .provider_schemas
        | to_entries
        | map({key: (.key | split("/")[-1]), value: (.value.ephemeral_resource_schemas // {} | keys | sort)})
        | from_entries
    '
fi
```

### Script: check_writeonly_support.sh

```bash
#!/bin/bash
# Check which resources/attributes support write-only
# Usage: ./check_writeonly_support.sh [provider_name] [resource_type]
# Requires: terraform, jq

set -e

PROVIDER=$1
RESOURCE=$2

if [ ! -d ".terraform" ]; then
    terraform init -upgrade > /dev/null 2>&1
fi

# Extract write-only capable attributes from provider schema
terraform providers schema -json 2>/dev/null | jq -r '
    .provider_schemas
    | to_entries[]
    | select(.key | endswith("/'${PROVIDER}'"))
    | .value.resource_schemas
    | to_entries[]
    | select(.key == "'${RESOURCE}'")
    | {
        resource: .key,
        write_only_attributes: [
            .value.block.attributes
            | to_entries[]
            | select(.value.write_only == true)
            | .key
        ]
    }
'
```

### Reference: ephemeral-resources.md

Detailed content covering:
- Complete explanation of ephemeral resources
- Lifecycle behavior (exist only during operation)
- Ephemeral context restrictions
- Naming conventions (same as data/resource)
- Provider support matrix
- 10+ before/after examples
- Common use cases (secrets, credentials, certificates)
- Edge cases and gotchas

### Reference: ephemeral-contexts.md

Detailed guide on where ephemeral values can be used:
- Definition of ephemeral contexts
- Valid contexts with examples:
  - Write-only arguments
  - Other ephemeral blocks
  - Ephemeral outputs
- Invalid contexts with error examples
- How to validate ephemeral usage
- Common validation errors and fixes
- Refactoring strategies when context is invalid

### Reference: write-only-arguments.md

Detailed content covering:
- Complete explanation of write-only arguments
- `_wo` suffix and `_wo_version` requirements
- State behavior (values not stored)
- Version tracking and update mechanism
- Combining with ephemeral resources
- 10+ before/after examples
- Common write-only argument patterns by provider
- Security best practices

### Reference: migration-patterns.md

5 comprehensive patterns:
1. AWS Secrets Manager → Ephemeral
2. Database passwords → Write-only
3. API tokens → Ephemeral
4. SSH keys → Write-only
5. TLS certificates → Ephemeral

Each with:
- Detection query
- Before code
- After code
- Migration steps
- Testing approach
- Rollback procedure

### Reference: provider-support.md

Comprehensive table with:
- Provider name
- Ephemeral resources list
- Write-only attributes list
- Minimum version requirements
- Documentation links
- Release notes

---

## Success Criteria

- [ ] SKILL.md follows Agent Skills specification
- [ ] All frontmatter fields present and valid
- [ ] Clear decision tree for version checking
- [ ] Scripts provide accurate provider feature detection
- [ ] Examples show both ephemeral resources and write-only arguments
- [ ] Write-only examples use correct `_wo` suffix and `_wo_version` syntax
- [ ] Ephemeral context restrictions clearly documented
- [ ] Validation step (`terraform validate`) included in all workflows
- [ ] References to version-upgrades skill for prerequisites
- [ ] Safety warnings prominently displayed
- [ ] Provider support documented with accurate version requirements
- [ ] Correct Terraform version requirements (1.10 ephemeral, 1.11 write-only)
- [ ] Troubleshooting covers ephemeral context errors
- [ ] All examples pass `terraform validate`
- [ ] Passes `tessl skill review` with 85%+ score
- [ ] Passes repository structure validation

## Estimated Token Count

- SKILL.md body: ~4,500 tokens (well under 5,000 limit)
- References: ~2,000 tokens each (loaded on demand)
- Scripts: Minimal (executed, not read)

## Next Steps

1. Create skill directory structure
2. Write SKILL.md following this plan
3. Implement check scripts:
   - `check_ephemeral_support.sh`
   - `check_writeonly_support.sh`
4. Write reference documents:
   - `ephemeral-resources.md`
   - `write-only-arguments.md`
   - `ephemeral-contexts.md`
   - `migration-patterns.md`
   - `provider-support.md`
5. Create example configurations for testing
6. Test all examples with `terraform validate`
7. Test with real Terraform configurations
8. Run `tessl skill review`
9. Iterate based on feedback (target 85%+ score)
10. Submit PR with updated plugin.json

## Testing Plan

**Test Configurations:**
1. Ephemeral secret to write-only argument (AWS Secrets Manager)
2. Data source to ephemeral migration
3. Regular password to write-only argument migration
4. Invalid ephemeral context (should fail validation)
5. Missing `_wo_version` (should fail validation)
6. Multi-provider configuration

**Validation Checklist:**
- [ ] All examples pass `terraform validate`
- [ ] Scripts correctly identify provider support
- [ ] Error messages match documentation
- [ ] Workflows produce valid Terraform code
- [ ] References are accurate and current
