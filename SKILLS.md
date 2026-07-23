# Skill Catalog

Each lifecycle value comes from the corresponding `SKILL.md` frontmatter.
`active` means the Skill is maintained, distributed, and recommended for normal
use. Other governed states are `deprecation-candidate`, `deprecated`, and
`retired`.

| Product | Skill | Lifecycle | Installation path |
| --- | --- | --- | --- |
| Packer | `aws-ami-builder` | `active` | `plugins/packer/skills/aws-ami-builder` |
| Packer | `azure-image-builder` | `active` | `plugins/packer/skills/azure-image-builder` |
| Packer | `push-to-registry` | `active` | `plugins/packer/skills/push-to-registry` |
| Packer | `windows-builder` | `active` | `plugins/packer/skills/windows-builder` |
| Terraform | `azure-verified-modules` | `active` | `plugins/terraform/skills/azure-verified-modules` |
| Terraform | `new-terraform-provider` | `active` | `plugins/terraform/skills/new-terraform-provider` |
| Terraform | `provider-actions` | `active` | `plugins/terraform/skills/provider-actions` |
| Terraform | `provider-configuration` | `active` | `plugins/terraform/skills/provider-configuration` |
| Terraform | `provider-docs` | `active` | `plugins/terraform/skills/provider-docs` |
| Terraform | `provider-ephemeral-resources` | `active` | `plugins/terraform/skills/provider-ephemeral-resources` |
| Terraform | `provider-framework-migration` | `active` | `plugins/terraform/skills/provider-framework-migration` |
| Terraform | `provider-resources` | `active` | `plugins/terraform/skills/provider-resources` |
| Terraform | `provider-test-patterns` | `active` | `plugins/terraform/skills/provider-test-patterns` |
| Terraform | `refactor-module` | `active` | `plugins/terraform/skills/refactor-module` |
| Terraform | `run-acceptance-tests` | `active` | `plugins/terraform/skills/run-acceptance-tests` |
| Terraform | `terraform-policy` | `active` | `plugins/terraform/skills/terraform-policy` |
| Terraform | `terraform-search-import` | `active` | `plugins/terraform/skills/terraform-search-import` |
| Terraform | `terraform-stacks` | `active` | `plugins/terraform/skills/terraform-stacks` |
| Terraform | `terraform-style-guide` | `active` | `plugins/terraform/skills/terraform-style-guide` |
| Terraform | `terraform-test` | `active` | `plugins/terraform/skills/terraform-test` |

Install one entry with:

```bash
npx skills add hashicorp/agent-skills/<installation-path>
```

`CODEOWNERS` is the canonical ownership source. Retired Skills must be removed
from this active catalog and every installation and distribution path.
