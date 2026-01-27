# Packer Skills

Agent skills for building machine images with Packer and HCP Packer.

## Plugins

### packer-builders

Skills for building images on AWS, Azure, and Windows.

| Skill | Description |
|-------|-------------|
| aws-ami-builder     | Build Amazon Machine Images (AMIs) with amazon-ebs builder |
| azure-image-builder | Build Azure managed images and Azure Compute Gallery images |
| windows-builder     | Platform-agnostic Windows image patterns with WinRM and PowerShell |

### packer-hcp

Skills for HCP Packer registry integration.

| Skill | Description |
|-------|-------------|
| push-to-registry | Configure hcp_packer_registry to push build metadata to HCP Packer |

## Installation

### Claude Code Plugin

```bash
claude plugin marketplace add hashicorp/agent-skills

claude plugin install packer-builders@hashicorp
claude plugin install packer-hcp@hashicorp
```

### Individual Skills

```bash
# Builders
npx skills add hashicorp/agent-skills/packer/builders/skills/aws-ami-builder
npx skills add hashicorp/agent-skills/packer/builders/skills/azure-image-builder
npx skills add hashicorp/agent-skills/packer/builders/skills/windows-builder

# HCP Packer
npx skills add hashicorp/agent-skills/packer/hcp/skills/push-to-registry
```

## MCP Server

The packer-hcp plugin includes the `packer-mcp-server` for HCP Packer API access. Set the following environment variables:

```bash
export HCP_CLIENT_ID="your-service-principal-client-id"
export HCP_CLIENT_SECRET="your-service-principal-secret"
export HCP_ORGANIZATION_ID="your-organization-id"
export HCP_PROJECT_ID="your-project-id"
```

**Note:** The `hashicorp/packer-mcp-server` Docker image would need to be implemented separately to provide MCP integration for HCP Packer APIs.

## Structure

```
packer/
├── builders/
│   ├── .claude-plugin/plugin.json
│   └── skills/
│       ├── aws-ami-builder/
│       ├── azure-image-builder/
│       └── windows-builder/
└── hcp/
    ├── .claude-plugin/plugin.json
    └── skills/
        └── push-to-registry/
```

## References

- [Packer Documentation](https://developer.hashicorp.com/packer)
- [HCP Packer](https://developer.hashicorp.com/hcp/docs/packer)
- [Amazon EBS Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/amazon/latest/components/builder/ebs)
- [Azure ARM Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm)
