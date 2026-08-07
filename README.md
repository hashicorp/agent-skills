# HashiCorp Agent Skills

HashiCorp Agent Skills for Terraform and Packer.

| Product | Skills | Product bundle |
| --- | ---: | --- |
| [Terraform](plugins/terraform/README.md) | 16 | `terraform` |
| [Packer](plugins/packer/README.md) | 4 | `packer` |

See [SKILLS.md](SKILLS.md) for the complete catalog and lifecycle status of each
Skill.

> **Legal note:** Your use of a third-party MCP client or LLM is subject solely
> to that provider's terms. IBM is not responsible for the performance of those
> third-party tools and may be unable to support issues caused by them.

## Table of Contents

- [Recent Updates](#recent-updates)
- [Install an Individual Skill](#install-an-individual-skill)
- [Install a Product Plugin Bundle](#install-a-product-plugin-bundle)
- [Repository Structure](#repository-structure)
- [Governance and Support](#governance-and-support)
- [License](#license)

## Recent Updates

This repository now organizes its 20 Skills under two product plugin roots:
`plugins/terraform/skills/` and `plugins/packer/skills/`.

### Migration from Legacy Plugin IDs and Paths

The product plugin bundles replace these legacy plugin IDs:
`terraform-code-generation`, `terraform-module-generation`,
`terraform-provider-development`, `terraform-policy-code`, `packer-builders`,
and `packer-hcp`.

Replace any legacy plugin installation with `terraform@hashicorp` or
`packer@hashicorp`. Replace individual paths under `terraform/<category>/skills`
or `packer/<category>/skills` with
`plugins/<product>/skills/<skill-name>`.

## Install an Individual Skill

Install Agent Skills in GitHub Copilot, Claude Code, Opencode, Cursor, IBM Bob,
and more.

List the repository's Skills:

```bash
npx skills add hashicorp/agent-skills
```

Install one Skill from its path:

```bash
npx skills add hashicorp/agent-skills/plugins/terraform/skills/terraform-style-guide
npx skills add hashicorp/agent-skills/plugins/packer/skills/aws-ami-builder
```

Every supported path appears in [SKILLS.md](SKILLS.md).

## Install a Product Plugin Bundle

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

## Repository Structure

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

## Governance and Support

- [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidance. Contributions
  are restricted to HashiCorp-internal contributors until further notice.
- [SECURITY.md](SECURITY.md) for instructions on reporting security or data
  sensitivity issues related to this repository's Agent Skills.
- [SUPPORT.md](SUPPORT.md) defines repository support boundaries.
- `CODEOWNERS` for canonical Skill ownership and review-routing source.

## License

MPL-2.0
