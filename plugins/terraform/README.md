# Terraform Agent Skills

The `terraform` product bundle contains 16 independently installable Skills for
Terraform configuration, module, provider, testing, import, stack, and policy
workflows.

Install an individual Skill using its canonical path from
[SKILLS.md](../../SKILLS.md):

```bash
npx skills add hashicorp/agent-skills/plugins/terraform/skills/terraform-style-guide
```

Install the Claude Code bundle:

```bash
claude plugin marketplace add hashicorp/agent-skills
claude plugin install terraform@hashicorp
```

Codex uses the same `plugins/terraform` root through
`.agents/plugins/marketplace.json`. The `.claude-plugin` and `.codex-plugin`
manifests are hand-maintained and must expose the same `skills/` directory.

See [Terraform documentation](https://developer.hashicorp.com/terraform) for
the product source of truth and [SUPPORTED_MODELS.md](../../SUPPORTED_MODELS.md)
for the model support contract.
