---
name: windows-builder
description: Build Windows images with Packer using WinRM communicator and PowerShell provisioners. Use when creating Windows AMIs, Azure images, or VMware templates.
---

# Windows Builder

Platform-agnostic patterns for building Windows images with Packer.

**Reference:** [Windows Builders](https://developer.hashicorp.com/packer/guides/windows)

> **Note:** Windows builds incur significant costs and time. Expect 45-120 minutes per build due to Windows Updates. Failed builds may leave resources running - always verify cleanup.

## WinRM Communicator Setup

Windows requires WinRM for Packer communication.

### AWS Example

```hcl
source "amazon-ebs" "windows" {
  region        = "us-west-2"
  instance_type = "t3.medium"

  source_ami_filter {
    filters = {
      name = "Windows_Server-2022-English-Full-Base-*"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  ami_name = "windows-server-2022-${local.timestamp}"

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "15m"

  user_data_file = "scripts/setup-winrm.ps1"
}
```

### WinRM Setup Script (scripts/setup-winrm.ps1)

```powershell
<powershell>
# Configure WinRM
winrm quickconfig -q
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

# Configure firewall
netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow
netsh advfirewall firewall add rule name="WinRM 5986" protocol=TCP dir=in localport=5986 action=allow

# Restart WinRM
net stop winrm
net start winrm
</powershell>
```

### Azure Example

```hcl
source "azure-arm" "windows" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  managed_image_resource_group_name = "images-rg"
  managed_image_name                = "windows-${local.timestamp}"

  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-datacenter-g2"

  location = "East US"
  vm_size  = "Standard_D2s_v3"

  # Azure auto-configures WinRM
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "15m"
  winrm_username = "packer"
}
```

## PowerShell Provisioners

### Install Software

```hcl
build {
  sources = ["source.amazon-ebs.windows"]

  # Install Chocolatey
  provisioner "powershell" {
    inline = [
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    ]
  }

  # Install applications
  provisioner "powershell" {
    inline = [
      "choco install -y googlechrome",
      "choco install -y 7zip",
    ]
  }

  # Install IIS
  provisioner "powershell" {
    inline = [
      "Install-WindowsFeature -Name Web-Server -IncludeManagementTools"
    ]
  }
}
```

### Windows Updates

```hcl
provisioner "powershell" {
  inline = [
    "Install-PackageProvider -Name NuGet -Force",
    "Install-Module -Name PSWindowsUpdate -Force",
    "Import-Module PSWindowsUpdate",
    "Get-WindowsUpdate -Install -AcceptAll -AutoReboot",
  ]
  timeout = "2h"
}

# Wait for reboots
provisioner "windows-restart" {
  restart_timeout = "30m"
}
```

## Cleanup

```hcl
provisioner "powershell" {
  inline = [
    "# Clear temp files",
    "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
    "# Clear Windows Update cache",
    "Stop-Service -Name wuauserv -Force",
    "Remove-Item -Path 'C:\\Windows\\SoftwareDistribution\\*' -Recurse -Force -ErrorAction SilentlyContinue",
    "Start-Service -Name wuauserv",
  ]
}
```

## Common Issues

**WinRM Timeout**
- Increase `winrm_timeout` to 15m or more
- Verify security group allows ports 5985/5986
- Check user data script completed successfully

**PowerShell Execution Policy**
```hcl
provisioner "powershell" {
  inline = [
    "Set-ExecutionPolicy Bypass -Scope Process -Force",
    "# Your commands here",
  ]
}
```

**Long Build Times**
- Windows Updates can take 1-2 hours
- Use pre-patched base images when available
- Set provisioner `timeout = "2h"`

## References

- [Packer Windows Builders](https://developer.hashicorp.com/packer/guides/windows)
- [WinRM Communicator](https://developer.hashicorp.com/packer/docs/communicators/winrm)
- [PowerShell Provisioner](https://developer.hashicorp.com/packer/docs/provisioners/powershell)
