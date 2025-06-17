# Advanced Development Environments

In this module, we'll explore more advanced development environment configurations, including Windows environments with NICE DCV and customizing your development environments.

## Windows Development with NICE DCV

Windows development environments are essential for many scenarios, such as:
- .NET Framework development
- Windows-specific application testing
- Visual Studio development
- Windows-only tools and SDKs

Coder supports Windows development environments using NICE DCV, a high-performance remote display protocol developed by AWS.

### Creating a Windows Development Environment

1. From the Coder dashboard, click on the "Create Workspace" button.
2. Select the "AWS Windows DCV" template.
3. Configure your workspace with the following settings:
   - **Name**: Choose a name for your workspace (e.g., `windows-dev`)
   - **AWS Region**: Select the AWS region closest to you
   - **Instance Type**: Choose `t3.large` (2 vCPU, 8 GiB RAM)
   - **Disk Size**: Set to 50 GiB
4. Click "Create" to provision your workspace.

The provisioning process will take a few minutes. Windows instances typically take longer to provision than Linux instances.

### Connecting to Your Windows Environment

Once your workspace is ready:

1. On your workspace page, click on the "NICE DCV" application icon.
2. This will open a new browser tab with the NICE DCV web client.
3. You'll be connected to a Windows desktop environment running in the cloud.

### Using Your Windows Environment

Your Windows environment comes pre-installed with several development tools:

- Git
- Visual Studio Code
- AWS CLI
- Node.js
- Python

You can install additional tools using Chocolatey, the package manager for Windows:

```powershell
# Install Visual Studio
choco install visualstudio2022community -y

# Install .NET SDK
choco install dotnet-sdk -y

# Install SQL Server Management Studio
choco install sql-server-management-studio -y
```

## GPU-Accelerated Environments for ML/AI Workloads

For machine learning and AI development, you often need GPU-accelerated environments. While not included in this workshop's templates, you can create GPU-accelerated environments in Coder by:

1. Selecting GPU-enabled instance types (e.g., `g4dn.xlarge`)
2. Installing CUDA and ML frameworks
3. Configuring the environment for GPU acceleration

Here's an example of how you might modify the Linux template to support GPU workloads:

```hcl
# In the template's main.tf file, modify the instance_type variable default
variable "instance_type" {
  description = "The AWS instance type to use for the workspace"
  default     = "g4dn.xlarge"  # GPU-enabled instance
  type        = string
}

# Add CUDA installation to the startup script
resource "coder_agent" "main" {
  # ... existing configuration ...
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Install Docker
    # ... existing Docker installation ...

    # Install CUDA
    if ! command -v nvidia-smi &> /dev/null; then
      echo "Installing CUDA..."
      wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
      sudo dpkg -i cuda-keyring_1.0-1_all.deb
      sudo apt-get update
      sudo apt-get install -y cuda-toolkit-11-8
      rm cuda-keyring_1.0-1_all.deb
    fi

    # Install ML frameworks
    pip install torch torchvision torchaudio tensorflow
    
    # ... rest of the startup script ...
  EOT
}
```

## Customizing Your Development Environment

One of the key benefits of Coder is the ability to customize your development environments to match your specific needs. Let's explore how to customize your environments.

### Customizing the Linux Environment

#### Adding Custom Tools and Dependencies

You can modify the `startup_script` in the template to install additional tools and dependencies:

```hcl
resource "coder_agent" "main" {
  # ... existing configuration ...
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Existing installations...

    # Install additional tools
    sudo apt-get update
    sudo apt-get install -y \
      build-essential \
      libssl-dev \
      zlib1g-dev \
      libbz2-dev \
      libreadline-dev \
      libsqlite3-dev \
      curl \
      llvm \
      tk-dev \
      xz-utils

    # Install Go
    if ! command -v go &> /dev/null; then
      echo "Installing Go..."
      curl -LO https://go.dev/dl/go1.19.linux-amd64.tar.gz
      sudo tar -C /usr/local -xzf go1.19.linux-amd64.tar.gz
      echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
      rm go1.19.linux-amd64.tar.gz
    fi

    # Install Rust
    if ! command -v rustc &> /dev/null; then
      echo "Installing Rust..."
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      source "$HOME/.cargo/env"
    fi
  EOT
}
```

#### Adding Persistent Storage

You can add persistent storage to your environment to preserve data between workspace rebuilds:

```hcl
resource "aws_ebs_volume" "home_volume" {
  availability_zone = "${var.aws_region}a"
  size              = 50
  type              = "gp3"
  tags = {
    Name = "coder-${data.coder_workspace.me.id}-home"
  }
}

resource "aws_volume_attachment" "home_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.home_volume.id
  instance_id = aws_instance.dev_workspace.id
}

# Modify the startup script to mount the volume
resource "coder_agent" "main" {
  # ... existing configuration ...
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Mount persistent home volume
    if [ ! -d "/home/${local.username}/persistent" ]; then
      sudo mkdir -p /home/${local.username}/persistent
      sudo chown ${local.username}:${local.username} /home/${local.username}/persistent
    fi

    DEVICE_NAME="/dev/nvme1n1"
    if [ -b "$DEVICE_NAME" ]; then
      if ! sudo file -s $DEVICE_NAME | grep -q filesystem; then
        sudo mkfs -t ext4 $DEVICE_NAME
      fi
      sudo mount $DEVICE_NAME /home/${local.username}/persistent
      sudo chown ${local.username}:${local.username} /home/${local.username}/persistent
    fi

    # Rest of the startup script...
  EOT
}
```

### Creating Custom Templates

For more advanced customization, you can create your own templates from scratch or modify the existing ones. Here's a basic workflow:

1. Clone an existing template:
   ```bash
   cp -r aws-linux-base my-custom-template
   ```

2. Modify the template files (`main.tf`, `variables.tf`) to suit your needs.

3. Push the template to Coder:
   ```bash
   coder templates push --ignore-lockfile -d my-custom-template
   ```

## Exercise: Customize Your Development Environment

1. Create a new workspace using the AWS Linux Base template.
2. Connect to the workspace using SSH or VS Code.
3. Customize your environment by:
   - Installing additional tools and languages
   - Configuring your shell with custom aliases and settings
   - Setting up your preferred editor configuration
4. Create a script that automates this customization for future workspaces.

## Next Steps

In the next module, we'll explore [Best Practices and Security](../05-best-practices/README.md) for cloud development environments.
