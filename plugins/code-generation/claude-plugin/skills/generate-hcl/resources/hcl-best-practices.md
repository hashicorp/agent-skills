# HCL Best Practices for Terraform

## Code Organization

### File Structure
Organize Terraform configurations using a consistent file structure:

```
terraform-project/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value declarations
├── locals.tf         # Local value definitions
├── versions.tf       # Terraform and provider version constraints
├── data.tf           # Data source declarations
├── backend.tf        # Backend configuration (optional, can be in versions.tf)
└── terraform.tfvars  # Variable values (gitignored if contains secrets)
```

### Naming Conventions

#### Resources
```hcl
# Pattern: resource_type.descriptive_name
# Use snake_case for resource names
resource "aws_vpc" "main_network" {
  # Configuration
}

resource "aws_subnet" "public_web" {
  # Configuration
}
```

#### Variables
```hcl
# Use descriptive names that indicate purpose
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC network"
  type        = string
}

# Prefix boolean variables with is_, has_, enable_
variable "enable_nat_gateway" {
  description = "Whether to provision NAT gateways"
  type        = bool
  default     = true
}
```

## Variable Design

### Type Constraints
Always specify explicit types:

```hcl
# Simple types
variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
}

# Complex types
variable "instance_tags" {
  description = "Tags to apply to instances"
  type        = map(string)
  default     = {}
}

# Structured objects
variable "database_config" {
  description = "Database configuration parameters"
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    allocated_storage = number
    multi_az       = bool
  })
}
```

### Validation Rules
Use validation blocks for business logic:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  
  validation {
    condition     = can(regex("^t[2-3]\\.(nano|micro|small|medium|large)$", var.instance_type))
    error_message = "Instance type must be a valid t2 or t3 burstable instance."
  }
}
```

### Sensitive Data
Mark sensitive variables appropriately:

```hcl
variable "database_password" {
  description = "Master password for database"
  type        = string
  sensitive   = true
}

output "db_connection_string" {
  description = "Database connection string"
  value       = "postgresql://${aws_db_instance.main.endpoint}"
  sensitive   = true
}
```

## Resource Management

### Dependencies

#### Implicit Dependencies (Preferred)
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Terraform infers dependency through reference
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}
```

#### Explicit Dependencies (When Necessary)
```hcl
# Use depends_on for non-obvious dependencies
resource "aws_iam_role_policy" "example" {
  name   = "example"
  role   = aws_iam_role.example.id
  policy = data.aws_iam_policy_document.example.json
  
  # Ensure role is fully created before attaching policy
  depends_on = [aws_iam_role.example]
}
```

### Count vs For_Each

#### Avoid Count for Resource Sets
```hcl
# ❌ Don't: Using count makes resources positional
resource "aws_subnet" "private" {
  count      = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 4, count.index)
}
```

#### Use For_Each for Stability
```hcl
# ✅ Do: Using for_each makes resources addressable by key
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

resource "aws_subnet" "private" {
  for_each = toset(var.availability_zones)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, index(var.availability_zones, each.value))
  availability_zone = each.value
  
  tags = {
    Name = "private-${each.value}"
  }
}
```

### Lifecycle Rules

```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  lifecycle {
    # Create new resource before destroying old
    create_before_destroy = true
    
    # Prevent accidental deletion
    prevent_destroy = false
    
    # Ignore changes to specific attributes
    ignore_changes = [
      tags["LastModified"],
      user_data
    ]
  }
}
```

## Local Values

Use locals for computed values and DRY principles:

```hcl
locals {
  # Common tags applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CostCenter  = var.cost_center
  }
  
  # Computed naming prefix
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Conditional logic
  vpc_cidr = var.environment == "prod" ? "10.0.0.0/16" : "10.1.0.0/16"
  
  # Data transformations
  subnet_configs = {
    for idx, az in var.availability_zones : az => {
      cidr = cidrsubnet(var.vpc_cidr, 4, idx)
      az   = az
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}
```

## Data Sources

Fetch existing infrastructure information:

```hcl
# Query existing resources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Reference data in resources
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
}

# Use data sources for remote state
data "terraform_remote_state" "network" {
  backend = "s3"
  
  config = {
    bucket = "terraform-state-bucket"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Dynamic Blocks

Use dynamic blocks for repeated nested blocks:

```hcl
variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id
  
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

## Module Design

### Input Variables
```hcl
# modules/vpc/variables.tf
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}
```

### Output Values
```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}
```

### Module Usage
```hcl
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  enable_dns_support  = true
  enable_nat_gateway  = var.environment == "prod"
  
  tags = local.common_tags
}

# Reference module outputs
resource "aws_instance" "app" {
  subnet_id = module.vpc.private_subnet_ids[0]
  # ...
}
```

## Security Best Practices

### Encryption
```hcl
# Enable encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

# Enable encryption in transit
resource "aws_db_instance" "main" {
  # ...
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn
  
  # Require SSL connections
  enabled_cloudwatch_logs_exports = ["postgresql"]
}
```

### Network Security
```hcl
# Block public access
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Minimal security group rules
resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-db-"
  vpc_id      = module.vpc.vpc_id
  
  # Only allow traffic from application tier
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "PostgreSQL from application tier"
  }
  
  # No outbound internet access needed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
    description = "VPC-local traffic only"
  }
}
```

### Secrets Management
```hcl
# ❌ Never hardcode secrets
resource "aws_db_instance" "bad" {
  password = "SuperSecret123!"  # DON'T DO THIS
}

# ✅ Use variables marked as sensitive
variable "db_password" {
  type      = string
  sensitive = true
}

# ✅ Or fetch from secrets manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/master-password"
}

resource "aws_db_instance" "good" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

## Tagging Strategy

```hcl
locals {
  # Mandatory tags for all resources
  mandatory_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = var.team_email
    CostCenter  = var.cost_center
  }
  
  # Merge with optional tags
  common_tags = merge(
    local.mandatory_tags,
    var.additional_tags
  )
}

# Apply to all resources
resource "aws_instance" "app" {
  # ...
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-app-${count.index}"
      Role = "Application"
    }
  )
}
```

## Error Handling

### Preconditions and Postconditions
```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  lifecycle {
    # Validate assumptions before apply
    precondition {
      condition     = data.aws_ami.selected.architecture == "x86_64"
      error_message = "AMI must be x86_64 architecture"
    }
    
    # Validate results after creation
    postcondition {
      condition     = self.public_ip != ""
      error_message = "Instance must have a public IP address"
    }
  }
}
```

## Performance Optimization

### Parallelism
```hcl
# Limit concurrent operations for API rate limits
# Run with: terraform apply -parallelism=5
```

### Targeted Operations
```hcl
# Update specific resources
# terraform apply -target=module.vpc
# terraform apply -target=aws_instance.app[0]
```

### State Management
```hcl
# Use workspaces for environment isolation
# terraform workspace new staging
# terraform workspace select prod

# Or use separate state files
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "environments/${var.environment}/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Documentation

### Inline Comments
```hcl
# High-level purpose of resource
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Required for RDS DNS endpoints
  
  # Enable flow logs for security auditing
  enable_flow_log = true
}
```

### README Files
Every module should include:
- Purpose and use cases
- Input variables with examples
- Output values
- Usage examples
- Dependencies and prerequisites
- Testing instructions

## Testing

### Validation Commands
```bash
# Format check
terraform fmt -check -recursive

# Validate syntax
terraform validate

# Security scanning
tfsec .
checkov -d .

# Cost estimation
infracost breakdown --path .

# Plan review
terraform plan -out=tfplan
terraform show -json tfplan | jq
```

## Version Control

### .gitignore
```
# Local state
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Sensitive files
*.tfvars
!example.tfvars

# Crash logs
crash.log

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI config
.terraformrc
terraform.rc
```

### Commit Messages
Follow conventional commits:
- `feat: add RDS database module`
- `fix: correct subnet CIDR calculation`
- `docs: update vpc module README`
- `refactor: migrate to for_each loops`

## Conclusion

These best practices ensure:
- Maintainable and readable code
- Security by default
- Reproducible infrastructure
- Team collaboration
- Compliance with standards

Always prioritize clarity over cleverness, and consistency over personal preference.
