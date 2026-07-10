---
name: terraform-policy
description: Index / router for the terraform-policy skill family. Points users at the focused sub-skill that matches their journey — authoring, testing, or Sentinel migration. Prefer loading the sub-skill SKILL.md files directly when your loader supports it.
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

> **This file is a router**, not a full skill. It exists so loaders that
> read a single root `SKILL.md` keep working. Loaders that glob
> `**/SKILL.md` should prefer the three focused sub-skills under
> [`skills/`](skills/) and may ignore this file.

## Routing

| Write a new Terraform Policy from an English description | [`skills/tfpolicy-author/`](skills/tfpolicy-author/SKILL.md) |
| Write or debug a `.policytest.hcl` test, mock resources, reason about runner behavior | [`skills/tfpolicy-test/`](skills/tfpolicy-test/SKILL.md) |
| Translate a Sentinel `.sentinel` policy (or compare with OPA/Rego) to tfpolicy | [`skills/tfpolicy-author/`](skills/tfpolicy-author/SKILL.md) |

Shared verified-syntax facts that every sub-skill links to live at
[`reference/verified-syntax.md`](reference/verified-syntax.md). That file is
**not** itself a skill — it is reference material consumed by the three
sub-skills above.

## Migration note

This repository previously shipped a single broad `terraform-policy` skill
covering authoring, testing, and Sentinel conversion in one file. It has
been split into the three focused skills above so that each one has a
narrow, non-overlapping trigger surface and can be versioned independently.

If you have a downstream consumer that pinned the old `terraform-policy`
skill name, this router file keeps that name resolvable while it points
you at the right sub-skill for the task at hand.
