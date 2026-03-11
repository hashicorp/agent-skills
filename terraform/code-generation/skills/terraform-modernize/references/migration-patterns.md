# Migration Patterns

Common patterns for migrating Terraform configurations to use ephemeral resources and write-only arguments.

## Pattern 1: AWS Secrets Manager to Ephemeral + Write-only

### Scenario
Database password stored in AWS Secrets Manager, currently fetched via data source and stored in state.

### Before

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod-db-password"
}

resource "aws_db_instance" "main" {
  identifier     = "production-db"
  engine         = "postgres"
  instance_class = "db.t3.medium"

  username = "admin"
  password = data.aws_secretsmanager_secret_version.db_password.secret_string

  allocated_storage = 100
}
```

**Issues:**
- Password visible in state file
- Password visible in plan output
- Security risk if state file is compromised

### After

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod-db-password"
}

resource "aws_db_instance" "main" {
  identifier     = "production-db"
  engine         = "postgres"
  instance_class = "db.t3.medium"

  username = "admin"
  password_wo         = ephemeral.aws_secretsmanager_secret_version.db_password.secret_string
  password_wo_version = 1

  allocated_storage = 100
}
```

**Benefits:**
- Password not stored in state
- Password not in plan output
- Better security posture

### Migration Steps

1. Check support: `./scripts/check_ephemeral_support.sh aws`
2. Change `data` to `ephemeral`
3. Change `password =` to `password_wo =`
4. Add `password_wo_version = 1`
5. Run `terraform validate`
6. Run `terraform plan` (review changes)
7. Run `terraform apply`

---

## Pattern 2: Generated Password to Ephemeral

### Scenario
Using random_password resource, password stored in state.

### Before

```hcl
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "main" {
  identifier = "mydb"
  password   = random_password.db_password.result
}
```

**Issues:**
- Generated password stored in random_password state
- Password also stored in aws_db_instance state
- Double exposure in state file

### After

```hcl
ephemeral "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "main" {
  identifier          = "mydb"
  password_wo         = ephemeral.random_password.db_password.result
  password_wo_version = 1
}
```

**Benefits:**
- Password not in random_password state (ephemeral)
- Password not in aws_db_instance state (write-only)
- Completely removed from state file

### Migration Steps

1. Change `resource "random_password"` to `ephemeral "random_password"`
2. Update reference to `ephemeral.random_password...`
3. Change `password =` to `password_wo =`
4. Add `password_wo_version = 1`
5. Validate and apply

---

## Pattern 3: Variable-based Password to Write-only

### Scenario
Password passed as variable, stored in state.

### Before

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_instance" "main" {
  identifier = "mydb"
  password   = var.db_password
}
```

**Issues:**
- Password stored in state despite `sensitive = true`
- Sensitive flag only hides from console output

### After

```hcl
variable "db_password" {
  type      = string
  sensitive = true
  ephemeral = true  # Optional: if passing ephemeral value
}

resource "aws_db_instance" "main" {
  identifier          = "mydb"
  password_wo         = var.db_password
  password_wo_version = 1
}
```

**Benefits:**
- Password not stored in state
- Can mark variable as ephemeral if needed

### Migration Steps

1. Change `password =` to `password_wo =`
2. Add `password_wo_version = 1`
3. Optionally add `ephemeral = true` to variable
4. Validate and apply

---

## Pattern 4: Provider Authentication (EKS/Kubernetes)

### Scenario
Using EKS cluster auth token for Kubernetes provider.

### Before

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
  token                  = data.aws_eks_cluster_auth.main.token
}
```

**Issues:**
- Auth token stored in state
- Token may be short-lived but persisted

### After

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
  token                  = ephemeral.aws_eks_cluster_auth.main.token
}
```

**Benefits:**
- Token not stored in state
- Provider blocks are ephemeral contexts
- Token regenerated on each run

### Migration Steps

1. Change `data "aws_eks_cluster_auth"` to `ephemeral "aws_eks_cluster_auth"`
2. Update provider reference
3. Validate and apply

---

## Pattern 5: API Key Rotation

### Scenario
API key that needs periodic rotation.

### Before

```hcl
variable "api_key" {
  type      = string
  sensitive = true
}

resource "datadog_api_key" "monitoring" {
  name = "production-monitoring"
  key  = var.api_key
}
```

**Issues:**
- Key stored in state
- Manual rotation difficult to track

### After

```hcl
variable "api_key_version" {
  type        = number
  description = "Increment to rotate API key"
  default     = 1
}

variable "api_key" {
  type      = string
  sensitive = true
  ephemeral = true
}

resource "datadog_api_key" "monitoring" {
  name           = "production-monitoring-v${var.api_key_version}"
  key_wo         = var.api_key
  key_wo_version = var.api_key_version
}
```

**Benefits:**
- Key not stored in state
- Version tracking for rotation
- Easy to trigger rotation

### Rotation Procedure

1. Update secret in secret manager
2. Increment `api_key_version` variable
3. Run `terraform apply`

---

## Common Combinations

### Ephemeral + Write-only (Maximum Security)

```hcl
ephemeral "aws_secretsmanager_secret_version" "creds" {
  secret_id = "app-credentials"
}

locals {
  credentials = jsondecode(ephemeral.aws_secretsmanager_secret_version.creds.secret_string)
}

resource "aws_db_instance" "main" {
  username_wo         = local.credentials.username
  username_wo_version = 1
  password_wo         = local.credentials.password
  password_wo_version = 1
}
```

### Multiple Ephemeral Sources

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "db-password"
}

ephemeral "aws_secretsmanager_secret_version" "api_key" {
  secret_id = "api-key"
}

resource "aws_db_instance" "main" {
  password_wo         = ephemeral.aws_secretsmanager_secret_version.db_password.secret_string
  password_wo_version = 1
}

resource "datadog_api_key" "api" {
  key_wo         = ephemeral.aws_secretsmanager_secret_version.api_key.secret_string
  key_wo_version = 1
}
```

## Validation Checklist

After each migration:

- [ ] Run `terraform validate` - must pass
- [ ] Review `terraform plan` output
- [ ] Verify no unexpected resource replacements
- [ ] Check ephemeral values only in ephemeral contexts
- [ ] Confirm write-only arguments paired with `_wo_version`
- [ ] Test in non-production environment first
- [ ] Backup state file before applying

## Related Documentation

- [Ephemeral Resources](ephemeral-resources.md)
- [Write-only Arguments](write-only-arguments.md)
- [Ephemeral Contexts](ephemeral-contexts.md)
