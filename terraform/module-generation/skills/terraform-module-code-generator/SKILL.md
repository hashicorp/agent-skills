---
name: terraform-module-code-generator
description: >
  Generate Terraform module implementation files from a module specification
  document with user story and EARS requirements.
metadata:
  domain: terraform
  tags: ["terraform", "iac", "module", "code-generation", "ears"]
  owner: "platform-engineering"
  maturity: "experimental"
---

# Terraform Module Code Generator

Generate a Terraform module from a specification document. This skill focuses
on implementation only and does not orchestrate other skills.

## Input

Accept input in two ways:
1. Direct content: specification text provided in the prompt.
2. File path: path to a Markdown specification file.

If a file path is provided, read the file. Otherwise, use the provided content.

## Implementation workflow

### Step 1: Parse the specification

Extract:
- Module name and purpose
- User story (persona, capability, value)
- EARS requirements and requirement IDs
- Variable specification table
- Output specification table

### Step 2: Create module directory

Create module files in the repository root directory.

Rule:
- Always generate Terraform module implementation files in the root directory.
- Do not create or use `modules/<module-name>` for generated output unless the
  calling context explicitly overrides this behavior.

### Step 3: Generate module files

Create standard module files:
- main.tf
- variables.tf
- outputs.tf
- versions.tf

### Step 4: Map EARS requirements to code

For each requirement, implement behavior and keep traceability comments.

Example:

```hcl
# REQ-1 (Ubiquitous): Encryption must always be enabled
resource "aws_s3_bucket" "this" {
  # ...
}
```

Pattern mapping guidance:
- Ubiquitous: always-on core resource configuration.
- Event-driven: conditional behavior tied to explicit triggers or conditions.
- Optional: feature-flag behavior controlled by variables.
- Unwanted: input validation and safe failure behavior.

### Step 5: Generate versions.tf

Include Terraform and provider constraints that match module requirements.

### Step 6: Ensure generated code quality baseline

Apply Terraform style conventions in generated files:
- descriptive names
- predictable locals usage
- complete variable descriptions and types
- clear output descriptions

### Step 7: Preserve requirement traceability

All implemented behaviors tied to EARS requirements must be linked to REQ-* IDs
in comments near relevant blocks.

## Output expectations

Generated module should:
- satisfy all listed requirements
- have a complete public interface (variables and outputs)
- be ready for subsequent style/test/documentation workflow steps
  handled outside this skill
