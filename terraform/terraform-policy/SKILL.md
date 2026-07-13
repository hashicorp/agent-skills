---
name: terraform-policy
description: >
  Routes Terraform Policy tasks to the right focused sub-skill. Use for authoring
  .policy.hcl files, writing .policytest.hcl tests, or converting Sentinel
  policies to Terraform Policy. Trigger phrases: "write a policy", "terraform policy",
  "policy.hcl", "policytest", "convert sentinel", "tfpolicy".
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.1.0"
  deprecated: true
  superseded_by:
    - skills/tfpolicy-author/SKILL.md
    - skills/tfpolicy-test/SKILL.md
    - skills/sentinel-to-tfpolicy/SKILL.md
---

# terraform-policy (router)

**Routes to the right Terraform Policy sub-skill based on the user's task.**

> **This file is a router**, not a full skill. It exists so loaders that
> read a single root `SKILL.md` keep working. Loaders that glob
> `**/SKILL.md` should prefer the three focused sub-skills under
> [`skills/`](skills/tfpolicy-author/SKILL.md) and may ignore this file.

## USE FOR

- Writing a new `.policy.hcl` policy from a requirement or description
- Converting a Sentinel `.sentinel` policy to Terraform Policy (`.policy.hcl`)
- Writing or debugging a `.policytest.hcl` test file
- Asking about `core::` functions, `operations`, `prior_attrs`, or `input` blocks
- Migrating a Sentinel policy library to Terraform Policy

## DO NOT USE FOR

- Writing `.tftest.hcl` test files (for Terraform modules — use `terraform-test`)
- Writing Sentinel policies (this skill targets Terraform Policy / tfpolicy only)
- General Terraform HCL authoring (use `terraform-style-guide` or `terraform-code-generation`)

## Routing

| Task | Sub-skill |
|------|-----------|
| Write a new Terraform Policy from an English description | [`skills/tfpolicy-author/`](skills/tfpolicy-author/SKILL.md) |
| Write or debug a `.policytest.hcl` test, mock resources, reason about runner behavior | [`skills/tfpolicy-test/`](skills/tfpolicy-test/SKILL.md) |
| Translate a Sentinel `.sentinel` policy (or compare with OPA/Rego) to tfpolicy | [`skills/tfpolicy-author/`](skills/tfpolicy-author/SKILL.md) |

Shared verified-syntax facts that every sub-skill links to live at
[`reference/verified-syntax.md`](reference/verified-syntax.md). That file is
**not** itself a skill — it is reference material consumed by the three
sub-skills above.

## Quick Start

```bash
# Install the plugin
claude plugin install terraform-policy-code@hashicorp

# Or install individual skills
npx skills add hashicorp/agent-skills/terraform/terraform-policy/skills/tfpolicy-author
npx skills add hashicorp/agent-skills/terraform/terraform-policy/skills/tfpolicy-test
```

## Examples

**Author a new policy:**
> "Write a Terraform Policy that blocks EC2 instances without encryption."
→ Load [`skills/tfpolicy-author/SKILL.md`](skills/tfpolicy-author/SKILL.md)

**Test an existing policy:**
> "Write a `.policytest.hcl` for my EBS encryption policy."
→ Load [`skills/tfpolicy-test/SKILL.md`](skills/tfpolicy-test/SKILL.md)

**Convert from Sentinel:**
> "Convert this Sentinel policy to Terraform Policy."
→ Load [`skills/tfpolicy-author/SKILL.md`](skills/tfpolicy-author/SKILL.md)

## Migration Note

This repository previously shipped a single broad `terraform-policy` skill
covering authoring, testing, and Sentinel conversion in one file. It has
been split into the three focused skills above so that each one has a
narrow, non-overlapping trigger surface and can be versioned independently.

If you have a downstream consumer that pinned the old `terraform-policy`
skill name, this router file keeps that name resolvable while it points
you at the right sub-skill for the task at hand.
