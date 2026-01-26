---
name: terraform-test
description: Comprehensive guide for writing and running Terraform tests. Use when creating test files (.tftest.hcl), writing test scenarios with run blocks, validating infrastructure behavior with assertions, mocking providers and data sources, testing module outputs and resource configurations, or troubleshooting Terraform test syntax and execution.
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Terraform Test

Terraform's built-in testing framework enables module authors to validate that configuration updates don't introduce breaking changes. Tests execute against temporary resources, protecting existing infrastructure and state files.

## Core Concepts

**Test File**: A `.tftest.hcl` or `.tftest.json` file containing test configuration and run blocks that validate your Terraform configuration.

**Test Block**: Optional configuration block that defines test-wide settings (available since Terraform 1.6.0).

**Run Block**: Defines a single test scenario with optional variables, provider configurations, and assertions. Each test file requires at least one run block.

**Assert Block**: Contains conditions that must evaluate to true for the test to pass. Failed assertions cause the test to fail.

**Mock Provider**: Simulates provider behavior without creating real infrastructure (available since Terraform 1.7.0).

**Test Modes**: Tests run in apply mode (default, creates real infrastructure) or plan mode (validates logic without creating resources).

## File Structure

Terraform test files use the `.tftest.hcl` or `.tftest.json` extension and are typically organized in a `tests/` directory. Use clear naming conventions to distinguish between unit tests (plan mode) and integration tests (apply mode):

```
my-module/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── validation_unit_test.tftest.hcl      # Unit test (plan mode)
    ├── edge_cases_unit_test.tftest.hcl      # Unit test (plan mode)
    └── full_stack_integration_test.tftest.hcl  # Integration test (apply mode - creates real resources)
```

### Test File Components

A test file contains:
- **Zero to one** `test` block (configuration settings)
- **One to many** `run` blocks (test executions)
- **Zero to one** `variables` block (input values)
- **Zero to many** `provider` blocks (provider configuration)
- **Zero to many** `mock_provider` blocks (mock provider data, since v1.7.0)

**Important**: The order of `variables` and `provider` blocks doesn't matter. Terraform processes all values within these blocks at the beginning of the test operation.

## Test Configuration (.tftest.hcl)

### Test Block

The optional `test` block configures test-wide settings:

```hcl
test {
  parallel = true  # Enable parallel execution for all run blocks (default: false)
}
```

**Test Block Attributes:**
- `parallel` - Boolean, when set to `true`, enables parallel execution for all run blocks by default (default: `false`). Individual run blocks can override this setting.

### Run Block

Each `run` block executes a command against your configuration. Run blocks execute **sequentially by default**.

**Basic Integration Test (Apply Mode - Default):**

```hcl
run "test_instance_creation" {
  command = apply

  assert {
    condition     = aws_instance.example.id != ""
    error_message = "Instance should be created with a valid ID"
  }

  assert {
    condition     = output.instance_public_ip != ""
    error_message = "Instance should have a public IP"
  }
}
```

**Unit Test (Plan Mode):**

```hcl
run "test_default_configuration" {
  command = plan

  assert {
    condition     = aws_instance.example.instance_type == "t2.micro"
    error_message = "Instance type should be t2.micro by default"
  }

  assert {
    condition     = aws_instance.example.tags["Environment"] == "test"
    error_message = "Environment tag should be 'test'"
  }
}
```

**Run Block Attributes:**

- `command` - Either `apply` (default) or `plan`
- `plan_options` - Configure plan behavior (see below)
- `variables` - Override test-level variable values
- `module` - Reference alternate modules for testing
- `providers` - Customize provider availability
- `assert` - Validation conditions (multiple allowed)
- `expect_failures` - Specify expected validation failures
- `state_key` - Manage state file isolation (since v1.9.0)
- `parallel` - Enable parallel execution when set to `true` (since v1.9.0)

### Plan Options

The `plan_options` block configures plan command behavior:

```hcl
run "test_refresh_only" {
  command = plan

  plan_options {
    mode    = refresh-only  # "normal" (default) or "refresh-only"
    refresh = true           # boolean, defaults to true
    replace = [
      aws_instance.example
    ]
    target = [
      aws_instance.example
    ]
  }

  assert {
    condition     = aws_instance.example.instance_type == "t2.micro"
    error_message = "Instance type should be t2.micro"
  }
}
```

**Plan Options Attributes:**
- `mode` - `normal` (default) or `refresh-only`
- `refresh` - Boolean, defaults to `true`
- `replace` - List of resource addresses to replace
- `target` - List of resource addresses to target

### Variables Block

Define variables at the test file level (applied to all run blocks) or within individual run blocks.

**Important**: Variables defined in test files take the **highest precedence**, overriding environment variables, variables files, or command-line input.

**File-Level Variables:**

```hcl
# Applied to all run blocks
variables {
  aws_region    = "us-west-2"
  instance_type = "t2.micro"
  environment   = "test"
}

run "test_with_file_variables" {
  command = plan

  assert {
    condition     = var.aws_region == "us-west-2"
    error_message = "Region should be us-west-2"
  }
}
```

**Run Block Variables (Override File-Level):**

```hcl
variables {
  instance_type = "t2.small"
  environment   = "test"
}

run "test_with_override_variables" {
  command = plan

  # Override file-level variables
  variables {
    instance_type = "t3.large"
  }

  assert {
    condition     = var.instance_type == "t3.large"
    error_message = "Instance type should be overridden to t3.large"
  }
}
```

**Variables Referencing Prior Run Blocks:**

```hcl
run "setup_vpc" {
  command = apply
}

run "test_with_vpc_output" {
  command = plan

  variables {
    vpc_id = run.setup_vpc.vpc_id
  }

  assert {
    condition     = var.vpc_id == run.setup_vpc.vpc_id
    error_message = "VPC ID should match setup_vpc output"
  }
}
```

### Assert Block

Assert blocks validate conditions within run blocks. All assertions must pass for the test to succeed.

**Syntax:**

```hcl
assert {
  condition     = <expression>
  error_message = "failure description"
}
```

**Resource Attribute Assertions:**

```hcl
run "test_resource_configuration" {
  command = plan

  assert {
    condition     = aws_s3_bucket.example.bucket == "my-test-bucket"
    error_message = "Bucket name should match expected value"
  }

  assert {
    condition     = aws_s3_bucket.example.versioning[0].enabled == true
    error_message = "Bucket versioning should be enabled"
  }

  assert {
    condition     = length(aws_s3_bucket.example.tags) > 0
    error_message = "Bucket should have at least one tag"
  }
}
```

**Output Validation:**

```hcl
run "test_outputs" {
  command = plan

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC ID output should not be empty"
  }

  assert {
    condition     = length(output.subnet_ids) == 3
    error_message = "Should create exactly 3 subnets"
  }
}
```

**Referencing Prior Run Block Outputs:**

```hcl
run "create_vpc" {
  command = apply
}

run "validate_vpc_output" {
  command = plan

  assert {
    condition     = run.create_vpc.vpc_id != ""
    error_message = "VPC from previous run should have an ID"
  }
}
```

**Complex Conditions:**

```hcl
run "test_complex_validation" {
  command = plan

  assert {
    condition = alltrue([
      for subnet in aws_subnet.private :
      can(regex("^10\\.0\\.", subnet.cidr_block))
    ])
    error_message = "All private subnets should use 10.0.0.0/8 CIDR range"
  }

  assert {
    condition = alltrue([
      for instance in aws_instance.workers :
      contains(["t2.micro", "t2.small", "t3.micro"], instance.instance_type)
    ])
    error_message = "Worker instances should use approved instance types"
  }
}
```

### Expect Failures Block

Test that certain conditions intentionally fail. The test **passes** if the specified checkable objects report an issue, and **fails** if they do not.

**Checkable objects include**: Input variables, output values, check blocks, and managed resources or data sources.

```hcl
run "test_invalid_input_rejected" {
  command = plan

  variables {
    instance_count = -1
  }

  expect_failures = [
    var.instance_count
  ]
}
```

**Testing Custom Conditions:**

```hcl
run "test_custom_condition_failure" {
  command = plan

  variables {
    instance_type = "t2.nano"  # Invalid type
  }

  expect_failures = [
    var.instance_type
  ]
}
```

### Module Block

Test a specific module rather than the root configuration.

**Supported Module Sources:**
- ✅ **Local modules**: `./modules/vpc`, `../shared/networking`
- ✅ **Public Terraform Registry**: `terraform-aws-modules/vpc/aws`
- ✅ **Private Registry (HCP Terraform)**: `app.terraform.io/org/module/provider`

**Unsupported Module Sources:**
- ❌ Git repositories: `git::https://github.com/...`
- ❌ HTTP URLs: `https://example.com/module.zip`
- ❌ Other remote sources (S3, GCS, etc.)

**Module Block Attributes:**
- `source` - Module source (local path or registry address)
- `version` - Version constraint (only for registry modules)

**Testing Local Modules:**

```hcl
run "test_vpc_module" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    cidr_block = "10.0.0.0/16"
    name       = "test-vpc"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR should match input variable"
  }
}
```

**Testing Public Registry Modules:**

```hcl
run "test_registry_module" {
  command = plan

  module {
    source  = "terraform-aws-modules/vpc/aws"
    version = "5.0.0"
  }

  variables {
    name = "test-vpc"
    cidr = "10.0.0.0/16"
  }

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC should be created"
  }
}
```

### Provider Configuration

Override or configure providers for tests. Since Terraform 1.7.0, provider blocks can reference test variables and prior run block outputs.

**Basic Provider Configuration:**

```hcl
provider "aws" {
  region = "us-west-2"
}

run "test_with_provider" {
  command = plan

  assert {
    condition     = aws_instance.example.availability_zone == "us-west-2a"
    error_message = "Instance should be in us-west-2 region"
  }
}
```

**Multiple Provider Configurations:**

```hcl
provider "aws" {
  alias  = "primary"
  region = "us-west-2"
}

provider "aws" {
  alias  = "secondary"
  region = "us-east-1"
}

run "test_with_specific_provider" {
  command = plan

  providers = {
    aws = provider.aws.secondary
  }

  assert {
    condition     = aws_instance.example.availability_zone == "us-east-1a"
    error_message = "Instance should be in us-east-1 region"
  }
}
```

**Provider with Test Variables:**

```hcl
variables {
  aws_region = "eu-west-1"
}

provider "aws" {
  region = var.aws_region
}
```

### State Key Management

The `state_key` attribute controls which state file a run block uses. By default:
- The main configuration shares a state file across all run blocks
- Each alternate module (referenced via `module` block) gets its own state file

**Force Run Blocks to Share State:**

```hcl
run "create_vpc" {
  command = apply

  module {
    source = "./modules/vpc"
  }

  state_key = "shared_state"
}

run "create_subnet" {
  command = apply

  module {
    source = "./modules/subnet"
  }

  state_key = "shared_state"  # Shares state with create_vpc
}
```

### Parallel Execution

Run blocks execute **sequentially by default**. Enable parallel execution with `parallel = true`.

**Requirements for Parallel Execution:**
- No inter-run output references (run blocks cannot reference outputs from parallel runs)
- Different state files (via different modules or state keys)
- Explicit `parallel = true` attribute

```hcl
run "test_module_a" {
  command  = plan
  parallel = true

  module {
    source = "./modules/module-a"
  }

  assert {
    condition     = output.result != ""
    error_message = "Module A should produce output"
  }
}

run "test_module_b" {
  command  = plan
  parallel = true

  module {
    source = "./modules/module-b"
  }

  assert {
    condition     = output.result != ""
    error_message = "Module B should produce output"
  }
}

# This creates a synchronization point
run "test_integration" {
  command = plan

  # Waits for parallel runs above to complete
  assert {
    condition     = output.combined != ""
    error_message = "Integration should work"
  }
}
```

## Mock Providers

Mock providers simulate provider behavior without creating real infrastructure (available since Terraform 1.7.0).

**Basic Mock Provider:**

```hcl
mock_provider "aws" {
  mock_resource "aws_instance" {
    defaults = {
      id            = "i-1234567890abcdef0"
      instance_type = "t2.micro"
      ami           = "ami-12345678"
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-12345678"
    }
  }
}

run "test_with_mocks" {
  command = plan

  assert {
    condition     = aws_instance.example.id == "i-1234567890abcdef0"
    error_message = "Mock instance ID should match"
  }
}
```

**Advanced Mock with Custom Values:**

```hcl
mock_provider "aws" {
  alias = "mocked"

  mock_resource "aws_s3_bucket" {
    defaults = {
      id     = "test-bucket-12345"
      bucket = "test-bucket"
      arn    = "arn:aws:s3:::test-bucket"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b", "us-west-2c"]
    }
  }
}

run "test_with_mock_provider" {
  command = plan

  providers = {
    aws = provider.aws.mocked
  }

  assert {
    condition     = length(data.aws_availability_zones.available.names) == 3
    error_message = "Should return 3 availability zones"
  }
}
```

## Test Execution

### Running Tests

**Run all tests:**

```bash
terraform test
```

**Run specific test file:**

```bash
terraform test tests/defaults.tftest.hcl
```

**Run with verbose output:**

```bash
terraform test -verbose
```

**Run tests in a specific directory:**

```bash
terraform test -test-directory=integration-tests
```

**Filter tests by name:**

```bash
terraform test -filter=test_vpc_configuration
```

**Run tests without cleanup (for debugging):**

```bash
terraform test -no-cleanup
```

### Test Output

**Successful test output:**

```
tests/defaults.tftest.hcl... in progress
  run "test_default_configuration"... pass
  run "test_outputs"... pass
tests/defaults.tftest.hcl... tearing down
tests/defaults.tftest.hcl... pass

Success! 2 passed, 0 failed.
```

**Failed test output:**

```
tests/defaults.tftest.hcl... in progress
  run "test_default_configuration"... fail
    Error: Test assertion failed
    Instance type should be t2.micro by default

Success! 0 passed, 1 failed.
```

## Common Test Patterns (Unit Tests - Plan Mode)

The following examples demonstrate common unit test patterns using `command = plan`. These tests validate Terraform logic without creating real infrastructure, making them fast and cost-free.

### Testing Module Outputs

```hcl
run "test_module_outputs" {
  command = plan

  assert {
    condition     = output.vpc_id != null
    error_message = "VPC ID output must be defined"
  }

  assert {
    condition     = can(regex("^vpc-", output.vpc_id))
    error_message = "VPC ID should start with 'vpc-'"
  }

  assert {
    condition     = length(output.subnet_ids) >= 2
    error_message = "Should output at least 2 subnet IDs"
  }
}
```

### Testing Resource Counts

```hcl
run "test_resource_count" {
  command = plan

  variables {
    instance_count = 3
  }

  assert {
    condition     = length(aws_instance.workers) == 3
    error_message = "Should create exactly 3 worker instances"
  }
}
```

### Testing Conditional Resources

```hcl
run "test_conditional_resource_created" {
  command = plan

  variables {
    create_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 1
    error_message = "NAT gateway should be created when enabled"
  }
}

run "test_conditional_resource_not_created" {
  command = plan

  variables {
    create_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 0
    error_message = "NAT gateway should not be created when disabled"
  }
}
```

### Testing Tags

```hcl
run "test_resource_tags" {
  command = plan

  variables {
    common_tags = {
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }

  assert {
    condition     = aws_instance.example.tags["Environment"] == "production"
    error_message = "Environment tag should be set correctly"
  }

  assert {
    condition     = aws_instance.example.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy tag should be set correctly"
  }
}
```

### Sequential Tests with Dependencies

```hcl
run "setup_vpc" {
  # command defaults to apply

  variables {
    vpc_cidr = "10.0.0.0/16"
  }

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC should be created"
  }
}

run "test_subnet_in_vpc" {
  command = plan

  variables {
    vpc_id = run.setup_vpc.vpc_id
  }

  assert {
    condition     = aws_subnet.example.vpc_id == run.setup_vpc.vpc_id
    error_message = "Subnet should be created in the VPC from setup_vpc"
  }
}
```

### Testing Data Sources

```hcl
run "test_data_source_lookup" {
  command = plan

  assert {
    condition     = data.aws_ami.ubuntu.id != ""
    error_message = "Should find a valid Ubuntu AMI"
  }

  assert {
    condition     = can(regex("^ami-", data.aws_ami.ubuntu.id))
    error_message = "AMI ID should be in correct format"
  }
}
```

### Testing Validation Rules

```hcl
# In variables.tf
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# In test file
run "test_valid_environment" {
  command = plan

  variables {
    environment = "staging"
  }

  assert {
    condition     = var.environment == "staging"
    error_message = "Valid environment should be accepted"
  }
}

run "test_invalid_environment" {
  command = plan

  variables {
    environment = "invalid"
  }

  expect_failures = [
    var.environment
  ]
}
```

## Integration Testing

For tests that create real infrastructure (default behavior with `command = apply`):

```hcl
run "integration_test_full_stack" {
  # command defaults to apply

  variables {
    environment = "integration-test"
    vpc_cidr    = "10.100.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.id != ""
    error_message = "VPC should be created"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create 2 private subnets"
  }

  assert {
    condition     = aws_instance.bastion.public_ip != ""
    error_message = "Bastion instance should have a public IP"
  }
}

# Cleanup happens automatically after test completes
```

## Cleanup and Destruction

**Important**: Resources are destroyed in **reverse run block order** after test completion. This is critical for configurations with dependencies.

**Example**: For S3 buckets containing objects, the bucket must be emptied before deletion:

```hcl
run "create_bucket_with_objects" {
  command = apply

  assert {
    condition     = aws_s3_bucket.example.id != ""
    error_message = "Bucket should be created"
  }
}

run "add_objects_to_bucket" {
  command = apply

  assert {
    condition     = length(aws_s3_object.files) > 0
    error_message = "Objects should be added"
  }
}

# Cleanup occurs in reverse order:
# 1. Destroys objects (run "add_objects_to_bucket")
# 2. Destroys bucket (run "create_bucket_with_objects")
```

**Disable Cleanup for Debugging:**

```bash
terraform test -no-cleanup
```

## Best Practices

1. **Test Organization**: Organize tests by type using clear naming conventions:
   - Unit tests (plan mode): `*_unit_test.tftest.hcl` - fast, no resources created
   - Integration tests (apply mode): `*_integration_test.tftest.hcl` - creates real resources
   - Example: `defaults_unit_test.tftest.hcl`, `validation_unit_test.tftest.hcl`, `full_stack_integration_test.tftest.hcl`
   - This makes it easy to run unit tests separately from integration tests in CI/CD

2. **Apply vs Plan**:
   - Default is `command = apply` (integration testing with real resources)
   - Use `command = plan` for unit tests (fast, no real resources)
   - Use mocks for isolated unit testing

3. **Meaningful Assertions**: Write clear, specific assertion error messages that help diagnose failures

4. **Test Isolation**: Each run block should be independent when possible. Use sequential runs only when testing dependencies

5. **Variable Coverage**: Test different variable combinations to validate all code paths. Remember that test variables have the highest precedence

6. **Mock Providers**: Use mocks for external dependencies to speed up tests and reduce costs (requires Terraform 1.7.0+)

7. **Cleanup**: Integration tests automatically destroy resources in reverse order after completion. Use `-no-cleanup` flag for debugging

8. **CI Integration**: Run `terraform test` in CI/CD pipelines to catch issues early

9. **Test Naming**: Use descriptive names for run blocks that explain what scenario is being tested

10. **Negative Testing**: Test invalid inputs and expected failures using `expect_failures`

11. **Module Support**: Remember that test files only support **local** and **registry** modules, not Git or other sources

12. **Parallel Execution**: Use `parallel = true` for independent tests with different state files to speed up test execution

## Advanced Features

### Testing with Refresh-Only Mode

```hcl
run "test_refresh_only" {
  command = plan

  plan_options {
    mode = refresh-only
  }

  assert {
    condition     = aws_instance.example.tags["Environment"] == "production"
    error_message = "Tags should be refreshed correctly"
  }
}
```

### Testing with Targeted Resources

```hcl
run "test_specific_resource" {
  command = plan

  plan_options {
    target = [
      aws_instance.example
    ]
  }

  assert {
    condition     = aws_instance.example.instance_type == "t2.micro"
    error_message = "Targeted resource should be planned"
  }
}
```

### Testing Multiple Modules in Parallel

```hcl
run "test_networking_module" {
  command  = plan
  parallel = true

  module {
    source = "./modules/networking"
  }

  variables {
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC should be created"
  }
}

run "test_compute_module" {
  command  = plan
  parallel = true

  module {
    source = "./modules/compute"
  }

  variables {
    instance_type = "t2.micro"
  }

  assert {
    condition     = output.instance_id != ""
    error_message = "Instance should be created"
  }
}
```

### Custom State Management

```hcl
run "create_foundation" {
  command   = apply
  state_key = "foundation"

  assert {
    condition     = aws_vpc.main.id != ""
    error_message = "Foundation VPC should be created"
  }
}

run "create_application" {
  command   = apply
  state_key = "foundation"  # Share state with foundation

  variables {
    vpc_id = run.create_foundation.vpc_id
  }

  assert {
    condition     = aws_instance.app.vpc_id == run.create_foundation.vpc_id
    error_message = "Application should use foundation VPC"
  }
}
```

## Troubleshooting

### Test Failures

**Issue**: Assertion failures

**Solution**: Review error messages, check actual vs expected values, verify variable inputs. Use `-verbose` flag for detailed output

### Provider Authentication

**Issue**: Tests fail due to missing credentials

**Solution**: Configure provider credentials for testing, or use mock providers for unit tests (available since v1.7.0)

### Resource Dependencies

**Issue**: Tests fail due to missing dependencies

**Solution**: Use sequential run blocks or create setup runs to establish required resources. Remember cleanup happens in reverse order

### Long Test Execution

**Issue**: Tests take too long to run

**Solution**:
- Use `command = plan` instead of `apply` where possible
- Leverage mock providers
- Use `parallel = true` for independent tests
- Organize slow integration tests separately

### State Conflicts

**Issue**: Multiple tests interfere with each other

**Solution**:
- Use different modules (automatic separate state)
- Use `state_key` attribute to control state file sharing
- Use mock providers for isolated testing

### Module Source Errors

**Issue**: Test fails with unsupported module source

**Solution**: Terraform test files only support **local** and **registry** modules. Convert Git or HTTP sources to local modules or use registry modules

## Example Test Suite

Complete example testing a VPC module, demonstrating both unit tests (plan mode) and integration tests (apply mode):

```hcl
# tests/vpc_module_unit_test.tftest.hcl
# This file contains unit tests using command = plan (fast, no resources created)

variables {
  environment = "test"
  aws_region  = "us-west-2"
}

# ============================================================================
# UNIT TESTS (Plan Mode) - Validate logic without creating resources
# ============================================================================

# Test default configuration
run "test_defaults" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
    vpc_name = "test-vpc"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR should match input"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames should be enabled by default"
  }

  assert {
    condition     = aws_vpc.main.tags["Name"] == "test-vpc"
    error_message = "VPC name tag should match input"
  }
}

# Test subnet creation
run "test_subnets" {
  command = plan

  variables {
    vpc_cidr        = "10.0.0.0/16"
    vpc_name        = "test-vpc"
    public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Should create 2 public subnets"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create 2 private subnets"
  }

  assert {
    condition = alltrue([
      for subnet in aws_subnet.private :
      subnet.map_public_ip_on_launch == false
    ])
    error_message = "Private subnets should not assign public IPs"
  }
}

# Test outputs
run "test_outputs" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
    vpc_name = "test-vpc"
  }

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC ID output should not be empty"
  }

  assert {
    condition     = can(regex("^vpc-", output.vpc_id))
    error_message = "VPC ID should have correct format"
  }

  assert {
    condition     = output.vpc_cidr == "10.0.0.0/16"
    error_message = "VPC CIDR output should match input"
  }
}

# Test invalid CIDR block
run "test_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr = "invalid"
    vpc_name = "test-vpc"
  }

  expect_failures = [
    var.vpc_cidr
  ]
}
```

```hcl
# tests/vpc_module_integration_test.tftest.hcl
# This file contains integration tests using command = apply (creates real resources)

variables {
  environment = "integration-test"
  aws_region  = "us-west-2"
}

# ============================================================================
# INTEGRATION TESTS (Apply Mode) - Creates and validates real infrastructure
# ============================================================================

# Integration test creating real VPC
run "integration_test_vpc_creation" {
  # command defaults to apply - creates real AWS resources!

  variables {
    vpc_cidr = "10.100.0.0/16"
    vpc_name = "integration-test-vpc"
  }

  assert {
    condition     = aws_vpc.main.id != ""
    error_message = "VPC should be created with valid ID"
  }

  assert {
    condition     = aws_vpc.main.state == "available"
    error_message = "VPC should be in available state"
  }
}
```

```hcl
# tests/vpc_module_mock_test.tftest.hcl
# This file demonstrates mock provider testing - fastest option, no credentials needed

# ============================================================================
# MOCK TESTS (Plan Mode with Mocks) - No real infrastructure or API calls
# ============================================================================
# Mock tests are ideal for:
# - Testing complex logic without cloud costs
# - Running tests without provider credentials
# - Fast feedback in local development
# - CI/CD pipelines without cloud access
# - Testing with predictable data source results

# Define mock provider to simulate AWS behavior
mock_provider "aws" {
  # Mock EC2 instances - returns these values instead of creating real resources
  mock_resource "aws_instance" {
    defaults = {
      id                          = "i-1234567890abcdef0"
      arn                         = "arn:aws:ec2:us-west-2:123456789012:instance/i-1234567890abcdef0"
      instance_type               = "t2.micro"
      ami                         = "ami-12345678"
      availability_zone           = "us-west-2a"
      subnet_id                   = "subnet-12345678"
      vpc_security_group_ids      = ["sg-12345678"]
      associate_public_ip_address = true
      public_ip                   = "203.0.113.1"
      private_ip                  = "10.0.1.100"
      tags                        = {}
    }
  }

  # Mock VPC resources
  mock_resource "aws_vpc" {
    defaults = {
      id                       = "vpc-12345678"
      arn                      = "arn:aws:ec2:us-west-2:123456789012:vpc/vpc-12345678"
      cidr_block              = "10.0.0.0/16"
      enable_dns_hostnames    = true
      enable_dns_support      = true
      instance_tenancy        = "default"
      tags                    = {}
    }
  }

  # Mock subnet resources
  mock_resource "aws_subnet" {
    defaults = {
      id                      = "subnet-12345678"
      arn                     = "arn:aws:ec2:us-west-2:123456789012:subnet/subnet-12345678"
      vpc_id                  = "vpc-12345678"
      cidr_block             = "10.0.1.0/24"
      availability_zone       = "us-west-2a"
      map_public_ip_on_launch = false
      tags                    = {}
    }
  }

  # Mock S3 bucket resources
  mock_resource "aws_s3_bucket" {
    defaults = {
      id                  = "test-bucket-12345"
      arn                 = "arn:aws:s3:::test-bucket-12345"
      bucket              = "test-bucket-12345"
      bucket_domain_name  = "test-bucket-12345.s3.amazonaws.com"
      region              = "us-west-2"
      tags                = {}
    }
  }

  # Mock data sources - critical for testing modules that query existing infrastructure
  mock_data "aws_ami" {
    defaults = {
      id                  = "ami-0c55b159cbfafe1f0"
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20210430"
      architecture        = "x86_64"
      root_device_type    = "ebs"
      virtualization_type = "hvm"
      owners              = ["099720109477"]
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b", "us-west-2c"]
      zone_ids = ["usw2-az1", "usw2-az2", "usw2-az3"]
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id                   = "vpc-12345678"
      cidr_block          = "10.0.0.0/16"
      enable_dns_hostnames = true
      enable_dns_support   = true
    }
  }
}

# Test 1: Validate resource configuration with mocked values
run "test_instance_with_mocks" {
  command = plan  # Mocks only work with plan mode

  variables {
    instance_type = "t2.micro"
    ami_id        = "ami-12345678"
  }

  assert {
    condition     = aws_instance.example.instance_type == "t2.micro"
    error_message = "Instance type should match input variable"
  }

  assert {
    condition     = aws_instance.example.id == "i-1234567890abcdef0"
    error_message = "Mock should return consistent instance ID"
  }

  assert {
    condition     = can(regex("^203\\.0\\.113\\.", aws_instance.example.public_ip))
    error_message = "Mock public IP should be in TEST-NET-3 range"
  }
}

# Test 2: Validate data source behavior with mocked results
run "test_data_source_with_mocks" {
  command = plan

  assert {
    condition     = data.aws_ami.ubuntu.id == "ami-0c55b159cbfafe1f0"
    error_message = "Mock data source should return predictable AMI ID"
  }

  assert {
    condition     = length(data.aws_availability_zones.available.names) == 3
    error_message = "Should return 3 mocked availability zones"
  }

  assert {
    condition = contains(
      data.aws_availability_zones.available.names,
      "us-west-2a"
    )
    error_message = "Should include us-west-2a in mocked zones"
  }
}

# Test 3: Validate complex logic with for_each and mocks
run "test_multiple_subnets_with_mocks" {
  command = plan

  variables {
    subnet_cidrs = {
      "public-a"  = "10.0.1.0/24"
      "public-b"  = "10.0.2.0/24"
      "private-a" = "10.0.10.0/24"
      "private-b" = "10.0.11.0/24"
    }
  }

  # Test that all subnets are created
  assert {
    condition     = length(keys(aws_subnet.subnets)) == 4
    error_message = "Should create 4 subnets from for_each map"
  }

  # Test that public subnets have correct naming
  assert {
    condition = alltrue([
      for name, subnet in aws_subnet.subnets :
      can(regex("^public-", name)) ? subnet.map_public_ip_on_launch == true : true
    ])
    error_message = "Public subnets should map public IPs on launch"
  }

  # Test that all subnets belong to mocked VPC
  assert {
    condition = alltrue([
      for subnet in aws_subnet.subnets :
      subnet.vpc_id == "vpc-12345678"
    ])
    error_message = "All subnets should belong to mocked VPC"
  }
}

# Test 4: Validate output values with mocks
run "test_outputs_with_mocks" {
  command = plan

  assert {
    condition     = output.vpc_id == "vpc-12345678"
    error_message = "VPC ID output should match mocked value"
  }

  assert {
    condition     = can(regex("^vpc-", output.vpc_id))
    error_message = "VPC ID output should have correct format"
  }

  assert {
    condition     = output.instance_public_ip == "203.0.113.1"
    error_message = "Instance public IP should match mock"
  }
}

# Test 5: Test conditional logic with mocks
run "test_conditional_resources_with_mocks" {
  command = plan

  variables {
    create_bastion     = true
    create_nat_gateway = false
  }

  assert {
    condition     = length(aws_instance.bastion) == 1
    error_message = "Bastion should be created when enabled"
  }

  assert {
    condition     = length(aws_nat_gateway.nat) == 0
    error_message = "NAT gateway should not be created when disabled"
  }
}

# Test 6: Test tag propagation with mocks
run "test_tag_inheritance_with_mocks" {
  command = plan

  variables {
    common_tags = {
      Environment = "test"
      ManagedBy   = "Terraform"
      Project     = "MockTesting"
    }
  }

  # Verify tags are properly merged with defaults
  assert {
    condition = alltrue([
      for key in keys(var.common_tags) :
      contains(keys(aws_instance.example.tags), key)
    ])
    error_message = "All common tags should be present on instance"
  }

  assert {
    condition     = aws_instance.example.tags["Environment"] == "test"
    error_message = "Environment tag should be set correctly"
  }
}

# Test 7: Test validation rules with mocks (expect_failures)
run "test_invalid_cidr_with_mocks" {
  command = plan

  variables {
    vpc_cidr = "192.168.0.0/8"  # Invalid - should be /16 or /24
  }

  # Expect custom validation to fail
  expect_failures = [
    var.vpc_cidr
  ]
}

# Test 8: Sequential mock tests with state sharing
run "setup_vpc_with_mocks" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
    vpc_name = "test-vpc"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR should match input"
  }
}

run "test_subnet_references_vpc_with_mocks" {
  command = plan

  variables {
    vpc_id      = run.setup_vpc_with_mocks.vpc_id
    subnet_cidr = "10.0.1.0/24"
  }

  assert {
    condition     = aws_subnet.example.vpc_id == run.setup_vpc_with_mocks.vpc_id
    error_message = "Subnet should reference VPC from previous run"
  }

  assert {
    condition     = aws_subnet.example.vpc_id == "vpc-12345678"
    error_message = "VPC ID should match mocked value"
  }
}
```

**Key Benefits of Mock Testing:**

1. **No Cloud Costs**: Runs entirely locally without creating infrastructure
2. **No Credentials Needed**: Perfect for CI/CD environments without cloud access
3. **Fast Execution**: Tests complete in seconds, not minutes
4. **Predictable Results**: Data sources return consistent values
5. **Isolated Testing**: No dependencies on existing cloud resources
6. **Safe Experimentation**: Test destructive operations without risk

**Limitations of Mock Testing:**

1. **Plan Mode Only**: Mocks don't work with `command = apply`
2. **Not Real Behavior**: Mocks may not reflect actual provider API behavior
3. **Computed Values**: Mock defaults may not match real computed attributes
4. **Provider Updates**: Mocks need manual updates when provider schemas change
5. **Resource Interactions**: Can't test real resource dependencies or timing issues

**When to Use Mock Tests:**

- ✅ Testing Terraform logic and conditionals
- ✅ Validating variable transformations
- ✅ Testing for_each and count expressions
- ✅ Checking output calculations
- ✅ Local development without cloud access
- ✅ Fast CI/CD feedback loops
- ❌ Validating actual provider behavior
- ❌ Testing real resource creation side effects
- ❌ Verifying API-level interactions
- ❌ End-to-end integration testing

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Terraform Tests

on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]

jobs:
  terraform-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Run Terraform Tests
        run: terraform test -verbose
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### GitLab CI Example

```yaml
terraform-test:
  image: hashicorp/terraform:1.9
  stage: test
  before_script:
    - terraform init
  script:
    - terraform fmt -check -recursive
    - terraform validate
    - terraform test -verbose
  only:
    - merge_requests
    - main
```

## References

For more information:
- [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Terraform Test Command Reference](https://developer.hashicorp.com/terraform/cli/commands/test)
- [Testing Best Practices](https://developer.hashicorp.com/terraform/language/tests/best-practices)
