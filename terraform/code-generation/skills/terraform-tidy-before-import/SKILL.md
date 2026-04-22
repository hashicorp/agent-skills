---
name: terraform-tidy-before-import
description: Guide for transforming Terraform code to make it ready for import. Use this before committing generated Terraform code to version control and before running `terraform apply` on generated Terraform code.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---
# Tidy generated Terraform code

Generated Terraform configuration includes all resource attributes. For
correctness, reliability, and security, we tidy Terraform code before we commit
it to version control and before we run `terraform apply`.

The resource schema analysis needed for computed and sensitive attribute
cleanup is time-consuming, due to the size of the resource schemas. Analysis
needs to use local tools in order to avoid slow model calls. Start that work as
a non-blocking background task as early as possible, let it run while other
cleanup continues, and only wait for it immediately before the schema-dependent
cleanup steps. That background task should identify the distinct `TYPE`
arguments for the `resource` blocks in the input Terraform code, look up the
schema for each resource types, build a lookup table of sensitive attributes by
resource type, and build a lookup table of computed attributes by resource type
that also records whether each computed attribute is optional.

Perform this analysis via a Python script. For future skill optimization, write
this script to the current working directory.

When editing Terraform `resource` blocks, honor the Terraform resource
configuration model. Preserve any Terraform-supported built-in resource
argument or nested block that is already present, including `count`,
`depends_on`, `for_each`, `provider`, `lifecycle`, `connection`, and
`provisioner`, along with supported nested arguments and blocks inside them.
Never remove these Terraform language arguments or blocks during cleanup. Apply
computed, sensitive, and timeout cleanup only to provider-defined resource
attributes and provider-defined top-level blocks. For provider-defined
attributes, remove attributes that are `computed` and not `optional`. Preserve
attributes that are both `computed` and `optional` unless the configuration
explicitly sets them to `null`; in that case, remove the null-valued argument
instead of preserving an explicit `null`.

When editing Terraform `import` blocks, honor the Terraform import
configuration model. If an existing `import` block passes `terraform validate`,
it does not need to be edited. Preserve all Terraform-supported `import` block
arguments, including `to`, `id`, `identity`, `for_each`, and `provider`. Never
remove a valid `import` block or remove the `provider` argument from one.

<parse_terraform_code_using_python_hcl2_and_hq>
Prioritize correctness when parsing Terraform code. To do so, use the
python-hcl2 module in a virtualenv. This module includes the hq command line
tool. Examples:

* Convert to JSON: `hq '*' <input file> --json`
* Identity resource blocks with top-level timeouts: `hq 'resource~[select(.timeouts)] | .labels' <input file>`
* Identity null-valued attributes: `hq '*..attribute:*[select(.value == null)]' <input file>`

Use generic tools such as grep, awk, and sed only as a last resort when parsing Terraform code.
</parse_terraform_code_using_python_hcl2_and_hq>

The user may specify a priority of either speed or thoroughness. Default to
thoroughness. If the user prioritizes speed, then skip all schema-dependent
work and simply use `terraform validate` as a feedback loop to converge on a
validatable configuration.

1. Temporarily rename the source file to a .tf.bak extension so that
   `terraform` commands do not read it.
1. Start a non-blocking background task in a temporary directory to collect
   schema data for the resource types present in the input Terraform code. Save
   resource schema information for later reference by running `terraform
   providers schema -json | jq '.provider_schemas | with_entries(.value |=
   .resource_schemas)' > resource_schemas.json`. Then, trim the JSON structure
   to only the resource types that are present in the input Terraform code.
   Then derive a sensitive-attributes lookup table and a computed-attributes
   lookup table for just those resource types, including whether each computed
   attribute is optional. Never send the entire schema JSON in a model call --
   it is too large and too slow.
1. Run `terraform validate`. Resolve conflicting generated provider arguments
   without removing Terraform-supported built-in resource arguments or blocks.
   Resolve all other validation errors.
1. Replace literal values with variables for values that are used 3 or more
   times
1. Remove top-level provider-defined `timeout` blocks from all resources. Do
   not remove Terraform-supported arguments such as `connection { timeout = ...
   }`.
1. Add proper resource naming
1. Organize into appropriate files
1. Wait for the background schema-analysis task to finish, then use its lookup
   tables for the remaining schema-dependent cleanup steps.
1. Remove provider-defined attributes that are `computed` and not `optional` by
   using the computed-attributes lookup table for each resource type. Preserve
   provider-defined attributes that are both `computed` and `optional`, unless
   the configuration explicitly sets them to `null`; in that case, remove the
   null-valued argument. Do not remove Terraform-supported built-in resource
   arguments or blocks.
1. Apply the same rule to computed sensitive provider-defined attributes:
   remove them only when the schema for this resource type marks them as
   `computed` and not `optional`, or when a `computed`+`optional` attribute is
   explicitly set to `null`. A sensitive value is defined as `sensitive: true`
   by the schema for this resource type. Use the sensitive-attributes lookup
   table together with the computed-attributes lookup table. Do not remove
   Terraform-supported built-in resource arguments or blocks.
1. Remove non-computed sensitive provider-defined attributes. If the provider
   still requires one of the removed arguments, try to use an equivalent
   write-only attribute, such as the `value_wo` and `value_wo_version` pair for
   `value`. Use the sensitive-attributes lookup table to identify the
   attributes to remove. If the write-only attribute requires a non-write-only
   paired attribute, use the `lifecycle` meta-argument to ignore changes only
   to that paired non-write-only attribute, e.g. `value_wo_version`. Do not add
   the write-only attribute itself, such as `value_wo`, to `ignore_changes`,
   and do not re-add the removed sensitive attribute just to ignore it. The
   write-only attribute itself cannot produce a plan difference, so there is no
   change to ignore for the write-only attribute itself -- only the paired
   non-write-only attribute. Do not remove Terraform-supported built-in
   resource arguments or blocks.
1. On completion, restore the original source file name

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
