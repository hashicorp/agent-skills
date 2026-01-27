---
name: aws-ami-builder
description: Build Amazon Machine Images (AMIs) with Packer using the amazon-ebs builder. Use when creating custom AMIs for EC2 instances.
---

# AWS AMI Builder

Build Amazon Machine Images (AMIs) using Packer's `amazon-ebs` builder.

**Reference:** [Amazon EBS Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/amazon/latest/components/builder/ebs)

## Basic AMI Template

```hcl
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.3"
    }
  }
}

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "ami_name" {
  type    = string
  default = "my-application"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  region        = var.region
  instance_type = "t3.micro"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ssh_username = "ubuntu"
  ami_name     = "${var.ami_name}-${local.timestamp}"

  tags = {
    Name        = var.ami_name
    Environment = "production"
    OS          = "Ubuntu 22.04"
    BuildDate   = local.timestamp
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
    ]
  }
}
```

## Common Source AMI Filters

### Ubuntu 22.04 LTS
```hcl
source_ami_filter {
  filters = {
    name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"] # Canonical
}
```

### Amazon Linux 2023
```hcl
source_ami_filter {
  filters = {
    name                = "al2023-ami-*-x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
}
```

### Red Hat Enterprise Linux 9
```hcl
source_ami_filter {
  filters = {
    name                = "RHEL-9*_HVM-*-x86_64-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["309956199498"] # Red Hat
}
```

## Multi-Region AMI

Build and copy AMI to multiple regions:

```hcl
source "amazon-ebs" "ubuntu" {
  region        = "us-west-2"
  instance_type = "t3.micro"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"
  ami_name     = "${var.ami_name}-${local.timestamp}"

  # Copy to additional regions
  ami_regions = [
    "us-east-1",
    "us-east-2",
    "eu-west-1"
  ]

  tags = {
    Name = var.ami_name
  }
}
```

## EBS Volume Configuration

Customize root and additional volumes:

```hcl
source "amazon-ebs" "ubuntu" {
  region        = "us-west-2"
  instance_type = "t3.micro"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"
  ami_name     = "${var.ami_name}-${local.timestamp}"

  # Root volume configuration
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 20
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
    encrypted   = true
    delete_on_termination = true
  }

  # Additional data volume
  launch_block_device_mappings {
    device_name = "/dev/sdf"
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
    delete_on_termination = true
  }
}
```

## Authentication

Packer uses standard AWS credential resolution:

1. Environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
2. AWS credentials file: `~/.aws/credentials`
3. IAM instance profile (when running on EC2)

```bash
# Using environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-west-2"

packer build .
```

## IAM Permissions Required

Minimum IAM policy for building AMIs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

## Tagging Strategy

```hcl
source "amazon-ebs" "ubuntu" {
  # ... other configuration ...

  tags = {
    Name        = var.ami_name
    Environment = var.environment
    OS          = "Ubuntu 22.04"
    Application = "web-server"
    Team        = "platform"
    BuildDate   = local.timestamp
    GitCommit   = var.git_commit
  }

  # Tags for snapshots
  snapshot_tags = {
    Name        = "${var.ami_name}-snapshot"
    Environment = var.environment
  }

  # Share AMI with other accounts
  ami_users = ["123456789012", "234567890123"]
}
```

## Build Commands

```bash
# Initialize plugins
packer init .

# Validate template
packer validate .

# Build AMI
packer build .

# Build with variables
packer build -var "region=us-east-1" -var "ami_name=my-app" .

# Debug mode
packer build -debug .
```

## Common Issues

**SSH Timeout**
- Ensure security group allows SSH (port 22) from Packer's IP
- Verify subnet has internet access or VPC endpoint for SSM

**AMI Already Exists**
- AMI names must be unique
- Use timestamp in name: `${var.ami_name}-${local.timestamp}`
- Or use `force_deregister = true` to replace existing AMI

**Volume Size Too Small**
- Source AMI requires minimum volume size
- Check source AMI's volume size and set `volume_size` accordingly

## References

- [Amazon EBS Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/amazon/latest/components/builder/ebs)
- [AWS AMI Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
