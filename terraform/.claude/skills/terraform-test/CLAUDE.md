# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Skill repository** for HashiCorp Terraform Test - a specialized knowledge base that provides comprehensive documentation and guidance for writing and running automated tests for Terraform configurations. This is not a traditional software project with executable code, but rather a documentation repository structured as a skill module for Claude AI assistants.

**Purpose**: Enable Claude to help users create test files (`.tftest.hcl`), write test scenarios with run blocks, validate infrastructure behavior with assertions, mock providers and data sources, test module outputs and resource configurations, and troubleshoot Terraform test syntax and execution.

## Repository Structure

```
claude-skill-terraform-test/
├── README.md     # Brief project description
├── SKILL.md      # Main comprehensive guide
└── CLAUDE.md     # This file - guidance for Claude Code
```

## Documentation Architecture

### Core Documentation

**[SKILL.md](SKILL.md)** - Comprehensive guide covering:
- Core concepts (test files, run blocks, assert blocks, mock providers)
- Test file structure and components
- Test configuration syntax (run, assert, variables, expect_failures, etc.)
- Mock providers for unit testing
- Test execution commands and options
- Common test patterns
- Integration testing
- Cleanup and destruction
- Best practices
- Advanced features (parallel execution, state management)
- Troubleshooting
- Complete example test suite
- CI/CD integration

## Key Terraform Test Concepts

### Test Modes: Apply vs Plan

**Critical Understanding**: Terraform tests use two modes:

1. **Integration Testing (Default)**: `command = apply`
   - Creates **real infrastructure** in your cloud provider
   - Tests actual resource creation and behavior
   - Slower and incurs cloud costs
   - Resources are automatically destroyed after test completion
   - Best for validating end-to-end infrastructure behavior

2. **Unit Testing**: `command = plan`
   - Does **NOT** create real infrastructure
   - Validates Terraform logic, conditionals, and outputs
   - Fast and free (no cloud resources created)
   - Best for testing module logic, variable handling, resource counts

**Important**: When helping users write tests, always clarify which mode is appropriate for their use case. Default is `apply`, not `plan`.

### Test File Structure

Test files (`.tftest.hcl` or `.tftest.json`) contain:
- **Zero to one** `test` block (configuration settings)
- **One to many** `run` blocks (test scenarios)
- **Zero to one** `variables` block (input values)
- **Zero to many** `provider` blocks (provider configuration)
- **Zero to many** `mock_provider` blocks (mock provider data, since v1.7.0)

**Important**: The order of `variables` and `provider` blocks doesn't matter - they're all processed at the beginning.

### Run Block Execution

Run blocks execute **sequentially by default**:
- Each run block can reference outputs from previous run blocks via `run.<block_name>.<output_name>`
- Use `parallel = true` for independent tests (requires different state files)
- Sequential execution is critical for tests with dependencies

### Variable Precedence

**Critical**: Variables defined in test files have the **highest precedence**, overriding:
- Environment variables
- Variables files (`.tfvars`)
- Command-line input (`-var`)

This ensures test scenarios are reproducible and not affected by external configuration.

### Module Support Limitation

**Important**: Terraform test files only support:
- **Local modules**: `./modules/vpc` or `../shared-modules/networking`
- **Registry modules**: `terraform-aws-modules/vpc/aws` or `app.terraform.io/my-org/vpc/aws`

**NOT supported**:
- Git sources
- HTTP/HTTPS archives
- Other remote sources

If users have Git-based modules, guide them to either clone locally or publish to a registry.

### Cleanup and Destruction

**Critical behavior**: Resources created with `command = apply` are destroyed in **reverse run block order** after test completion.

**Why this matters**: For resources with dependencies (e.g., S3 bucket with objects), destruction order is critical:
1. Objects must be deleted first (later run block)
2. Bucket can then be deleted (earlier run block)

The reverse order ensures dependencies are respected during cleanup.

**Debugging**: Use `terraform test -no-cleanup` to leave resources in place for inspection.

## Common Scenarios and Patterns

### When Users Ask "How do I test my module?"

Guide them to:
1. Create a `tests/` directory in their module
2. Start with a simple `defaults.tftest.hcl` testing default configuration
3. Use `command = plan` for fast unit tests
4. Add `command = apply` integration tests for critical paths
5. Organize tests by scenario (defaults, edge cases, integration)

### When Users Ask "My tests are too slow"

Suggest:
1. Use `command = plan` instead of `apply` where possible
2. Use mock providers (requires Terraform 1.7.0+) for isolated unit tests
3. Use `parallel = true` for independent tests with different state files
4. Separate slow integration tests from fast unit tests
5. Run integration tests only in CI, not locally

### When Users Ask About Testing Multiple Scenarios

Guide them to:
1. Create multiple run blocks in the same test file
2. Override variables in each run block for different scenarios
3. Use descriptive names: `run "test_small_deployment"`, `run "test_large_deployment"`
4. Keep related scenarios in the same file for context

### When Users Ask About Mocking

Guide them to:
1. Requires Terraform 1.7.0 or later
2. Use `mock_provider` blocks to simulate provider behavior
3. Define `mock_resource` and `mock_data` with default values
4. Enables fast unit testing without cloud resources
5. Best for testing logic in isolation

### When Users Ask About Testing Failures

Guide them to use `expect_failures`:
1. Test that validation rules work correctly
2. Test that invalid inputs are rejected
3. Specify checkable objects: variables, outputs, check blocks, resources
4. Test **passes** when the specified objects fail as expected

### When Users Ask About CI/CD Integration

Recommend:
1. Run `terraform test` in CI pipeline
2. Include `terraform fmt -check`, `terraform validate`, and `terraform test`
3. Set up cloud credentials as secrets/environment variables
4. Use `-verbose` flag for detailed CI output
5. **Separate unit tests from integration tests** for optimal CI performance:
   - Run unit tests (plan mode) on every PR: `terraform test tests/*_unit_test.tftest.hcl`
   - Run integration tests (apply mode) only on merge to main or scheduled: `terraform test tests/*_integration_test.tftest.hcl`
   - Unit tests are fast (seconds) and free; integration tests are slow (minutes) and cost money
   - Example: Run unit tests in ~10 seconds for quick feedback, integration tests in ~5 minutes nightly

## Common Errors and Solutions

### "Test failed: assertion failed"

**Issue**: Assertion condition evaluated to false
**Solution**: Review the error message, check actual vs expected values, verify variable inputs. Use `-verbose` for detailed output.

### "Provider authentication failed"

**Issue**: Missing credentials for integration tests
**Solution**: Either configure provider credentials (for integration tests) or use mock providers (for unit tests, requires v1.7.0+).

### "Cannot reference run block output"

**Issue**: Trying to reference outputs from a parallel run or invalid run block name
**Solution**: Ensure run blocks are sequential (not parallel) and use correct syntax: `run.<block_name>.<output_name>`

### "Module source not supported"

**Issue**: Test references Git or HTTP module source
**Solution**: Terraform test only supports local and registry modules. Clone Git modules locally or use registry sources.

### "Tests interfere with each other"

**Issue**: State conflicts between tests
**Solution**: Use different modules (automatic separate state), `state_key` attribute, or mock providers for isolation.

## Test Organization Best Practices

### File Naming

**Organize by test type using clear naming conventions:**

```
tests/
├── defaults_unit_test.tftest.hcl           # Unit test (plan mode - fast, no resources)
├── edge_cases_unit_test.tftest.hcl         # Unit test (plan mode)
├── validation_unit_test.tftest.hcl         # Unit test (plan mode)
├── full_stack_integration_test.tftest.hcl  # Integration test (apply mode - creates real resources)
└── multi_region_integration_test.tftest.hcl  # Integration test (apply mode)
```

**Benefits:**
- Clearly distinguishes unit tests (plan mode) from integration tests (apply mode)
- Makes it easy to run tests selectively: `terraform test tests/*_unit_test.tftest.hcl`
- Self-documenting file names indicate test type and resource implications

### Run Block Naming

Use descriptive names that explain the test scenario:
- Good: `run "test_with_3_availability_zones"`
- Good: `run "test_invalid_cidr_rejected"`
- Bad: `run "test1"`
- Bad: `run "test"`

### Assertion Error Messages

Write clear error messages that help diagnose failures:
- Good: `"Should create exactly 3 subnets across availability zones"`
- Good: `"VPC CIDR must be within 10.0.0.0/8 range for private networks"`
- Bad: `"Test failed"`
- Bad: `"Wrong value"`

## Test Writing Strategy

### Start with Unit Tests (Plan Mode)

1. Test default configuration works
2. Test variable overrides
3. Test conditional logic
4. Test resource counts and attributes
5. Test outputs are defined correctly

All with `command = plan` - fast, free, no real resources.

### Add Integration Tests (Apply Mode) Selectively

Only for:
- Critical infrastructure paths
- Actual resource behavior validation
- Provider-specific features
- Real cloud service interactions

Use `command = apply` sparingly - slower, costs money, creates real resources.

### Use Mocks for Isolated Unit Testing

When available (Terraform 1.7.0+):
- Mock external data sources
- Mock dependencies between modules
- Test logic without cloud provider calls
- Fastest option for pure logic testing

## How to Work with This Repository

### No Build System

This is a documentation-only repository:
- No compilation or build commands
- No package manager or dependencies
- No automated tests
- No Docker or containerization

### Making Changes

When updating documentation:

1. **Keep examples accurate** - All code examples must use valid Terraform test syntax
2. **Update version-specific features** - Note when features require specific Terraform versions
3. **Test command accuracy** - Ensure all CLI commands are correct
4. **Maintain consistency** - Terminology should be consistent throughout

### Version Control

Use Git for all changes:
```bash
git status                    # Check current changes
git add <files>              # Stage changes
git commit -m "message"      # Commit changes
git push                     # Push to remote
```

## Documentation Style Guide

### Code Blocks

All Terraform test examples use HCL syntax:

```hcl
# Correct test structure
run "test_example" {
  command = plan

  variables {
    key = "value"
  }

  assert {
    condition     = resource.example.attribute == "expected"
    error_message = "Clear, helpful error message"
  }
}
```

### Terminology Consistency

Use these exact terms consistently:
- **Test file** (not "test configuration" or "test script")
- **Run block** (not "test block" or "test case")
- **Assert block** (not "assertion" or "check")
- **Integration test** for `command = apply` (creates real resources)
- **Unit test** for `command = plan` (no real resources)
- **Mock provider** (not "fake provider" or "stub provider")

### Command Format

Always use the full command format:

```bash
# Correct
terraform test
terraform test tests/defaults.tftest.hcl
terraform test -verbose
terraform test -filter=test_vpc_configuration

# Not abbreviated
tf test  # Don't use
```

## CLI Commands (Terraform Test)

```bash
# Run all tests
terraform test

# Run specific test file
terraform test tests/defaults.tftest.hcl

# Run with verbose output
terraform test -verbose

# Run tests in specific directory
terraform test -test-directory=integration-tests

# Filter tests by name
terraform test -filter=test_vpc_configuration

# Run tests without cleanup (for debugging)
terraform test -no-cleanup
```

Note: These are subcommands of the regular `terraform` CLI, not a separate tool.

## Key Differences from Other Testing Frameworks

Users familiar with other testing frameworks may have incorrect assumptions:

### vs. Terratest (Go-based)
- **Terraform Test**: Native, no additional languages, HCL syntax
- **Terratest**: Requires Go, programmatic testing, more flexibility

### vs. Kitchen-Terraform (Ruby-based)
- **Terraform Test**: Built-in, no external dependencies
- **Kitchen-Terraform**: Requires Ruby and Test Kitchen setup

### vs. Terraform Compliance (Policy)
- **Terraform Test**: Tests actual infrastructure behavior and logic
- **Terraform Compliance**: Policy-as-code, compliance checks only

## Terraform Version Requirements

Key version milestones:
- **Terraform 1.6.0**: Terraform test introduced
- **Terraform 1.7.0**: Mock providers added
- **Terraform 1.9.0**: `state_key` and `parallel` attributes added

Always check user's Terraform version if they request features from newer versions.

## Integration with HCP Terraform / Terraform Cloud

Terraform tests work with:
- Local Terraform CLI (most common)
- HCP Terraform / Terraform Cloud (run tests in workspace context)
- CI/CD pipelines (GitHub Actions, GitLab CI, etc.)

Tests access the same state and variables as regular Terraform operations.

## Common User Questions

### "Should I use Terraform test or Terratest?"

**Terraform Test**: Start here for most projects
- Built-in, no additional setup
- Perfect for module testing
- Native HCL syntax

**Terratest**: Consider when:
- Need complex test logic
- Testing across multiple tools (Packer, Docker, etc.)
- Already invested in Go ecosystem

### "How do I test without creating real resources?"

Two options:
1. Use `command = plan` (validates logic without creating resources)
2. Use mock providers with `command = plan` (requires Terraform 1.7.0+)

### "Can I test Terraform Cloud/Enterprise features?"

Yes, but with limitations:
- Test runs in context of your workspace
- Remote state access works normally
- Sentinel policies and run triggers are not tested
- Cost estimation is not included in test runs

### "How do I test modules in a monorepo?"

Use the `module` block in run blocks:
```hcl
run "test_vpc_module" {
  module {
    source = "./modules/vpc"
  }
  # ...
}
```

Each module can have its own `tests/` directory with test files.
