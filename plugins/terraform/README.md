# Terraform Agent Skills

The `terraform` product bundle contains 16 independently installable Skills for
Terraform configuration, module, provider, testing, import, stack, and policy
workflows.

Install an individual Skill using its canonical path from
[SKILLS.md](https://github.com/hashicorp/agent-skills/blob/main/SKILLS.md):

```bash
npx skills add hashicorp/agent-skills/plugins/terraform/skills/terraform-style-guide
```

Install the Claude Code bundle:

```bash
claude plugin marketplace add hashicorp/agent-skills
claude plugin install terraform@hashicorp
```

Codex uses the same `plugins/terraform` root through
`.agents/plugins/marketplace.json`.

Kiro installs the same root as a Power through its Agent Plugins `plugin.json`.
In the Kiro Powers panel, choose **Add Custom Power**, then **Import power from
GitHub**, and enter
`https://github.com/hashicorp/agent-skills/tree/main/plugins/terraform`.

The `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and root
`plugin.json` manifests are hand-maintained and must expose the same `skills/`
directory.

See [Terraform documentation](https://developer.hashicorp.com/terraform) for
the product source of truth and [SUPPORTED_MODELS.md](https://github.com/hashicorp/agent-skills/blob/main/SUPPORTED_MODELS.md)
for the model support contract.
