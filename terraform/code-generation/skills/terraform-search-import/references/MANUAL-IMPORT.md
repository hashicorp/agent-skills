# Manual Terraform Import Reference

Use this workflow when your target resource type isn't supported by Terraform Search.

## 1. Discover Resources Using Provider CLI

AWS CLI examples:

```bash
# RDS instances (not yet supported by Terraform Search)
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'

# DynamoDB tables (not yet supported by Terraform Search)
aws dynamodb list-tables --query 'TableNames[]'

# API Gateway REST APIs (not yet supported by Terraform Search)
aws apigateway get-rest-apis --query 'items[].id'

# SNS topics (not yet supported by Terraform Search)
aws sns list-topics --query 'Topics[].TopicArn'
```

## 2. Create Resource Blocks Manually

```hcl
# Example for RDS instance
resource "aws_db_instance" "existing_db" {
  identifier = "my-existing-db"
  # Add other required attributes
}

# Example for DynamoDB table
resource "aws_dynamodb_table" "existing_table" {
  name = "my-existing-table"
  # Add other required attributes
}

# Example for SNS topic
resource "aws_sns_topic" "existing_topic" {
  name = "my-existing-topic"
}
```

## 3. Create Import Blocks (Config-Driven Import)

```hcl
# Example for RDS instance
resource "aws_db_instance" "existing_db" {
  identifier = "my-existing-db"
  # Add other required attributes
}

import {
  to = aws_db_instance.existing_db
  id = "my-existing-db"
}

# Example for DynamoDB table
resource "aws_dynamodb_table" "existing_table" {
  name = "my-existing-table"
  # Add other required attributes
}

import {
  to = aws_dynamodb_table.existing_table
  id = "my-existing-table"
}
```

## 4. Run Import Plan

```bash
# Plan the import to see what will happen
terraform plan

# Apply to import the resources
terraform apply
```

## Bulk Import Script Example

For multiple resources of the same type:

```bash
#!/bin/bash
# bulk-import-dynamodb.sh

# Get all table names
tables=$(aws dynamodb list-tables --query 'TableNames[]' --output text)

# Generate import configuration
cat > dynamodb-imports.tf << 'EOF'
# DynamoDB Table Resources and Imports
EOF

for table in $tables; do
  # Create resource and import blocks
  cat >> dynamodb-imports.tf << EOF
resource "aws_dynamodb_table" "table_${table//[-.]/_}" {
  name = "$table"
}

import {
  to = aws_dynamodb_table.table_${table//[-.]/_}
  id = "$table"
}

EOF
done

echo "Generated dynamodb-imports.tf with import blocks"
echo "Run 'terraform plan' to review, then 'terraform apply' to import"
```
