
# Terraform Instructions Library

This directory contains curated instruction sets, skills, and workflows for AI agents working with HashiCorp Terraform. Use these instructions to enhance AI-assisted development with context-aware, security-focused guidance.

## Directory Structure

```
terraform/
├── README.md (this file)
├── provider-development/                # Guidance and skills for developing Terraform providers
├── provider-feature-development/        # Feature-specific provider development instructions
│   └── terraform-actions/               # Action patterns and automation for providers
├── terraform-code-generation/           # Skills for generating HCL and Terraform code
```

---

tfsec . --minimum-severity HIGH
on: [pull_request]
jobs:
echo "Running Terraform validation..."
echo "All pre-commit checks passed"

## What's Inside

### Provider Development
- `provider-development/`: Guidance and skills for developing Terraform providers
- `provider-feature-development/`: Feature-specific provider development instructions
  - `terraform-actions/`: Action patterns and automation for providers

### Code Generation
- `terraform-code-generation/`: Skills for generating HCL and Terraform code

### Usage
Reference specific skills or workflows in your prompts:
```
@workspace Using the generate-hcl skill, create an AWS VPC module
```
```
@workspace Apply Terraform best practices to this configuration
```

## Best Practices
- Always query Terraform Registry for latest versions before code generation
- Follow HCL best practices from `/terraform/skills/generate-hcl/resources/`
- Apply security scanning before deployment
- Use explicit typing and validation for all variables
- Implement proper state management and locking

## Contributing
Add new instructions to the appropriate directory and update this README with a description.

