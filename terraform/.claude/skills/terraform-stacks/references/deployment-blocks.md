# Deployment Configuration Block Reference

Complete reference for all blocks available in Terraform Stack deployment configuration files (`.tfdeploy.hcl`).

## Table of Contents

1. [Identity Token Block](#identity-token-block)
2. [Locals Block](#locals-block)
3. [Deployment Block](#deployment-block)
4. [Deployment Group Block](#deployment-group-block)
5. [Deployment Auto-Approve Block](#deployment-auto-approve-block)
6. [Publish Output Block](#publish-output-block)
7. [Upstream Input Block](#upstream-input-block)

## Identity Token Block

Generates JWT tokens for OIDC authentication with cloud providers.

### Syntax

```hcl
identity_token "<token_name>" {
  audience = [<audience_strings>]
}
```

### Arguments

- **token_name** (label, required): Unique identifier for this token
- **audience** (required): List of audience strings for the JWT

### Accessing Token

Reference the JWT using: `identity_token.<n>.jwt`

### Cloud Provider Audiences

**AWS:**
```hcl
identity_token "aws" {
  audience = ["aws.workload.identity"]
}
```

**Azure:**
```hcl
identity_token "azure" {
  audience = ["api://AzureADTokenExchange"]
}
```

**Google Cloud:**
```hcl
identity_token "gcp" {
  audience = ["//iam.googleapis.com/projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/<POOL_ID>/providers/<PROVIDER_ID>"]
}
```

### Examples

**Single Token:**

```hcl
identity_token "aws" {
  audience = ["aws.workload.identity"]
}

deployment "production" {
  inputs = {
    identity_token = identity_token.aws.jwt
    role_arn       = var.role_arn
  }
}
```

**Multiple Tokens for Different Regions:**

```hcl
identity_token "aws_east" {
  audience = ["aws.workload.identity.east"]
}

identity_token "aws_west" {
  audience = ["aws.workload.identity.west"]
}

deployment "east_deployment" {
  inputs = {
    identity_token = identity_token.aws_east.jwt
    role_arn       = var.east_role_arn
  }
}

deployment "west_deployment" {
  inputs = {
    identity_token = identity_token.aws_west.jwt
    role_arn       = var.west_role_arn
  }
}
```

## Locals Block

Defines local values for reuse within deployment configuration.

### Syntax

```hcl
locals {
  <n> = <expression>
}
```

### Examples

```hcl
locals {
  aws_regions = ["us-west-1", "us-east-1", "eu-west-1"]
  
  role_arn = "arn:aws:iam::123456789012:role/hcp-terraform-stacks"
  
  common_inputs = {
    project_name = "my-app"
    environment  = "production"
  }
  
  environments = {
    dev = {
      region         = "us-east-1"
      instance_count = 1
      instance_type  = "t3.micro"
    }
    staging = {
      region         = "us-west-1"
      instance_count = 2
      instance_type  = "t3.small"
    }
    prod = {
      region         = "us-west-1"
      instance_count = 5
      instance_type  = "t3.large"
    }
  }
}
```

## Deployment Block

Defines deployment instances of the Stack.

### Syntax

```hcl
deployment "<deployment_name>" {
  inputs = {
    <input_name> = <value>
  }
}
```

### Arguments

- **deployment_name** (label, required): Unique identifier for this deployment
- **inputs** (required): Map of input variable values
- **destroy** (optional, default: false): Boolean flag to destroy this deployment

### Constraints

- Minimum 1 deployment per Stack
- Maximum 20 deployments per Stack
- No meta-arguments supported (no `for_each`, `count`)

### Destroying a Deployment

To safely remove a deployment from your Stack:

1. Set `destroy = true` in the deployment block
2. Apply the plan through HCP Terraform
3. After successful destruction, remove the deployment block from your configuration

**Important**: Using the `destroy` argument ensures your configuration has the provider authentication necessary to properly destroy the deployment's resources.

**Example:**
```hcl
deployment "old_environment" {
  inputs = {
    aws_region     = "us-west-1"
    instance_count = 2
    role_arn       = local.role_arn
    identity_token = identity_token.aws.jwt
  }
  destroy = true  # Mark for destruction
}
```

After applying this plan and the deployment is destroyed, remove the entire `deployment "old_environment"` block from your configuration.

### Examples

**Single Deployment:**

```hcl
deployment "production" {
  inputs = {
    aws_region     = "us-west-1"
    instance_count = 5
    instance_type  = "t3.large"
    role_arn       = local.role_arn
    identity_token = identity_token.aws.jwt
  }
}
```

**Multiple Environment Deployments:**

```hcl
deployment "development" {
  inputs = {
    aws_region     = "us-east-1"
    instance_count = 1
    instance_type  = "t3.micro"
    name_suffix    = "dev"
    role_arn       = local.role_arn
    identity_token = identity_token.aws.jwt
  }
}

deployment "staging" {
  inputs = {
    aws_region     = "us-west-1"
    instance_count = 2
    instance_type  = "t3.small"
    name_suffix    = "staging"
    role_arn       = local.role_arn
    identity_token = identity_token.aws.jwt
  }
}

deployment "production" {
  inputs = {
    aws_region     = "us-west-1"
    instance_count = 5
    instance_type  = "t3.large"
    name_suffix    = "prod"
    role_arn       = local.role_arn
    identity_token = identity_token.aws.jwt
  }
}
```

**Multi-Region Deployments:**

```hcl
deployment "us_prod_east" {
  inputs = {
    aws_region     = "us-east-1"
    instance_count = 3
    name_suffix    = "prod-east"
    role_arn       = local.role_arn
    identity_token = identity_token.aws_east.jwt
  }
}

deployment "us_prod_west" {
  inputs = {
    aws_region     = "us-west-1"
    instance_count = 3
    name_suffix    = "prod-west"
    role_arn       = local.role_arn
    identity_token = identity_token.aws_west.jwt
  }
}

deployment "eu_prod" {
  inputs = {
    aws_region     = "eu-west-1"
    instance_count = 3
    name_suffix    = "prod-eu"
    role_arn       = local.role_arn
    identity_token = identity_token.aws_eu.jwt
  }
}
```

**Using Locals for DRY Configuration:**

```hcl
locals {
  common_inputs = {
    role_arn       = "arn:aws:iam::123456789012:role/terraform"
    identity_token = identity_token.aws.jwt
    project_name   = "my-app"
  }
}

deployment "dev" {
  inputs = merge(local.common_inputs, {
    aws_region     = "us-east-1"
    instance_count = 1
    environment    = "dev"
  })
}

deployment "prod" {
  inputs = merge(local.common_inputs, {
    aws_region     = "us-west-1"
    instance_count = 5
    environment    = "prod"
  })
}
```

## Deployment Group Block

Groups deployments together to configure shared settings and auto-approval rules (HCP Terraform Premium feature).

**Best Practice**: Always create deployment groups for all deployments, even when you have only a single deployment. This establishes a consistent configuration pattern, enables future auto-approval rules, and provides a foundation for scaling your Stack.

### Syntax

```hcl
deployment_group "<group_name>" {
  deployments = [<deployment_references>]
}
```

### Arguments

- **group_name** (label, required): Unique identifier for this deployment group
- **deployments** (required): List of deployment references to include in this group

### Purpose

Deployment groups allow you to:
- Organize deployments logically (by environment, team, region, etc.)
- Configure shared auto-approval rules for multiple deployments
- Manage deployments more effectively at scale
- Establish consistent configuration patterns across all Stacks

### Examples

**Single Deployment Group (Best Practice):**

```hcl
deployment "production" {
  inputs = {
    aws_region     = "us-west-1"
    instance_count = 5
    role_arn       = local.role_arn
    identity_token = identity_token.aws.jwt
  }
}

deployment_group "production" {
  deployments = [deployment.production]
}
```

**Multiple Deployment Groups:**

```hcl
deployment_group "non_production" {
  deployments = [
    deployment.development,
    deployment.staging
  ]
}

deployment_group "production" {
  deployments = [
    deployment.prod_us_east,
    deployment.prod_us_west,
    deployment.prod_eu_west
  ]
}
```

**Environment-Based Groups:**

```hcl
deployment_group "development_environments" {
  deployments = [
    deployment.dev_feature_a,
    deployment.dev_feature_b,
    deployment.dev_integration
  ]
}

deployment_group "production_environments" {
  deployments = [
    deployment.prod_primary,
    deployment.prod_dr
  ]
}
```

**Regional Groups:**

```hcl
deployment_group "americas" {
  deployments = [
    deployment.us_east,
    deployment.us_west,
    deployment.brazil
  ]
}

deployment_group "europe" {
  deployments = [
    deployment.eu_west,
    deployment.eu_central
  ]
}
```

## Deployment Auto-Approve Block

Defines rules that automatically approve deployment plans based on specific conditions (HCP Terraform Premium feature).

### Syntax

```hcl
deployment_auto_approve "<rule_name>" {
  deployment_group = deployment_group.<group_name>
  
  check {
    condition = <boolean_expression>
    reason    = "<failure_message>"
  }
}
```

### Arguments

- **rule_name** (label, required): Unique identifier for this auto-approve rule
- **deployment_group** (required): Reference to the deployment group this rule applies to
- **check** (required, one or more): Condition that must be met for auto-approval

### Context Variables

Access plan information through `context` object:

- `context.plan.applyable` - Boolean: plan succeeded without errors
- `context.plan.changes.add` - Number: resources to add
- `context.plan.changes.change` - Number: resources to change
- `context.plan.changes.remove` - Number: resources to remove
- `context.plan.changes.import` - Number: resources to import

### Important Notes

- All checks must pass for auto-approval to occur
- If any check fails, manual approval is required
- HCP Terraform displays the failure reason from failed checks
- Auto-approve rules only apply to deployments in the specified deployment group

### Examples

**Auto-approve Successful Plans:**

```hcl
deployment_group "canary" {
  deployments = [
    deployment.dev,
    deployment.staging
  ]
}

deployment_auto_approve "applyable_plans" {
  deployment_group = deployment_group.canary
  
  check {
    condition = context.plan.applyable
    reason    = "Plan must be applyable without errors"
  }
}
```

**Auto-approve Only Additions (No Changes or Deletions):**

```hcl
deployment_group "non_prod" {
  deployments = [
    deployment.development,
    deployment.qa
  ]
}

deployment_auto_approve "additions_only" {
  deployment_group = deployment_group.non_prod
  
  check {
    condition = context.plan.changes.change == 0
    reason    = "Cannot auto-approve changes to existing resources"
  }
  
  check {
    condition = context.plan.changes.remove == 0
    reason    = "Cannot auto-approve resource deletions"
  }
  
  check {
    condition = context.plan.applyable
    reason    = "Plan must be applyable"
  }
}
```

**Auto-approve Small Changes:**

```hcl
deployment_group "staging" {
  deployments = [deployment.staging]
}

deployment_auto_approve "small_changes" {
  deployment_group = deployment_group.staging
  
  check {
    condition = (
      context.plan.changes.add + 
      context.plan.changes.change + 
      context.plan.changes.remove
    ) <= 10
    reason    = "Cannot auto-approve changes affecting more than 10 resources"
  }
  
  check {
    condition = context.plan.changes.remove == 0
    reason    = "Cannot auto-approve plans with deletions"
  }
  
  check {
    condition = context.plan.applyable
    reason    = "Plan must be applyable"
  }
}
```

**Auto-approve Non-Destructive Changes:**

```hcl
deployment_group "production" {
  deployments = [
    deployment.prod_primary,
    deployment.prod_secondary
  ]
}

deployment_auto_approve "safe_production_changes" {
  deployment_group = deployment_group.production
  
  check {
    condition = context.plan.changes.remove == 0
    reason    = "Production deletions require manual approval"
  }
  
  check {
    condition = context.plan.applyable
    reason    = "Plan must be successful"
  }
}
```

**Multiple Auto-Approve Rules for Different Groups:**

```hcl
deployment_group "development" {
  deployments = [deployment.dev]
}

deployment_group "staging" {
  deployments = [deployment.staging]
}

deployment_group "production" {
  deployments = [deployment.production]
}

# Auto-approve all successful dev plans
deployment_auto_approve "dev_auto" {
  deployment_group = deployment_group.development
  
  check {
    condition = context.plan.applyable
    reason    = "Plan must be applyable"
  }
}

# Auto-approve staging plans with no deletions
deployment_auto_approve "staging_safe" {
  deployment_group = deployment_group.staging
  
  check {
    condition = context.plan.changes.remove == 0
    reason    = "No deletions allowed in staging auto-approve"
  }
  
  check {
    condition = context.plan.applyable
    reason    = "Plan must be applyable"
  }
}

# Production requires manual approval (no auto-approve rule defined)
```

**Graduated Rollout Pattern:**

```hcl
deployment_group "canary" {
  deployments = [deployment.canary]
}

deployment_group "production" {
  deployments = [
    deployment.prod_us,
    deployment.prod_eu,
    deployment.prod_asia
  ]
}

# Canary auto-approves with strict checks
deployment_auto_approve "canary_strict" {
  deployment_group = deployment_group.canary
  
  check {
    condition = context.plan.changes.remove == 0
    reason    = "Canary cannot delete resources"
  }
  
  check {
    condition = context.plan.changes.change <= 5
    reason    = "Canary limited to 5 resource changes"
  }
  
  check {
    condition = context.plan.applyable
    reason    = "Plan must be applyable"
  }
}

# Production requires manual approval after canary validation
```

## Deprecated: Orchestrate Block

**Note:** The `orchestrate` block is deprecated. Use `deployment_group` and `deployment_auto_approve` blocks instead.

The `orchestrate` block was used in public beta but has been replaced by deployment groups for better scalability and flexibility:

```hcl
# ❌ DEPRECATED - Do not use
orchestrate "auto_approve" "rule_name" {
  check {
    condition = context.plan.applyable
    reason    = "Plan must be applyable"
  }
}

# ✅ Use deployment_group and deployment_auto_approve instead
deployment_group "my_group" {
  deployments = [deployment.my_deployment]
}

deployment_auto_approve "my_rule" {
  deployment_group = deployment_group.my_group
  
  check {
    condition = context.plan.applyable
    reason    = "Plan must be applyable"
  }
}
```

## Publish Output Block

Exports outputs from a Stack for consumption by other Stacks (linked Stacks).

### Syntax

```hcl
publish_output "<output_name>" {
  type  = <type>
  value = <expression>
}
```

### Arguments

- **output_name** (label, required): Unique identifier for this published output
- **type** (required): Data type of the output
- **value** (required): Expression to export

### Accessing Deployment Outputs

Reference deployment outputs using: `deployment.<deployment_name>.<output_name>`

### Important Notes

- Must apply the Stack's deployment configuration before downstream Stacks can reference outputs
- Published outputs create a snapshot that other Stacks can read
- Changes to published outputs automatically trigger runs in downstream Stacks

### Examples

**Basic Published Output:**

```hcl
publish_output "vpc_id" {
  type  = string
  value = deployment.network.vpc_id
}

publish_output "subnet_ids" {
  type  = list(string)
  value = deployment.network.private_subnet_ids
}
```

**Multiple Deployment Outputs:**

```hcl
publish_output "regional_vpc_ids" {
  type = map(string)
  value = {
    us_east = deployment.us_east.vpc_id
    us_west = deployment.us_west.vpc_id
    eu_west = deployment.eu_west.vpc_id
  }
}
```

**Complex Output:**

```hcl
publish_output "database_config" {
  type = object({
    endpoint = string
    port     = number
    name     = string
  })
  value = {
    endpoint = deployment.production.db_endpoint
    port     = deployment.production.db_port
    name     = deployment.production.db_name
  }
}
```

**Regional Endpoints:**

```hcl
publish_output "api_endpoints" {
  type = map(object({
    url    = string
    region = string
  }))
  value = {
    for env in ["dev", "staging", "prod"] : env => {
      url    = deployment[env].api_url
      region = deployment[env].region
    }
  }
}
```

## Upstream Input Block

References published outputs from another Stack (linked Stacks).

### Syntax

```hcl
upstream_input "<input_name>" {
  type   = "stack"
  source = "<stack_address>"
}
```

### Arguments

- **input_name** (label, required): Local name for this upstream input
- **type** (required): Must be "stack"
- **source** (required): Full Stack address in format: `app.terraform.io/<org>/<project>/<stack-name>`

### Accessing Upstream Outputs

Reference upstream outputs using: `upstream_input.<input_name>.<output_name>`

### Important Notes

- Creates a dependency on the upstream Stack
- Upstream Stack must have applied its deployment configuration
- Changes in upstream Stack automatically trigger downstream Stack runs
- Only works with Stacks in the same HCP Terraform project

### Examples

**Basic Upstream Reference:**

```hcl
upstream_input "network" {
  type   = "stack"
  source = "app.terraform.io/my-org/my-project/networking-stack"
}

deployment "application" {
  inputs = {
    vpc_id     = upstream_input.network.vpc_id
    subnet_ids = upstream_input.network.subnet_ids
  }
}
```

**Multiple Upstream Stacks:**

```hcl
upstream_input "network" {
  type   = "stack"
  source = "app.terraform.io/my-org/my-project/network-stack"
}

upstream_input "database" {
  type   = "stack"
  source = "app.terraform.io/my-org/my-project/database-stack"
}

deployment "application" {
  inputs = {
    vpc_id              = upstream_input.network.vpc_id
    subnet_ids          = upstream_input.network.private_subnet_ids
    database_endpoint   = upstream_input.database.endpoint
    database_credentials = upstream_input.database.credentials
  }
}
```

**Regional Upstream Dependencies:**

```hcl
upstream_input "regional_network" {
  type   = "stack"
  source = "app.terraform.io/my-org/my-project/regional-networks"
}

deployment "us_east_app" {
  inputs = {
    region     = "us-east-1"
    vpc_id     = upstream_input.regional_network.regional_vpc_ids["us_east"]
    subnet_ids = upstream_input.regional_network.regional_subnet_ids["us_east"]
  }
}

deployment "eu_west_app" {
  inputs = {
    region     = "eu-west-1"
    vpc_id     = upstream_input.regional_network.regional_vpc_ids["eu_west"]
    subnet_ids = upstream_input.regional_network.regional_subnet_ids["eu_west"]
  }
}
```

**Complete Linked Stack Example:**

Upstream Stack (network-stack):
```hcl
# deployments.tfdeploy.hcl
deployment "network" {
  inputs = {
    vpc_cidr = "10.0.0.0/16"
  }
}

publish_output "vpc_id_network" {
  type  = string
  value = deployment.network.vpc_id
}

publish_output "private_subnet_ids" {
  type  = list(string)
  value = deployment.network.private_subnet_ids
}

publish_output "security_group_id" {
  type  = string
  value = deployment.network.default_sg_id
}
```

Downstream Stack (application-stack):
```hcl
# deployments.tfdeploy.hcl
upstream_input "networking" {
  type   = "stack"
  source = "app.terraform.io/my-org/my-project/network-stack"
}

deployment "application" {
  inputs = {
    vpc_id             = upstream_input.networking.vpc_id_network
    subnet_ids         = upstream_input.networking.private_subnet_ids
    security_group_id  = upstream_input.networking.security_group_id
    instance_type      = "t3.large"
  }
}
```

## Complete Deployment Configuration Example

```hcl
# Identity tokens for cloud authentication
identity_token "aws" {
  audience = ["aws.workload.identity"]
}

# Local values
locals {
  role_arn    = "arn:aws:iam::123456789012:role/terraform-stacks"
  project     = "my-application"
  cost_center = "engineering"
}

# Upstream dependencies
upstream_input "shared_services" {
  type   = "stack"
  source = "app.terraform.io/my-org/my-project/shared-services"
}

# Deployments
deployment "development" {
  inputs = {
    aws_region     = "us-east-1"
    environment    = "dev"
    instance_count = 1
    instance_type  = "t3.micro"
    role_arn       = local.role_arn
    identity_token = identity_token.aws.jwt
    vpc_id         = upstream_input.shared_services.dev_vpc_id
  }
}

deployment "staging" {
  inputs = {
    aws_region     = "us-west-1"
    environment    = "staging"
    instance_count = 2
    instance_type  = "t3.small"
    role_arn       = local.role_arn
    identity_token = identity_token.aws.jwt
    vpc_id         = upstream_input.shared_services.staging_vpc_id
  }
}

deployment "production" {
  inputs = {
    aws_region     = "us-west-1"
    environment    = "prod"
    instance_count = 5
    instance_type  = "t3.large"
    role_arn       = local.role_arn
    identity_token = identity_token.aws.jwt
    vpc_id         = upstream_input.shared_services.prod_vpc_id
  }
}

# Deployment groups
deployment_group "non_production" {
  deployments = [
    deployment.development,
    deployment.staging
  ]
}

deployment_group "production" {
  deployments = [
    deployment.production
  ]
}

# Auto-approval rules
deployment_auto_approve "non_prod_auto" {
  deployment_group = deployment_group.non_production
  
  check {
    condition = context.plan.applyable
    reason    = "Non-production plans must be applyable"
  }
}

deployment_auto_approve "prod_safe" {
  deployment_group = deployment_group.production
  
  check {
    condition = context.plan.changes.remove == 0
    reason    = "Production cannot auto-approve deletions"
  }
  
  check {
    condition = context.plan.applyable
    reason    = "Plan must be applyable"
  }
}

# Published outputs
publish_output "application_url" {
  type  = string
  value = deployment.production.load_balancer_url
}
```
