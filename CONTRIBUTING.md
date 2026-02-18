# Contributing to HashiCorp Agent Skills

Thank you for your interest in contributing to the HashiCorp Agent Skills repository!

## Quick Links

- **Adding Products, Plugins, or Skills**: See [examples/README.md](examples/README.md) for detailed instructions
- **Template Files**: See [examples/new-product-template/](examples/new-product-template/)
- **Specification**: See [examples/spec.md](examples/spec.md)

## Getting Started

### Prerequisites

- Git
- Claude Code (for testing skills)
- Bash (for validation scripts)
- jq (for JSON validation)

### Clone the Repository

```bash
git clone https://github.com/hashicorp/agent-skills.git
cd agent-skills
```

### Validate Your Environment

```bash
./scripts/validate-structure.sh
```

## Types of Contributions

### Adding a New Product

Use the `/new-product` command or follow the manual steps in [examples/README.md](examples/README.md).

Products are top-level directories containing plugins. Examples: `terraform/`, `packer/`

### Adding a Plugin

Plugins are use-case groupings within a product. Each plugin has its own `plugin.json` and contains skills.

### Adding a Skill

Skills are individual SKILL.md files that teach Claude about specific topics or tasks.

### Improving Existing Skills

- Fix errors or outdated information
- Add missing examples
- Improve clarity

### Documentation

- Fix typos
- Improve explanations
- Add missing sections

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b add-vault-skills
```

### 2. Make Changes

Follow the structure documented in [examples/README.md](examples/README.md).

### 3. Validate

```bash
./scripts/validate-structure.sh
```

### 4. Test Your Skills

Open Claude Code in the repository and test that your skills work as expected.

### 5. Submit a Pull Request

- Provide a clear description of what you're adding
- Reference any related issues
- Ensure CI checks pass

## Code of Conduct

- Be respectful and constructive
- Follow HashiCorp's community guidelines
- Help others learn and contribute

## Style Guidelines

### SKILL.md

- Use clear, concise language
- Include practical examples
- Link to official documentation
- Follow the existing skill patterns

### plugin.json

- Use lowercase, hyphenated names
- Provide descriptive keywords
- Include accurate descriptions

### Directory Names

- Use lowercase
- Use hyphens for multi-word names
- Match the skill/plugin name

## License

All contributions are licensed under MPL-2.0. By submitting a pull request, you agree to license your contribution under this license.

## Questions?

Open an issue if you have questions about contributing.
