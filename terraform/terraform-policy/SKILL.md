---
name: terraform-policy
description: "Write, test, or convert Terraform Policy files (.policy.hcl, .policytest.hcl, Sentinel→tfpolicy). Triggers: policy.hcl, policytest, convert sentinel, tfpolicy, write a policy."
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.1.0"
---

# terraform-policy

**UTILITY SKILL** — INVOKES: [tfpolicy-author](skills/tfpolicy-author/SKILL.md) | [tfpolicy-test](skills/tfpolicy-test/SKILL.md)

## USE FOR:

- Writing a new `.policy.hcl` policy from a description or requirement
- Converting a `.sentinel` policy to Terraform Policy
- Writing or debugging a `.policytest.hcl` test file
- Migrating a Sentinel policy library to Terraform Policy

## DO NOT USE FOR:

- Writing `.tftest.hcl` files for Terraform modules — use `terraform-test`
- General Terraform HCL authoring — use `terraform-style-guide`

## Routing

| Task | Sub-skill |
|------|-----------|
| Write or convert a `.policy.hcl` policy | [tfpolicy-author](skills/tfpolicy-author/SKILL.md) |
| Write or debug a `.policytest.hcl` test | [tfpolicy-test](skills/tfpolicy-test/SKILL.md) |

## Examples

- "Block EC2 instances without encryption" → [tfpolicy-author](skills/tfpolicy-author/SKILL.md)
- "Convert this Sentinel policy to tfpolicy" → [tfpolicy-author](skills/tfpolicy-author/SKILL.md)
- "Write a policytest for my EBS policy" → [tfpolicy-test](skills/tfpolicy-test/SKILL.md)

## Troubleshooting

- **Wrong skill triggered?** Load the sub-skill directly from the routing table above.

```bash
npx skills add hashicorp/agent-skills/terraform/terraform-policy/skills/tfpolicy-author
npx skills add hashicorp/agent-skills/terraform/terraform-policy/skills/tfpolicy-test
```
