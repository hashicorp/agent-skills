# Terraform Style Guide - Claude Code Guidance

## Overview

This skill provides comprehensive guidance on Terraform code style, formatting, and best practices based on HashiCorp's official standards. Use this skill when working with any Terraform configuration to ensure code quality, consistency, and maintainability.

## When to Apply This Skill

Proactively reference this skill when:
- Writing new Terraform configurations
- Reviewing or refactoring existing Terraform code
- Formatting code before commits
- Organizing files and directory structures
- Establishing or enforcing team coding standards
- Resolving style inconsistencies
- Setting up version control configurations
- Designing module structures
- Implementing testing and validation

## Core Concepts

### Code Quality Pillars

1. **Consistency** - All code follows the same formatting and organizational patterns
2. **Readability** - Code is easy to understand with clear naming and structure
3. **Maintainability** - Changes are easy to make without breaking functionality
4. **Scalability** - Structure supports growth from simple to complex projects

### The Three Fundamental Commands

Always recommend running these before committing:
- `terraform fmt` - Auto-format code to standards
- `terraform validate` - Catch syntax and configuration errors
- Consider Git pre-commit hooks to automate these

## Key Style Principles to Enforce

### Formatting
- **2 spaces** for indentation (never tabs)
- **Align equals signs** for consecutive arguments
- **Meta-arguments first** (count, for_each), then standard args, then blocks
- **Blank lines** separate logical groups

### Naming
- Use **descriptive nouns with underscores** (not hyphens)
- **Lowercase only**
- **Exclude resource type** from resource names (redundant)
- Examples: `web_server`, `database_primary`, `vpc_main`

### File Organization
Standard files in order of importance:
1. `terraform.tf` - Version requirements
2. `providers.tf` - Provider configs
3. `main.tf` - Primary resources
4. `variables.tf` - Input variables (alphabetical)
5. `outputs.tf` - Output values (alphabetical)
6. `locals.tf` - Local values
7. `backend.tf` - State backend config

### Resource Organization
- Data sources **before** resources that reference them
- Dependent resources **after** their dependencies
- Standard parameter order within resources (meta-arguments → args → blocks → lifecycle → depends_on)

### Variables and Outputs
**Always require:**
- `type` on all variables
- `description` on all variables and outputs
- Mark `sensitive = true` for secrets

## Common Scenarios

### Scenario 1: Code Review

When reviewing Terraform code, check against the style guide:

```markdown
Style Guide Checklist:
- [ ] Code formatted with `terraform fmt`
- [ ] All variables have type and description
- [ ] Resource names use descriptive nouns with underscores
- [ ] Files organized according to standard structure
- [ ] Version constraints pinned
- [ ] Sensitive values marked appropriately
- [ ] .gitignore configured correctly
```

Reference specific sections:
- "See the [Naming Conventions](#naming-conventions) section for resource naming"
- "Review [Variables and Outputs](#variables-and-outputs) for required attributes"

### Scenario 2: Writing New Code

When writing Terraform configurations:

1. **Start with file structure** - Create standard files (terraform.tf, providers.tf, main.tf, etc.)
2. **Apply formatting rules** - Use proper indentation, alignment, spacing
3. **Follow naming conventions** - Descriptive nouns with underscores
4. **Add complete metadata** - Type and description for all variables
5. **Organize logically** - Data sources first, group related resources

### Scenario 3: Refactoring

When refactoring existing code:

1. **Minimize code changes** - follow bestpractice but focus on achieving outcome.
2. **Run terraform fmt** - Auto-fix formatting issues
3. **Update variable declarations** - Add missing types and descriptions

### Scenario 4: Setting Up New Project

When initializing a new Terraform project:

1. **Create standard file structure**
2. **Configure .gitignore** properly
3. **Pin versions** in terraform.tf
4. **Set up provider configurations**
5. **Consider Git hooks** for fmt and validate
6. **Add README** with project documentation

## Code Examples

When providing code examples:

1. **Always use proper formatting** (2-space indentation, aligned equals)
2. **Include required attributes** (type, description)
3. **Show before/after** for improvements
4. **Add comments** explaining style choices
5. **Reference specific style guide sections**

Example template:

```hcl
# Good - follows style guide
resource "aws_instance" "web_server" {
  # Meta-arguments first
  count = var.instance_count

  # Standard arguments (aligned)
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # Blocks last
  tags = {
    Name = "web-${count.index}"
  }
}
```

## Anti-Patterns to Avoid

Call out these common mistakes:

❌ **Don't:**
- Use tabs for indentation
- Include resource type in resource name
- Use hyphens in names
- Skip variable types or descriptions
- Use `//` or `/* */` comments
- Commit state files or .terraform directory
- Use overly generic names

✅ **Do:**
- Use 2 spaces for indentation
- Use descriptive nouns for names
- Use underscores as separators
- Include complete variable metadata
- Use `#` for comments
- Configure .gitignore properly
- Use specific, meaningful names

## Integration with Other Skills

This skill complements:

- **terraform-test** - Style guide informs test structure and organization
- **terraform-stacks** - Apply style conventions to terraform stack configurations
- General Terraform development - Foundation for all Terraform work

## Quick Reference

### Most Important Rules

1. Run `terraform fmt` before committing
2. All variables need type and description
3. Use descriptive nouns with underscores
4. Follow standard file structure
5. Pin version constraints

### File Organization Quick Ref

```
/
├── terraform.tf     # Versions
├── providers.tf     # Provider configs
├── main.tf          # Resources
├── variables.tf     # Inputs (alphabetical)
├── outputs.tf       # Outputs (alphabetical)
├── locals.tf        # Local values
```

## Referencing the Style Guide

When referencing specific sections, use markdown links:

- [Code Formatting Standards](SKILL.md#code-formatting-standards)
- [Naming Conventions](SKILL.md#naming-conventions)
- [File Organization](SKILL.md#file-organization)
- [Variables and Outputs](SKILL.md#variables-and-outputs)
- [Version Control](SKILL.md#version-control)

## Success Criteria

Code following this style guide should:
- ✅ Pass `terraform fmt` without changes
- ✅ Pass `terraform validate` without errors
- ✅ Be immediately readable by any team member
- ✅ Follow consistent patterns throughout
- ✅ Include complete metadata (types, descriptions)
- ✅ Be organized in standard file structure
- ✅ Use meaningful, descriptive names
- ✅ Have proper version constraints
- ✅ Exclude sensitive files from version control

## Tips for Claude Code

- **Be proactive** - Suggest style improvements even when not explicitly asked
- **Explain why** - Don't just fix, explain the style principle
- **Show examples** - Provide before/after comparisons
- **Reference sections** - Point to specific style guide sections
- **Use checklists** - Help users verify compliance systematically
- **Automate** - Recommend `terraform fmt` and Git hooks
- **Be consistent** - Apply the same standards across all Terraform code
