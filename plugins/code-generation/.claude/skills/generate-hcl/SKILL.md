# Skill: Generate HCL

## Overview
This skill enables AI agents to generate HashiCorp Configuration Language (HCL) code for Terraform configurations, following best practices, security standards, and organizational conventions.

## Capability Statement
When invoked, the agent will:
1. Analyze infrastructure requirements and constraints
2. Query Terraform Registry for latest provider versions and module patterns
3. Generate idiomatic HCL with proper resource dependencies
4. Apply security best practices and compliance standards
5. Include comprehensive documentation and examples

## Prerequisites
- Understanding of target infrastructure provider (AWS, Azure, GCP, etc.)
- Access to Terraform Registry APIs
- Knowledge of organizational naming conventions
- Awareness of security compliance requirements (CIS, SOC2, etc.)

## Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `provider` | string | Yes | Target cloud provider (aws, azurerm, google, etc.) |
| `resource_types` | array | Yes | List of resource types to generate (e.g., ["vpc", "subnet", "security_group"]) |
| `environment` | string | Yes | Target environment (dev, staging, prod) |
| `compliance_framework` | string | No | Compliance standard to follow (cis, pci, hipaa) |
| `naming_convention` | object | No | Organization-specific naming rules |
| `terraform_version` | string | No | Target Terraform version (defaults to latest stable) |

## Execution Steps

### 1. Provider Discovery
```markdown
- Use `get_latest_provider_version` to fetch current provider release
- Call `get_provider_capabilities` to understand available resources
- Retrieve `get_provider_details` for specific resource documentation
```

### 2. Code Generation Strategy
```markdown
- Start with provider configuration block
- Generate required_providers with version constraints
- Create data sources before dependent resources
- Build resources in dependency order
- Add outputs for key resource attributes
```

### 3. Best Practices Application
```markdown
- Use variables for all configurable values
- Implement local values for computed expressions
- Add lifecycle rules where appropriate
- Include depends_on only when implicit dependencies insufficient
- Use for_each instead of count for resource sets
```

### 4. Security Hardening
```markdown
- Enable encryption at rest by default
- Configure private networking where applicable
- Add security group rules with principle of least privilege
- Enable logging and monitoring
- Tag resources for cost tracking and compliance
```

### 5. Validation
```markdown
- Ensure valid HCL syntax
- Verify resource attribute compatibility
- Check for circular dependencies
- Validate against compliance rules
```

## Output Format

### Generated File Structure
```hcl
# main.tf
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# variables.tf
variable "environment" {
  description = "Target deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# locals.tf
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}

# resources.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

# outputs.tf
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}
```

## Error Handling

### Common Issues
1. **Provider Version Conflicts**: Always pin provider versions with ~> constraint
2. **Missing Dependencies**: Use depends_on explicitly for cross-module dependencies
3. **State Drift**: Include lifecycle ignore_changes for attributes modified externally
4. **Resource Naming Collisions**: Use unique prefixes with environment/region

### Validation Checklist
- [ ] All resources have descriptive names
- [ ] Variables have descriptions and types
- [ ] Sensitive outputs marked with `sensitive = true`
- [ ] Tags include minimum required metadata
- [ ] No hardcoded credentials or secrets
- [ ] Backend configuration externalized

## Examples

### Example 1: S3 Bucket with Security Best Practices
```hcl
resource "aws_s3_bucket" "data" {
  bucket = "${var.project}-${var.environment}-data"
  
  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### Example 2: Compute Instance with Module Abstraction
```hcl
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"
  
  name = "${var.project}-${var.environment}-web"
  
  instance_type          = var.instance_type
  key_name              = var.key_name
  monitoring            = true
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id             = aws_subnet.private[0].id
  
  user_data = templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    app_version = var.app_version
  })
  
  tags = merge(
    local.common_tags,
    {
      Role = "WebServer"
    }
  )
}
```

## Related Skills
- [Refactor Module](../refactor-module/SKILL.md) - Restructure existing code into reusable modules
- [Validate Configuration](../validate-configuration/SKILL.md) - Run validation and compliance checks

## Resources
- [HCL Best Practices](./resources/hcl-best-practices.md)
- [Terraform Registry Documentation](https://registry.terraform.io/)
- [Provider Version Constraints](https://developer.hashicorp.com/terraform/language/providers/requirements)

## Success Metrics
- Code passes `terraform validate` without errors
- Security scanner (tfsec, checkov) shows no critical issues
- Resources follow organizational naming conventions
- All variables have descriptions and appropriate types
- Outputs provide necessary information for downstream consumers

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-07 | Initial skill definition |
