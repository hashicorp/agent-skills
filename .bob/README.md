# Bob Skills Directory

This directory contains Bob-specific configuration and metadata for HashiCorp Agent Skills.

## Files

### skills.json

The `skills.json` file is a manifest that provides:

- **Skill Discovery**: Complete list of all available skills with descriptions
- **Categorization**: Skills organized by product (Terraform, Packer)
- **Metadata**: Tags, paths, and descriptions for each skill
- **MCP Configuration**: Pre-configured MCP server settings for Terraform

This manifest enables Bob to:
1. Discover all available skills without browsing directories
2. Understand skill categories and relationships
3. Configure MCP servers with recommended settings
4. Display skill information in Bob's interface

## Usage

Bob can automatically read this manifest to:

```bash
# List all skills from the manifest
npx skills add hashicorp/agent-skills

# Install skills by category
# (if Bob supports category-based installation)
npx skills add hashicorp/agent-skills --category terraform

# Install all skills
# (if Bob supports bulk installation)
npx skills add hashicorp/agent-skills --all
```

## Schema

The `skills.json` follows this structure:

```json
{
  "name": "repository-name",
  "version": "1.0.0",
  "description": "Repository description",
  "skills": [
    {
      "name": "skill-name",
      "path": "relative/path/to/skill",
      "description": "Skill description",
      "category": "product-name",
      "tags": ["tag1", "tag2"]
    }
  ],
  "mcpServers": {
    "server-name": {
      "description": "Server description",
      "command": "command",
      "args": ["arg1", "arg2"],
      "env": {
        "VAR": "value"
      }
    }
  }
}
```

## Maintenance

When adding new skills:

1. Add skill entry to `skills.json`
2. Include accurate path, description, and tags
3. Update category if introducing new product
4. Test manifest with `npx skills add`

## References

- [Bob Documentation](https://ibm.com/bob) - IBM's Bob documentation
- [Skills CLI](https://github.com/skills-ai/cli) - Skills installation tool
- [Parent README](../README.md) - Main repository documentation
- [Bob Integration Guide](../BOB.md) - Complete Bob setup guide