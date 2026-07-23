# HashiCorp Agent Skills

HashiCorp Agent Skills provide focused, installable guidance for Terraform and
Packer workflows. Individual Skill installation is the primary distribution
method. Product bundles are also available for Claude Code and Codex.

| Product | Skills | Product bundle |
| --- | ---: | --- |
| [Terraform](plugins/terraform/README.md) | 16 | `terraform` |
| [Packer](plugins/packer/README.md) | 4 | `packer` |

See [SKILLS.md](SKILLS.md) for the complete catalog and lifecycle status of each
Skill. See [SUPPORTED_MODELS.md](SUPPORTED_MODELS.md) for the governed model
support contract.

> **Legal note:** Your use of a third-party MCP client or LLM is subject solely
> to that provider's terms. IBM is not responsible for the performance of those
> third-party tools and may be unable to support issues caused by them.

## Install an individual Skill

List the repository's Skills:

```bash
npx skills add hashicorp/agent-skills
```

Install one Skill from its canonical path:

```bash
npx skills add hashicorp/agent-skills/plugins/terraform/skills/terraform-style-guide
npx skills add hashicorp/agent-skills/plugins/packer/skills/aws-ami-builder
```

Every supported path appears in [SKILLS.md](SKILLS.md).

## Install a product bundle

### Claude Code

```bash
claude plugin marketplace add hashicorp/agent-skills
claude plugin install terraform@hashicorp
claude plugin install packer@hashicorp
```

### Codex

Add this repository's `.agents/plugins/marketplace.json` as a repository
marketplace, then install the `terraform` or `packer` plugin in Codex. Both
marketplaces expose the same product bundles and Skill directories.

## Migration from legacy plugin IDs and paths

The product-bundle integration removes these legacy plugin IDs without aliases:
`terraform-code-generation`, `terraform-module-generation`,
`terraform-provider-development`, `terraform-policy-code`, `packer-builders`,
and `packer-hcp`.

Replace any legacy plugin installation with `terraform@hashicorp` or
`packer@hashicorp`. Replace individual paths under `terraform/<category>/skills`
or `packer/<category>/skills` with
`plugins/<product>/skills/<skill-name>`.

This migration guidance is time-bound and must remain available until three
calendar months after the product-bundle integration PR merges. The merge date
and resulting removal date must be recorded in this section when that PR merges.

## Repository structure

```text
agent-skills/
├── .agents/plugins/marketplace.json
├── .claude-plugin/marketplace.json
├── plugins/
│   ├── terraform/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── .codex-plugin/plugin.json
│   │   └── skills/
│   └── packer/
│       ├── .claude-plugin/plugin.json
│       ├── .codex-plugin/plugin.json
│       └── skills/
└── SKILLS.md
```

## Governance and support

- [CONTRIBUTING.md](CONTRIBUTING.md) describes the internal contribution and
  proposal process.
- [SECURITY.md](SECURITY.md) redirects sensitive reports away from public
  issues.
- [SUPPORT.md](SUPPORT.md) defines repository support boundaries.
- `CODEOWNERS` is the canonical Skill ownership and review-routing source.

## License

MPL-2.0
