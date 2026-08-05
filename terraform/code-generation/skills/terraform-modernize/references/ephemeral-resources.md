# Ephemeral Resources Reference

Comprehensive guide to Terraform ephemeral resources.

## What are Ephemeral Resources?

Ephemeral resources are temporary infrastructure components that exist only during the current Terraform operation. Unlike managed resources or data sources, ephemeral resources:

- **Do not persist in state files**
- **Do not appear in plan files**
- **Exist only during plan/apply operations**
- **Are re-evaluated on every Terraform run**

**Available since:** Terraform 1.10.0

## Lifecycle

Ephemeral resources have a unique lifecycle:

```
1. Plan/Apply starts
2. Ephemeral resource is created/read
3. Value is used in ephemeral contexts
4. Plan/Apply completes
5. Ephemeral resource is destroyed (no state saved)
```

On the next Terraform run, the ephemeral resource is recreated fresh.

## Syntax

```hcl
ephemeral "provider_resource_type" "name" {
  # Configuration arguments
  argument1 = "value1"
  argument2 = "value2"
}
```

**Example:**
```hcl
ephemeral "aws_secretsmanager_secret_version" "api_key" {
  secret_id = "prod-api-key"
}

ephemeral "random_password" "database" {
  length  = 16
  special = true
}
```

## When to Use Ephemeral Resources

### ✅ Good Use Cases

1. **Secrets and Credentials**
   - Fetching passwords from secret managers
   - Retrieving API tokens
   - Getting temporary credentials

2. **Short-lived Data**
   - Certificate data for TLS connections
   - Authentication tokens for providers
   - Temporary access keys

3. **Sensitive Information**
   - Data that shouldn't be stored in state
   - Values that change frequently
   - Credentials with short TTLs

4. **Provider Configuration**
   - Dynamic provider authentication
   - EKS cluster credentials
   - Vault tokens

### ❌ Poor Use Cases

1. **Long-lived Infrastructure**
   - VPCs, subnets, security groups
   - S3 buckets, databases
   - Anything that needs to persist

2. **Referenced in Outputs**
   - Unless output is marked `ephemeral = true`
   - Values needed by other tools/scripts

3. **Used in depends_on**
   - Ephemeral resources cannot be dependencies
   - Use implicit dependencies instead

## Ephemeral Contexts

Ephemeral values can **ONLY** be used in these contexts:

### 1. Write-only Arguments

```hcl
ephemeral "random_password" "db" {
  length = 16
}

resource "aws_db_instance" "main" {
  password_wo         = ephemeral.random_password.db.result
  password_wo_version = 1
}
```

### 2. Other Ephemeral Blocks

```hcl
ephemeral "aws_iam_role" "temp_role" {
  name = "temp-role"
}

ephemeral "aws_iam_policy" "temp_policy" {
  role = ephemeral.aws_iam_role.temp_role.name
}
```

### 3. Provider Configuration

```hcl
ephemeral "aws_eks_cluster_auth" "cluster" {
  name = "my-cluster"
}

provider "kubernetes" {
  host  = data.aws_eks_cluster.cluster.endpoint
  token = ephemeral.aws_eks_cluster_auth.cluster.token
}
```

### 4. Ephemeral Outputs

```hcl
ephemeral "random_password" "temp" {
  length = 16
}

output "temp_password" {
  value     = ephemeral.random_password.temp.result
  ephemeral = true  # REQUIRED
  sensitive = true  # Recommended
}
```

## Provider Support

Not all providers support ephemeral resources yet. Support is growing:

### AWS Provider (hashicorp/aws >= 5.70)

Common ephemeral resources:
- `ephemeral.aws_secretsmanager_secret_version` - Secrets Manager secrets
- `ephemeral.aws_eks_cluster_auth` - EKS authentication tokens
- `ephemeral.aws_iam_role` - Temporary IAM roles

### Random Provider (hashicorp/random >= 3.6)

- `ephemeral.random_password` - Generate temporary passwords
- `ephemeral.random_string` - Generate temporary strings
- `ephemeral.random_id` - Generate temporary IDs

### TLS Provider (hashicorp/tls >= 4.0)

- `ephemeral.tls_certificate` - Fetch TLS certificates
- `ephemeral.tls_private_key` - Generate temporary private keys

### Check Support

Use the provided script:
```bash
./scripts/check_ephemeral_support.sh aws
```

## Naming Convention

Providers use consistent naming across resource types:

| Type | Format | Example |
|------|--------|---------|
| Data Source | `data.<type>.<name>` | `data.aws_secretsmanager_secret_version.api_key` |
| Ephemeral | `ephemeral.<type>.<name>` | `ephemeral.aws_secretsmanager_secret_version.api_key` |
| Managed Resource | `<type>` | `aws_secretsmanager_secret_version` (if exists) |

## Migration Examples

### Example 1: Secrets Manager Secret

**Before:**
```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod-db-password"
}

resource "aws_db_instance" "main" {
  identifier = "mydb"
  password   = data.aws_secretsmanager_secret_version.db_password.secret_string
  # ... other config
}
```

**After:**
```hcl
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod-db-password"
}

resource "aws_db_instance" "main" {
  identifier          = "mydb"
  password_wo         = ephemeral.aws_secretsmanager_secret_version.db_password.secret_string
  password_wo_version = 1
  # ... other config
}
```

**Benefits:**
- Password not stored in state
- Secret not in plan files
- Better security posture

### Example 2: Random Password Generation

**Before:**
```hcl
resource "random_password" "api_token" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "token" {
  name  = "/app/api-token"
  type  = "SecureString"
  value = random_password.api_token.result  # Stored in state
}
```

**After:**
```hcl
ephemeral "random_password" "api_token" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "token" {
  name              = "/app/api-token"
  type              = "SecureString"
  value_wo          = ephemeral.random_password.api_token.result  # Not stored
  value_wo_version  = 1
}
```

### Example 3: Provider Authentication

**Before:**
```hcl
data "aws_eks_cluster" "main" {
  name = "my-cluster"
}

data "aws_eks_cluster_auth" "main" {
  name = "my-cluster"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token  # Stored in state
}
```

**After:**
```hcl
data "aws_eks_cluster" "main" {
  name = "my-cluster"
}

ephemeral "aws_eks_cluster_auth" "main" {
  name = "my-cluster"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = ephemeral.aws_eks_cluster_auth.main.token  # Not stored
}
```

## Common Errors

### Error: "ephemeral values cannot be used in this context"

**Cause:** Trying to use ephemeral value in non-ephemeral context.

**Example:**
```hcl
ephemeral "random_password" "db" {
  length = 16
}

resource "aws_db_instance" "main" {
  password = ephemeral.random_password.db.result  # ❌ ERROR
}
```

**Solution:** Use write-only argument:
```hcl
resource "aws_db_instance" "main" {
  password_wo         = ephemeral.random_password.db.result  # ✅ Correct
  password_wo_version = 1
}
```

### Error: "ephemeral resource type not supported"

**Cause:** Provider doesn't support ephemeral version of the resource.

**Check support:**
```bash
./scripts/check_ephemeral_support.sh aws
```

**Solutions:**
1. Update provider to newer version
2. Check provider documentation
3. Use data source instead (less secure)

### Error: "cannot use ephemeral value in output"

**Cause:** Output not marked as ephemeral.

**Wrong:**
```hcl
output "password" {
  value = ephemeral.random_password.db.result  # ❌ ERROR
}
```

**Correct:**
```hcl
output "password" {
  value     = ephemeral.random_password.db.result  # ✅
  ephemeral = true  # Required
  sensitive = true  # Recommended
}
```

## Edge Cases

### Ephemeral with for_each

```hcl
variable "secret_ids" {
  type    = list(string)
  default = ["secret1", "secret2", "secret3"]
}

ephemeral "aws_secretsmanager_secret_version" "secrets" {
  for_each  = toset(var.secret_ids)
  secret_id = each.value
}

# Use in ephemeral context:
resource "aws_instance" "app" {
  for_each = ephemeral.aws_secretsmanager_secret_version.secrets

  user_data_wo         = each.value.secret_string
  user_data_wo_version = 1
}
```

### Ephemeral with count

```hcl
ephemeral "random_password" "passwords" {
  count  = 3
  length = 16
}

# Use in ephemeral context
resource "aws_db_instance" "dbs" {
  count = 3

  password_wo         = ephemeral.random_password.passwords[count.index].result
  password_wo_version = 1
}
```

### Chaining Ephemeral Resources

```hcl
ephemeral "vault_generic_secret" "root" {
  path = "secret/root"
}

ephemeral "vault_generic_secret" "derived" {
  path = ephemeral.vault_generic_secret.root.data["derived_path"]
}

resource "aws_instance" "app" {
  user_data_wo         = ephemeral.vault_generic_secret.derived.data["config"]
  user_data_wo_version = 1
}
```

## Best Practices

1. **Use for sensitive data only** - Ephemeral has restrictions, only use when security benefit justifies complexity

2. **Combine with write-only arguments** - Maximum security when both are used together

3. **Document ephemeral outputs** - Make it clear to consumers that outputs are ephemeral

4. **Test validation** - Always run `terraform validate` after changes

5. **Check provider support** - Use scripts to verify support before starting

6. **Use implicit dependencies** - Avoid explicit depends_on with ephemeral resources

7. **Mark outputs as sensitive** - Ephemeral outputs should usually be sensitive too

## Related Documentation

- [Write-only Arguments](write-only-arguments.md)
- [Ephemeral Contexts](ephemeral-contexts.md)
- [Migration Patterns](migration-patterns.md)
- [Official Terraform Docs](https://developer.hashicorp.com/terraform/language/resources/ephemeral)
