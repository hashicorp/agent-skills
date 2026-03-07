# Write-only Arguments Reference

Comprehensive guide to Terraform write-only arguments.

## What are Write-only Arguments?

Write-only arguments are resource arguments that accept sensitive values but do not store them in state or plan files. They use a special `_wo` suffix naming convention and require version tracking.

**Available since:** Terraform 1.11.0

## How They Work

```
1. You pass a value to a _wo argument
2. Terraform sends value to provider
3. Provider applies the value
4. Terraform discards the value (never stored)
5. State contains only the _wo_version, not the value
```

On subsequent runs, Terraform cannot detect if the value changed. You must increment `_wo_version` to trigger updates.

## Syntax

Write-only arguments require **two** arguments:

1. The write-only argument (`<name>_wo`)
2. The version tracker (`<name>_wo_version`)

```hcl
resource "provider_resource_type" "name" {
  argument_wo         = "sensitive-value"
  argument_wo_version = 1  # Increment to trigger updates
}
```

**Example:**
```hcl
resource "aws_db_instance" "main" {
  identifier          = "mydb"
  password_wo         = var.db_password
  password_wo_version = 1
}
```

## When to Use Write-only Arguments

### ✅ Good Use Cases

1. **Database Credentials**
   - RDS passwords
   - ElastiCache auth tokens
   - Database connection strings

2. **API Keys and Tokens**
   - Service API keys
   - Authentication tokens
   - Bearer tokens

3. **Private Keys**
   - SSH private keys
   - TLS private keys
   - Encryption keys

4. **Sensitive Configuration**
   - Webhook secrets
   - Integration credentials
   - Service passwords

### ❌ Not Suitable When

1. **Need to Read Value Later**
   - Values for use in other resources
   - Values needed in outputs
   - Values for conditional logic

2. **Value Managed by Provider**
   - Provider-generated IDs
   - Auto-assigned attributes
   - Computed values

3. **Non-sensitive Data**
   - Resource names, tags
   - Configuration options
   - Public information

## Naming Convention

Write-only arguments use `_wo` suffix and require matching `_wo_version`:

| Regular Argument | Write-only Equivalent | Version Tracker |
|-----------------|----------------------|-----------------|
| `password` | `password_wo` | `password_wo_version` |
| `api_key` | `api_key_wo` | `api_key_wo_version` |
| `private_key` | `private_key_wo` | `private_key_wo_version` |
| `token` | `token_wo` | `token_wo_version` |

## Version Tracking

The `_wo_version` argument is crucial for triggering updates.

### How Version Tracking Works

```hcl
resource "aws_db_instance" "main" {
  password_wo         = var.db_password
  password_wo_version = 1  # Initial creation
}

# Later, when password changes:
resource "aws_db_instance" "main" {
  password_wo         = var.db_password  # New value
  password_wo_version = 2  # Incremented - triggers update!
}
```

**Why needed:** Terraform can't compare write-only values (they're not in state), so it can't detect changes. The version number is the signal.

### Version Number Rules

1. **Start with 1** - Initial value should be 1, not 0
2. **Increment to update** - Increase by 1 each time value changes
3. **Any integer works** - Can use timestamps, build numbers, etc.
4. **Must change** - If version doesn't change, value won't update

```hcl
# ✅ Good versioning strategies
password_wo_version = 1    # Simple incrementing
password_wo_version = 2
password_wo_version = 3

password_wo_version = 20250306  # Date-based
password_wo_version = 20250307

# ❌ Bad - version not changed
password_wo         = "new-password"
password_wo_version = 1  # Same as before - no update!
```

## Value Sources

Write-only arguments can accept values from various sources:

### 1. Variables (most common)

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_instance" "main" {
  password_wo         = var.db_password
  password_wo_version = 1
}
```

### 2. Ephemeral Resources (recommended for secrets)

```hcl
ephemeral "random_password" "db" {
  length = 16
}

resource "aws_db_instance" "main" {
  password_wo         = ephemeral.random_password.db.result
  password_wo_version = 1
}
```

### 3. Ephemeral Data Sources

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod-db-password"
}

resource "aws_db_instance" "main" {
  password_wo         = ephemeral.aws_secretsmanager_secret_version.db_password.secret_string
  password_wo_version = 1
}
```

### 4. Local Values

```hcl
locals {
  api_token = sensitive("secret-token-value")
}

resource "datadog_api_key" "api" {
  key_wo         = local.api_token
  key_wo_version = 1
}
```

## Provider Support

Not all providers or resources support write-only arguments yet. Check support:

```bash
./scripts/check_writeonly_support.sh aws
./scripts/check_writeonly_support.sh aws aws_db_instance
```

### AWS Provider (hashicorp/aws >= 5.70)

Common resources with write-only arguments:
- `aws_db_instance` - `password_wo`, `master_user_secret_kms_key_id_wo`
- `aws_elasticache_cluster` - `auth_token_wo`
- `aws_secretsmanager_secret_version` - `secret_string_wo`, `secret_binary_wo`

### Azure Provider (hashicorp/azurerm >= 4.0)

- `azurerm_mssql_server` - `administrator_login_password_wo`
- `azurerm_postgresql_server` - `administrator_login_password_wo`

### GCP Provider (hashicorp/google >= 6.0)

- `google_sql_user` - `password_wo`

## Migration Examples

### Example 1: Database Password

**Before:**
```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_instance" "main" {
  identifier = "mydb"
  password   = var.db_password  # Stored in state
}
```

**After:**
```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_instance" "main" {
  identifier          = "mydb"
  password_wo         = var.db_password  # Not stored in state
  password_wo_version = 1
}
```

**State changes:**
- Before: State contains encrypted password value
- After: State contains only `password_wo_version = 1`

### Example 2: Generated Password with Ephemeral

**Before:**
```hcl
resource "random_password" "db" {
  length  = 16
  special = true
}

resource "aws_db_instance" "main" {
  identifier = "mydb"
  password   = random_password.db.result  # Both stored in state
}
```

**After:**
```hcl
ephemeral "random_password" "db" {
  length  = 16
  special = true
}

resource "aws_db_instance" "main" {
  identifier          = "mydb"
  password_wo         = ephemeral.random_password.db.result  # Nothing in state
  password_wo_version = 1
}
```

**Benefits:**
- Password not in random_password state
- Password not in aws_db_instance state
- Completely removed from state file

### Example 3: API Key Rotation

**Scenario:** Need to rotate API key every 90 days

```hcl
variable "api_key_version" {
  type        = number
  description = "Increment this to rotate the API key"
  default     = 1
}

ephemeral "aws_secretsmanager_secret_version" "api_key" {
  secret_id = "prod-api-key"
}

resource "datadog_api_key" "monitoring" {
  name           = "prod-monitoring-${var.api_key_version}"
  key_wo         = ephemeral.aws_secretsmanager_secret_version.api_key.secret_string
  key_wo_version = var.api_key_version
}
```

**To rotate:**
1. Update secret in Secrets Manager
2. Increment `api_key_version` variable: `default = 2`
3. Run `terraform apply`

## Common Errors

### Error: "unknown argument password_wo"

**Cause:** Provider doesn't support write-only arguments for this resource.

**Check:**
```bash
./scripts/check_writeonly_support.sh aws aws_db_instance
```

**Solutions:**
1. Update provider to newer version
2. Check provider documentation
3. Use regular argument (less secure)

### Error: "missing required argument password_wo_version"

**Cause:** Every `_wo` argument requires matching `_wo_version`.

**Wrong:**
```hcl
resource "aws_db_instance" "main" {
  password_wo = var.db_password  # ❌ Missing version
}
```

**Correct:**
```hcl
resource "aws_db_instance" "main" {
  password_wo         = var.db_password
  password_wo_version = 1  # ✅ Version provided
}
```

### Error: "both password and password_wo cannot be set"

**Cause:** Cannot use both regular and write-only versions of same argument.

**Wrong:**
```hcl
resource "aws_db_instance" "main" {
  password            = var.old_password    # ❌ Conflicting
  password_wo         = var.new_password    # ❌ Conflicting
  password_wo_version = 1
}
```

**Correct:** Choose one
```hcl
resource "aws_db_instance" "main" {
  password_wo         = var.password  # ✅ Use write-only
  password_wo_version = 1
}
```

### Value Not Updating

**Symptom:** Changed password but resource not updating.

**Cause:** Forgot to increment `_wo_version`.

**Solution:**
```hcl
resource "aws_db_instance" "main" {
  password_wo         = var.new_password
  password_wo_version = 2  # Increment from 1 to 2
}
```

## Best Practices

1. **Always pair with version** - Never use `_wo` without `_wo_version`

2. **Use with ephemeral sources** - Maximum security: ephemeral + write-only

3. **Increment version on changes** - Document when/why version was incremented

4. **Start with version 1** - Not 0, makes incrementing clearer

5. **Use semantic versioning** - Can use dates, build numbers, etc.

6. **Document rotation procedures** - How to update passwords/keys

7. **Test in non-prod first** - Verify behavior before production

8. **Keep external records** - Write-only values can't be retrieved from state

## State Management

### What's in State

**With regular arguments:**
```json
{
  "password": "super-secret-password",
  "username": "admin"
}
```

**With write-only arguments:**
```json
{
  "password_wo_version": 1,
  "username": "admin"
}
```

Note: `password_wo` value is NOT in state.

### State Migration

When migrating to write-only, Terraform will:

1. Remove old password value from state
2. Add `password_wo_version` to state
3. Resource may require replacement (check plan)

Always review plan carefully before applying.

## Combination Patterns

### Pattern: Ephemeral + Write-only

Maximum security - nothing in state:

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod-db-password"
}

resource "aws_db_instance" "main" {
  password_wo         = ephemeral.aws_secretsmanager_secret_version.db_password.secret_string
  password_wo_version = 1
}
```

Result:
- Secret not in ephemeral state ✓
- Secret not in aws_db_instance state ✓
- Completely removed from Terraform state ✓

### Pattern: Multiple Write-only Arguments

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = "prod-db-creds"
}

locals {
  db_creds = jsondecode(ephemeral.aws_secretsmanager_secret_version.db_creds.secret_string)
}

resource "aws_db_instance" "main" {
  username_wo         = local.db_creds.username
  username_wo_version = 1
  password_wo         = local.db_creds.password
  password_wo_version = 1
}
```

### Pattern: Rotation Tracking

```hcl
variable "password_rotation_date" {
  type        = string
  description = "Date of last password rotation (YYYYMMDD)"
  default     = "20250306"
}

resource "aws_db_instance" "main" {
  password_wo         = var.db_password
  password_wo_version = parseint(var.password_rotation_date, 10)
}
```

Benefits:
- Version number is meaningful
- Easy to track rotation history
- Audit trail in version control

## Related Documentation

- [Ephemeral Resources](ephemeral-resources.md)
- [Ephemeral Contexts](ephemeral-contexts.md)
- [Migration Patterns](migration-patterns.md)
- [Official Terraform Docs](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/write-only)
