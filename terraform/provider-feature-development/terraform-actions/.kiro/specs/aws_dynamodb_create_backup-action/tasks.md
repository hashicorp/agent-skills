# Implementation Plan: AWS DynamoDB Create Backup Action

## Overview

This implementation plan breaks down the development of the AWS DynamoDB Create Backup Action into discrete, manageable tasks. Each task builds incrementally on previous work, following the async job submission pattern with polling for completion status.

## Tasks

- [ ] 1. Set up action file structure and core interfaces
  - Create `internal/service/dynamodb/create_backup_action.go`
  - Create `internal/service/dynamodb/create_backup_action_test.go`
  - Define action type struct implementing `action.Action` interface
  - Define action model struct with all required fields
  - _Requirements: 1.1, 2.1, 7.1_

- [ ] 2. Implement action schema definition
  - [ ] 2.1 Define Schema() method with all attributes
    - Add `table_name` as required String attribute (1-1024 characters)
    - Add `backup_name` as required String attribute with validators (3-255 characters, pattern `[a-zA-Z0-9_.-]+`)
    - Add `timeout` as optional Int64 attribute with default 1800 seconds and range validator (60-7200)
    - Add `backup_arn` as computed String attribute for output
    - Include region support via `framework.WithRegionModel`
    - _Requirements: 1.1, 2.1, 2.2, 2.3, 2.4, 4.1, 4.2, 4.3, 4.4, 7.1, 7.2_
  
  - [ ] 2.2 Import required validator packages
    - Import `github.com/hashicorp/terraform-plugin-framework-validators/int64validator`
    - Import `github.com/hashicorp/terraform-plugin-framework-validators/stringvalidator`
    - Import `github.com/hashicorp/terraform-plugin-framework/resource/schema/int64default`
    - _Requirements: 2.2, 2.3, 2.4, 4.3, 4.4_
  
  - [ ] 2.3 Verify schema uses correct types
    - Ensure model struct uses `fwtypes.String` (NOT `types.String`)
    - Ensure schema uses `fwtypes.StringType` for ElementType where needed
    - Verify `timeout` uses `types.Int64` (framework type is correct for primitives)
    - Verify region handling uses `framework.WithRegionModel`
    - _Requirements: 1.1, 2.1, 7.1_

- [ ] 3. Implement table validation helper
  - [ ] 3.1 Create validateTable() helper function
    - Call DescribeTable API to verify table exists
    - Check table status is ACTIVE (not DELETING, CREATING, etc.)
    - Return clear error messages for table not found or invalid status
    - Handle ResourceNotFoundException with user-friendly message
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 7.5_
  
  - [ ] 3.2 Add error handling for table validation
    - Map TableNotFoundException to clear error message with region
    - Handle table in non-ACTIVE status with appropriate message
    - Include table name and region in all error messages
    - _Requirements: 3.2, 3.3, 6.1, 6.6_

- [ ] 4. Implement core Invoke() method structure
  - [ ] 4.1 Set up Invoke() method skeleton
    - Parse configuration from request into model struct
    - Get DynamoDB client for configured region
    - Add initial progress message "Starting backup creation"
    - Set up context with timeout from configuration
    - _Requirements: 1.1, 4.1, 4.2, 4.5, 5.1, 7.2, 7.3_
  
  - [ ] 4.2 Add configuration parsing and validation
    - Extract table_name, backup_name, timeout, and region from config
    - Validate backup_name format matches pattern `[a-zA-Z0-9_.-]+`
    - Validate backup_name length (3-255 characters)
    - Create timeout context from configured value
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 4.2, 4.5_

- [ ] 5. Implement CreateBackup API call
  - [ ] 5.1 Call table validation before backup creation
    - Invoke validateTable() helper with table name
    - Return error immediately if table validation fails
    - _Requirements: 3.1, 3.2, 3.3, 3.4_
  
  - [ ] 5.2 Invoke CreateBackup API
    - Create CreateBackupInput with table_name and backup_name
    - Call conn.CreateBackup() with context
    - Extract BackupArn from response
    - Store BackupArn for status polling
    - _Requirements: 1.1, 1.2, 1.3, 2.5_
  
  - [ ] 5.3 Handle CreateBackup errors
    - Handle TableNotFoundException with clear message including region
    - Handle BackupInUseException with message about conflicting operation
    - Handle TableInUseException with message about table being created/deleted
    - Handle LimitExceededException with message about 500 operation limit
    - Handle ContinuousBackupsUnavailableException
    - Handle InternalServerError with retry logic (up to 3 times)
    - Include table name and backup name in all error messages
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.6_

- [ ] 6. Implement backup status polling with actionwait
  - [ ] 6.1 Set up actionwait.WaitForStatus() call
    - Define fetch function that calls DescribeBackup API
    - Extract BackupStatus from DescribeBackup response
    - Return FetchResult with status and backup description
    - _Requirements: 1.4, 1.5, 5.3_
  
  - [ ] 6.2 Configure actionwait options
    - Set timeout from configuration
    - Set polling interval to 5 seconds (FixedInterval)
    - Define success states: ["AVAILABLE"]
    - Define transitional states: ["CREATING"]
    - Set progress interval to 30 seconds
    - _Requirements: 1.4, 4.1, 4.5, 5.2, 5.3_
  
  - [ ] 6.3 Implement progress sink for status updates
    - Send progress updates every 30 seconds during polling
    - Include current backup status in progress message
    - Include elapsed time in progress message
    - Format elapsed time as rounded seconds
    - _Requirements: 5.2, 5.3, 5.4_
  
  - [ ] 6.4 Handle polling errors
    - Handle BackupNotFoundException with retry (up to 3 times)
    - Handle timeout with error message including current status and ARN
    - Handle context cancellation gracefully
    - Include BackupArn in timeout error for manual inspection
    - _Requirements: 4.5, 6.5_

- [ ] 7. Complete Invoke() method with output
  - Set backup_arn in response data from successful polling result
  - Send final progress message "Backup completed successfully"
  - Return response with populated backup_arn
  - _Requirements: 1.5, 5.4_

- [ ] 8. Implement Metadata() method
  - Return action TypeName as "aws_dynamodb_create_backup"
  - _Requirements: 1.1_

- [ ] 9. Register action in service package
  - Add action to Actions() method in `internal/service/dynamodb/service_package_gen.go`
  - Verify factory function name matches action type
  - Ensure TypeName is correctly set
  - _Requirements: 1.1_

- [ ] 10. Create action documentation
  - [ ] 10.1 Create documentation file
    - Create `website/docs/actions/dynamodb_create_backup.html.markdown`
    - Add front matter with subcategory "DynamoDB" and page title
    - Add description of action purpose
    - _Requirements: 1.1, 2.1_
  
  - [ ] 10.2 Add documentation content
    - Add beta/alpha warning about experimental status
    - Add warning about potential unintended consequences
    - Include link to AWS CreateBackup API documentation
    - Add basic usage example with minimal configuration
    - Add advanced example with all parameters
    - Add trigger-based example with terraform_data and before_destroy
    - Add real-world use case example (pre-destruction backup)
    - _Requirements: 1.1, 2.1, 4.1, 7.1_
  
  - [ ] 10.3 Document arguments and attributes
    - Document table_name (required, string, 1-1024 characters)
    - Document backup_name (required, string, 3-255 characters, pattern)
    - Document timeout (optional, number, default 1800, range 60-7200)
    - Document region (optional, string)
    - Document backup_arn (computed, string, output only)
    - _Requirements: 1.1, 2.1, 2.2, 2.3, 2.4, 4.1, 4.2, 4.3, 4.4, 7.1_
  
  - [ ] 10.4 Add prerequisites and IAM permissions
    - Document required IAM permissions (dynamodb:CreateBackup, dynamodb:DescribeBackup, dynamodb:DescribeTable)
    - Provide example IAM policy JSON
    - Document prerequisites (table must exist and be ACTIVE)
    - Add notes about AWS service limits (500 concurrent operations)
    - _Requirements: 3.3, 6.4_
  
  - [ ] 10.5 Format documentation with terrafmt
    - Run `terrafmt fmt website/docs/actions/dynamodb_create_backup.html.markdown`
    - Verify all Terraform code blocks are properly formatted
    - Fix any terrafmt warnings or errors
    - _Requirements: All_

- [ ] 11. Implement acceptance tests
  - [ ] 11.1 Create basic acceptance test
    - Create TestAccDynamoDBCreateBackupAction_basic test function
    - Set up test table resource with point_in_time_recovery enabled
    - Configure action with table name and backup name
    - Verify backup is created successfully
    - Check backup_arn is populated in output
    - **Note**: Point-in-time recovery must be enabled on tables for on-demand backups
    - _Requirements: 1.1, 1.2, 1.3, 1.5_
  
  - [ ] 11.2 Create custom backup name test
    - Create TestAccDynamoDBCreateBackupAction_customName test
    - Test with user-specified backup name
    - Verify backup uses the specified name
    - Include point_in_time_recovery in table configuration
    - _Requirements: 2.1, 2.5_
  
  - [ ] 11.3 Create timeout configuration test
    - Create TestAccDynamoDBCreateBackupAction_timeout test
    - Test with custom timeout value (e.g., 600 seconds)
    - Verify action respects timeout configuration
    - Include point_in_time_recovery in table configuration
    - _Requirements: 4.1, 4.2_
  
  - [ ] 11.4 Create error handling tests
    - Create TestAccDynamoDBCreateBackupAction_tableNotFound test for non-existent table
    - Update error pattern to match actual error format: `(?s)Table Validation Failed.*does not exist`
    - Verify error messages are clear and actionable
    - **Note**: Removed duplicateName test - not applicable for lifecycle-triggered actions
    - _Requirements: 3.2, 6.2, 6.3_
  
  - [ ] 11.5 Create trigger-based test
    - **SKIPPED**: before_destroy event not supported in Terraform 1.14.0
    - Only before_create, after_create, before_update, and after_update are supported
    - Test commented out with explanation for future reference
    - _Requirements: 1.1_
  
  - [ ] 11.6 Create regional configuration test
    - Create TestAccDynamoDBCreateBackupAction_region test
    - Test with explicit region parameter using alternate region
    - Use ConfigMultipleRegionProvider(2) for multi-region setup
    - Create table in alternate region with awsalternate provider
    - Verify backup is created in specified region
    - Include point_in_time_recovery in table configuration
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 12. Implement sweep function for test cleanup
  - [ ] 12.1 Add sweepBackups function to sweep.go
    - List all tables in region
    - For each table, list backups
    - Filter for test backups (prefix "terraform-backup-tf-acc-test" or "tf-acc-test")
    - Delete test backups using DeleteBackup API
    - Handle errors gracefully and continue with remaining backups
    - Return aggregated errors
    - _Requirements: All test requirements_
  
  - [ ] 12.2 Register sweep function
    - Add sweeper registration in init() function
    - Set sweeper name to "aws_dynamodb_backup"
    - Configure sweeper to run for DynamoDB service
    - _Requirements: All test requirements_

- [ ] 13. Create changelog entry
  - Create `.changelog/dynamodb-create-backup-action.txt`
  - Use format: `release-note:new-action`
  - Add description: "action/aws_dynamodb_create_backup: New action for creating on-demand backups of DynamoDB tables"
  - _Requirements: 1.1_

- [ ] 14. Pre-submission validation
  - [ ] 14.1 Run compilation checks
    - Run `go build -o /dev/null .`
    - Run `go build -o /dev/null ./internal/service/dynamodb`
    - Run `go test -c -o /dev/null ./internal/service/dynamodb`
    - Fix any compilation errors
    - _Requirements: All_
  
  - [ ] 14.2 Run code formatting
    - Run `make fmt`
    - Verify all Go code is properly formatted
    - _Requirements: All_
  
  - [ ] 14.3 Run linting
    - Run `make golangci-lint PKG=dynamodb`
    - Run `make provider-lint`
    - Fix any linting errors or warnings
    - _Requirements: All_
  
  - [ ] 14.4 Verify documentation formatting
    - Run `terrafmt fmt website/docs/actions/dynamodb_create_backup.html.markdown`
    - Run `terrafmt diff website/docs/actions/dynamodb_create_backup.html.markdown`
    - Ensure no formatting differences
    - _Requirements: All_
  
  - [ ] 14.5 Run tests without TF_ACC
    - Run `go test ./internal/service/dynamodb -run TestAccDynamoDBCreateBackupAction_ -v`
    - Verify all tests are skipped (not run without TF_ACC=1)
    - _Requirements: All test requirements_
  
  - [ ] 14.6 Run acceptance tests
    - Run `TF_ACC=1 go test ./internal/service/dynamodb -run TestAccDynamoDBCreateBackupAction_ -v -timeout 30m`
    - Verify all tests pass
    - Fix any test failures
    - _Requirements: All test requirements_
  
  - [ ] 14.7 Run sweep to clean up test resources
    - Run `TF_ACC=1 go test ./internal/service/dynamodb -sweep=us-west-2 -v`
    - Verify test backups are cleaned up
    - _Requirements: All test requirements_
  
  - [ ] 14.8 Run diagnostics
    - Use getDiagnostics tool on action and test files
    - Fix any type errors, warnings, or issues
    - _Requirements: All_

## Pre-Submission Checklist

Before submitting the implementation, verify:

- [ ] Code compiles: `go build -o /dev/null .`
- [ ] Tests compile: `go test -c -o /dev/null ./internal/service/dynamodb`
- [ ] Tests run (skip): `go test ./internal/service/dynamodb -run TestAccDynamoDBCreateBackupAction_`
- [ ] Code formatted: `make fmt`
- [ ] Documentation formatted: `terrafmt fmt website/docs/actions/dynamodb_create_backup.html.markdown`
- [ ] Changelog entry created: `.changelog/dynamodb-create-backup-action.txt`
- [ ] Schema uses correct types (fwtypes.String, not types.String)
- [ ] All List/Map attributes have ElementType (if applicable)
- [ ] Progress updates implemented for long operations
- [ ] Error messages include context and resource identifiers
- [ ] Documentation includes multiple examples
- [ ] Documentation includes prerequisites and IAM permissions
- [ ] Sweep function implemented for test cleanup
- [ ] Action registered in service_package_gen.go
- [ ] All acceptance tests pass with TF_ACC=1

## Common Pitfalls to Avoid

### Schema Issues (Most Common)
- ❌ Don't use `types.String` from plugin-framework in model structs - use `fwtypes.String`
- ❌ Don't forget `ElementType` on List/Map attributes
- ❌ Don't mix Optional without Computed when using defaults
- ❌ Don't manually add region to schema - use `framework.WithRegionModel`
- ❌ Don't forget to import validators when using them

### Runtime Issues
- ❌ Don't block indefinitely - always respect timeouts
- ❌ Don't ignore partial failures in batch operations (N/A for this action)
- ❌ Don't assume resources exist - validate first
- ❌ Don't forget to update progress for long operations
- ❌ Don't hardcode timeouts - make them configurable
- ❌ Don't skip error context - include resource identifiers

### Documentation Issues
- ❌ Don't skip terrafmt linting - run it before submitting
- ❌ Don't forget the beta/alpha warning notice
- ❌ Don't omit real-world usage examples
- ❌ Don't forget to include prerequisites section

## Reference Documentation

- **Steering Doc**: `.kiro/steering/actions.md` - Complete implementation guidance
- **AWS API Docs**: 
  - CreateBackup: https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_CreateBackup.html
  - DescribeBackup: https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_DescribeBackup.html
- **Example Spec**: `.kiro/specs/aws_dynamodb_create_backup/` - This spec (reference for future actions)
- **Code Examples** (async job submission pattern):
  - `internal/service/codebuild/start_build_action.go`
  - `internal/service/transcribe/start_transcription_job_action.go`
  - `internal/service/bedrockagent/agent_prepare_action.go`
- **Documentation Examples**:
  - `website/docs/actions/codebuild_start_build.html.markdown`
  - `website/docs/actions/transcribe_start_transcription_job.html.markdown`

## Implementation Notes

1. **Polling Pattern**: This action uses the `actionwait` package for consistent polling behavior. See steering doc section on "Polling and Waiting" for complete pattern.

2. **Error Handling**: All AWS errors must be mapped to user-friendly messages with context. See steering doc section on "Error Handling" for complete list.

3. **Progress Reporting**: Progress updates should be sent every 30 seconds during polling. See steering doc section on "Progress Reporting" for requirements.

4. **Testing**: Acceptance tests must cover basic operation, error cases, and trigger-based invocation. See steering doc section on "Testing Actions" for patterns.

5. **Documentation**: Must include beta warning, multiple examples, IAM permissions, and prerequisites. See steering doc section on "Documentation Standards" for requirements.

## Key Implementation Findings

### DynamoDB Prerequisites
- **Point-in-Time Recovery Required**: DynamoDB tables MUST have point-in-time recovery (continuous backups) enabled before on-demand backups can be created
- All test tables must include:
  ```hcl
  point_in_time_recovery {
    enabled = true
  }
  ```
- Without this, CreateBackup API returns `ContinuousBackupsUnavailableException`

### Terraform 1.14.0 Action Limitations
- **Supported Events**: Only `before_create`, `after_create`, `before_update`, `after_update`
- **Not Supported**: `before_destroy` and `after_destroy` events are NOT available
- Tests using unsupported events will fail with: "Invalid event value before_destroy"

### Test Pattern Insights
- **Duplicate Name Test**: Not applicable for lifecycle-triggered actions
  - Actions trigger on lifecycle events, not on config reapplication
  - Applying the same config twice doesn't trigger the action again
  - Duplicate backup errors only occur with simultaneous operations (not testable)
  
- **Multi-Region Testing**: Use `ConfigMultipleRegionProvider(2)` and `ProtoV5FactoriesMultipleRegions(ctx, t, 2)`
  - Create resources in alternate region using `provider = awsalternate`
  - Action can specify explicit region parameter to create backup in different region than provider default

### Error Pattern Matching
- Use `(?s)` flag for multi-line error messages: `regexache.MustCompile(\`(?s)Table Validation Failed.*does not exist\`)`
- Terraform wraps action errors with additional context, so patterns must be flexible

### Test Execution
- Use `/tmp/terraform` binary for Terraform 1.14.0-rc2 support
- Set environment variables:
  ```bash
  export TF_ACC=1
  export TF_ACC_TERRAFORM_PATH=/tmp/terraform
  ```
- All 5 active tests pass in ~133 seconds
