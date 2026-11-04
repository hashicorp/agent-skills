# Packer Agent Skills

The `packer` product bundle contains four independently installable Skills for
AWS, Azure, and Windows image building and HCP Packer registry workflows.

Install an individual Skill using its canonical path from
[SKILLS.md](https://github.com/hashicorp/agent-skills/blob/main/SKILLS.md):

```bash
npx skills add hashicorp/agent-skills/plugins/packer/skills/aws-ami-builder
```

Install the Claude Code bundle:

```bash
claude plugin marketplace add hashicorp/agent-skills
claude plugin install packer@hashicorp
```

Codex uses the same `plugins/packer` root through
`.agents/plugins/marketplace.json`.

Kiro installs the same root as a Power through its Agent Plugins `plugin.json`.
In the Kiro Powers panel, choose **Add Custom Power**, then **Import power from
GitHub**, and enter
`https://github.com/hashicorp/agent-skills/tree/main/plugins/packer`.

The `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and root
`plugin.json` manifests are hand-maintained and must expose the same `skills/`
directory.

See [Packer documentation](https://developer.hashicorp.com/packer) for the
product source of truth and [SUPPORTED_MODELS.md](https://github.com/hashicorp/agent-skills/blob/main/SUPPORTED_MODELS.md) for
the model support contract.
