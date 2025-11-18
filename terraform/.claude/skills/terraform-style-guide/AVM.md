# Terraform Azure Verified Modules (AVM) Requirements Summary

## Functional Requirements

### TFFR1 - Cross-Referencing Modules
**Severity:** MUST | **Category:** Naming/Composition

Module owners **MAY** cross-reference other modules to build Resource or Pattern modules. However:
- Modules **MUST** be referenced using HashiCorp Terraform registry reference to a pinned version
  - Example: `source = "Azure/xxx/azurerm"` with `version = "1.2.3"`
- Modules **MUST NOT** use git references (e.g., `git::https://xxx.yyy/xxx.git` or `github.com/xxx/yyy`)
- Modules **MUST NOT** contain references to non-AVM modules

---

### TFFR2 - Additional Terraform Outputs
**Severity:** SHOULD | **Category:** Inputs/Outputs

Authors **SHOULD NOT** output entire resource objects as these may contain sensitive data and the schema can change with API or provider versions.

**Best Practices:**
- Output *computed* attributes of resources as discrete outputs (anti-corruption layer pattern)
- **SHOULD NOT** output values that are already inputs (except `name`)
- Use `sensitive = true` for sensitive attributes
- For resources deployed with `for_each`, output computed attributes in a map structure

**Examples:**
```terraform
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

---

### TFFR3 - Providers - Permitted Versions
**Severity:** MUST | **Category:** Naming/Composition

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
```terraform
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

## Non-Functional Requirements

### Documentation

#### TFNFR1 - Descriptions
**Severity:** MUST | **Category:** Documentation

Variable and output descriptions **MAY** span multiple lines using HEREDOC format with embedded markdown for examples.

#### TFNFR2 - Module Documentation Generation
**Severity:** MUST | **Category:** Documentation

- Documentation **MUST** be automatically generated via [Terraform Docs](https://github.com/terraform-docs/terraform-docs)
- A `.terraform-docs.yml` file **MUST** be present in the module root

---

### Contribution/Support

#### TFNFR3 - GitHub Repo Branch Protection
**Severity:** MUST | **Category:** Contribution/Support

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

### Naming & Code Style

#### TFNFR4 - Lower snake_casing
**Severity:** MUST | **Category:** Naming/Composition

**MUST** use lower snake_casing for:
- Locals
- Variables
- Outputs
- Resources (symbolic names)
- Modules (symbolic names)

Example: `snake_casing_example`

#### TFNFR6 - Resource & Data Order
**Severity:** SHOULD | **Category:** Code Style

- Resources that are depended on **SHOULD** come first
- Resources with dependencies **SHOULD** be defined close to each other

#### TFNFR7 - Count & for_each Use
**Severity:** MUST | **Category:** Code Style

- Use `count` for conditional resource creation
- **MUST** use `map(xxx)` or `set(xxx)` as resource's `for_each` collection
- The map's key or set's element **MUST** be static literals

**Good Example:**
```terraform
resource "azurerm_subnet" "pair" {
  for_each             = var.subnet_map  # map(string)
  name                 = "${each.value}"-pair
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

#### TFNFR8 - Resource & Data Block Orders
**Severity:** SHOULD | **Category:** Code Style

**Order within resource/data blocks:**

1. Meta-arguments (top):
   - `provider`
   - `count`
   - `for_each`

2. Arguments/blocks (middle, alphabetical):
   - Required arguments
   - Optional arguments
   - Required nested blocks
   - Optional nested blocks

3. Meta-arguments (bottom):
   - `depends_on`
   - `lifecycle` (with sub-order: `create_before_destroy`, `ignore_changes`, `prevent_destroy`)

Separate sections with blank lines.

#### TFNFR9 - Module Block Order
**Severity:** SHOULD | **Category:** Code Style

**Order within module blocks:**

1. Top meta-arguments:
   - `source`
   - `version`
   - `count`
   - `for_each`

2. Arguments (alphabetical):
   - Required arguments
   - Optional arguments

3. Bottom meta-arguments:
   - `depends_on`
   - `providers`

#### TFNFR10 - No Double Quotes in ignore_changes
**Severity:** MUST | **Category:** Code Style

The `ignore_changes` attribute **MUST NOT** be enclosed in double quotes.

**Good:**
```terraform
lifecycle {
  ignore_changes = [tags]
}
```

**Bad:**
```terraform
lifecycle {
  ignore_changes = ["tags"]
}
```

#### TFNFR11 - Null Comparison Toggle
**Severity:** SHOULD | **Category:** Code Style

For parameters requiring conditional resource creation, wrap with `object` type to avoid "known after apply" issues during plan stage.

**Recommended:**
```terraform
variable "security_group" {
  type = object({
    id = string
  })
  default = null
}
```

#### TFNFR12 - Dynamic for Optional Nested Objects
**Severity:** MUST | **Category:** Code Style

Nested blocks under conditions **MUST** use this pattern:

```terraform
dynamic "identity" {
  for_each = <condition> ? [<some_item>] : []
  
  content {
    # block content
  }
}
```

#### TFNFR13 - Default Values with coalesce/try
**Severity:** SHOULD | **Category:** Code Style

**Good:**
```terraform
coalesce(var.new_network_security_group_name, "${var.subnet_name}-nsg")
```

**Bad:**
```terraform
var.new_network_security_group_name == null ? "${var.subnet_name}-nsg" : var.new_network_security_group_name
```

---

### Variables

#### TFNFR14 - Not Allowed Variables
**Severity:** MUST | **Category:** Inputs/Outputs

Module owners **MUST NOT** add variables like `enabled` or `module_depends_on` to control entire module operation. Boolean feature toggles are acceptable.

#### TFNFR15 - Variable Definition Order
**Severity:** SHOULD | **Category:** Code Style

Variables **SHOULD** follow this order:
1. All required fields (alphabetical)
2. All optional fields (alphabetical)

#### TFNFR16 - Variable Naming Rules
**Severity:** SHOULD | **Category:** Code Style

- Follow [HashiCorp's naming rules](https://www.terraform.io/docs/extend/best-practices/naming.html)
- Feature switches **SHOULD** use positive statements: `xxx_enabled` instead of `xxx_disabled`

#### TFNFR17 - Variables with Descriptions
**Severity:** SHOULD | **Category:** Code Style

- `description` **SHOULD** precisely describe the parameter's purpose and expected data type
- Target audience is module users, not developers
- For `object` types, use HEREDOC format

#### TFNFR18 - Variables with Types
**Severity:** MUST | **Category:** Code Style

- `type` **MUST** be defined for every variable
- `type` **SHOULD** be as precise as possible
- `any` **MAY** only be used with adequate reasons
- Use `bool` instead of `string`/`number` for true/false values
- Use concrete `object` instead of `map(any)`

#### TFNFR19 - Sensitive Data Variables
**Severity:** SHOULD | **Category:** Code Style

If a variable's type is `object` and contains sensitive fields, the entire variable **SHOULD** be `sensitive = true`, or extract sensitive fields into separate variables.

#### TFNFR20 - Non-Nullable Defaults for Collection Values
**Severity:** SHOULD | **Category:** Code Style

Nullable **SHOULD** be set to `false` for collection values (sets, maps, lists) when using them in loops. For scalar values, null may have semantic meaning.

#### TFNFR21 - Discourage Nullability by Default
**Severity:** MUST | **Category:** Code Style

`nullable = true` **MUST** be avoided.

#### TFNFR22 - Avoid sensitive = false
**Severity:** MUST | **Category:** Code Style

`sensitive = false` **MUST** be avoided.

#### TFNFR23 - Sensitive Default Value Conditions
**Severity:** MUST | **Category:** Code Style

A default value **MUST NOT** be set for sensitive inputs (e.g., default passwords).

#### TFNFR24 - Handling Deprecated Variables
**Severity:** MUST | **Category:** Code Style

- Move deprecated variables to `deprecated_variables.tf`
- Annotate with `DEPRECATED` at the beginning of description
- Declare the replacement's name
- Clean up during major version releases

---

### Terraform Configuration

#### TFNFR25 - Verified Modules Requirements
**Severity:** MUST | **Category:** Code Style

**`terraform.tf` requirements:**
- **MUST** contain only one `terraform` block
- First line **MUST** define `required_version`
- **MUST** include minimum version constraint
- **MUST** include maximum major version constraint
- **SHOULD** use `~> #.#` or `>= #.#.#, < #.#.#` format

**Example:**
```terraform
terraform {
  required_version = "~> 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.11"
    }
  }
}
```

#### TFNFR26 - Providers in required_providers
**Severity:** MUST | **Category:** Code Style

- `terraform` block **MUST** contain `required_providers` block
- Each provider **MUST** specify `source` and `version`
- Providers **SHOULD** be sorted alphabetically
- Only include directly required providers
- `source` **MUST** be in format `namespace/name`
- `version` **MUST** include minimum and maximum major version constraints
- **SHOULD** use `~> #.#` or `>= #.#.#, < #.#.#` format

#### TFNFR27 - Provider Declarations in Modules
**Severity:** MUST | **Category:** Code Style

- `provider` **MUST NOT** be declared in modules (except for `configuration_aliases`)
- `provider` blocks in modules **MUST** only use `alias`
- Provider configurations **SHOULD** be passed in by module users

---

### Outputs

#### TFNFR29 - Sensitive Data Outputs
**Severity:** MUST | **Category:** Code Style

Outputs containing confidential data **MUST** be declared with `sensitive = true`.

#### TFNFR30 - Handling Deprecated Outputs
**Severity:** MUST | **Category:** Code Style

- Move deprecated outputs to `deprecated_outputs.tf`
- Define new outputs in `outputs.tf`
- Clean up during major version releases

---

### Locals

#### TFNFR31 - locals.tf for Locals Only
**Severity:** MAY | **Category:** Code Style

- `locals.tf` **SHOULD** only contain `locals` blocks
- **MAY** declare `locals` blocks next to resources for advanced scenarios

#### TFNFR32 - Alphabetical Local Arrangement
**Severity:** MUST | **Category:** Code Style

Expressions in `locals` blocks **MUST** be arranged alphabetically.

#### TFNFR33 - Precise Local Types
**Severity:** SHOULD | **Category:** Code Style

Use precise types (e.g., `number` for age, not `string`).

---

### Breaking Changes & Feature Management

#### TFNFR34 - Using Feature Toggles
**Severity:** MUST | **Category:** Code Style

New resources added in minor/patch versions **MUST** have a toggle variable to avoid creation by default:

```terraform
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

#### TFNFR35 - Reviewing Potential Breaking Changes
**Severity:** MUST | **Category:** Code Style

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

### Testing

#### TFNFR5 - Test Tooling
**Severity:** MUST | **Category:** Testing

**Required testing tools:**
- Terraform (`terraform validate/fmt/test`)
- terrafmt
- Checkov
- tflint (with azurerm ruleset)
- Go (optional for custom tests)

#### TFNFR36 - Setting prevent_deletion_if_contains_resources
**Severity:** SHOULD | **Category:** Code Style

For robust testing, `prevent_deletion_if_contains_resources` **SHOULD** be explicitly set to `false` in test provider configurations.

---

### Optional Tools

#### TFNFR37 - Tool Usage by Module Owner
**Severity:** MAY | **Category:** Code Style

Module owners **MAY** use `newres` command-line tool to generate Terraform configuration files for new resources, reducing manual configuration time.

---

## Summary Statistics

- **Functional Requirements:** 3
- **Non-Functional Requirements:** 34
- **Total Requirements:** 37

### By Severity:
- **MUST:** 21 requirements
- **SHOULD:** 14 requirements
- **MAY:** 2 requirements

### By Category:
- **Code Style:** 21 requirements
- **Documentation:** 2 requirements
- **Testing:** 2 requirements
- **Naming/Composition:** 3 requirements
- **Inputs/Outputs:** 3 requirements
- **Contribution/Support:** 1 requirement

---

*Generated on: November 5, 2025*  
*Source: Azure Verified Modules - Terraform Requirements*
