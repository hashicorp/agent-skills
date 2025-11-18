# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Skill repository** for HashiCorp Terraform Stacks - a specialized knowledge base that provides comprehensive documentation and guidance for working with Terraform Stacks configurations. This is not a traditional software project with executable code, but rather a documentation repository structured as a skill module for Claude AI assistants.

**Purpose**: Enable Claude to help users create, modify, validate, and troubleshoot Terraform Stack configurations (`.tfcomponent.hcl` and `.tfdeploy.hcl` files), manage multi-region/multi-environment infrastructure, and understand Terraform Stacks syntax and best practices.

## Repository Structure

```
claude-skill-terraform-stacks/
├── README.md                         # Brief project description (2 lines)
├── SKILL.md                          # Main comprehensive guide (580 lines)
└── references/                       # Detailed reference documentation
    ├── component-blocks.md           # Component block specification (649 lines)
    ├── deployment-blocks.md          # Deployment block specification (1009 lines)
    └── examples.md                   # Complete working examples (1529 lines)
```

Total: 3,767 lines of documentation organized into focused modules.

## Documentation Architecture

### Core Documentation Flow

1. **[SKILL.md](SKILL.md)** - Start here for high-level concepts, syntax overview, CLI commands, common patterns, and troubleshooting
2. **[references/component-blocks.md](references/component-blocks.md)** - Deep dive into component configuration syntax for `.tfcomponent.hcl` files
3. **[references/deployment-blocks.md](references/deployment-blocks.md)** - Deep dive into deployment configuration syntax for `.tfdeploy.hcl` files
4. **[references/examples.md](references/examples.md)** - Complete working examples from simple to complex scenarios

### Content Organization

**SKILL.md covers**:
- Core concepts (Stack, Component, Deployment, Stack Language)
- File structure and organization
- Configuration blocks: variables, providers, components, outputs, locals, removed blocks
- Deployment configuration syntax
- CLI commands (`terraform stacks validate`, `plan`, `apply`)
- Common patterns (multi-region, component dependencies)
- Best practices and troubleshooting

**references/component-blocks.md covers**:
- Complete syntax reference for all component configuration blocks
- Detailed argument specifications with types and constraints
- Code examples for each block type
- Key differences from traditional Terraform syntax

**references/deployment-blocks.md covers**:
- Complete syntax reference for all deployment configuration blocks
- Identity token configurations (OIDC)
- Deployment groups and auto-approval rules
- Linked Stacks (publish outputs and upstream inputs)
- Cloud provider-specific configurations (AWS, Azure, GCP)

**references/examples.md covers**:
- Simple single-region Stack (with deployment group)
- Stack with private registry modules
- Multi-environment Stack (dev/staging/prod with deployment groups)
- Multi-region Stack with regional provider configurations
- Linked Stacks with cross-stack dependencies
- Multi-cloud Stack (AWS + Azure)
- Complete AWS production Stack with all features
- Destroying deployments safely

## Key Terraform Stacks Concepts

### Stack Language vs Traditional Terraform

Terraform Stacks use a **separate HCL-based language** distinct from traditional Terraform:

- Different file extensions: `.tfcomponent.hcl` (components), `.tfdeploy.hcl` (deployments)
- Different block syntax for providers (use `for_each`, aliases in headers, `config` blocks)
- Components wrap modules (modules cannot contain provider blocks)
- Outputs and variables require `type` argument
- All files must be at root level (processed in dependency order)

### Component Module Sources

Components can reference modules from multiple source types:

- **Local paths**: `./modules/vpc` or `../shared-modules/networking`
- **Public registry**: `terraform-aws-modules/vpc/aws` (format: `<NAMESPACE>/<NAME>/<PROVIDER>`)
- **Private registry**: `app.terraform.io/my-org/vpc/aws` (format: `<HOSTNAME>/<ORG>/<MODULE>/<PROVIDER>`)
  - HCP Terraform SaaS: Use `app.terraform.io`
  - Terraform Enterprise: Use your instance hostname
  - Generic hostname: Use `localterraform.com` for multi-instance deployments
- **Git repositories**: `git::https://github.com/org/repo.git//modules/vpc?ref=v1.0.0`
- **HTTP/HTTPS archives**: `https://example.com/modules/vpc.tar.gz`

The `version` argument is supported only for registry sources (public and private). See [references/component-blocks.md](references/component-blocks.md) for complete details.

### Critical Architecture Points

1. **Components are abstractions around modules** - Each component specifies a source module, inputs, and providers
2. **Deployments are instances of the entire Stack** - Used for different environments, regions, or accounts
3. **Each deployment has isolated state** - No shared state between deployments
4. **Dependencies are auto-inferred** - When components reference other component outputs
5. **Provider configurations support `for_each`** - Enable multi-region patterns with single configuration
6. **Deployment groups are essential** - Always organize deployments into deployment groups, even single deployments. This enables auto-approval rules, maintains consistency, and provides a foundation for scaling

## Common Scenarios and Patterns

### When Users Ask About Multi-Region Infrastructure

Guide them to use:
- `for_each` on provider blocks to create regional providers
- `for_each` on component blocks to deploy per region
- Each region gets its own provider instance and component instance

See SKILL.md lines 442-476 for the complete pattern.

### When Users Ask About Multi-Environment Deployments

Guide them to create:
- Multiple deployment blocks (one per environment)
- Each deployment gets its own inputs and isolated state
- **Always create deployment groups** to organize deployments (even for single deployments)
- Deployment groups enable auto-approval rules and provide consistent configuration patterns

**Best Practice**: Every deployment should be organized into a deployment group, even if it's the only deployment in the Stack. This establishes a consistent pattern and enables future scaling.

See references/examples.md for multi-environment example.

### When Users Ask About Cross-Stack Dependencies

Guide them to use:
- `publish_output` blocks in the source Stack (exports values)
- `upstream_input` blocks in the dependent Stack (imports values)
- Reference upstream inputs in deployment inputs

See SKILL.md lines 375-407 for syntax.

### When Users Ask About OIDC Authentication

Guide them to use:
- `identity_token` blocks in `.tfdeploy.hcl` with appropriate audience
- Reference token via `identity_token.<name>.jwt`
- Pass token to provider configuration in deployment inputs
- Use `assume_role_with_web_identity` in AWS provider config

### When Users Ask About Destroying/Removing Deployments

Guide them to:
1. Set `destroy = true` in the deployment block
2. Apply the plan through HCP Terraform (this destroys all resources)
3. After successful destruction, remove the deployment block from configuration

**Important**: Using `destroy = true` ensures provider authentication is retained during resource destruction. See references/deployment-blocks.md lines 173-196 and references/examples.md "Destroying Deployments" section.

## Common Errors and Solutions

### "Deprecated filename usage" Warning

**Issue**: Files use `.tfcomponent.hcl` extension
**Solution**: Rename to `.tfcomponent.hcl` for component files; keep `.tfdeploy.hcl` for deployments

### Provider Configuration Errors

**Issue**: Providers defined inside modules
**Solution**: All provider configurations must be at Stack level in `.tfcomponent.hcl` files

### Circular Dependencies

**Issue**: Component A references Component B, and B references A
**Solution**: Refactor to break circular reference or introduce intermediate component

### Maximum Deployments Limit

HCP Terraform supports maximum 20 deployments per Stack. For more instances, use multiple Stacks or `for_each` within components.

## File Naming Conventions

Follow these naming patterns for clarity:

```
variables.tfcomponent.hcl      # Variable declarations
providers.tfcomponent.hcl      # Provider configurations
components.tfcomponent.hcl     # Component definitions
outputs.tfcomponent.hcl        # Stack outputs
deployments.tfdeploy.hcl       # Deployment definitions
```

All files are processed together by HCP Terraform, so the naming is for human organization only.

## How to Work with This Repository

### No Build System

This is a documentation-only repository:
- No compilation or build commands
- No package manager or dependencies
- No automated tests
- No Docker or containerization

### Making Changes

When updating documentation:

1. **Maintain consistency across files** - Changes to syntax should be reflected in SKILL.md, appropriate references/ file, and examples.md
2. **Update examples when syntax changes** - All code examples must remain valid and working
3. **Keep the architecture accurate** - The "big picture" concepts in SKILL.md must align with detailed specs in references/
4. **Test HCL syntax accuracy** - Ensure all code blocks use correct Terraform Stacks HCL syntax (not regular Terraform)
5. **Include deployment groups in all examples** - Every example with deployments must include corresponding deployment_group blocks, even for single deployments

### Version Control

Use Git for all changes:
```bash
git status                    # Check current changes
git add <files>              # Stage changes
git commit -m "message"      # Commit changes
git push                     # Push to remote
```

## Documentation Style Guide

### Code Blocks

All Terraform Stacks code examples use HCL syntax:

```hcl
# Correct block structure
component "example" {
  source = "./modules/example"

  inputs = {
    key = value
  }

  providers = {
    aws = provider.aws.this
  }
}
```

### File References

When referencing syntax details, point to specific files:
- Detailed component syntax → references/component-blocks.md
- Detailed deployment syntax → references/deployment-blocks.md
- Working examples → references/examples.md

### Terminology Consistency

Use these exact terms consistently:
- **Stack** (not "stack configuration" or "terraform stack")
- **Component** (not "module" - modules are what components wrap)
- **Deployment** (not "environment" - deployments can represent environments)
- **Stack Language** (not "HCL" - it's a separate language based on HCL)

## CLI Commands (Terraform Stacks)

```bash
# Generate provider lock file
terraform stacks providers lock

# Validate Stack configuration
terraform stacks validate

# Plan specific deployment
terraform stacks plan --deployment=<name>

# Apply specific deployment
terraform stacks apply --deployment=<name>
```

Note: These are **not** regular `terraform` commands - they are `terraform stacks` subcommands specific to Terraform Stacks.
