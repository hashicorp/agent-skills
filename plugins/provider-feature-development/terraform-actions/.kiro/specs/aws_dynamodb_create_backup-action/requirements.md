# Requirements Document: AWS DynamoDB Create Backup Action

## Introduction

The AWS DynamoDB Create Backup Action enables users to imperatively create on-demand backups of DynamoDB tables through Terraform. This action integrates with the AWS DynamoDB service to initiate backup operations and monitor their completion, providing real-time progress updates during the backup process. The action follows the async job submission pattern, where a backup request is submitted to AWS, and the action waits for the backup to reach a completed state before returning.

## Glossary

- **Action**: A Terraform Plugin Framework construct that enables imperative operations to be executed at specific lifecycle events (before/after create, update, destroy)
- **DynamoDB_Service**: The AWS DynamoDB service implementation within the Terraform AWS Provider
- **Backup_Operation**: The AWS DynamoDB CreateBackup API operation that initiates an on-demand backup of a table
- **Backup_Status**: The current state of a backup operation, including values such as CREATING, AVAILABLE, or DELETED
- **Table_ARN**: Amazon Resource Name uniquely identifying a DynamoDB table in the format `arn:aws:dynamodb:region:account-id:table/table-name`
- **Backup_ARN**: Amazon Resource Name uniquely identifying a DynamoDB backup in the format `arn:aws:dynamodb:region:account-id:table/table-name/backup/backup-name`
- **Acceptance_Test**: Integration tests that run against real AWS infrastructure to verify action behavior
- **Progress_Reporting**: Real-time status updates provided to users during long-running operations
- **Polling_Mechanism**: The process of repeatedly checking the status of an asynchronous operation until completion
- **Timeout_Configuration**: User-configurable time limit for how long the action will wait for an operation to complete
- **actionwait_Package**: Internal utility package for implementing polling and waiting logic with progress reporting
- **Sweep_Function**: Test cleanup function that removes test resources created during acceptance testing

## Requirements

### Requirement 1: Basic Backup Creation

**User Story:** As a Terraform user, I want to create an on-demand backup of a DynamoDB table, so that I can preserve table data at a specific point in time.

#### Acceptance Criteria

1. WHEN the Action receives a valid table name, THE DynamoDB_Create_Backup_Action SHALL invoke the AWS DynamoDB CreateBackup API with the specified table name
2. WHEN the CreateBackup API returns successfully, THE DynamoDB_Create_Backup_Action SHALL extract the Backup_ARN from the response
3. WHEN the backup creation is initiated, THE DynamoDB_Create_Backup_Action SHALL store the Backup_ARN for subsequent status polling
4. WHILE the Backup_Status is CREATING, THE DynamoDB_Create_Backup_Action SHALL continue polling the backup status at regular intervals
5. WHEN the Backup_Status transitions to AVAILABLE, THE DynamoDB_Create_Backup_Action SHALL complete successfully and return the Backup_ARN

### Requirement 2: Backup Naming and Identification

**User Story:** As a Terraform user, I want to specify a name for my backup, so that I can easily identify and manage backups in the AWS console.

#### Acceptance Criteria

1. THE DynamoDB_Create_Backup_Action SHALL require a backup_name parameter as mandatory input
2. WHEN the Action receives a backup name parameter, THE DynamoDB_Create_Backup_Action SHALL validate that the name contains only alphanumeric characters, hyphens, underscores, and periods matching the pattern `[a-zA-Z0-9_.-]+`
3. WHEN the backup name is less than 3 characters, THE DynamoDB_Create_Backup_Action SHALL return a validation error with a message indicating the minimum length
4. WHEN the backup name exceeds 255 characters, THE DynamoDB_Create_Backup_Action SHALL return a validation error with a message indicating the maximum length
5. WHEN the backup is created, THE DynamoDB_Create_Backup_Action SHALL use the validated name in the CreateBackup API call

### Requirement 3: Table Validation

**User Story:** As a Terraform user, I want the action to validate that the specified table exists before attempting backup creation, so that I receive clear error messages for invalid configurations.

#### Acceptance Criteria

1. WHEN the Action receives a table name, THE DynamoDB_Create_Backup_Action SHALL invoke the AWS DynamoDB DescribeTable API to verify table existence
2. IF the DescribeTable API returns a ResourceNotFoundException, THEN THE DynamoDB_Create_Backup_Action SHALL return an error with a message indicating the table was not found
3. WHEN the table exists but is in DELETING status, THE DynamoDB_Create_Backup_Action SHALL return an error indicating the table is not in a valid state for backup
4. WHEN the table exists and is in ACTIVE status, THE DynamoDB_Create_Backup_Action SHALL proceed with backup creation

**Note**: DynamoDB tables must have point-in-time recovery (continuous backups) enabled before on-demand backups can be created. If point-in-time recovery is not enabled, the CreateBackup API will return a `ContinuousBackupsUnavailableException`. This is an AWS service requirement, not a validation performed by the action.

### Requirement 4: Timeout Configuration

**User Story:** As a Terraform user, I want to configure how long the action waits for backup completion, so that I can balance between operation time and reliability based on my table size.

#### Acceptance Criteria

1. THE DynamoDB_Create_Backup_Action SHALL accept a timeout parameter specified in seconds
2. WHEN no timeout is specified, THE DynamoDB_Create_Backup_Action SHALL use a default timeout of 1800 seconds (30 minutes)
3. WHEN the timeout value is less than 60 seconds, THE DynamoDB_Create_Backup_Action SHALL return a validation error indicating the minimum timeout value
4. WHEN the timeout value exceeds 7200 seconds, THE DynamoDB_Create_Backup_Action SHALL return a validation error indicating the maximum timeout value
5. WHEN the elapsed time exceeds the configured timeout, THE DynamoDB_Create_Backup_Action SHALL cancel the polling operation and return a timeout error with the current Backup_Status

### Requirement 5: Progress Reporting

**User Story:** As a Terraform user, I want to see real-time progress updates during backup creation, so that I know the operation is proceeding and can estimate completion time.

#### Acceptance Criteria

1. WHEN the backup creation is initiated, THE DynamoDB_Create_Backup_Action SHALL send a progress message indicating "Starting backup creation"
2. WHILE polling for backup completion, THE DynamoDB_Create_Backup_Action SHALL send progress updates every 30 seconds
3. WHEN sending progress updates, THE DynamoDB_Create_Backup_Action SHALL include the current Backup_Status and elapsed time in the message
4. WHEN the backup reaches AVAILABLE status, THE DynamoDB_Create_Backup_Action SHALL send a final progress message indicating "Backup completed successfully"
5. WHEN an error occurs, THE DynamoDB_Create_Backup_Action SHALL send a progress message indicating the error before returning

### Requirement 6: Error Handling

**User Story:** As a Terraform user, I want to receive clear and actionable error messages when backup creation fails, so that I can diagnose and resolve issues quickly.

#### Acceptance Criteria

1. WHEN the CreateBackup API returns a TableNotFoundException, THE DynamoDB_Create_Backup_Action SHALL return an error message indicating the specified table does not exist in the region
2. WHEN the CreateBackup API returns a BackupInUseException, THE DynamoDB_Create_Backup_Action SHALL return an error message indicating there is another ongoing conflicting backup operation
3. WHEN the CreateBackup API returns a TableInUseException, THE DynamoDB_Create_Backup_Action SHALL return an error message indicating the table is being created or deleted
4. WHEN the CreateBackup API returns a LimitExceededException, THE DynamoDB_Create_Backup_Action SHALL return an error message indicating the account limit of 500 simultaneous table operations has been exceeded
5. WHEN the DescribeBackup API returns a BackupNotFoundException during polling, THE DynamoDB_Create_Backup_Action SHALL retry up to 3 times before returning an error
6. WHEN any AWS API call fails with an authentication or authorization error, THE DynamoDB_Create_Backup_Action SHALL return an error message indicating insufficient IAM permissions and listing the required permissions

### Requirement 7: Regional Configuration

**User Story:** As a Terraform user, I want to specify which AWS region to create the backup in, so that I can manage backups in the same region as my tables or in different regions for disaster recovery.

#### Acceptance Criteria

1. THE DynamoDB_Create_Backup_Action SHALL accept an optional region parameter
2. WHEN no region is specified, THE DynamoDB_Create_Backup_Action SHALL use the provider's default region configuration
3. WHEN a region is specified, THE DynamoDB_Create_Backup_Action SHALL create the AWS DynamoDB client for the specified region
4. WHEN the specified region is invalid, THE DynamoDB_Create_Backup_Action SHALL return a validation error indicating the region format is incorrect
5. WHEN the table does not exist in the specified region, THE DynamoDB_Create_Backup_Action SHALL return an error indicating the table was not found in that region
