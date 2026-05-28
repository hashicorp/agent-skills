---
name: terraform-module-acceptance-criteria-builder
description: >
  Use this skill to turn high-level needs about Terraform modules or
  infrastructure-as-code into clear, testable requirements using the
  EARS notation (Easy Approach to Requirements Syntax), including
  structured user-story input from companion IaC story skills.
metadata:
  domain: requirements
  tags: ["EARS", "requirements", "terraform", "iac", "testing"]
---

# Purpose

When this skill is active, you help the user express **behavioural requirements**
for Terraform modules or other IaC components using EARS patterns
(Ubiquitous, Event-driven, Optional, Unwanted, Complex).

You focus on:
- What the module must do in given conditions.
- What must never happen (unwanted behaviour).
- Options/flags and their effects.
- Requirements that can be turned into automated tests or checks.

# When to use this skill

Use this skill when:
- The user mentions EARS, requirements, or “spec” for a Terraform module / IaC.
- The user has a user story or high-level description and wants precise,
  low-ambiguity requirements.
- The user provides output from the Agent Skill `terraform-module-story-builder`
  and wants EARS requirements derived from it.
- The user wants to derive test cases or policy rules from requirements.

Do NOT use this skill for:
- Purely business-level discussions without any need for testable behaviour.
- Freeform documentation or README generation.

# EARS patterns (quick reference)

When writing requirements, use these standard EARS patterns.

- **Ubiquitous** (always true):  
  Pattern: `The <module/system> shall <response>.`  
  Use for behaviour that must always hold.

- **Event-driven**:  
  Pattern: `When <trigger>, the <module/system> shall <response>.`  
  Use for behaviour that depends on a condition or event.

- **Optional feature**:  
  Pattern: `Where <feature/option> is <state>, the <module/system> shall <response>.`  
  Use for flags or configuration options (e.g. `var.enable_x`).

- **Unwanted behaviour**:  
  Pattern: `If <undesired condition>, then the <module/system> shall <response>.`  
  Use for validation, errors, and safety constraints.

- **Complex**:  
  Pattern: combination of the above when needed.  
  Prefer splitting into multiple simpler requirements when possible.

# Instructions

When using this skill, always follow this process:

1. **Normalize the input (especially user-story skill output)**
   - If input includes a `## User story` section, treat it as primary source.
   - If input includes `## Context (optional)`, use it for domain,
     beneficiary, and constraints.
   - If story wording is unclear, restate it once in concise
     "As a / I want / so that" form before deriving requirements.

2. **Clarify the scope**
   - Identify the module or component being specified (e.g. `network`, `secure_bucket`).
   - Ask for missing details only if needed to write testable requirements.
   - If the user mentions Terraform, use terms like `module`, `variable`, `output`,
     `plan`, and `apply` in the requirements.

3. **Identify key behaviours**
   - Extract 3–10 core behaviours or rules from the user story and context:
     - always-true invariants (e.g. encryption must always be enabled),
     - configuration-dependent behaviours (flags, options),
     - error/validation conditions,
     - event-triggered actions (e.g. when a change is detected).

4. **Map behaviours to EARS patterns**
   - Choose the simplest fitting pattern for each behaviour:
     - invariant → Ubiquitous,
     - behaviour under condition/event → Event-driven,
     - feature/flag → Optional,
     - validation/error → Unwanted.
   - Avoid mixing multiple patterns in a single requirement if you can split them.

5. **Write EARS requirements in IaC/Terraform terms**
   - Refer to:
     - the **module** (`The network module shall ...`),
     - **variables** (`var.*`),
     - **outputs** (`output.*`),
     - Terraform actions (`plan`, `apply`) where relevant.
   - Use clear, specific language:
     - prefer “exactly one VPC” over “a VPC”,
     - prefer “deny apply with an error explaining …” over “fail gracefully”.

6. **Assign requirement IDs**
   - Use a simple scheme like `REQ-1`, `REQ-2`, … or `<MODULE>-REQ-1`.
   - Keep IDs stable so they can be referenced from tests and documentation.

7. **Output format**

Always respond using this structure:

```md
## User story

As a <persona>,
I want <capability or outcome>,
so that <value / risk reduction / benefit>.

## Scope

- Component: `<name or description>`
- Context: `<short summary of what this module does / where it is used>`

## EARS requirements

- **[REQ-1] (Ubiquitous)**  
  The `<module>` shall ...

- **[REQ-2] (Event-driven)**  
  When `<condition>`, the `<module>` shall ...

- **[REQ-3] (Optional)**  
  Where `<var.flag>` is `<value>`, the `<module>` shall ...

- **[REQ-4] (Unwanted)**  
  If `<invalid/unsafe condition>`, then the `<module>` shall ...

## Variable Specification

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| var.environment | string | Yes | - | Deployment environment |
| var.enable_logging | bool | No | false | Enable logging |

## Output Specification

| Output | Description | Value | Sensitive |
|--------|-------------|-------|-----------|
| bucket_id | The S3 bucket ID | aws_s3_bucket.main.id | No |
| bucket_arn | The S3 bucket ARN | aws_s3_bucket.main.arn | No |
```

The Variable Specification table is derived from variables referenced in the EARS requirements. Use [terraform-variables.md](references/terraform-variables.md) for best practices on choosing types, validation rules, and defaults.

The Output Specification table captures what values the module exposes. Use [terraform-outputs.md](references/terraform-outputs.md) for best practices on output design.

8. **Make them testable**

For each requirement, mentally check:
- Could a Terraform unit/integration test or policy check verify this?
- Is there a clear condition and an expected outcome?
- If not, refine the requirement to make it objectively verifiable.

If the user asks, you may add a short, optional section:

```md
## Suggested test ideas

- REQ-1: Verify that ...
- REQ-2: Verify that ...
```

If the user asks for traceability, you may instead add:

```md
## Suggested test mapping

- REQ-1 -> Unit/integration test
- REQ-2 -> Policy-as-code or contract test
```

9. **Stay concise**

- Prefer 4–8 high-quality requirements over a long, unfocused list.
- Do not repeat the same information in multiple requirements unless
  it clarifies different conditions.

10. **Variable extraction**

Extract variables from EARS requirements and populate the Variable Specification table:

| Pattern in Requirement | Variable Inference |
|------------------------|-------------------|
| `var.enable_*`, `var.is_*`, `var.has_*` | `bool`, optional, default `false` |
| `var.environment`, `var.region`, `var.name`, `var.*_id` | `string`, required unless default is safe |
| `var.count`, `var.size`, `var.replicas`, `var.*_count` | `number`, optional with sensible default |
| "must be one of X, Y, Z" | Add validation: `contains(["X", "Y", "Z"], var.X)` |
| "at least N" / "no more than N" | Add range validation |

Only include variables that are referenced in the requirements. The Variable Specification is derived from the EARS requirements, not a separate pattern.

11. **Output extraction**

Extract outputs from EARS requirements and populate the Output Specification table:

| Source | Inference |
|--------|-----------|
| "The module shall expose..." | Explicit output, add to table |
| Resource attributes in requirements | Derived output |
| Sensitive values (passwords, keys, secrets) | Mark sensitive = true |
| Complex structures | Prefer simple, predictable shapes |

Outputs should include:
- Values consumers actually need (other modules, CI/CD, debugging)
- Specific attributes, not full resource objects
- Clear descriptions explaining what the value is

The Output Specification is derived from the module's purpose and requirements, not a separate pattern.
