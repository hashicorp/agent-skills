---
name: windows-builder
description: Build Windows images with Packer using WinRM communicator and PowerShell provisioners. Use when creating Windows AMIs, Azure images, or VMware templates.
---

# Windows Builder

Platform-agnostic patterns for building Windows images with Packer.

**Reference:** [Windows Builders](https://developer.hashicorp.com/packer/guides/windows)

## WinRM Communicator Setup

Windows requires WinRM for Packer communication. Use this user data script:

### AWS Example with WinRM

```hcl
source "amazon-ebs" "windows" {
  region        = "us-west-2"
  instance_type = "t3.medium"

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  ami_name = "windows-server-2022-${local.timestamp}"

  # WinRM communicator
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "10m"

  # User data to enable WinRM
  user_data_file = "scripts/setup-winrm.ps1"

  tags = {
    Name = "Windows Server 2022"
    OS   = "Windows"
  }
}
```

### WinRM Setup Script (scripts/setup-winrm.ps1)

```powershell
<powershell>
# Set Administrator password
$admin = [adsi]("WinNT://./administrator, user")
$admin.SetPassword("${var.admin_password}")

# Configure WinRM
winrm quickconfig -q
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

# Configure firewall
netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow
netsh advfirewall firewall add rule name="WinRM 5986" protocol=TCP dir=in localport=5986 action=allow

# Restart WinRM service
net stop winrm
net start winrm
</powershell>
```

## Azure Windows Example

```hcl
source "azure-arm" "windows" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  managed_image_resource_group_name = var.resource_group
  managed_image_name                = "windows-server-2022-${local.timestamp}"

  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-datacenter-g2"

  location = "East US"
  vm_size  = "Standard_D2s_v3"

  # WinRM communicator (Azure handles setup automatically)
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "10m"
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
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    ]
  }

  # Install applications
  provisioner "powershell" {
    inline = [
      "choco install -y googlechrome",
      "choco install -y 7zip",
      "choco install -y git",
    ]
  }

  # Install IIS
  provisioner "powershell" {
    inline = [
      "Install-WindowsFeature -Name Web-Server -IncludeManagementTools",
      "Install-WindowsFeature -Name Web-Asp-Net45",
    ]
  }
}
```

### Run External Scripts

```hcl
build {
  sources = ["source.amazon-ebs.windows"]

  provisioner "powershell" {
    scripts = [
      "scripts/install-dependencies.ps1",
      "scripts/configure-iis.ps1",
      "scripts/harden-security.ps1",
    ]
  }
}
```

### Pass Variables to PowerShell

```hcl
variable "app_version" {
  type = string
}

build {
  sources = ["source.amazon-ebs.windows"]

  provisioner "powershell" {
    environment_vars = [
      "APP_VERSION=${var.app_version}",
      "ENVIRONMENT=production",
    ]
    inline = [
      "Write-Host \"Installing app version: $env:APP_VERSION\"",
      "# Download and install application",
    ]
  }
}
```

## Windows Updates

### Install All Updates

```hcl
build {
  sources = ["source.amazon-ebs.windows"]

  # Install PSWindowsUpdate module
  provisioner "powershell" {
    inline = [
      "Install-PackageProvider -Name NuGet -Force",
      "Install-Module -Name PSWindowsUpdate -Force",
    ]
  }

  # Install Windows updates (can take 30+ minutes)
  provisioner "powershell" {
    inline = [
      "Import-Module PSWindowsUpdate",
      "Get-WindowsUpdate -Install -AcceptAll -AutoReboot",
    ]
    # Allow extra time for updates and reboots
    timeout = "2h"
  }

  # Wait for potential reboots
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }
}
```

### Install Security Updates Only

```hcl
provisioner "powershell" {
  inline = [
    "Import-Module PSWindowsUpdate",
    "Get-WindowsUpdate -Category 'Security Updates' -Install -AcceptAll -AutoReboot",
  ]
  timeout = "1h"
}
```

## File Provisioner for Windows

```hcl
build {
  sources = ["source.amazon-ebs.windows"]

  # Copy files (note Windows path format)
  provisioner "file" {
    source      = "app/"
    destination = "C:\\temp\\app\\"
  }

  # Move to final location with PowerShell
  provisioner "powershell" {
    inline = [
      "Move-Item -Path 'C:\\temp\\app' -Destination 'C:\\Program Files\\MyApp'",
    ]
  }
}
```

## Windows Restart Provisioner

Use when reboots are needed (updates, driver installation):

```hcl
build {
  sources = ["source.amazon-ebs.windows"]

  provisioner "powershell" {
    inline = ["Install-WindowsFeature -Name Web-Server"]
  }

  # Restart and wait for WinRM
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  provisioner "powershell" {
    inline = ["Write-Host 'System restarted successfully'"]
  }
}
```

## Sysprep and Generalization

### AWS (EC2Config/EC2Launch)

AWS AMIs are automatically generalized. Optionally run custom sysprep:

```hcl
build {
  sources = ["source.amazon-ebs.windows"]

  # Your provisioning here...

  # Optional: Custom sysprep (AWS does this automatically)
  provisioner "powershell" {
    inline = [
      "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\InitializeInstance.ps1 -Schedule",
      "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\SysprepInstance.ps1 -NoShutdown",
    ]
  }
}
```

### Azure (waagent/Sysprep)

Azure automatically runs sysprep. No manual generalization needed.

### VMware/Hyper-V (Manual Sysprep)

```hcl
provisioner "powershell" {
  inline = [
    "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /generalize /oobe /shutdown /quiet",
  ]
}
```

## Common Windows Patterns

### Disable Windows Defender (for performance)

```hcl
provisioner "powershell" {
  inline = [
    "Set-MpPreference -DisableRealtimeMonitoring $true",
    "Set-MpPreference -DisableBehaviorMonitoring $true",
    "Set-MpPreference -DisableIOAVProtection $true",
  ]
}
```

### Configure Time Zone

```hcl
provisioner "powershell" {
  inline = [
    "Set-TimeZone -Id 'Eastern Standard Time'",
  ]
}
```

### Disable IE Enhanced Security

```hcl
provisioner "powershell" {
  inline = [
    "$AdminKey = 'HKLM:\\SOFTWARE\\Microsoft\\Active Setup\\Installed Components\\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}'",
    "$UserKey = 'HKLM:\\SOFTWARE\\Microsoft\\Active Setup\\Installed Components\\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}'",
    "Set-ItemProperty -Path $AdminKey -Name 'IsInstalled' -Value 0 -Force",
    "Set-ItemProperty -Path $UserKey -Name 'IsInstalled' -Value 0 -Force",
  ]
}
```

### Clean Up Before Image Creation

```hcl
provisioner "powershell" {
  inline = [
    "# Clear temp files",
    "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
    "Remove-Item -Path 'C:\\Users\\*\\AppData\\Local\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
    "",
    "# Clear Windows Update cache",
    "Stop-Service -Name wuauserv -Force",
    "Remove-Item -Path 'C:\\Windows\\SoftwareDistribution\\*' -Recurse -Force -ErrorAction SilentlyContinue",
    "Start-Service -Name wuauserv",
    "",
    "# Disk cleanup",
    "cleanmgr.exe /sagerun:1",
  ]
}
```

## Common Issues and Solutions

### WinRM Timeout
**Problem:** Packer can't connect via WinRM
**Solutions:**
- Increase `winrm_timeout` to "15m" or more
- Verify security group allows port 5985 (HTTP) or 5986 (HTTPS)
- Check user data script completed (view instance console output)
- Ensure Administrator password was set

### PowerShell Execution Policy
**Problem:** Scripts won't run due to execution policy
**Solution:**
```hcl
provisioner "powershell" {
  inline = [
    "Set-ExecutionPolicy Bypass -Scope Process -Force",
    "# Your commands here",
  ]
}
```

### Long Provisioning Times
**Problem:** Windows updates take too long
**Solutions:**
- Use pre-patched base images when available
- Increase provisioner timeout: `timeout = "2h"`
- Use `windows-restart` provisioner after updates
- Consider separate update image in pipeline

### File Copy Failures
**Problem:** Files not copying to Windows paths
**Solution:** Use Windows path format with escaped backslashes:
```hcl
destination = "C:\\temp\\app\\"  # Correct
destination = "C:/temp/app/"     # May not work
```

### Certificate Errors
**Problem:** SSL/TLS errors during downloads
**Solution:**
```hcl
provisioner "powershell" {
  inline = [
    "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12",
    "# Your download commands",
  ]
}
```

## References

- [Packer Windows Builders](https://developer.hashicorp.com/packer/guides/windows)
- [WinRM Communicator](https://developer.hashicorp.com/packer/docs/communicators/winrm)
- [PowerShell Provisioner](https://developer.hashicorp.com/packer/docs/provisioners/powershell)
- [Windows Restart Provisioner](https://developer.hashicorp.com/packer/docs/provisioners/windows-restart)
