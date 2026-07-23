# Packer Agent Skills

The `packer` product bundle contains four independently installable Skills for
AWS, Azure, and Windows image building and HCP Packer registry workflows.

Install an individual Skill using its canonical path from
[SKILLS.md](../../SKILLS.md):

```bash
npx skills add hashicorp/agent-skills/plugins/packer/skills/aws-ami-builder
```

Install the Claude Code bundle:

```bash
claude plugin marketplace add hashicorp/agent-skills
claude plugin install packer@hashicorp
```

Codex uses the same `plugins/packer` root through
`.agents/plugins/marketplace.json`. The `.claude-plugin` and `.codex-plugin`
manifests are hand-maintained and must expose the same `skills/` directory.

See [Packer documentation](https://developer.hashicorp.com/packer) for the
product source of truth and [SUPPORTED_MODELS.md](../../SUPPORTED_MODELS.md) for
the model support contract.
