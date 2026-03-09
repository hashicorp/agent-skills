---
name: terraform-test
description: Comprehensive guide for writing and running Terraform tests. Use when creating test files (.tftest.hcl), writing test scenarios with run blocks, validating infrastructure behavior with assertions, mocking providers and data sources, testing module outputs and resource configurations, or troubleshooting Terraform test syntax and execution.
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.2"
---

# Terraform Test

Terraform's built-in testing framework validates that configuration updates don't introduce breaking changes. Tests run against temporary resources, protecting existing infrastructure and state files.

## Reference Files

- `references/MOCK_PROVIDERS.md` — Mock provider syntax, common defaults, when to use mocks (Terraform 1.7.0+ only — skip if the user's version is below 1.7)
- `references/CI_CD.md` — GitHub Actions and GitLab CI pipeline examples
- `references/EXAMPLES.md` — Complete example test suite (unit, integration, and mock tests for a VPC module)

Read the relevant reference file when the user asks about mocking, CI/CD integration, or wants a full example.

## Core Concepts

- **Test file** (`.tftest.hcl` / `.tftest.json`): Contains `run` blocks that validate your configuration
- **Run block**: A single test scenario with optional variables, providers, and assertions
- **Assert block**: Conditions that must be true for the test to pass
- **Mock provider**: Simulates provider behavior without real infrastructure (Terraform 1.7.0+)
- **Test modes**: `apply` (default, creates real resources) or `plan` (validates logic only)

## File Structure

```
my-module/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── defaults_unit_test.tftest.hcl         # plan mode — fast, no resources
    ├── validation_unit_test.tftest.hcl        # plan mode
    └── full_stack_integration_test.tftest.hcl # apply mode — creates real resources
```

Use `*_unit_test.tftest.hcl` for plan-mode tests and `*_integration_test.tftest.hcl` for apply-mode tests so they can be filtered separately in CI.

## Test File Structure

```hcl
# Optional: test-wide settings
test {
  parallel = true  # Enable parallel execution for all run blocks (default: false)
}

# Optional: file-level variables (highest precedence, override all other sources)
variables {
  aws_region    = "us-west-2"
  instance_type = "t2.micro"
}

# Optional: provider configuration
provider "aws" {
  region = var.aws_region
}

# Required: at least one run block
run "test_default_configuration" {
  command = plan

  assert {
    condition     = aws_instance.example.instance_type == "t2.micro"
    error_message = "Instance type should be t2.micro by default"
  }
}
```

## Run Block

```hcl
run "test_name" {
  command  = plan  # or apply (default)
  parallel = true  # optional, since v1.9.0

  # Override file-level variables
  variables {
    instance_type = "t3.large"
  }

  # Reference a specific module
  module {
    source  = "./modules/vpc"  # local or registry only (not git/http)
    version = "5.0.0"          # registry modules only
  }

  # Control state isolation
  state_key = "shared_state"  # since v1.9.0

  # Plan behavior
  plan_options {
    mode    = refresh-only  # or normal (default)
    refresh = true
    replace = [aws_instance.example]
    target  = [aws_instance.example]
  }

  # Assertions
  assert {
    condition     = aws_instance.example.id != ""
    error_message = "Instance should have a valid ID"
  }

  # Expected failures (test passes if these fail)
  expect_failures = [
    var.instance_count
  ]
}
```

## Common Test Patterns

### Validate outputs

```hcl
run "test_outputs" {
  command = plan

  assert {
    condition     = output.vpc_id != null
    error_message = "VPC ID output must be defined"
  }

  assert {
    condition     = can(regex("^vpc-", output.vpc_id))
    error_message = "VPC ID should start with 'vpc-'"
  }
}
```

### Conditional resources

```hcl
run "test_nat_gateway_disabled" {
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

### Validation rules

```hcl
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

### Sequential tests with dependencies

```hcl
run "setup_vpc" {
  command = apply

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
    error_message = "Subnet should be in the VPC from setup_vpc"
  }
}
```

### Complex conditions

```hcl
assert {
  condition = alltrue([
    for subnet in aws_subnet.private :
    can(regex("^10\\.0\\.", subnet.cidr_block))
  ])
  error_message = "All private subnets should use 10.0.0.0/8 CIDR range"
}
```

## Cleanup

Resources are destroyed in **reverse run block order** after test completion. This matters for dependencies (e.g., S3 objects before bucket). Use `terraform test -no-cleanup` to skip cleanup for debugging.

## Running Tests

```bash
terraform test                                        # all tests
terraform test tests/defaults.tftest.hcl             # specific file
terraform test -filter=test_vpc_configuration        # by run block name
terraform test -test-directory=integration-tests     # custom directory
terraform test -verbose                              # detailed output
terraform test -no-cleanup                           # skip resource cleanup
```

## Best Practices

1. **Naming**: `*_unit_test.tftest.hcl` for plan mode, `*_integration_test.tftest.hcl` for apply mode
2. **Test naming**: Use descriptive run block names that explain the scenario being tested
3. **Default to plan**: Use `command = plan` unless you need to test real resource behavior
4. **Use mocks** for external dependencies — faster and no credentials needed (see `references/MOCK_PROVIDERS.md`)
5. **Error messages**: Make them specific enough to diagnose failures without running the test again
6. **Negative tests**: Use `expect_failures` to verify validation rules reject bad inputs
7. **Variable coverage**: Test different variable combinations to validate all code paths — test variables have the highest precedence and override all other sources
8. **Module sources**: Test files only support local paths and registry modules — not git or HTTP URLs
9. **Parallel execution**: Use `parallel = true` for independent tests with different state files
10. **Cleanup**: Integration tests destroy resources in reverse run block order automatically; use `-no-cleanup` for debugging
11. **CI/CD**: Run unit tests on every PR, integration tests on merge (see `references/CI_CD.md`)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Assertion failures | Use `-verbose` to see actual vs expected values |
| Missing credentials | Use mock providers for unit tests |
| Unsupported module source | Convert git/HTTP sources to local modules |
| Tests interfering | Use `state_key` or separate modules for isolation |
| Slow tests | Use `command = plan` and mocks; run integration tests separately |

## References

- [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Terraform Test Command](https://developer.hashicorp.com/terraform/cli/commands/test)
- [Testing Best Practices](https://developer.hashicorp.com/terraform/language/tests/best-practices)
