terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
    }
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

locals {
  username = data.coder_workspace.me.owner
}

provider "aws" {
  region = var.aws_region
}

data "coder_workspace" "me" {
}

data "aws_ami" "windows" {
  most_recent = true
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["801119661308"] # Amazon
}

resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "windows"
  startup_script = <<-EOT
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    # Install development tools
    choco install -y git vscode awscli nodejs-lts python
    
    # Configure DCV
    $DcvPort = 8443
    netsh advfirewall firewall add rule name="DCV Server" dir=in action=allow protocol=TCP localport=$DcvPort
  EOT

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display this information.
  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select -ExpandProperty Average"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "ram"
    script       = <<-EOT
      $ComputerMemory = Get-WmiObject -Class win32_operatingsystem
      $Memory = ((($ComputerMemory.TotalVisibleMemorySize - $ComputerMemory.FreePhysicalMemory) * 100) / $ComputerMemory.TotalVisibleMemorySize)
      [math]::Round($Memory, 2)
    EOT
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Disk Usage"
    key          = "disk"
    script       = <<-EOT
      $Disk = Get-WmiObject -Class win32_logicaldisk -Filter "DeviceID='C:'"
      $UsedSpace = ($Disk.Size - $Disk.FreeSpace) / $Disk.Size * 100
      [math]::Round($UsedSpace, 2)
    EOT
    interval     = 60
    timeout      = 1
  }
}

resource "aws_security_group" "windows_workspace" {
  name        = "coder-windows-${data.coder_workspace.me.id}"
  description = "Coder Windows workspace security group for ${data.coder_workspace.me.name}"

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "DCV"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "coder-windows-${data.coder_workspace.me.id}"
    Workspace = data.coder_workspace.me.name
    Owner     = data.coder_workspace.me.owner
  }
}

resource "aws_instance" "windows_workspace" {
  ami               = data.aws_ami.windows.id
  availability_zone = "${var.aws_region}a"
  instance_type     = var.instance_type
  get_password_data = true

  root_block_device {
    volume_size = var.disk_size
  }

  vpc_security_group_ids = [aws_security_group.windows_workspace.id]

  user_data = <<-EOF
    <powershell>
    # Install DCV
    $DcvUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"
    $DcvInstaller = "$env:TEMP\dcv-server.msi"
    (New-Object System.Net.WebClient).DownloadFile($DcvUrl, $DcvInstaller)
    Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i $DcvInstaller /quiet /norestart ADDLOCAL=ALL"
    
    # Configure DCV
    $ConfigPath = "C:\Program Files\NICE\DCV\Server\conf\dcv.conf"
    $Config = @"
    [license]
    [session-management]
    create-session = true
    [session-management/automatic-console-session]
    owner="$env:USERNAME"
    [display]
    enable-yuv444 = true
    [connectivity]
    web-port=8443
    "@
    Set-Content -Path $ConfigPath -Value $Config
    
    # Restart DCV service
    Restart-Service -Name dcvserver
    </powershell>
  EOF

  tags = {
    Name      = "coder-windows-${data.coder_workspace.me.id}"
    Workspace = data.coder_workspace.me.name
    Owner     = data.coder_workspace.me.owner
  }
}

resource "coder_app" "dcv" {
  agent_id     = coder_agent.main.id
  slug         = "dcv"
  display_name = "NICE DCV"
  url          = "https://${aws_instance.windows_workspace.public_ip}:8443"
  icon         = "/icon/windows.svg"
  subdomain    = true
  share        = "owner"
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = aws_instance.windows_workspace.id
  
  item {
    key   = "region"
    value = var.aws_region
  }
  
  item {
    key   = "instance type"
    value = aws_instance.windows_workspace.instance_type
  }
  
  item {
    key   = "disk"
    value = "${var.disk_size} GiB"
  }
}
