# Terraform Policy Agent Skills

A family of focused agent skills for working with [Terraform Policy](https://developer.hashicorp.com/terraform/cloud-docs/policy-enforcement) — HCP Terraform's native policy-as-code engine for `.policy.hcl` and `.policytest.hcl` files.

## Routing

Pick the skill that matches the user's journey:

| Journey | Reference |
| --- | --- |
| Write a new Terraform Policy from an English description | [**tfpolicy-author**](skills/tfpolicy-author/SKILL.md) |
| Translate Sentinel (or adjacent OPA/Rego) to Terraform Policy | [**tfpolicy-author**](skills/tfpolicy-author/SKILL.md) |
| Write or debug a `.policytest.hcl` test, mock resources, reason about the runner | [**tfpolicy-test**](skills/tfpolicy-test/SKILL.md) |

## Repository layout

```
terraform-policy/
├── SKILL.md                        # Router — routes to references below
├── references/
│   ├── tfpolicy-author.md          # Authoring + Sentinel conversion (v0.2.0)
│   ├── tfpolicy-test.md            # Testing + full testing guide
│   └── verified-syntax.md         # Shared source-of-truth syntax reference
├── examples/
│   └── conversion/                 # Side-by-side .sentinel / .policy.hcl examples
└── evals/
    ├── eval.yaml
    └── tasks/
```

## Shared reference

[`references/verified-syntax.md`](references/verified-syntax.md) is the single source of truth for verified Terraform Policy syntax, function names, and runtime limitations. All reference files link to it rather than duplicating facts — when reference content disagrees with this file, the reference wins.

## Versioning

Each reference is versioned independently via its `metadata.version` field.

## License

MPL-2.0. Copyright IBM Corp. 2026.
