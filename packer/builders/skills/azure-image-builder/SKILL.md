---
name: azure-image-builder
description: Build Azure managed images and Azure Compute Gallery (Shared Image Gallery) images with Packer. Use when creating custom images for Azure VMs.
---

# Azure Image Builder

Build Azure managed images and Azure Compute Gallery images using Packer's `azure-arm` builder.

**Reference:** [Azure ARM Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm)

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

variable "tenant_id" {
  type = string
}

variable "resource_group" {
  type    = string
  default = "packer-images-rg"
}

variable "image_name" {
  type    = string
  default = "my-application"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "azure-arm" "ubuntu" {
  # Authentication
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Managed image output
  managed_image_resource_group_name = var.resource_group
  managed_image_name                = "${var.image_name}-${local.timestamp}"

  # Source image
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  # Build VM configuration
  location = "East US"
  vm_size  = "Standard_B2s"

  azure_tags = {
    Name        = var.image_name
    Environment = "production"
    OS          = "Ubuntu 22.04"
    BuildDate   = local.timestamp
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

## Azure Compute Gallery (Shared Image Gallery)

Publish to Azure Compute Gallery for versioned, replicated images:

```hcl
source "azure-arm" "ubuntu" {
  # Authentication
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Source image
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  # Build VM configuration
  location = "East US"
  vm_size  = "Standard_B2s"

  # Azure Compute Gallery configuration
  shared_image_gallery_destination {
    resource_group       = "gallery-rg"
    gallery_name         = "myImageGallery"
    image_name           = "ubuntu-webapp"
    image_version        = "1.0.${formatdate("YYYYMMDD", timestamp())}"
    replication_regions  = ["East US", "West US 2", "West Europe"]
    storage_account_type = "Standard_LRS"
  }

  # Optional: Also create managed image
  managed_image_resource_group_name = var.resource_group
  managed_image_name                = "${var.image_name}-${local.timestamp}"
}
```

## Common Source Images

### Ubuntu 22.04 LTS
```hcl
os_type         = "Linux"
image_publisher = "Canonical"
image_offer     = "0001-com-ubuntu-server-jammy"
image_sku       = "22_04-lts-gen2"
```

### Red Hat Enterprise Linux 9
```hcl
os_type         = "Linux"
image_publisher = "RedHat"
image_offer     = "RHEL"
image_sku       = "9-lvm-gen2"
```

### Windows Server 2022
```hcl
os_type         = "Windows"
image_publisher = "MicrosoftWindowsServer"
image_offer     = "WindowsServer"
image_sku       = "2022-datacenter-g2"
```

## Authentication Methods

### Service Principal (Recommended)
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
When running Packer on an Azure VM with managed identity:

```hcl
source "azure-arm" "ubuntu" {
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id

  # ... rest of configuration
}
```

## Custom VNet and Subnet

Build in existing VNet (required for private networks):

```hcl
source "azure-arm" "ubuntu" {
  # Authentication
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Source image
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  # Custom networking
  virtual_network_name                = "packer-vnet"
  virtual_network_resource_group_name = "networking-rg"
  virtual_network_subnet_name         = "packer-subnet"
  private_virtual_network_with_public_ip = false

  # Build VM configuration
  location = "East US"
  vm_size  = "Standard_B2s"

  managed_image_resource_group_name = var.resource_group
  managed_image_name                = "${var.image_name}-${local.timestamp}"
}
```

## Azure Compute Gallery Versioning

Use semantic versioning with date stamps:

```hcl
locals {
  # Version format: MAJOR.MINOR.PATCH
  # Example: 1.0.20240115
  image_version = "1.0.${formatdate("YYYYMMDD", timestamp())}"
}

source "azure-arm" "ubuntu" {
  # ... other configuration ...

  shared_image_gallery_destination {
    resource_group      = "gallery-rg"
    gallery_name        = "myImageGallery"
    image_name          = "ubuntu-webapp"
    image_version       = local.image_version
    replication_regions = ["East US", "West US 2"]
  }
}
```

## Required Azure Permissions

Service principal needs these permissions:

```bash
# Contributor role on resource group
az role assignment create \
  --assignee <service-principal-id> \
  --role Contributor \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>

# For Azure Compute Gallery
az role assignment create \
  --assignee <service-principal-id> \
  --role Contributor \
  --scope /subscriptions/<subscription-id>/resourceGroups/<gallery-resource-group>
```

## Generalization

Azure requires VM generalization before creating images:

### Linux (automatic)
```hcl
source "azure-arm" "ubuntu" {
  # ... configuration ...

  # Packer automatically runs: sudo waagent -deprovision+user -force
}
```

### Windows (automatic)
```hcl
source "azure-arm" "windows" {
  # ... configuration ...

  # Packer automatically runs: sysprep with generalize option
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
- Ensure service principal has Contributor role on resource group
- Check subscription ID and tenant ID are correct

**Compute Gallery Image Already Exists**
- Image versions are immutable
- Use unique version numbers (include date/build number)
- Cannot overwrite existing gallery image version

**VNet Not Found**
- Ensure VNet and subnet exist before build
- Verify resource group name is correct
- Check Packer has permissions to VNet resource group

**Timeout During Provisioning**
- Increase `async_resourcegroup_delete = true` for faster cleanup
- Check network connectivity from build VM
- Verify NSG rules allow required traffic

## References

- [Azure ARM Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm)
- [Azure Compute Gallery](https://learn.microsoft.com/en-us/azure/virtual-machines/azure-compute-gallery)
- [Azure Image Builder Service](https://learn.microsoft.com/en-us/azure/virtual-machines/image-builder-overview)
