# Manual Terraform Import Reference

Use this workflow when your target resource type isn't supported by Terraform Search.

## 1. Discover Resources Using Provider CLI

### AWS Examples
```bash
# S3 buckets
aws s3api list-buckets --query 'Buckets[].Name' --output table

# RDS instances  
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'

# VPCs
aws ec2 describe-vpcs --query 'Vpcs[].VpcId'

# Lambda functions
aws lambda list-functions --query 'Functions[].FunctionName'
```

### Azure Examples
```bash
# Storage accounts
az storage account list --query '[].name' --output table

# Virtual machines
az vm list --query '[].name' --output table
```

### GCP Examples
```bash
# Storage buckets
gcloud storage buckets list --format="value(name)"

# Compute instances
gcloud compute instances list --format="value(name)"
```

## 2. Create Resource Blocks Manually

```hcl
# Example for S3 bucket
resource "aws_s3_bucket" "existing_bucket" {
  bucket = "my-existing-bucket-name"
}

# Example for RDS instance
resource "aws_db_instance" "existing_db" {
  identifier = "my-existing-db"
  # Add other required attributes
}
```

## 3. Create Import Blocks (Config-Driven Import)

```hcl
# Example for S3 bucket
resource "aws_s3_bucket" "existing_bucket" {
  bucket = "my-existing-bucket-name"
}

import {
  to = aws_s3_bucket.existing_bucket
  id = "my-existing-bucket-name"
}

# Example for RDS instance
resource "aws_db_instance" "existing_db" {
  identifier = "my-existing-db"
  # Add other required attributes
}

import {
  to = aws_db_instance.existing_db
  id = "my-existing-db"
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
# bulk-import-s3.sh

# Get all bucket names
buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)

# Generate import configuration
cat > s3-imports.tf << 'EOF'
# S3 Bucket Resources and Imports
EOF

for bucket in $buckets; do
  # Create resource and import blocks
  cat >> s3-imports.tf << EOF
resource "aws_s3_bucket" "bucket_${bucket//[-.]/_}" {
  bucket = "$bucket"
}

import {
  to = aws_s3_bucket.bucket_${bucket//[-.]/_}
  id = "$bucket"
}

EOF
done

echo "Generated s3-imports.tf with import blocks"
echo "Run 'terraform plan' to review, then 'terraform apply' to import"
```
