---
name: terraform-tidy-before-import
description: Prepares Terraform code for safe and correct import. Resolves validation errors, sensitive attributes, and computed attributes. De-duplicates literal values. Use this before committing generated Terraform code to version control and before importing resources into Terraform.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---
# Tidy generated Terraform code

Generated Terraform configuration includes all resource attributes. For
correctness, reliability, and security, we tidy Terraform code before we commit
it to version control and before we run `terraform apply`.

The user may specify a priority of either speed or thoroughness. Default to
thoroughness. If the user prioritizes speed, then skip all schema-dependent
work and simply use `terraform validate` as a feedback loop to converge on a
validatable configuration.

When editing Terraform `resource` blocks, honor the Terraform resource
configuration model. Preserve any Terraform-supported built-in resource
argument or nested block that is already present, including `count`,
`depends_on`, `for_each`, `provider`, `lifecycle`, `connection`, and
`provisioner`, along with supported nested arguments and blocks inside them.
Never remove these Terraform language arguments or blocks during cleanup.

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


1. Temporarily rename the source file to a .tf.bak extension so that
   `terraform` commands do not read it.
1. Start a non-blocking background task in a temporary directory to build
   resource schema lookup tables, as detailed in
   [resource-schema-lookup-tables.md](references/resource-schema-lookup-tables.md).
1. Run `terraform validate`. Resolve conflicting generated provider arguments
   without removing Terraform-supported built-in resource arguments or blocks.
   Resolve all other validation errors.
1. Replace literal values with variables for values that are used 3 or more
   times
1. Remove top-level provider-defined `timeouts` blocks from all resources.
1. Wait for the background schema-analysis task to finish, then use its lookup
   tables for the remaining schema-dependent cleanup steps.
1. Remove provider-defined attributes that are `computed` and not `optional` by
   using the computed-attributes lookup table for each resource type. Preserve
   provider-defined attributes that are both `computed` and `optional`, unless
   the configuration explicitly sets them to `null`; in that case, remove the
   null-valued argument.
1. Remove non-computed sensitive provider-defined attributes. If the provider
   requires one of the removed arguments, try to use an equivalent
   write-only attribute, such as the `value_wo` and `value_wo_version` pair for
   `value`. If the write-only attribute requires a non-write-only
   paired attribute, use the `lifecycle` meta-argument to ignore changes only
   to that paired non-write-only attribute, e.g. `value_wo_version`.
1. Run `terraform validate` as the final validation step. Make a best effort to
   resolve errors before continuing.
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

# After: tidied
resource "aws_instance" "all_0" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
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
