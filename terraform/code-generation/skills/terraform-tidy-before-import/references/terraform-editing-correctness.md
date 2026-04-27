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

