# Terraform Policy Agent Skills

A family of focused agent skills for working with [Terraform Policy](https://developer.hashicorp.com/terraform/cloud-docs/policy-enforcement) — HCP Terraform's native policy-as-code engine for `.policy.hcl` and `.policytest.hcl` files.

## Routing

Pick the skill that matches the user's journey:

| Journey | Skill |
| --- | --- |
| Write a new Terraform Policy from an English description | [**tfpolicy-author**](skills/tfpolicy-author/SKILL.md) |
| Translate Sentinel (or adjacent OPA/Rego) to Terraform Policy | [**tfpolicy-author**](skills/tfpolicy-author/SKILL.md) |
| Write or debug a `.policytest.hcl` test, mock resources, reason about the runner | [**tfpolicy-test**](skills/tfpolicy-test/SKILL.md) |

Each sub-skill is self-contained, has its own `metadata.version`, and links back to the shared reference described below.

## Repository layout

```
terraform-policy-agent-skills/
├── README.md                                 # This file
├── SKILL.md                                  # Router stub (kept for loaders that read root SKILL.md)
├── reference/
│   └── verified-syntax.md                    # Shared source-of-truth syntax reference
└── skills/
    ├── tfpolicy-author/
    │   ├── SKILL.md                          # Authoring + Sentinel conversion (v0.2.0)
    │   ├── conversion-examples/              # Side-by-side .sentinel / .policy.hcl examples
    │   └── learning/                         # Quick-start + common patterns
    ├── tfpolicy-test/
    │   ├── SKILL.md
    │   └── testing-guide.md
    └── sentinel-to-tfpolicy/
        └── SKILL.md                          # Deprecated stub — points to tfpolicy-author
```

## Shared reference

[`reference/verified-syntax.md`](reference/verified-syntax.md) is the single source of truth for verified Terraform Policy syntax, function names, and runtime limitations. All sub-skills link to it rather than duplicating facts — when sub-skill content disagrees with this file, the reference wins.

## Loader compatibility

- **Single-`SKILL.md` loaders** (the HashiCorp loader today): read [`SKILL.md`](SKILL.md) at the repo root. It's a thin router that points at the active sub-skills.
- **Glob loaders** (`**/SKILL.md`): discover all three `SKILL.md` files. The root router is marked `metadata.deprecated: true` so glob loaders can deprioritize it. `sentinel-to-tfpolicy/SKILL.md` is marked `deprecated: true` — loaders should skip it and use `tfpolicy-author` for all conversion tasks.

## Versioning

Each sub-skill is versioned independently via its `metadata.version` field. The old monolithic `terraform-policy@0.0.1` is preserved in git history; sub-skills start at `0.1.0`. `tfpolicy-author` is now at `0.2.0` following the merge of Sentinel conversion knowledge.

## License

MPL-2.0. Copyright IBM Corp. 2026.
