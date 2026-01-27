---
name: push-to-registry
description: Push Packer build metadata to HCP Packer registry for tracking and managing image lifecycle. Use when integrating Packer builds with HCP Packer for version control and governance.
---

# Push to HCP Packer Registry

Configure Packer templates to push build metadata to HCP Packer registry.

**Reference:** [HCP Packer Registry](https://developer.hashicorp.com/hcp/docs/packer)

## Basic Registry Configuration

```hcl
packer {
  required_version = ">= 1.7.7"
}

variable "image_name" {
  type    = string
  default = "web-server"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

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
  ami_name     = "${var.image_name}-${local.timestamp}"
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  # HCP Packer Registry configuration
  hcp_packer_registry {
    bucket_name = var.image_name
    description = "Ubuntu 22.04 base image for web servers"

    bucket_labels = {
      "os"          = "ubuntu"
      "version"     = "22.04"
      "team"        = "platform"
      "environment" = "production"
    }

    build_labels = {
      "build-time"     = local.timestamp
      "packer-version" = packer.version
    }
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
    ]
  }
}
```

## Authentication

Set environment variables before building:

```bash
export HCP_CLIENT_ID="your-service-principal-client-id"
export HCP_CLIENT_SECRET="your-service-principal-secret"
export HCP_ORGANIZATION_ID="your-org-id"
export HCP_PROJECT_ID="your-project-id"

packer build .
```

### Create HCP Service Principal

```bash
# Using HCP Portal:
# 1. Navigate to HCP → Access Control (IAM)
# 2. Create Service Principal
# 3. Grant "Contributor" role on project
# 4. Generate client secret
# 5. Save client ID and secret
```

## Registry Configuration Options

### bucket_name (required)
The image identifier in HCP Packer. Must remain constant across builds.

```hcl
hcp_packer_registry {
  bucket_name = "web-server"  # Stay consistent!
}
```

### description (optional)
Appears on the bucket's main page. Updates with each build.

```hcl
hcp_packer_registry {
  bucket_name = "web-server"
  description = <<-EOT
    Production web server image:
    - Ubuntu 22.04 LTS
    - Nginx 1.24
    - Application v${var.app_version}
  EOT
}
```

### bucket_labels (optional)
Metadata displayed at the bucket level. Updates with each build.

```hcl
hcp_packer_registry {
  bucket_name = "web-server"

  bucket_labels = {
    "os"           = "ubuntu"
    "os-version"   = "22.04"
    "team"         = "platform"
    "component"    = "web-tier"
    "compliance"   = "pci-dss"
  }
}
```

### build_labels (optional)
Metadata for each iteration (build). Immutable after build completes.

```hcl
hcp_packer_registry {
  bucket_name = "web-server"

  build_labels = {
    "build-time"     = local.timestamp
    "packer-version" = packer.version
    "git-commit"     = var.git_commit
    "git-branch"     = var.git_branch
    "build-number"   = var.build_number
  }
}
```

## Multi-Cloud Builds

Single iteration with artifacts across clouds:

```hcl
source "amazon-ebs" "ubuntu" {
  region = "us-west-2"
  # ... AWS configuration
}

source "azure-arm" "ubuntu" {
  location = "East US"
  # ... Azure configuration
}

source "googlecompute" "ubuntu" {
  zone = "us-central1-a"
  # ... GCP configuration
}

build {
  sources = [
    "source.amazon-ebs.ubuntu",
    "source.azure-arm.ubuntu",
    "source.googlecompute.ubuntu"
  ]

  # Single bucket with artifacts from all clouds
  hcp_packer_registry {
    bucket_name = "multi-cloud-web-server"
    description = "Web server image available on AWS, Azure, and GCP"
  }
}
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Build and Push to HCP Packer

on:
  push:
    branches: [main]

env:
  HCP_CLIENT_ID: ${{ secrets.HCP_CLIENT_ID }}
  HCP_CLIENT_SECRET: ${{ secrets.HCP_CLIENT_SECRET }}
  HCP_ORGANIZATION_ID: ${{ secrets.HCP_ORGANIZATION_ID }}
  HCP_PROJECT_ID: ${{ secrets.HCP_PROJECT_ID }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Packer
        uses: hashicorp/setup-packer@main

      - name: Initialize Packer
        run: packer init .

      - name: Build and push to HCP Packer
        run: |
          packer build \
            -var "git_commit=${{ github.sha }}" \
            -var "git_branch=${{ github.ref_name }}" \
            -var "build_number=${{ github.run_number }}" \
            .
```

### GitLab CI

```yaml
build-image:
  image: hashicorp/packer:latest
  variables:
    HCP_CLIENT_ID: $HCP_CLIENT_ID
    HCP_CLIENT_SECRET: $HCP_CLIENT_SECRET
    HCP_ORGANIZATION_ID: $HCP_ORGANIZATION_ID
    HCP_PROJECT_ID: $HCP_PROJECT_ID
  script:
    - packer init .
    - packer build -var "git_commit=$CI_COMMIT_SHA" .
  only:
    - main
```

## Using Variables for Metadata

```hcl
variable "git_commit" {
  type        = string
  description = "Git commit SHA"
  default     = "unknown"
}

variable "build_number" {
  type        = string
  description = "CI build number"
  default     = "local"
}

variable "app_version" {
  type        = string
  description = "Application version"
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  hcp_packer_registry {
    bucket_name = "web-server"
    description = "Web server v${var.app_version}"

    bucket_labels = {
      "app-version" = var.app_version
    }

    build_labels = {
      "git-commit"   = var.git_commit
      "build-number" = var.build_number
    }
  }
}
```

## Querying HCP Packer in Terraform

After pushing to HCP Packer, reference in Terraform:

```hcl
# Get latest iteration from a channel
data "hcp_packer_artifact" "ubuntu" {
  bucket_name  = "web-server"
  channel_name = "production"
  platform     = "aws"
  region       = "us-west-2"
}

resource "aws_instance" "web" {
  ami           = data.hcp_packer_artifact.ubuntu.external_identifier
  instance_type = "t3.micro"

  tags = {
    PackerBucket    = data.hcp_packer_artifact.ubuntu.bucket_name
    PackerIteration = data.hcp_packer_artifact.ubuntu.iteration_id
    PackerChannel   = "production"
  }
}
```

## Viewing Registry Data

### HCP Portal
1. Navigate to HCP Packer in the HCP Portal
2. Select your bucket (e.g., "web-server")
3. View iterations (builds)
4. See artifacts (AMIs, images) for each iteration

### HCP CLI

```bash
# Install HCP CLI
brew install hashicorp/tap/hcp

# Authenticate
hcp auth login

# List buckets
hcp packer bucket list

# View bucket details
hcp packer bucket read web-server

# List iterations
hcp packer iteration list --bucket web-server
```

## Common Issues

### Authentication Failed
**Problem:** `Error: unable to authenticate to HCP`

**Solutions:**
- Verify environment variables are set correctly
- Ensure service principal has "Contributor" role on project
- Check organization ID and project ID are correct
- Regenerate client secret if expired

### Bucket Name Mismatch
**Problem:** New bucket created instead of adding iteration to existing bucket

**Solution:** Keep `bucket_name` consistent across builds:
```hcl
# Always use the same bucket_name
bucket_name = "web-server"  # ✓ Correct

# Don't include timestamp or version in bucket_name
bucket_name = "web-server-${local.timestamp}"  # ✗ Wrong
```

### Build Fails with Registry Error
**Problem:** Build fails when unable to push to HCP Packer

**Note:** Packer fails immediately to prevent drift between artifacts and registry.

**Solutions:**
- Check network connectivity to HCP API
- Verify HCP service is operational
- Use `HCP_PACKER_BUILD_FINGERPRINT` to retry failed push
- Ensure credentials haven't expired

### Missing Artifacts in Registry
**Problem:** Build succeeded but artifacts not visible in HCP

**Solutions:**
- Verify `hcp_packer_registry` block is in `build` block (not `source`)
- Check build completed successfully (no errors)
- Wait a few moments for registry to update
- Verify you're viewing the correct bucket name

## Best Practices

1. **Consistent Bucket Names** - Never change bucket_name for same image type
2. **Meaningful Labels** - Use labels to track versions, teams, compliance
3. **Immutable Build Labels** - Put changing data (git commit, date) in build_labels
4. **CI/CD Integration** - Automate builds and registry pushes
5. **Document Buckets** - Use description to explain image purpose
6. **Service Principal Scope** - Grant minimal permissions (Contributor on project only)

## References

- [HCP Packer Documentation](https://developer.hashicorp.com/hcp/docs/packer)
- [hcp_packer_registry Block](https://developer.hashicorp.com/packer/docs/templates/hcl_templates/blocks/build/hcp_packer_registry)
- [HCP Packer Terraform Provider](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/data-sources/packer_artifact)
