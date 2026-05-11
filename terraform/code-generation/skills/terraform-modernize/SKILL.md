---
name: terraform-modernize
description: Modernize Terraform configurations to use ephemeral resources and write-only arguments. Use when upgrading code to leverage newer Terraform 1.10+ features for better security and state management.
compatibility: Requires Terraform >= 1.10 (ephemeral) or >= 1.11 (write-only), provider versions that support these features. For version upgrades, use the version-upgrades skill first.
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.1.0"
---

# Terraform Modernize

Modernize Terraform configurations to use ephemeral resources and write-only arguments for better security and state management.

## Overview

Terraform 1.10+ introduced **ephemeral resources** and **write-only arguments** to handle sensitive data without storing it in state or plan files. This skill helps you identify and migrate legacy patterns to these modern features.

**Key benefits:**
- **Ephemeral resources** - Temporary values that exist only during apply (secrets, credentials)
- **Write-only arguments** - Sensitive values passed to resources but never stored in state
- **Better security** - Secrets never written to state files
- **Cleaner state** - Reduced sensitive data exposure

**Important:** All transformations must pass `terraform validate`. Ephemeral values can only be used in ephemeral contexts.

## Prerequisites

**Version Requirements:**
- Terraform >= 1.10.0 for ephemeral resources
- Terraform >= 1.11.0 for write-only arguments
- Provider versions that support ephemeral resources and write-only arguments

**If you need to upgrade versions first:**
- Use [version-upgrades skill](https://github.com/thrashr888/hcptf-cli/tree/main/.skills/version-upgrades)

**Understanding:**
- Ephemeral contexts and their restrictions
- Write-only argument syntax (`_wo` suffix + `_wo_version`)
- Provider schema capabilities

## When to Use

Use this skill when you want to:
- Migrate sensitive data sources (secrets, passwords) to ephemeral resources
- Remove credentials from state files using write-only arguments
- Improve security posture of Terraform configurations
- Modernize legacy configurations to use latest Terraform features
- Eliminate sensitive data from plan/state files

## Decision Tree

```
1. Check Terraform version:
   - For ephemeral: >= 1.10?
   - For write-only: >= 1.11?
   → NO: Use version-upgrades skill first
   → YES: Continue

2. Identify providers in use:
   terraform providers

3. Check what modernization features each provider supports:
   ./scripts/check_ephemeral_support.sh <provider>
   ./scripts/check_writeonly_support.sh <provider>

   → No support: Check provider documentation for minimum version
   → Supported: Note the available ephemeral resources and write-only arguments

4. If provider version too old:
   → Use version-upgrades skill to update provider
   → Then re-check support

5. Scan configuration for legacy patterns matching supported features:
   - Find data sources that have ephemeral equivalents
   - Find resources using regular arguments that have write-only equivalents
   - Example: data.aws_secretsmanager_secret_version → ephemeral version exists

6. Apply transformations (see workflows below)

7. Validate transformations:
   terraform validate  # MUST pass
   - Verify ephemeral values only in ephemeral contexts
   - Verify write-only arguments paired with _wo_version
```

## Quick Start

```bash
# 1. Check Terraform version
terraform version  # >= 1.10.0 for ephemeral, >= 1.11.0 for write-only

# 2. Identify providers in use
terraform providers

# 3. Check what each provider supports
./scripts/check_ephemeral_support.sh aws
./scripts/check_writeonly_support.sh aws
# Output shows: ["aws_secretsmanager_secret_version", "aws_iam_role", ...]

# 4. Search configuration for legacy versions of supported resources
# If provider supports ephemeral.aws_secretsmanager_secret_version:
grep -r "data \"aws_secretsmanager_secret_version\"" .

# If provider supports write-only password_wo:
grep -r "resource \"aws_db_instance\"" . | xargs grep -l "password ="

# 5. Apply transformations (see examples below)

# 6. Validate changes
terraform validate  # Must pass!
terraform plan
```

## Ephemeral Resources

### What are Ephemeral Resources?

Ephemeral resources are temporary infrastructure components that exist only during the current Terraform operation. Terraform does not store ephemeral resource information in state or plan files.

**Available since:** Terraform 1.10

**Common uses:**
- Retrieving secrets from secret managers
- Generating temporary passwords
- Obtaining short-lived credentials
- Fetching certificates or tokens

**See:** [references/ephemeral-resources.md](references/ephemeral-resources.md) for details.

### Migration Pattern

```hcl
# BEFORE: Data source stores secret in state
data "aws_secretsmanager_secret_version" "api_key" {
  secret_id = "my-api-key"
}

resource "aws_instance" "app" {
  user_data = data.aws_secretsmanager_secret_version.api_key.secret_string
}

# AFTER: Ephemeral resource - not stored in state
ephemeral "aws_secretsmanager_secret_version" "api_key" {
  secret_id = "my-api-key"
}

resource "aws_instance" "app" {
  user_data_wo         = ephemeral.aws_secretsmanager_secret_version.api_key.secret_string
  user_data_wo_version = 1
}
```

### When to Use Ephemeral Resources

Use ephemeral when:
- [ ] Data contains secrets or credentials
- [ ] Data only needed during apply/plan
- [ ] Provider supports ephemeral version of the resource (check with scripts)
- [ ] Terraform version >= 1.10
- [ ] Value will be used in ephemeral context

Do NOT use ephemeral when:
- [ ] Need to reference in regular (non-ephemeral) outputs
- [ ] Data needs to persist across applies
- [ ] Provider doesn't support ephemeral type
- [ ] Value will be used in non-ephemeral context

### Naming Convention

Providers typically use the same name for data sources, ephemeral resources, and managed resources:

- Data source: `data.aws_secretsmanager_secret_version.name`
- Ephemeral: `ephemeral.aws_secretsmanager_secret_version.name`
- Resource: `aws_secretsmanager_secret_version` (if available)

### Ephemeral Contexts

**CRITICAL:** Ephemeral values can ONLY be used in ephemeral contexts.

**Valid ephemeral contexts:**

```hcl
# 1. Write-only arguments (most common)
resource "aws_db_instance" "db" {
  password_wo         = ephemeral.random_password.db.result  # ✅ Valid
  password_wo_version = 1
}

# 2. Other ephemeral blocks
ephemeral "vault_generic_secret" "combined" {
  path = ephemeral.vault_generic_secret.api.path  # ✅ Valid
}

# 3. Provider configuration blocks
provider "kubernetes" {
  host  = ephemeral.aws_eks_cluster_auth.cluster.endpoint  # ✅ Valid
  token = ephemeral.aws_eks_cluster_auth.cluster.token      # ✅ Valid
}

# 4. Ephemeral outputs
output "temp_password" {
  value     = ephemeral.random_password.db.result  # ✅ Valid
  ephemeral = true  # REQUIRED
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

**See:** [references/ephemeral-contexts.md](references/ephemeral-contexts.md) for comprehensive guide.

## Write-only Arguments

### What are Write-only Arguments?

Write-only arguments are resource arguments that accept sensitive values but do not store them in state or plan files. They use a special `_wo` suffix and require version tracking.

**Available since:** Terraform 1.11

**Common uses:**
- Database passwords
- API keys and tokens
- Private keys and certificates
- Encryption keys

**See:** [references/write-only-arguments.md](references/write-only-arguments.md) for details.

### Migration Pattern

```hcl
# BEFORE: Password stored in state file
resource "aws_db_instance" "main" {
  password = var.db_password  # Stored in state
}

# AFTER: Password not stored in state
ephemeral "random_password" "db_password" {
  length           = 16
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "main" {
  password_wo         = ephemeral.random_password.db_password.result
  password_wo_version = 1  # Increment to trigger updates
}

# Or with existing variable (non-ephemeral source):
resource "aws_db_instance" "main" {
  password_wo         = var.db_password  # Can use regular variables too
  password_wo_version = 1
}
```

### When to Use Write-only Arguments

Use write-only when:
- [ ] Argument contains password, key, or token
- [ ] Value should not be stored in state
- [ ] Don't need to read value after creation
- [ ] Provider supports write-only version (check schema)
- [ ] Terraform version >= 1.11

### Write-only Requirements

**1. Naming:** Attribute MUST end with `_wo` suffix
```hcl
password_wo = "secret"  # ✅ Correct
password    = "secret"  # ❌ Wrong - will be stored in state
```

**2. Version tracking:** MUST include corresponding `_wo_version` argument
```hcl
password_wo         = var.db_password
password_wo_version = 1  # REQUIRED
```

**3. Version updates:** Increment `_wo_version` to trigger updates
```hcl
# Terraform can't detect changes to write-only values
# Increment version to force update:
password_wo_version = 2  # Changed from 1
```

**4. Provider support:** Check provider schema for `_wo` argument availability
```bash
./scripts/check_writeonly_support.sh aws
```

## Workflows

### Workflow 1: Migrate Data Source to Ephemeral

```bash
# Step 1: Identify providers and check support
terraform providers
./scripts/check_ephemeral_support.sh aws

# Step 2: Find data sources that have ephemeral equivalents
# Example: Provider supports ephemeral.aws_secretsmanager_secret_version
grep -r "data \"aws_secretsmanager_secret_version\"" .

# Step 3: Update code
# Change: data "aws_secretsmanager_secret_version" "name"
# To:     ephemeral "aws_secretsmanager_secret_version" "name"

# Step 4: Update all references (IMPORTANT: verify ephemeral context)
# Change: data.aws_secretsmanager_secret_version.name.attribute
# To:     ephemeral.aws_secretsmanager_secret_version.name.attribute
# Only in: write-only arguments, other ephemeral blocks, provider blocks, ephemeral outputs

# Step 5: Validate
terraform validate  # Must pass!

# Step 6: Test
terraform plan

# Step 7: Apply
terraform apply
```

### Workflow 2: Migrate to Write-only Arguments

```bash
# Step 1: Identify providers and check support
terraform providers
./scripts/check_writeonly_support.sh aws

# Step 2: Find resources using regular arguments that have write-only equivalents
# Example: Provider supports password_wo for aws_db_instance
grep -r "resource \"aws_db_instance\"" . | xargs grep -l "password ="

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
terraform state show <resource> | grep -i password
# Should show password_wo_version but NOT password_wo value
```

### Workflow 3: Combine Ephemeral + Write-only

```bash
# Step 1: Check support for both features
./scripts/check_ephemeral_support.sh aws
./scripts/check_writeonly_support.sh aws

# Step 2: Create ephemeral resource for sensitive data
# Add:
# ephemeral "aws_secretsmanager_secret_version" "db_password" {
#   secret_id = "prod-db-password"
# }

# Step 3: Use ephemeral value in write-only argument
# resource "aws_db_instance" "main" {
#   password_wo         = ephemeral.aws_secretsmanager_secret_version.db_password.secret_string
#   password_wo_version = 1
# }

# Step 4: Validate and apply
terraform validate
terraform plan
terraform apply
```

## Common Patterns

See [references/migration-patterns.md](references/migration-patterns.md) for detailed examples.

### Pattern 1: Secrets Manager to Ephemeral + Write-only

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

### Pattern 2: Generated Password with Write-only

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

### Pattern 3: Provider Authentication

```hcl
# BEFORE
data "aws_eks_cluster_auth" "cluster" {
  name = "my-cluster"
}
provider "kubernetes" {
  host  = data.aws_eks_cluster.cluster.endpoint
  token = data.aws_eks_cluster_auth.cluster.token  # Stored in state
}

# AFTER
ephemeral "aws_eks_cluster_auth" "cluster" {
  name = "my-cluster"
}
provider "kubernetes" {
  host  = data.aws_eks_cluster.cluster.endpoint
  token = ephemeral.aws_eks_cluster_auth.cluster.token  # Not stored
}
```

## Troubleshooting

### Error: "ephemeral resource type not supported"

**Cause:** Provider doesn't support ephemeral version of the resource.

**Solutions:**
- Check provider version (may be too old)
- Check Terraform version (must be >= 1.10)
- Run: `./scripts/check_ephemeral_support.sh <provider>`
- Check provider documentation for ephemeral resource support
- If not available, use version-upgrades skill to update provider

### Error: "write-only argument not recognized" or "unknown argument password_wo"

**Cause:** Provider doesn't support write-only arguments or Terraform version too old.

**Solutions:**
- Check Terraform version (must be >= 1.11)
- Run: `./scripts/check_writeonly_support.sh <provider>`
- Check provider schema: `terraform providers schema -json | jq '.provider_schemas' | grep "_wo"`
- Verify argument name ends with `_wo` suffix
- Update provider if version is too old

### Error: "ephemeral values cannot be used in this context"

**Cause:** Trying to use ephemeral value in non-ephemeral context.

**Valid contexts:**
- Write-only arguments (attributes ending in `_wo`)
- Other ephemeral resource blocks
- Provider configuration blocks
- Outputs marked with `ephemeral = true`

**Invalid contexts:**
- Regular resource arguments
- Regular (non-ephemeral) outputs
- Module outputs (unless ephemeral)
- Data sources
- depends_on

**Solution:** Refactor to use ephemeral value only in valid contexts, or use regular data source instead.

### Error: "write-only argument missing corresponding _wo_version"

**Cause:** Every `_wo` argument requires a `_wo_version` argument.

**Solution:**
```hcl
resource "aws_db_instance" "main" {
  password_wo         = var.db_password
  password_wo_version = 1  # Add this
}
```

### Validation fails after transformation

**Steps to diagnose:**
1. Run `terraform validate` to see specific error
2. Verify all ephemeral references are in ephemeral contexts
3. Check that write-only arguments are paired with version arguments
4. Review provider schema for correct argument names:
   ```bash
   terraform providers schema -json | jq '.provider_schemas'
   ```

## Safety Considerations

⚠️ **Important Notes:**

1. **Ephemeral context restrictions**: Ephemeral values can ONLY be used in:
   - Write-only arguments (`_wo` suffix)
   - Other ephemeral blocks
   - Provider configuration blocks
   - Outputs marked `ephemeral = true`

2. **Write-only requires version tracking**: Always pair `_wo` with `_wo_version`
   - Terraform can't detect changes to write-only values
   - Increment version number to trigger updates
   - Example: Change `password_wo_version = 1` to `password_wo_version = 2`

3. **Write-only removes from state**: Cannot read values after apply
   - Once written, values are not retrievable from state
   - Plan accordingly for recovery/rotation scenarios
   - Keep external records if needed

4. **Validation is mandatory**: Always run `terraform validate` after transformations
   - Catches ephemeral context violations
   - Verifies write-only argument pairing
   - Ensures provider support

5. **Test in non-prod first**: Always test migrations in dev/staging
   - Transformations affect state structure
   - May require resource replacement
   - Verify behavior before production

6. **Backup state files**: Keep state backups before changes
   - Use remote state with versioning
   - Test rollback procedures
   - Document recovery steps

7. **Provider compatibility**: Not all providers support these features yet
   - Check support before starting
   - Update providers if needed
   - Consult provider documentation

## Related Skills

- [version-upgrades](https://github.com/thrashr888/hcptf-cli/tree/main/.skills/version-upgrades) - Upgrade Terraform and provider versions first
- [terraform-style-guide](../terraform-style-guide/SKILL.md) - Format modernized code
- [terraform-test](../terraform-test/SKILL.md) - Test modernized configurations

## References

**Official Documentation:**
- [Ephemeral Resources](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral)
- [Write-only Arguments](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/write-only)
- [Ephemeral Resources (Block Reference)](https://developer.hashicorp.com/terraform/language/resources/ephemeral)
- [AWS Provider Ephemeral Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/ephemeral-resources)

**Blog Posts:**
- [Introducing Ephemeral Resources (Terraform 1.10)](https://www.hashicorp.com/blog/terraform-1-10-adds-ephemeral-resources)
- [Write-only Arguments (Terraform 1.11)](https://www.hashicorp.com/blog/terraform-1-11-write-only-arguments)
