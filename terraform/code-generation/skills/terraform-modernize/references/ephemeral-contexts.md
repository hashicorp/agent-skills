# Ephemeral Contexts Reference

Comprehensive guide to where ephemeral values can and cannot be used in Terraform configurations.

## What are Ephemeral Contexts?

Ephemeral contexts are specific locations in Terraform configurations where ephemeral values are permitted. Because ephemeral values don't persist in state, Terraform restricts where they can be referenced.

**Rule:** Ephemeral values can ONLY be used in ephemeral contexts.

## Valid Ephemeral Contexts

### 1. Write-only Arguments

Write-only arguments (attributes ending in `_wo`) are ephemeral contexts.

```hcl
ephemeral "random_password" "db" {
  length = 16
}

resource "aws_db_instance" "main" {
  password_wo         = ephemeral.random_password.db.result  # ✅ Valid
  password_wo_version = 1
}
```

### 2. Other Ephemeral Blocks

Ephemeral resources can reference other ephemeral resources.

```hcl
ephemeral "aws_secretsmanager_secret" "root" {
  name = "root-secret"
}

ephemeral "aws_secretsmanager_secret_version" "root_version" {
  secret_id = ephemeral.aws_secretsmanager_secret.root.id  # ✅ Valid
}
```

### 3. Provider Configuration Blocks

Provider blocks can use ephemeral values for dynamic authentication.

```hcl
ephemeral "aws_eks_cluster_auth" "cluster" {
  name = "my-cluster"
}

provider "kubernetes" {
  host  = data.aws_eks_cluster.cluster.endpoint
  token = ephemeral.aws_eks_cluster_auth.cluster.token  # ✅ Valid
}
```

### 4. Ephemeral Outputs

Outputs marked with `ephemeral = true` can contain ephemeral values.

```hcl
ephemeral "random_password" "temp" {
  length = 16
}

output "temporary_password" {
  value     = ephemeral.random_password.temp.result  # ✅ Valid
  ephemeral = true  # REQUIRED
  sensitive = true  # Recommended
}
```

### 5. Ephemeral Input Variables

Input variables marked with `ephemeral = true` can accept and pass ephemeral values.

```hcl
variable "db_password" {
  type      = string
  ephemeral = true  # Marks this variable as ephemeral
  sensitive = true
}

# Can pass ephemeral value to this variable
# terraform apply -var="db_password=$(get-secret)"

resource "aws_db_instance" "main" {
  password_wo         = var.db_password  # ✅ Valid - variable is ephemeral
  password_wo_version = 1
}
```

**Note:** Ephemeral variables behave like ephemeral resources - they can only be used in ephemeral contexts.

## Invalid (Non-ephemeral) Contexts

### 1. Regular Resource Arguments

```hcl
ephemeral "random_password" "db" {
  length = 16
}

resource "aws_db_instance" "main" {
  password = ephemeral.random_password.db.result  # ❌ ERROR
}
```

**Solution:** Use write-only argument.

### 2. Regular Outputs

```hcl
output "db_password" {
  value = ephemeral.random_password.db.result  # ❌ ERROR
}
```

**Solution:** Mark output as ephemeral with `ephemeral = true`.

### 3. Data Sources

```hcl
data "aws_instance" "app" {
  filter {
    values = [ephemeral.random_string.suffix.result]  # ❌ ERROR
  }
}
```

### 4. depends_on

```hcl
resource "aws_instance" "app" {
  depends_on = [ephemeral.random_password.db]  # ❌ ERROR
}
```

**Solution:** Use implicit dependencies through regular resources.

## Validation

Always validate after using ephemeral values:

```bash
terraform validate
```

## Related Documentation

- [Ephemeral Resources](ephemeral-resources.md)
- [Write-only Arguments](write-only-arguments.md)
- [Migration Patterns](migration-patterns.md)
