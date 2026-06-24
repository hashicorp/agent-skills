# Migration Patterns

Read only the section(s) matching your scan findings. All three patterns share the same input
variable shape and conditional consumer approach — only the resource/block types differ.

---

## ephemeral-creates — resource → ephemeral block

Replace a secret-generating `resource` block with an `ephemeral` block. The resource leaves
state via a `removed` block; existing users pass their extracted value as an ephemeral variable.

### Original

```hcl
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

### variables.tf — add variables

```hcl
variable "tls_private_key_data" {
  description = "Deprecated variable. Contains private key PEM from 1 time migration. Set only when migrating existing deployments to remove secret from state. Leave null for new deployments which will generate their own private key data."
  type        = string
  ephemeral   = true
  sensitive   = true
  default     = null
}

variable "secret_version" {
  description = "Increment to trigger a re-write of the write-only secret. Shared across all write-only attributes in this module — add once, not per resource."
  type        = number
  default     = 1
}
```

### main.tf — replace resource

```hcl
removed {
  lifecycle {
    destroy = false
  }
  from = tls_private_key.this
}

ephemeral "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

### Consumer — conditional write-only

```hcl
resource "vault_kv_secret_v2" "example" {
  mount = "kvv2"
  name  = "mytls"

  data_json_wo = var.tls_private_key_data != null ? jsonencode(
    { private_key = var.tls_private_key_data }) : jsonencode(
    { private_key = ephemeral.tls_private_key.this.private_key_pem })

  data_json_wo_version = var.secret_version
}
```

Name the input variable `<resource_type>_data`. Use `var.<resource_type>_data != null` as the conditional guard on every consumer.

---

## ephemeral-retrieves — data source → ephemeral block

Replace a secret-reading `data` block with an `ephemeral` block. Add an ephemeral input variable
so existing users can pass their extracted value on the first apply.

### Original

```hcl
data "vault_kv_secret_v2" "creds" {
  mount = "secret"
  name  = "db"
}
```

### variables.tf — add variable

```hcl
variable "vault_secret_data" {
  description = "Legacy secret data. Set only when migrating existing deployments. Leave null for new deployments."
  type        = string
  ephemeral   = true
  sensitive   = true
  default     = null
}
```

### main.tf — replace data source

```hcl
removed {
  lifecycle {
    destroy = false
  }
  from = data.vault_kv_secret_v2.creds
}

ephemeral "vault_kv_secret_v2" "creds" {
  mount = "secret"
  name  = "db"
}
```

### Consumer — conditional local

```hcl
locals {
  db_password = var.vault_secret_data != null ? var.vault_secret_data : ephemeral.vault_kv_secret_v2.creds.data["password"]
}
```

Name the input variable `<data_source_type>_data`. Use `var.<data_source_type>_data != null` as the guard.

---

## write-only — add write-only attribute

For resources with `_wo` attribute equivalents: replace the plain attribute with the write-only
version and add a version counter. The resource itself stays — no `removed` block needed.

### Original

```hcl
resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.example.id
  secret_string = some_value
}
```

### variables.tf — add variables

```hcl
variable "secret_string_data" {
  description = "Legacy secret string. Set only when migrating existing deployments."
  type        = string
  ephemeral   = true
  sensitive   = true
  default     = null
}

variable "secret_version" {
  description = "Increment to trigger a re-write of the write-only secret. Shared across all write-only attributes in this module — add once, not per resource."
  type        = number
  default     = 1
}
```

### main.tf — update resource

```hcl
resource "aws_secretsmanager_secret_version" "example" {
  secret_id = aws_secretsmanager_secret.example.id

  secret_string_wo         = var.secret_string_data != null ? var.secret_string_data : ephemeral.tls_private_key.this.private_key_pem
  secret_string_wo_version = var.secret_version
}
```

Use the `write_only{}` map from the ephemerality JSON to find the correct `_wo` attribute name.
Name the input variable `<attribute_name>_data`. `secret_version` is shared — add it once per module.
