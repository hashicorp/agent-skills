---
name: azure-verified-modules
description: Azure Verified Modules (AVM) requirements and best practices for developing certified Azure Terraform modules. Use when creating or reviewing Azure modules that need AVM certification.
---

# Azure Verified Modules (AVM) Requirements

This guide covers the mandatory requirements for Azure Verified Modules certification. These requirements ensure consistency, quality, and maintainability across Azure Terraform modules.

**References:**
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [AVM Terraform Requirements](https://azure.github.io/Azure-Verified-Modules/specs/terraform/)

## Table of Contents

- [Module Cross-Referencing](#module-cross-referencing)
- [Azure Provider Requirements](#azure-provider-requirements)
- [Code Style Standards](#code-style-standards)
- [Variable Requirements](#variable-requirements)
- [Output Requirements](#output-requirements)
- [Local Values Standards](#local-values-standards)
- [Terraform Configuration Requirements](#terraform-configuration-requirements)
- [Testing Requirements](#testing-requirements)
- [Documentation Requirements](#documentation-requirements)
- [Breaking Changes & Feature Management](#breaking-changes--feature-management)
- [Contribution Standards](#contribution-standards)
- [Compliance Checklist](#compliance-checklist)

---

## Module Cross-Referencing

**Severity:** MUST | **Requirement:** TFFR1

When building Resource or Pattern modules, module owners **MAY** cross-reference other modules. However:

- Modules **MUST** be referenced using HashiCorp Terraform registry reference to a pinned version
  - Example: `source = "Azure/xxx/azurerm"` with `version = "1.2.3"`
- Modules **MUST NOT** use git references (e.g., `git::https://xxx.yyy/xxx.git` or `github.com/xxx/yyy`)
- Modules **MUST NOT** contain references to non-AVM modules

---

## Azure Provider Requirements

**Severity:** MUST | **Requirement:** TFFR3

Authors **MUST** only use the following Azure providers:

| Provider | Min Version | Max Version |
|----------|-------------|-------------|
| azapi    | >= 2.0      | < 3.0       |
| azurerm  | >= 4.0      | < 5.0       |

**Requirements:**

- Authors **MAY** select either Azurerm, Azapi, or both providers
- **MUST** use `required_providers` block to enforce provider versions
- **SHOULD** use pessimistic version constraint operator (`~>`)

**Example:**

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}
```

---

## Code Style Standards

### Lower snake_casing

**Severity:** MUST | **Requirement:** TFNFR4

**MUST** use lower snake_casing for:

- Locals
- Variables
- Outputs
- Resources (symbolic names)
- Modules (symbolic names)

Example: `snake_casing_example`

### Resource & Data Source Ordering

**Severity:** SHOULD | **Requirement:** TFNFR6

- Resources that are depended on **SHOULD** come first
- Resources with dependencies **SHOULD** be defined close to each other

### Count & for_each Usage

**Severity:** MUST | **Requirement:** TFNFR7

- Use `count` for conditional resource creation
- **MUST** use `map(xxx)` or `set(xxx)` as resource's `for_each` collection
- The map's key or set's element **MUST** be static literals

**Example:**

```hcl
resource "azurerm_subnet" "pair" {
  for_each             = var.subnet_map  # map(string)
  name                 = "${each.value}-pair"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

### Resource & Data Block Internal Ordering

**Severity:** SHOULD | **Requirement:** TFNFR8

**Order within resource/data blocks:**

1. **Meta-arguments (top)**:
   - `provider`
   - `count`
   - `for_each`

2. **Arguments/blocks (middle, alphabetical)**:
   - Required arguments
   - Optional arguments
   - Required nested blocks
   - Optional nested blocks

3. **Meta-arguments (bottom)**:
   - `depends_on`
   - `lifecycle` (with sub-order: `create_before_destroy`, `ignore_changes`, `prevent_destroy`)

Separate sections with blank lines.

### Module Block Ordering

**Severity:** SHOULD | **Requirement:** TFNFR9

**Order within module blocks:**

1. **Top meta-arguments**:
   - `source`
   - `version`
   - `count`
   - `for_each`

2. **Arguments (alphabetical)**:
   - Required arguments
   - Optional arguments

3. **Bottom meta-arguments**:
   - `depends_on`
   - `providers`

### Lifecycle ignore_changes Syntax

**Severity:** MUST | **Requirement:** TFNFR10

The `ignore_changes` attribute **MUST NOT** be enclosed in double quotes.

**Good:**

```hcl
lifecycle {
  ignore_changes = [tags]
}
```

**Bad:**

```hcl
lifecycle {
  ignore_changes = ["tags"]
}
```

### Null Comparison for Conditional Creation

**Severity:** SHOULD | **Requirement:** TFNFR11

For parameters requiring conditional resource creation, wrap with `object` type to avoid "known after apply" issues during plan stage.

**Recommended:**

```hcl
variable "security_group" {
  type = object({
    id = string
  })
  default = null
}
```

### Dynamic Blocks for Optional Nested Objects

**Severity:** MUST | **Requirement:** TFNFR12

Nested blocks under conditions **MUST** use this pattern:

```hcl
dynamic "identity" {
  for_each = <condition> ? [<some_item>] : []

  content {
    # block content
  }
}
```

### Default Values with coalesce/try

**Severity:** SHOULD | **Requirement:** TFNFR13

**Good:**

```hcl
coalesce(var.new_network_security_group_name, "${var.subnet_name}-nsg")
```

**Bad:**

```hcl
var.new_network_security_group_name == null ? "${var.subnet_name}-nsg" : var.new_network_security_group_name
```

### Provider Declarations in Modules

**Severity:** MUST | **Requirement:** TFNFR27

- `provider` **MUST NOT** be declared in modules (except for `configuration_aliases`)
- `provider` blocks in modules **MUST** only use `alias`
- Provider configurations **SHOULD** be passed in by module users

---

## Variable Requirements

### Not Allowed Variables

**Severity:** MUST | **Requirement:** TFNFR14

Module owners **MUST NOT** add variables like `enabled` or `module_depends_on` to control entire module operation. Boolean feature toggles for specific resources are acceptable.

### Variable Definition Order

**Severity:** SHOULD | **Requirement:** TFNFR15

Variables **SHOULD** follow this order:

1. All required fields (alphabetical)
2. All optional fields (alphabetical)

### Variable Naming Rules

**Severity:** SHOULD | **Requirement:** TFNFR16

- Follow [HashiCorp's naming rules](https://www.terraform.io/docs/extend/best-practices/naming.html)
- Feature switches **SHOULD** use positive statements: `xxx_enabled` instead of `xxx_disabled`

### Variables with Descriptions

**Severity:** SHOULD | **Requirement:** TFNFR17

- `description` **SHOULD** precisely describe the parameter's purpose and expected data type
- Target audience is module users, not developers
- For `object` types, use HEREDOC format

### Variables with Types

**Severity:** MUST | **Requirement:** TFNFR18

- `type` **MUST** be defined for every variable
- `type` **SHOULD** be as precise as possible
- `any` **MAY** only be used with adequate reasons
- Use `bool` instead of `string`/`number` for true/false values
- Use concrete `object` instead of `map(any)`

### Sensitive Data Variables

**Severity:** SHOULD | **Requirement:** TFNFR19

If a variable's type is `object` and contains sensitive fields, the entire variable **SHOULD** be `sensitive = true`, or extract sensitive fields into separate variables.

### Non-Nullable Defaults for Collections

**Severity:** SHOULD | **Requirement:** TFNFR20

Nullable **SHOULD** be set to `false` for collection values (sets, maps, lists) when using them in loops. For scalar values, null may have semantic meaning.

### Discourage Nullability by Default

**Severity:** MUST | **Requirement:** TFNFR21

`nullable = true` **MUST** be avoided unless there's a specific semantic need for null values.

### Avoid sensitive = false

**Severity:** MUST | **Requirement:** TFNFR22

`sensitive = false` **MUST** be avoided (this is the default).

### Sensitive Default Value Conditions

**Severity:** MUST | **Requirement:** TFNFR23

A default value **MUST NOT** be set for sensitive inputs (e.g., default passwords).

### Handling Deprecated Variables

**Severity:** MUST | **Requirement:** TFNFR24

- Move deprecated variables to `deprecated_variables.tf`
- Annotate with `DEPRECATED` at the beginning of description
- Declare the replacement's name
- Clean up during major version releases

---

## Output Requirements

### Additional Terraform Outputs

**Severity:** SHOULD | **Requirement:** TFFR2

Authors **SHOULD NOT** output entire resource objects as these may contain sensitive data and the schema can change with API or provider versions.

**Best Practices:**

- Output *computed* attributes of resources as discrete outputs (anti-corruption layer pattern)
- **SHOULD NOT** output values that are already inputs (except `name`)
- Use `sensitive = true` for sensitive attributes
- For resources deployed with `for_each`, output computed attributes in a map structure

**Examples:**

```hcl
# Single resource computed attribute
output "foo" {
  description = "MyResource foo attribute"
  value       = azurerm_resource_myresource.foo
}

# for_each resources
output "childresource_foos" {
  description = "MyResource children's foo attributes"
  value = {
    for key, value in azurerm_resource_mychildresource : key => value.foo
  }
}

# Sensitive output
output "bar" {
  description = "MyResource bar attribute"
  value       = azurerm_resource_myresource.bar
  sensitive   = true
}
```

### Sensitive Data Outputs

**Severity:** MUST | **Requirement:** TFNFR29

Outputs containing confidential data **MUST** be declared with `sensitive = true`.

### Handling Deprecated Outputs

**Severity:** MUST | **Requirement:** TFNFR30

- Move deprecated outputs to `deprecated_outputs.tf`
- Define new outputs in `outputs.tf`
- Clean up during major version releases

---

## Local Values Standards

### locals.tf Organization

**Severity:** MAY | **Requirement:** TFNFR31

- `locals.tf` **SHOULD** only contain `locals` blocks
- **MAY** declare `locals` blocks next to resources for advanced scenarios

### Alphabetical Local Arrangement

**Severity:** MUST | **Requirement:** TFNFR32

Expressions in `locals` blocks **MUST** be arranged alphabetically.

### Precise Local Types

**Severity:** SHOULD | **Requirement:** TFNFR33

Use precise types (e.g., `number` for age, not `string`).

---

## Terraform Configuration Requirements

### Terraform Version Requirements

**Severity:** MUST | **Requirement:** TFNFR25

**`terraform.tf` requirements:**

- **MUST** contain only one `terraform` block
- First line **MUST** define `required_version`
- **MUST** include minimum version constraint
- **MUST** include maximum major version constraint
- **SHOULD** use `~> #.#` or `>= #.#.#, < #.#.#` format

**Example:**

```hcl
terraform {
  required_version = "~> 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

### Providers in required_providers

**Severity:** MUST | **Requirement:** TFNFR26

- `terraform` block **MUST** contain `required_providers` block
- Each provider **MUST** specify `source` and `version`
- Providers **SHOULD** be sorted alphabetically
- Only include directly required providers
- `source` **MUST** be in format `namespace/name`
- `version` **MUST** include minimum and maximum major version constraints
- **SHOULD** use `~> #.#` or `>= #.#.#, < #.#.#` format

---

## Testing Requirements

### Test Tooling

**Severity:** MUST | **Requirement:** TFNFR5

**Required testing tools for AVM:**

- Terraform (`terraform validate/fmt/test`)
- terrafmt
- Checkov
- tflint (with azurerm ruleset)
- Go (optional for custom tests)

### Test Provider Configuration

**Severity:** SHOULD | **Requirement:** TFNFR36

For robust testing, `prevent_deletion_if_contains_resources` **SHOULD** be explicitly set to `false` in test provider configurations.

---

## Documentation Requirements

### Module Documentation Generation

**Severity:** MUST | **Requirement:** TFNFR2

- Documentation **MUST** be automatically generated via [Terraform Docs](https://github.com/terraform-docs/terraform-docs)
- A `.terraform-docs.yml` file **MUST** be present in the module root

---

## Breaking Changes & Feature Management

### Using Feature Toggles

**Severity:** MUST | **Requirement:** TFNFR34

New resources added in minor/patch versions **MUST** have a toggle variable to avoid creation by default:

```hcl
variable "create_route_table" {
  type     = bool
  default  = false
  nullable = false
}

resource "azurerm_route_table" "this" {
  count = var.create_route_table ? 1 : 0
  # ...
}
```

### Reviewing Potential Breaking Changes

**Severity:** MUST | **Requirement:** TFNFR35

**Breaking changes requiring caution:**

**Resource blocks:**

1. Adding new resource without conditional creation
2. Adding arguments with non-default values
3. Adding nested blocks without `dynamic`
4. Renaming resources without `moved` blocks
5. Changing `count` to `for_each` or vice versa

**Variable/Output blocks:**

1. Deleting/renaming variables
2. Changing variable `type`
3. Changing variable `default` values
4. Changing `nullable` to false
5. Changing `sensitive` from false to true
6. Adding variables without `default`
7. Deleting outputs
8. Changing output `value`
9. Changing output `sensitive` value

---

## Contribution Standards

### GitHub Repository Branch Protection

**Severity:** MUST | **Requirement:** TFNFR3

Module owners **MUST** set branch protection policies on the default branch (typically `main`):

1. Require Pull Request before merging
2. Require approval of most recent reviewable push
3. Dismiss stale PR approvals when new commits are pushed
4. Require linear history
5. Prevent force pushes
6. Not allow deletions
7. Require CODEOWNERS review
8. No bypassing settings allowed
9. Enforce for administrators

---

## Compliance Checklist

Use this checklist when developing or reviewing Azure Verified Modules:

### Module Structure
- [ ] Module cross-references use registry sources with pinned versions
- [ ] Azure providers (azurerm/azapi) versions meet AVM requirements
- [ ] `.terraform-docs.yml` present in module root
- [ ] CODEOWNERS file present

### Code Style
- [ ] All names use lower snake_casing
- [ ] Resources ordered with dependencies first
- [ ] `for_each` uses `map()` or `set()` with static keys
- [ ] Resource/data/module blocks follow proper internal ordering
- [ ] `ignore_changes` not quoted
- [ ] Dynamic blocks used for conditional nested objects
- [ ] `coalesce()` or `try()` used for default values

### Variables
- [ ] No `enabled` or `module_depends_on` variables
- [ ] Variables ordered: required (alphabetical) then optional (alphabetical)
- [ ] All variables have precise types (avoid `any`)
- [ ] All variables have descriptions
- [ ] Collections have `nullable = false`
- [ ] No `sensitive = false` declarations
- [ ] No default values for sensitive inputs
- [ ] Deprecated variables moved to `deprecated_variables.tf`

### Outputs
- [ ] Outputs use anti-corruption layer pattern (discrete attributes)
- [ ] Sensitive outputs marked `sensitive = true`
- [ ] Deprecated outputs moved to `deprecated_outputs.tf`

### Terraform Configuration
- [ ] `terraform.tf` has version constraints (`~>` format)
- [ ] `required_providers` block present with all providers
- [ ] No `provider` declarations in module (except aliases)
- [ ] Locals arranged alphabetically

### Testing & Quality
- [ ] Required testing tools configured
- [ ] New resources have feature toggles
- [ ] Breaking changes reviewed and documented

---

## Summary Statistics

- **Functional Requirements:** 3
- **Non-Functional Requirements:** 34
- **Total Requirements:** 37

### By Severity
- **MUST:** 21 requirements
- **SHOULD:** 14 requirements
- **MAY:** 2 requirements

---

*Based on: Azure Verified Modules - Terraform Requirements*
