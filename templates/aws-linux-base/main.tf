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

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "coder_agent" "main" {
  arch                   = "amd64"
  os                     = "linux"
  startup_script         = <<-EOT
    #!/bin/bash
    set -e

    # Install Docker
    if ! command -v docker &> /dev/null; then
      echo "Installing Docker..."
      sudo apt-get update
      sudo apt-get install -y ca-certificates curl gnupg
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo usermod -aG docker $USER
    fi

    # Install AWS CLI
    if ! command -v aws &> /dev/null; then
      echo "Installing AWS CLI..."
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip awscliv2.zip
      sudo ./aws/install
      rm -rf aws awscliv2.zip
    fi

    # Install kubectl
    if ! command -v kubectl &> /dev/null; then
      echo "Installing kubectl..."
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      rm kubectl
    fi

    # Install Node.js
    if ! command -v node &> /dev/null; then
      echo "Installing Node.js..."
      curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
      sudo apt-get install -y nodejs
    fi

    # Install Python
    if ! command -v python3 &> /dev/null; then
      echo "Installing Python..."
      sudo apt-get install -y python3 python3-pip python3-venv
    fi

    # Install code-server
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337 &
  EOT

  # These environment variables allow you to make Git commits right away.
  env = {
    GIT_AUTHOR_NAME     = "${data.coder_workspace.me.owner}"
    GIT_COMMITTER_NAME  = "${data.coder_workspace.me.owner}"
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace.me.owner_email}"
    GIT_COMMITTER_EMAIL = "${data.coder_workspace.me.owner_email}"
  }

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display this information.
  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "top -bn1 | grep \"Cpu(s)\" | awk '{print $2 + $4}' | awk '{print $1\"%\"}'"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "ram"
    script       = "free -m | awk 'NR==2{printf \"%.1f%%\", $3*100/$2 }'"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "home_disk"
    script       = "df -h /home | awk 'NR==2{print $5}'"
    interval     = 60
    timeout      = 1
  }
}

resource "aws_security_group" "dev_workspace" {
  name        = "coder-${data.coder_workspace.me.id}"
  description = "Coder workspace security group for ${data.coder_workspace.me.name}"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Web IDE"
    from_port   = 13337
    to_port     = 13337
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
    Name      = "coder-${data.coder_workspace.me.id}"
    Workspace = data.coder_workspace.me.name
    Owner     = data.coder_workspace.me.owner
  }
}

resource "aws_instance" "dev_workspace" {
  ami               = data.aws_ami.ubuntu.id
  availability_zone = "${var.aws_region}a"
  instance_type     = var.instance_type

  root_block_device {
    volume_size = var.disk_size
  }

  vpc_security_group_ids = [aws_security_group.dev_workspace.id]

  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Create user and configure SSH
    useradd -m -s /bin/bash ${local.username}
    mkdir -p /home/${local.username}/.ssh
    echo "${var.public_key}" > /home/${local.username}/.ssh/authorized_keys
    chown -R ${local.username}:${local.username} /home/${local.username}/.ssh
    chmod 700 /home/${local.username}/.ssh
    chmod 600 /home/${local.username}/.ssh/authorized_keys
    
    # Add user to sudoers
    echo "${local.username} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${local.username}
    chmod 440 /etc/sudoers.d/${local.username}
  EOF

  tags = {
    Name      = "coder-${data.coder_workspace.me.id}"
    Workspace = data.coder_workspace.me.name
    Owner     = data.coder_workspace.me.owner
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337/?folder=/home/${local.username}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = aws_instance.dev_workspace.id
  
  item {
    key   = "region"
    value = var.aws_region
  }
  
  item {
    key   = "instance type"
    value = aws_instance.dev_workspace.instance_type
  }
  
  item {
    key   = "disk"
    value = "${var.disk_size} GiB"
  }
}
