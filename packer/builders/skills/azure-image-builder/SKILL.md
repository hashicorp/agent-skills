---
name: azure-image-builder
description: Build Azure managed images and Azure Compute Gallery images with Packer. Use when creating custom images for Azure VMs.
---

# Azure Image Builder

Build Azure managed images and Azure Compute Gallery images using Packer's `azure-arm` builder.

**Reference:** [Azure ARM Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm)

> **Note:** Building Azure images incurs costs (compute, storage, data transfer). Builds typically take 15-45 minutes depending on provisioning and OS.

## Basic Managed Image

```hcl
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2.0"
    }
  }
}

variable "client_id" {
  type      = string
  sensitive = true
}

variable "client_secret" {
  type      = string
  sensitive = true
}

variable "subscription_id" {
  type = string
}

variable "resource_group" {
  type    = string
  default = "packer-images-rg"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "azure-arm" "ubuntu" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  managed_image_resource_group_name = var.resource_group
  managed_image_name                = "my-app-${local.timestamp}"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  location = "East US"
  vm_size  = "Standard_B2s"

  azure_tags = {
    Name      = "my-app"
    BuildDate = local.timestamp
  }
}

build {
  sources = ["source.azure-arm.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
    ]
  }
}
```

## Azure Compute Gallery

```hcl
source "azure-arm" "ubuntu" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  location = "East US"
  vm_size  = "Standard_B2s"

  shared_image_gallery_destination {
    resource_group       = "gallery-rg"
    gallery_name         = "myImageGallery"
    image_name           = "ubuntu-webapp"
    image_version        = "1.0.${formatdate("YYYYMMDD", timestamp())}"
    replication_regions  = ["East US", "West US 2"]
    storage_account_type = "Standard_LRS"
  }
}
```

## Authentication

### Service Principal
```bash
# Create service principal
az ad sp create-for-rbac \
  --name "packer-sp" \
  --role Contributor \
  --scopes /subscriptions/<subscription-id>

# Set environment variables
export ARM_CLIENT_ID="<client-id>"
export ARM_CLIENT_SECRET="<client-secret>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"
```

### Managed Identity
```hcl
source "azure-arm" "ubuntu" {
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id
  # ... rest of configuration
}
```

## Build Commands

```bash
# Set authentication
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Initialize plugins
packer init .

# Validate template
packer validate .

# Build image
packer build .
```

## Common Issues

**Authentication Failed**
- Verify service principal credentials
- Ensure Contributor role on resource group
- Check subscription and tenant IDs

**Compute Gallery Version Exists**
- Image versions are immutable
- Use unique version numbers with date/build number
- Cannot overwrite existing versions

**Timeout During Provisioning**
- Check network connectivity from build VM
- Verify NSG rules allow required traffic
- Increase timeout if needed

## References

- [Azure ARM Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm)
- [Azure Compute Gallery](https://learn.microsoft.com/en-us/azure/virtual-machines/azure-compute-gallery)
