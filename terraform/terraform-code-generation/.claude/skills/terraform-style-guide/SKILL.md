---
name: terraform-style-guide
description: Comprehensive guide for Terraform code style, formatting, and best practices based on HashiCorp's official standards and Azure Verified Modules (AVM) requirements. Use when writing or reviewing Terraform configurations, formatting code, organizing files and modules, establishing team conventions, managing version control, ensuring code quality and consistency across infrastructure projects, or developing Azure Verified Modules.
---

# Terraform Style Guide

Adopting and adhering to a style guide keeps your Terraform code legible, scalable, and maintainable. This guide is based on HashiCorp's official Terraform style conventions and best practices, enhanced with Azure Verified Modules (AVM) requirements for Azure-specific Terraform development.

> **Note on AVM Requirements**: The Azure Verified Modules section provides requirements specific to Azure module development. While these requirements are mandatory for AVM certification, many of the patterns and practices have broader applicability to Terraform module development across all cloud providers and can be adopted to improve code quality, consistency, and maintainability in any Terraform project.

## Table of Contents

- [Code Style Fundamentals](#code-style-fundamentals)
- [Code Formatting Standards](#code-formatting-standards)
- [File Organization](#file-organization)
- [Naming Conventions](#naming-conventions)
- [Resource Organization](#resource-organization)
- [Variables and Outputs](#variables-and-outputs)
- [Local Values](#local-values)
- [Provider Configuration and Aliasing](#provider-configuration-and-aliasing)
- [Dynamic Resource Creation](#dynamic-resource-creation)
- [Version Control](#version-control)
- [Workflow Standards](#workflow-standards)
- [Multi-Environment Management](#multi-environment-management)
- [State and Secrets Management](#state-and-secrets-management)
- [Testing and Policy](#testing-and-policy)
- [Azure Verified Modules (AVM) Requirements](#azure-verified-modules-avm-requirements)
  - [Module Cross-Referencing](#module-cross-referencing)
  - [Azure Provider Requirements](#azure-provider-requirements)
  - [AVM Code Style Standards](#avm-code-style-standards)
  - [AVM Variable Requirements](#avm-variable-requirements)
  - [AVM Output Requirements](#avm-output-requirements)
  - [AVM Testing Requirements](#avm-testing-requirements)
  - [Breaking Changes & Feature Management](#breaking-changes--feature-management)

---

## Code Style Fundamentals

### Core Principles

Always follow these fundamental practices:

- **Execute `terraform fmt`** before committing code to version control
- **Execute `terraform validate`** to catch syntax and configuration errors
- **Use `#` for comments** (avoid `//` and `/* */` style comments)
- **Name resources with descriptive nouns** using underscores, excluding the resource type
- **Define dependent resources after their dependencies** for better readability
- **Include type and description for all variables**
- **Include descriptions for all outputs**
- **Use `count` and `for_each` judiciously** with clear intent

### Automation with Git Hooks

Consider using Git pre-commit hooks to automatically run `terraform fmt` and `terraform validate`:

```bash
#!/bin/bash
# .git/hooks/pre-commit

terraform fmt -recursive
terraform validate
```

---

## Code Formatting Standards

Terraform has specific formatting conventions that the `terraform fmt` command automates.

### Indentation

- Use **two spaces** per nesting level
- Never use tabs

```hcl
resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = "example-instance"
  }
}
```

### Alignment

- **Align equals signs** for consecutive single-line arguments at the same nesting level
- Separate different argument groups with blank lines

```hcl
# Good - aligned equals signs
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = "subnet-12345678"

  tags = {
    Name        = "web-server"
    Environment = "production"
  }
}

# Bad - unaligned
resource "aws_instance" "web" {
  ami = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id = "subnet-12345678"
}
```

### Block Organization

- **Arguments precede blocks** within a resource
- **Separate with one blank line** between arguments and blocks
- **Meta-arguments come first**, followed by standard arguments, then blocks

```hcl
resource "aws_instance" "example" {
  # Meta-arguments first
  count = 3

  # Standard arguments
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  # Blocks last
  root_block_device {
    volume_size = 20
  }
}
```

### Spacing

- Use **single blank lines** to separate logical groups of arguments
- **Top-level blocks** (resources, data sources, modules) require blank lines between them
- Do not use excessive blank lines

```hcl
variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
```

---

## File Organization

### Standard File Structure

Organize your Terraform code into these standard files:

| File | Purpose |
|------|---------|
| `terraform.tf` | Terraform and provider version requirements |
| `providers.tf` | Provider configurations |
| `main.tf` | Primary resources and data sources |
| `variables.tf` | Input variable declarations (alphabetical order) |
| `outputs.tf` | Output value declarations (alphabetical order) |
| `locals.tf` | Local value declarations |

Example `terraform.tf`:

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.34.0"
    }
  }
}
```

Example `providers.tf`:

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "MyProject"
    }
  }
}
```


---

## Naming Conventions

### General Rules

- Use **descriptive nouns and underscores** to separate multiple words
- **Exclude the resource type** from the resource name (redundant)
- Use **lowercase** for all names
- Be **specific and meaningful**

### Examples

```hcl
# ❌ Bad - includes resource type, uses hyphens, mixed case
resource "aws_instance" "webAPI-aws-instance" {
  # ...
}

# ✅ Good - descriptive noun, underscores, lowercase
resource "aws_instance" "web_api" {
  # ...
}

# ❌ Bad - too generic
variable "name" {
  type = string
}

# ✅ Good - specific and clear
variable "application_name" {
  type = string
}
```

### Variable Naming

Variables should clearly indicate their purpose:

```hcl
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}
```

---

## Resource Organization

### Dependency Order

**Define a data source before the resource that references it** for better readability:

```hcl
# Data source first
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Resource that uses it second
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
}
```

### Parameter Order Within Resources

Follow this standard ordering for resource parameters:

1. **`count` or `for_each`** (meta-arguments)
2. **Resource-specific non-block parameters** (alphabetically or logically grouped)
3. **Resource-specific block parameters**
4. **`lifecycle` block** (if needed)
5. **`depends_on`** (if required, as last resort)

```hcl
resource "aws_instance" "web" {
  # 1. Meta-arguments
  count = var.instance_count

  # 2. Non-block parameters
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id

  # 3. Block parameters
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "web-${count.index}"
  }

  # 4. Lifecycle
  lifecycle {
    create_before_destroy = true
  }

  # 5. depends_on (avoid if possible)
  # depends_on = [aws_iam_role_policy.example]
}
```

---

## Variables and Outputs

### Variable Declaration Standards

**Every variable must include:**
- `type` - the data type
- `description` - clear explanation of purpose

**Optional but recommended:**
- `default` - default value if applicable
- `sensitive` - mark as true for secrets
- `validation` - for uniquely restrictive requirements

```hcl
variable "instance_type" {
  description = "EC2 instance type for the web server"
  type        = string
  default     = "t2.micro"

  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium"], var.instance_type)
    error_message = "Instance type must be t2.micro, t2.small, or t2.medium."
  }
}

variable "database_password" {
  description = "Password for the database admin user"
  type        = string
  sensitive   = true
}

variable "availability_zones" {
  description = "List of availability zones for resource placement"
  type        = list(string)
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### Output Declaration Standards

**Every output must include:**
- `description` - clear explanation of the value

**Optional attributes:**
- `sensitive` - mark as true to hide from console output
- `depends_on` - explicit dependencies if needed

```hcl
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "database_password" {
  description = "Database administrator password"
  value       = aws_db_instance.main.password
  sensitive   = true
}
```

### Variable Files Organization

Organize variables alphabetically in `variables.tf` and use `.tfvars` files for environment-specific values:

```hcl
# terraform.tfvars (or dev.tfvars, prod.tfvars)
instance_type      = "t2.micro"
instance_count     = 3
availability_zones = ["us-west-2a", "us-west-2b"]
```

---

## Local Values

### Usage Guidelines

Use local values **sparingly** to avoid unnecessary complexity. Locals are appropriate when:
- Avoiding repetition of complex expressions
- Giving meaningful names to intermediate values
- Computing values used multiple times

```hcl
locals {
  # Good use case - computing a reusable value
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  )

  # Good use case - naming a complex expression
  vpc_id = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.existing[0].id
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  tags = local.common_tags
}
```

### Anti-patterns to Avoid

```hcl
# ❌ Bad - unnecessary local for a simple reference
locals {
  instance_type = var.instance_type
}

# ✅ Good - use the variable directly
resource "aws_instance" "web" {
  instance_type = var.instance_type
}
```

---

## Provider Configuration and Aliasing

### Default Provider First

**Always define a default provider configuration first**, then aliases:

```hcl
# Default provider
provider "aws" {
  region = "us-west-2"
}

# Aliased provider for another region
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

# Using the aliased provider
resource "aws_instance" "east_web" {
  provider = aws.east

  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
```

### Module Provider Configuration

For modules that use multiple providers, specify via the `providers` meta-argument:

```hcl
module "vpc_replication" {
  source = "./modules/vpc"

  providers = {
    aws.primary   = aws
    aws.secondary = aws.east
  }
}
```

---

## Dynamic Resource Creation

### count vs for_each

Choose the appropriate meta-argument based on your use case:

**Use `for_each`** when:
- Resources need distinct argument values
- You want to reference resources by key instead of index
- Resources are based on a map or set
- Preference for_each over count

**Use `count`** when:
- Conditional resource creation (0 or 1)

**Avoid `count`** for:
- Simple numeric repetition (use `for_each` with a set or map instead)

### for_each Examples

```hcl
# Using for_each with a map
variable "instances" {
  type = map(object({
    instance_type = string
    ami           = string
  }))
  default = {
    web = {
      instance_type = "t2.micro"
      ami           = "ami-0c55b159cbfafe1f0"
    }
    api = {
      instance_type = "t2.small"
      ami           = "ami-0c55b159cbfafe1f0"
    }
  }
}

resource "aws_instance" "servers" {
  for_each = var.instances

  ami           = each.value.ami
  instance_type = each.value.instance_type

  tags = {
    Name = each.key
  }
}

# Reference: aws_instance.servers["web"].id
```

```hcl
# Using for_each with a set
variable "subnet_cidrs" {
  type    = set(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

resource "aws_subnet" "private" {
  for_each = var.subnet_cidrs

  vpc_id     = aws_vpc.main.id
  cidr_block = each.value

  tags = {
    Name = "private-${each.key}"
  }
}
```

### count Examples

```hcl
# Conditional resource creation
variable "enable_monitoring" {
  type    = bool
  default = false
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "high-cpu-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
}

# Reference (when created): aws_cloudwatch_metric_alarm.cpu[0].id
```

### Anti-pattern: count for Numeric Repetition

**❌ Avoid this pattern** - Using `count` for simple numeric repetition:

```hcl
# BAD: Don't use count for numeric repetition
variable "instance_count" {
  type    = number
  default = 3
}

resource "aws_instance" "web" {
  count = var.instance_count

  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = "web-${count.index}"
  }
}
```

**✅ Better approach** - Use `for_each` with a set instead:

```hcl
# GOOD: Use for_each for multiple similar resources
variable "instance_names" {
  type    = set(string)
  default = ["web-1", "web-2", "web-3"]
}

resource "aws_instance" "web" {
  for_each = var.instance_names

  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = each.key
  }
}

# Reference: aws_instance.web["web-1"].id
```

**Why?** Using `for_each` provides stable resource addresses that don't change when you add or remove instances from the middle of the list.

---

## Version Control

### .gitignore Configuration

**Never commit to version control:**
- State files (`terraform.tfstate`, `terraform.tfstate.backup`)
- Lock info files (`.terraform.tfstate.lock.info`)
- `.terraform` directory (provider plugins and modules)
- Saved plan files (`*.tfplan`, `plan.out`)
- `.tfvars` files containing sensitive data

**Always commit:**
- All `.tf` configuration files
- `.terraform.lock.hcl` (dependency lock file)
- `.gitignore` file
- README and documentation files

---

## Workflow Standards

### Version Pinning

**Always pin versions explicitly** to ensure reproducible deployments:

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.34.0"  # Pin to exact version for stability
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"  # Allow patch updates only
    }
  }
}
```

**Version constraint operators:**
- `= 1.0.0` - Exact version only
- `>= 1.0.0` - Greater than or equal to
- `~> 1.0` - Allow rightmost version component to increment (1.0, 1.1, but not 2.0)
- `>= 1.0, < 2.0` - Version range

### Module Repository Naming

Use the convention: `terraform-<PROVIDER>-<NAME>`

Examples:
- `terraform-aws-vpc`
- `terraform-azurerm-virtual-network`
- `terraform-google-kubernetes-engine`

### Repository Strategy

Three common approaches:

**1. Separate Module Repositories** (Recommended)
- Each module in its own repository
- Independent versioning and release cycles
- Clear ownership boundaries

**2. Logical Infrastructure Grouping**
- Group related resources per repository
- Example: `infra-networking`, `infra-compute`, `infra-databases`
- Easier to manage related changes together

**3. Monorepo**
- All infrastructure code in one repository
- Centralized management
- Requires careful CI/CD targeting

### Branching Strategy

Adopt **GitHub Flow** for simplicity:

1. Create **short-lived feature branches** from main
2. Submit **pull requests** for review
3. Enable **speculative plans** in HCP Terraform (automatic on PRs)
4. **Merge** to main after approval
5. **Delete** feature branches after merge

```bash
# Create feature branch
git checkout -b feature/add-monitoring

# Make changes and commit
git add .
git commit -m "Add CloudWatch monitoring for EC2 instances"

# Push and create PR
git push origin feature/add-monitoring
```

---

## Multi-Environment Management

### Workspace-Based Approach (Recommended with HCP Terraform)

Use separate workspaces for each environment:

```hcl
# Development workspace: app-dev
# Staging workspace: app-staging
# Production workspace: app-prod
```

Terraform Cloud/HCP Terraform automatically manages state per workspace.

---

## State and Secrets Management

### Use HCP Terraform for state storage

### State File Security

**Never share full state files directly**. State files contain sensitive information.

**Alternatives for sharing data:**

1. **tfe_outputs data source** (HCP Terraform):

```hcl
data "tfe_outputs" "vpc" {
  organization = "my-org"
  workspace    = "networking-prod"
}

resource "aws_instance" "web" {
  subnet_id = data.tfe_outputs.vpc.values.private_subnet_ids[0]
}
```

2. **Provider-specific data sources**:

```hcl
data "aws_vpc" "main" {
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "app" {
  vpc_id = data.aws_vpc.main.id
}
```

### Secrets Management

**Protect credentials** through:

1. **Dynamic Provider Credentials** (HCP Terraform)
   - OIDC-based authentication
   - No long-lived credentials in configuration

2. **HashiCorp Vault Integration**:

```hcl
data "vault_generic_secret" "database" {
  path = "secret/database"
}

resource "aws_db_instance" "main" {
  username = data.vault_generic_secret.database.data["username"]
  password = data.vault_generic_secret.database.data["password"]
}
```

3. **Environment Variables**:

```hcl
variable "database_password" {
  description = "Database password (set via TF_VAR_database_password)"
  type        = string
  sensitive   = true
}
```

```bash
export TF_VAR_database_password="secure-password"
terraform apply
```

---

## Testing and Policy

### Module Testing

Write tests for modules using **Terraform's native testing framework**:

```hcl
# tests/vpc.tftest.hcl
run "valid_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block did not match expected value"
  }
}

run "vpc_enables_dns" {
  command = plan

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "VPC should have DNS hostnames enabled"
  }
}
```

Run tests:

```bash
terraform test
```


### Common Testing Scenarios

1. **Validation Tests** - Verify variable constraints
2. **Plan Tests** - Check expected resources will be created
3. **Apply Tests** - Test actual resource creation (in isolated environment)
4. **Integration Tests** - Verify resources work together correctly

---

## Summary Checklist

Use this checklist for code reviews:

- [ ] Code formatted with `terraform fmt`
- [ ] Configuration validated with `terraform validate`
- [ ] Files organized according to standard structure
- [ ] All variables have type and description
- [ ] All outputs have descriptions
- [ ] Resource names use descriptive nouns with underscores
- [ ] Resources ordered with dependencies first
- [ ] Version constraints pinned explicitly
- [ ] Sensitive values marked with `sensitive = true`
- [ ] `.gitignore` excludes state files and secrets
- [ ] Tests written for modules
- [ ] Policy requirements satisfied
- [ ] Code reviewed by teammate

---

## Azure Verified Modules (AVM) Requirements

> **Important**: The following requirements are **mandatory for Azure Verified Modules** but represent best practices that can enhance Terraform module development across any cloud provider.

### Module Cross-Referencing

**Severity:** MUST | **Requirement:** TFFR1

When building Resource or Pattern modules, module owners **MAY** cross-reference other modules. However:

- Modules **MUST** be referenced using HashiCorp Terraform registry reference to a pinned version
  - Example: `source = "Azure/xxx/azurerm"` with `version = "1.2.3"`
- Modules **MUST NOT** use git references (e.g., `git::https://xxx.yyy/xxx.git` or `github.com/xxx/yyy`)
- Modules **MUST NOT** contain references to non-AVM modules

**Broader Applicability**: Always use registry references with pinned versions for any module to ensure reproducibility and version control.

---

### Azure Provider Requirements

**Severity:** MUST | **Requirement:** TFFR3

For Azure Verified Modules, authors **MUST** only use the following Azure providers:

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

**Broader Applicability**: Always specify provider versions with appropriate constraints for any cloud provider to ensure compatibility.

---

### AVM Code Style Standards

#### Lower snake_casing

**Severity:** MUST | **Requirement:** TFNFR4

**MUST** use lower snake_casing for:

- Locals
- Variables
- Outputs
- Resources (symbolic names)
- Modules (symbolic names)

Example: `snake_casing_example`

#### Resource & Data Source Ordering

**Severity:** SHOULD | **Requirement:** TFNFR6

- Resources that are depended on **SHOULD** come first
- Resources with dependencies **SHOULD** be defined close to each other

#### Count & for_each Usage

**Severity:** MUST | **Requirement:** TFNFR7

- Use `count` for conditional resource creation
- **MUST** use `map(xxx)` or `set(xxx)` as resource's `for_each` collection
- The map's key or set's element **MUST** be static literals

**Good Example:**

```hcl
resource "azurerm_subnet" "pair" {
  for_each             = var.subnet_map  # map(string)
  name                 = "${each.value}-pair"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

**Broader Applicability**: Using typed collections with `for_each` ensures predictable behavior across all providers.

#### Resource & Data Block Internal Ordering

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

#### Module Block Ordering

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

#### Lifecycle ignore_changes Syntax

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

#### Null Comparison for Conditional Creation

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

**Broader Applicability**: This pattern prevents plan-time issues across all providers when using conditional resources.

#### Dynamic Blocks for Optional Nested Objects

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

**Broader Applicability**: This is the standard Terraform pattern for conditional nested blocks.

#### Default Values with coalesce/try

**Severity:** SHOULD | **Requirement:** TFNFR13

**Good:**

```hcl
coalesce(var.new_network_security_group_name, "${var.subnet_name}-nsg")
```

**Bad:**

```hcl
var.new_network_security_group_name == null ? "${var.subnet_name}-nsg" : var.new_network_security_group_name
```

**Broader Applicability**: `coalesce()` and `try()` functions provide cleaner, more readable default value handling.

#### Provider Declarations in Modules

**Severity:** MUST | **Requirement:** TFNFR27

- `provider` **MUST NOT** be declared in modules (except for `configuration_aliases`)
- `provider` blocks in modules **MUST** only use `alias`
- Provider configurations **SHOULD** be passed in by module users

**Broader Applicability**: This is a universal best practice for reusable Terraform modules.

---

### AVM Variable Requirements

#### Not Allowed Variables

**Severity:** MUST | **Requirement:** TFNFR14

Module owners **MUST NOT** add variables like `enabled` or `module_depends_on` to control entire module operation. Boolean feature toggles for specific resources are acceptable.

#### Variable Definition Order

**Severity:** SHOULD | **Requirement:** TFNFR15

Variables **SHOULD** follow this order:

1. All required fields (alphabetical)
2. All optional fields (alphabetical)

#### Variable Naming Rules

**Severity:** SHOULD | **Requirement:** TFNFR16

- Follow [HashiCorp's naming rules](https://www.terraform.io/docs/extend/best-practices/naming.html)
- Feature switches **SHOULD** use positive statements: `xxx_enabled` instead of `xxx_disabled`

#### Variables with Descriptions

**Severity:** SHOULD | **Requirement:** TFNFR17

- `description` **SHOULD** precisely describe the parameter's purpose and expected data type
- Target audience is module users, not developers
- For `object` types, use HEREDOC format

Variable and output descriptions **MAY** span multiple lines using HEREDOC format with embedded markdown for examples.

#### Variables with Types

**Severity:** MUST | **Requirement:** TFNFR18

- `type` **MUST** be defined for every variable
- `type` **SHOULD** be as precise as possible
- `any` **MAY** only be used with adequate reasons
- Use `bool` instead of `string`/`number` for true/false values
- Use concrete `object` instead of `map(any)`

**Broader Applicability**: Precise typing prevents errors and improves documentation across all Terraform code.

#### Sensitive Data Variables

**Severity:** SHOULD | **Requirement:** TFNFR19

If a variable's type is `object` and contains sensitive fields, the entire variable **SHOULD** be `sensitive = true`, or extract sensitive fields into separate variables.

#### Non-Nullable Defaults for Collections

**Severity:** SHOULD | **Requirement:** TFNFR20

Nullable **SHOULD** be set to `false` for collection values (sets, maps, lists) when using them in loops. For scalar values, null may have semantic meaning.

#### Discourage Nullability by Default

**Severity:** MUST | **Requirement:** TFNFR21

`nullable = true` **MUST** be avoided unless there's a specific semantic need for null values.

#### Avoid sensitive = false

**Severity:** MUST | **Requirement:** TFNFR22

`sensitive = false` **MUST** be avoided (this is the default).

#### Sensitive Default Value Conditions

**Severity:** MUST | **Requirement:** TFNFR23

A default value **MUST NOT** be set for sensitive inputs (e.g., default passwords).

#### Handling Deprecated Variables

**Severity:** MUST | **Requirement:** TFNFR24

- Move deprecated variables to `deprecated_variables.tf`
- Annotate with `DEPRECATED` at the beginning of description
- Declare the replacement's name
- Clean up during major version releases

**Broader Applicability**: Clear deprecation management improves user experience for any module.

---

### AVM Output Requirements

#### Additional Terraform Outputs

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

**Broader Applicability**: The anti-corruption layer pattern protects consumers from provider API changes.

#### Sensitive Data Outputs

**Severity:** MUST | **Requirement:** TFNFR29

Outputs containing confidential data **MUST** be declared with `sensitive = true`.

#### Handling Deprecated Outputs

**Severity:** MUST | **Requirement:** TFNFR30

- Move deprecated outputs to `deprecated_outputs.tf`
- Define new outputs in `outputs.tf`
- Clean up during major version releases

---

### AVM Local Values Standards

#### locals.tf Organization

**Severity:** MAY | **Requirement:** TFNFR31

- `locals.tf` **SHOULD** only contain `locals` blocks
- **MAY** declare `locals` blocks next to resources for advanced scenarios

#### Alphabetical Local Arrangement

**Severity:** MUST | **Requirement:** TFNFR32

Expressions in `locals` blocks **MUST** be arranged alphabetically.

#### Precise Local Types

**Severity:** SHOULD | **Requirement:** TFNFR33

Use precise types (e.g., `number` for age, not `string`).

**Broader Applicability**: Type precision improves code clarity and catches errors early.

---

### AVM Terraform Configuration Requirements

#### Terraform Version Requirements

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

**Broader Applicability**: Version constraints prevent compatibility issues across all Terraform projects.

#### Providers in required_providers

**Severity:** MUST | **Requirement:** TFNFR26

- `terraform` block **MUST** contain `required_providers` block
- Each provider **MUST** specify `source` and `version`
- Providers **SHOULD** be sorted alphabetically
- Only include directly required providers
- `source` **MUST** be in format `namespace/name`
- `version` **MUST** include minimum and maximum major version constraints
- **SHOULD** use `~> #.#` or `>= #.#.#, < #.#.#` format

---

### AVM Testing Requirements

#### Test Tooling

**Severity:** MUST | **Requirement:** TFNFR5

**Required testing tools for AVM:**

- Terraform (`terraform validate/fmt/test`)
- terrafmt
- Checkov
- tflint (with azurerm ruleset)
- Go (optional for custom tests)

**Broader Applicability**: These tools provide comprehensive quality checks for any Terraform code.

#### Test Provider Configuration

**Severity:** SHOULD | **Requirement:** TFNFR36

For robust testing, `prevent_deletion_if_contains_resources` **SHOULD** be explicitly set to `false` in test provider configurations.

---

### AVM Documentation Requirements

#### Module Documentation Generation

**Severity:** MUST | **Requirement:** TFNFR2

- Documentation **MUST** be automatically generated via [Terraform Docs](https://github.com/terraform-docs/terraform-docs)
- A `.terraform-docs.yml` file **MUST** be present in the module root

**Broader Applicability**: Automated documentation ensures consistency and reduces maintenance burden.

---

### Breaking Changes & Feature Management

#### Using Feature Toggles

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

**Broader Applicability**: Feature toggles allow backward-compatible module evolution.

#### Reviewing Potential Breaking Changes

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

**Broader Applicability**: Understanding breaking changes is crucial for maintaining any public Terraform module.

---

### AVM Contribution Standards

#### GitHub Repository Branch Protection

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

**Broader Applicability**: These protections ensure code quality for any collaborative project.

---

## AVM Compliance Checklist

For Azure Verified Modules, add these items to your review checklist:

- [ ] Module cross-references use registry sources with pinned versions
- [ ] Azure providers (azurerm/azapi) versions meet AVM requirements
- [ ] All names use lower snake_casing
- [ ] Resources ordered with dependencies first
- [ ] `for_each` uses `map()` or `set()` with static keys
- [ ] Resource/data/module blocks follow proper internal ordering
- [ ] `ignore_changes` not quoted
- [ ] Dynamic blocks used for conditional nested objects
- [ ] No `enabled` or `module_depends_on` variables
- [ ] Variables ordered: required (alphabetical) then optional (alphabetical)
- [ ] All variables have precise types (avoid `any`)
- [ ] Collections have `nullable = false`
- [ ] No `sensitive = false` declarations
- [ ] No default values for sensitive inputs
- [ ] Deprecated variables moved to `deprecated_variables.tf`
- [ ] Outputs use anti-corruption layer pattern (discrete attributes)
- [ ] Sensitive outputs marked `sensitive = true`
- [ ] Deprecated outputs moved to `deprecated_outputs.tf`
- [ ] Locals arranged alphabetically
- [ ] `terraform.tf` has version constraints (`~>` format)
- [ ] `required_providers` block present with all providers
- [ ] No `provider` declarations in module (except aliases)
- [ ] `.terraform-docs.yml` present
- [ ] New resources have feature toggles
- [ ] CODEOWNERS file present

---

## Summary

This style guide combines HashiCorp's official Terraform conventions with Azure Verified Modules requirements to provide comprehensive guidance for:

- **General Terraform Development**: Core formatting, naming, and organizational standards
- **Module Development**: Best practices for creating reusable, maintainable modules
- **Azure-Specific Modules**: Mandatory requirements for AVM certification
- **Cross-Cloud Applicability**: Patterns and practices beneficial for all cloud providers

By following these guidelines, you'll create Terraform code that is:

- **Consistent**: Predictable structure and formatting
- **Maintainable**: Easy to update and extend
- **Scalable**: Supports growth in complexity
- **Reliable**: Tested and validated
- **Collaborative**: Easy for teams to work with

---

*Last Updated: November 5, 2025*
*Based on: HashiCorp Terraform Style Conventions & Azure Verified Modules Requirements*