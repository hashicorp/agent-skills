---
name: terraform-search-import
description: Discover existing cloud resources using Terraform Search queries and bulk import them into Terraform management. Use when bringing unmanaged infrastructure under Terraform control, auditing cloud resources, or migrating to IaC.
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.1.0"
compatibility: Requires Terraform >= 1.14 and providers with list resource support (always use latest provider version)
---

# Terraform Search and Bulk Import

Discover existing cloud resources using declarative queries and generate configuration for bulk import into Terraform state.

**References:**
- [Terraform Search - list block](https://developer.hashicorp.com/terraform/language/block/tfquery/list)
- [Bulk Import](https://developer.hashicorp.com/terraform/language/import/bulk)

## When to Use

- Bringing unmanaged resources under Terraform control
- Auditing existing cloud infrastructure
- Migrating from manual provisioning to IaC
- Discovering resources across multiple regions/accounts

## IMPORTANT: Check Provider Support First

**BEFORE starting, you MUST verify the target resource type is supported:**

```bash
# Check what list resources are available
./scripts/list_resources.sh aws      # Specific provider
./scripts/list_resources.sh          # All configured providers
```

## Decision Tree

1. **Identify target resource type** (e.g., aws_s3_bucket, aws_instance)
2. **Check if supported**: Run `./scripts/list_resources.sh <provider>`
3. **Choose workflow**:
   - ** If supported**: Check for terraform version available.
   - ** If terraform version is above 1.14.0** Use Terraform Search workflow (below)
   - ** If not supported or terraform version is below 1.14.0 **: Use Manual Discovery workflow (see [references/MANUAL-IMPORT.md](references/MANUAL-IMPORT.md))

## Prerequisites

Before writing queries, verify the provider supports list resources for your target resource type.

### Discover Available List Resources

Run the helper script to extract supported list resources from your provider:

```bash
# From a directory with provider configuration (runs terraform init if needed)
./scripts/list_resources.sh aws      # Specific provider
./scripts/list_resources.sh          # All configured providers
```

Or manually query the provider schema:

```bash
terraform providers schema -json | jq '.provider_schemas | to_entries | map({key: (.key | split("/")[-1]), value: (.value.list_resource_schemas // {} | keys)})'
```

Terraform Search requires an initialized working directory. Ensure you have a configuration with the required provider before running queries:

```hcl
# terraform.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

Run `terraform init` to download the provider, then proceed with queries.

## Terraform Search Workflow (Supported Resources Only)

1. Create `.tfquery.hcl` files with `list` blocks defining search queries
2. Run `terraform query` to discover matching resources
3. Generate configuration with `-generate-config-out=<file>`
4. Review and refine generated `resource` and `import` blocks
5. Run `terraform plan` and `terraform apply` to import

## Query File Structure

Query files use `.tfquery.hcl` extension and support:
- `provider` blocks for authentication
- `list` blocks for resource discovery
- `variable` and `locals` blocks for parameterization

```hcl
# discovery.tfquery.hcl
provider "aws" {
  region = "us-west-2"
}

list "aws_instance" "all" {
  provider = aws
}
```

## List Block Syntax

```hcl
list "<list_type>" "<symbolic_name>" {
  provider = <provider_reference>  # Required
  
  # Optional: filter configuration
  config {
    filter {
      name   = "<filter_name>"
      values = ["<value1>", "<value2>"]
    }
    region = "<region>"  # Provider-specific config
  }
  
  # Optional: limit results
  limit = 100
}
```

## Supported List Resources

Provider support for list resources varies by version. **Always check what's available for your specific provider version using the discovery script.**

## Query Examples

### Basic Discovery

```hcl
# Find all EC2 instances in configured region
list "aws_instance" "all" {
  provider = aws
}
```

### Filtered Discovery

```hcl
# Find instances by tag
list "aws_instance" "production" {
  provider = aws
  
  config {
    filter {
      name   = "tag:Environment"
      values = ["production"]
    }
  }
}

# Find instances by type
list "aws_instance" "large" {
  provider = aws
  
  config {
    filter {
      name   = "instance-type"
      values = ["t3.large", "t3.xlarge"]
    }
  }
}
```

### Multi-Region Discovery

```hcl
provider "aws" {
  region = "us-west-2"
}

locals {
  regions = ["us-west-2", "us-east-1", "eu-west-1"]
}

list "aws_instance" "all_regions" {
  for_each = toset(local.regions)
  provider = aws
  
  config {
    region = each.value
  }
}
```

### Parameterized Queries

```hcl
variable "target_environment" {
  type    = string
  default = "staging"
}

list "aws_instance" "by_env" {
  provider = aws
  
  config {
    filter {
      name   = "tag:Environment"
      values = [var.target_environment]
    }
  }
}
```

## Running Queries

```bash
# Execute queries and display results
terraform query

# Generate configuration file
terraform query -generate-config-out=imported.tf

# Pass variables
terraform query -var='target_environment=production'
```

## Query Output Format

```
list.aws_instance.all   account_id=123456789012,id=i-0abc123,region=us-west-2   web-server
```

Columns: `<query_address>   <identity_attributes>   <name_tag>`

## Generated Configuration

The `-generate-config-out` flag creates:

```hcl
# __generated__ by Terraform
resource "aws_instance" "all_0" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  # ... all attributes
}

import {
  to       = aws_instance.all_0
  provider = aws
  identity = {
    account_id = "123456789012"
    id         = "i-0abc123"
    region     = "us-west-2"
  }
}
```

## Post-Generation Cleanup

Generated configuration includes all attributes. Clean up by:

1. Remove computed/read-only attributes
2. Replace hardcoded values with variables
3. Add proper resource naming
4. Organize into appropriate files

```hcl
# Before: generated
resource "aws_instance" "all_0" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  arn                    = "arn:aws:ec2:..."  # Remove - computed
  id                     = "i-0abc123"        # Remove - computed
  # ... many more attributes
}

# After: cleaned
resource "aws_instance" "web_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  
  tags = {
    Name        = "web-server"
    Environment = var.environment
  }
}
```

## Import by Identity

Generated imports use identity-based import (Terraform 1.12+):

```hcl
import {
  to       = aws_instance.web
  provider = aws
  identity = {
    account_id = "123456789012"
    id         = "i-0abc123"
    region     = "us-west-2"
  }
}
```

## Best Practices

### Query Design
- Start broad, then add filters to narrow results
- Use `limit` to prevent overwhelming output
- Test queries before generating configuration

### Configuration Management
- Review all generated code before applying
- Remove unnecessary default values
- Use consistent naming conventions
- Add proper variable abstraction

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No list resources found" | Check provider version supports list resources |
| Query returns empty | Verify region and filter values |
| Generated config has errors | Remove computed attributes, fix deprecated arguments |
| Import fails | Ensure resource not already in state |

## Complete Example

```hcl
# main.tf - Initialize provider
terraform {
  required_version = ">= 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"  # Always use latest version
    }
  }
}

# discovery.tfquery.hcl - Define queries
provider "aws" {
  region = "us-west-2"
}

list "aws_instance" "team_instances" {
  provider = aws
  
  config {
    filter {
      name   = "tag:Owner"
      values = ["platform"]
    }
    filter {
      name   = "instance-state-name"
      values = ["running"]
    }
  }
  
  limit = 50
}
```

```bash
# Execute workflow
terraform init
terraform query
terraform query -generate-config-out=generated.tf
# Review and clean generated.tf
terraform plan
terraform apply
```
