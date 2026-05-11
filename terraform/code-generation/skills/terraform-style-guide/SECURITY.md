---
name: terraform-style-guide-security
description: Generate Terraform HCL code following HashiCorp's security practices
---

# Terraform Style Guide - Security

When generating code, apply security hardening:

- Enable encryption at rest by default
- Configure private networking where applicable
- Apply principle of least privilege for security groups
- Enable logging and monitoring
- Never hardcode credentials or secrets
- Mark sensitive outputs with `sensitive = true`
- Use `ephemeral` resources and write-only attributes
  for sensitive data when possible

## Example: Secure S3 Bucket

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "${var.project}-${var.environment}-data"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## Ephemeral resources

Ephemeral resources prevent sensitive data being stored in state.
For more information on ephemeral resources, see the
[Terraform documentation](https://developer.hashicorp.com/terraform/language/block/ephemeral).

Before you generate code for an ephemeral resource, check that the Terraform
version is greater than or equal to 1.11.0.

Then, follow this priority order for managing sensitive attributes:

1. **First priority: Native secrets manager integration**
   If a resource has the ability to automatically manage a sensitive attribute by
   storing it in a secrets manager (e.g., AWS Secrets Manager, Azure Key Vault),
   use that configuration. This is the preferred approach.

   ```hcl
   # Bad
   resource "aws_rds_cluster" "example" {
     cluster_identifier = "example"
     database_name      = "test"
     master_username    = "test"
     master_password    = var.db_master_password
   }

   # Good, managed by AWS Secrets Manager by default
   resource "aws_rds_cluster" "test" {
     cluster_identifier          = "example"
     database_name               = "test"
     manage_master_user_password = true
     master_username             = "test"
   }
   ```

2. **Second priority: Write-only attributes with ephemeral resources**
   If a resource has a write-only attribute but no native secrets manager integration,
   use an `ephemeral` resource for the sensitive data and pass that to the write-only
   attribute. Default the write-only version to 1.

   ```hcl
   # Bad
   resource "random_password" "password" {
     length           = 16
     special          = true
     override_special = "!#$%&*()-_=+[]{}<>:?"
   }
 
   resource "vault_kv_secret_v2" "example" {
     mount               = vault_mount.kvv2.path
     name                = "secret"
 
     data_json = jsonencode(
       {
         password = "${random_password.password.result}",
       }
     )
   }
 
   # Good
   ephemeral "random_password" "password" {
     length           = 16
     special          = true
     override_special = "!#$%&*()-_=+[]{}<>:?"
   }
 
   resource "vault_kv_secret_v2" "example" {
     mount               = vault_mount.kvv2.path
     name                = "secret"
 
     data_json_wo = jsonencode(
       {
         password = "${ephemeral.random_password.password.result}",
       }
     )
     data_json_wo_version = 1
   }
   ```

   If you need to retrieve a secret from a secrets manager to pass
   to a resource, use the `ephemeral` version of the resource to
   retrieve the secret and pass it to another resource.
   
   ```hcl
   # Good
   ephemeral "vault_kv_secret_v2" "db_secret" {
     mount = vault_mount.kvv2.path
     mount_id = vault_mount.kvv2.id
     name = vault_kv_secret_v2.db_root.name
   }
   
   resource "vault_database_secret_backend_connection" "postgres" {
     backend       = vault_mount.db.path
     name          = "postrgres-db"
     allowed_roles = ["*"]
   
     postgresql {
       connection_url = "postgresql://{{username}}:{{password}}@localhost:5432/postgres"
       password_authentication = ""
       username = "postgres"
       password_wo = tostring(ephemeral.vault_kv_secret_v2.db_secret.data.password)
       password_wo_version = 1
     }
   }
   ```

3. **Last resort: Regular resources**
   Only use a regular resource that has sensitive data written to state if neither of the above
   options are available, resource does not offer a write-only attribute or ephemeral resource
   alternative, or the Terraform version is less than 1.11.0.