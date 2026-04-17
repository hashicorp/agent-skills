---
name: terraform-tidy-before-import
description: Guide for transforming Terraform code to make it ready for import. Use this before committing generated Terraform code to version control and before running `terraform apply` on generated Terraform code.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---
# Tidy generated Terraform code

Generated configuration includes all resource attributes. For correctness, reliability, and security, we tidy Terraform code before committing it to version control and before running `terraform apply`.

1. Remove computed/read-only attributes
1. Replace hardcoded values with variables
1. Remove computed sensitive values
1. Remove non-computed sensitive values. If the provider still requires one of the removed arguments, use an equivalent write-only attribute, such as `value_wo` for `value`. Use the `lifecycle` meta-argument to ignore changes to these sensitive attributes.
1. Remove top-level `timeout` blocks from all resources.
1. Run `terraform validate` and resolve conflicting generated arguments.
1. Add proper resource naming
1. Organize into appropriate files

```hcl
# Before: generated
resource "aws_instance" "all_0" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  arn                    = "arn:aws:ec2:..."  # Remove - computed
  id                     = "i-0abc123"        # Remove - computed
  # ... many more attributes
}

resource "aws_ssm_parameter" "all_0" {
  type = "SecureString"
  name = "AccessCode"
  value = "secret" # Remove - sensitive
}

# After: cleaned
resource "aws_instance" "web_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  
  tags = {
    Name        = "web-server"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "access_code" {
  type             = "SecureString"
  name             = "AccessCode"
  value_wo         = "__imported__"
  value_wo_version = 1

  lifecycle {
    ignore_changes = [value, value_wo, value_wo_version]
  }
}
```

## Import by Identity

Generated imports use identity-based import (Terraform 1.12+):

```hcl
import {
  to       = aws_instance.web
  provider = aws
  identity = {
    account_id = "123456789012"
    id         = "i-0abc123"
    region     = "us-west-2"
  }
}
```
