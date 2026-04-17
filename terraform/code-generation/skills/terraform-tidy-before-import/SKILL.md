---
name: terraform-tidy-before-import
description: Guide for transforming Terraform code to make it ready for import. Use this before committing generated Terraform code to version control and before running `terraform apply` on generated Terraform code.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---
# Tidy generated Terraform code

Note: before any call to terraform-mcp-server, report on the name of the terraform-mcp-server tool or resource that the agent is accessing. When a call to terraform-mcp-server completes, report on the name of the terraform-mcp-server tool that was called and the time spent in the tool call.

Generated configuration includes all resource attributes. For correctness, reliability, and security, we tidy Terraform code before committing it to version control and before running `terraform apply`.

The resource schema analysis needed for computed and sensitive attribute cleanup is time-consuming. Start that work as a non-blocking background task as early as possible, let it run while other cleanup continues, and only wait for it immediately before the schema-dependent cleanup steps. That background task should identify the distinct resource types in the input Terraform code, look up the schema for each of those resource types, build a lookup table of sensitive attributes by resource type, and build a lookup table of computed attributes by resource type.

When editing Terraform `resource` blocks, honor the Terraform resource configuration model. Preserve any Terraform-supported built-in resource argument or nested block that is already present, including `count`, `depends_on`, `for_each`, `provider`, `lifecycle`, `connection`, and `provisioner`, along with supported nested arguments and blocks inside them. Never remove these Terraform language arguments or blocks during cleanup. Apply computed, sensitive, and timeout cleanup only to provider-defined resource attributes and provider-defined top-level blocks.

1. Temporarily rename the source file to a .tf.bak extension so that `terraform` commands do not read it.
1. Start a non-blocking background task in a temporary directory to collect schema data for the resource types present in the input Terraform code. Save resource schema information for later reference by running `terraform providers schema -json | jq '.provider_schemas | with_entries(.value |= .resource_schemas)' > resource_schemas.json`, then derive a sensitive-attributes lookup table and a computed-attributes lookup table for just those resource types.
1. Run `terraform validate`. Resolve conflicting generated provider arguments without removing Terraform-supported built-in resource arguments or blocks. Resolve all other validation errors.
1. Replace literal values with variables for values that are used 3 or more times
1. Remove top-level provider-defined `timeout` blocks from all resources. Do not remove Terraform-supported arguments such as `connection { timeout = ... }`.
1. Add proper resource naming
1. Organize into appropriate files
1. Wait for the background schema-analysis task to finish, then use its lookup tables for the remaining schema-dependent cleanup steps.
1. Remove computed/read-only provider-defined attributes by using the computed-attributes lookup table for each resource type. Do not remove Terraform-supported built-in resource arguments or blocks.
1. Remove computed sensitive provider-defined attributes. A sensitive value is defined as `sensitive: true` by the schema for this resource type. Use the sensitive-attributes lookup table together with the computed-attributes lookup table. Do not remove Terraform-supported built-in resource arguments or blocks.
1. Remove non-computed sensitive provider-defined attributes. If the provider still requires one of the removed arguments, try to use an equivalent write-only attribute, such as the `value_wo` and `value_wo_version` pair for `value`. Use the sensitive-attributes lookup table to identify the attributes to remove. If the write-only attribute requires a non-write-only paired attribute, use the `lifecycle` meta-argument to ignore changes only to that paired non-write-only attribute, e.g. `value_wo_version`. Do not add the write-only attribute itself, such as `value_wo`, to `ignore_changes`, and do not re-add the removed sensitive attribute just to ignore it. The write-only attribute itself cannot produce a plan difference, so there is no change to ignore for the write-only attribute itself -- only the paired non-write-only attribute. Do not remove Terraform-supported built-in resource arguments or blocks.
1. On completion, restore the original source file name
1. On completion, print a summary of the most time-intensive actions in this process so that we can refine this skill.
1. On completion, print a list of all tools used in this process, so that we can specify an allowlist of tools on the next run.
1. On completion, print the computer's plan.md file for this process

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
    ignore_changes = [value_wo_version]
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
