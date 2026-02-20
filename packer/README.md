# Packer Skills

Agent skills for building machine images with Packer and HCP Packer.

## Plugins

### build-machine-image

Skills for building images on AWS, Azure, and Windows.

| Skill | Description |
|-------|-------------|
| aws-ami-builder     | Build Amazon Machine Images (AMIs) with amazon-ebs builder |
| azure-image-builder | Build Azure managed images and Azure Compute Gallery images |
| windows-builder     | Platform-agnostic Windows image patterns with WinRM and PowerShell |

### publish-metadata-to-hcp

Skills for HCP Packer registry integration.

| Skill | Description |
|-------|-------------|
| push-to-registry | Configure hcp_packer_registry to push build metadata to HCP Packer |

## Installation

### Claude Code Plugin

```bash
claude plugin marketplace add hashicorp/agent-skills

claude plugin install packer-build-machine-image@hashicorp
claude plugin install packer-publish-metadata-to-hcp@hashicorp
```

### Individual Skills

```bash
# Build machine image
npx skills add hashicorp/agent-skills/packer/build-machine-image/skills/aws-ami-builder
npx skills add hashicorp/agent-skills/packer/build-machine-image/skills/azure-image-builder
npx skills add hashicorp/agent-skills/packer/build-machine-image/skills/windows-builder

# Publish metadata to HCP
npx skills add hashicorp/agent-skills/packer/publish-metadata-to-hcp/skills/push-to-registry
```

## Structure

```
packer/
├── build-machine-image/
│   ├── .claude-plugin/plugin.json
│   └── skills/
│       ├── aws-ami-builder/
│       ├── azure-image-builder/
│       └── windows-builder/
└── publish-metadata-to-hcp/
    ├── .claude-plugin/plugin.json
    └── skills/
        └── push-to-registry/
```

## References

- [Packer Documentation](https://developer.hashicorp.com/packer)
- [HCP Packer](https://developer.hashicorp.com/hcp/docs/packer)
- [Amazon EBS Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/amazon/latest/components/builder/ebs)
- [Azure ARM Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm)
