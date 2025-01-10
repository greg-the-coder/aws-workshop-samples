terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}
# Last updated 2023-03-14
# aws ec2 describe-regions | jq -r '[.Regions[].RegionName] | sort'
data "coder_parameter" "region" {
  name         = "region"
  display_name = "Region"
  description  = "The region to deploy the workspace in."
  default      = "us-east-1"
  mutable      = false
  option {
    name  = "US East (N. Virginia)"
    value = "us-east-1"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  option {
    name  = "US East (Ohio)"
    value = "us-east-2"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  option {
    name  = "US West (N. California)"
    value = "us-west-1"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  option {
    name  = "US West (Oregon)"
    value = "us-west-2"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  option {
    name  = "Canada (Central)"
    value = "ca-central-1"
    icon  = "/emojis/1f1e8-1f1e6.png"
  }
  option {
    name  = "EU (Frankfurt)"
    value = "eu-central-1"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "EU (Stockholm)"
    value = "eu-north-1"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "EU (Ireland)"
    value = "eu-west-1"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "EU (London)"
    value = "eu-west-2"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "EU (Paris)"
    value = "eu-west-3"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  option {
    name  = "South America (São Paulo)"
    value = "sa-east-1"
    icon  = "/emojis/1f1e7-1f1f7.png"
  }
}

data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance type"
  description  = "What instance type should your workspace use?"
  default      = "t3.micro"
  mutable      = false
  option {
    name  = "2 vCPU, 1 GiB RAM"
    value = "t3.micro"
  }
  option {
    name  = "2 vCPU, 2 GiB RAM"
    value = "t3.small"
  }
  option {
    name  = "2 vCPU, 4 GiB RAM"
    value = "t3.medium"
  }
  option {
    name  = "2 vCPU, 8 GiB RAM"
    value = "t3.large"
  }
  option {
    name  = "4 vCPU, 16 GiB RAM"
    value = "t3.xlarge"
  }
  option {
    name  = "8 vCPU, 32 GiB RAM"
    value = "t3.2xlarge"
  }
}

provider "aws" {
  region = data.coder_parameter.region.value
}

data "coder_workspace" "me" {
}
data "coder_workspace_owner" "me" {}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

resource "coder_agent" "dev" {
  count = data.coder_workspace.me.start_count
  arch  = "amd64"
  auth  = "aws-instance-identity"
  os    = "windows"
}

locals {
  # User data is used to stop/start AWS instances. See:
  # https://github.com/hashicorp/terraform-provider-aws/issues/22
  user_data_start = <<EOT
<powershell>
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
${try(coder_agent.dev[0].init_script, "")}
</powershell>
<persist>true</persist>
EOT
  #   user_data_end   = <<EOT
  # <powershell>
  # shutdown /s
  # </powershell>
  # EOT
  user_data_end = ""
}

resource "aws_instance" "dev" {
  ami               = data.aws_ami.windows.id
  availability_zone = "${data.coder_parameter.region.value}a"
  instance_type     = data.coder_parameter.instance_type.value

  user_data = data.coder_workspace.me.transition == "start" ? local.user_data_start : local.user_data_end
  tags = {
    Name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    # Required if you are using our example policy, see template README
    Coder_Provisioned = "true"
  }
  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}
resource "aws_ec2_instance_state" "dev" {
  instance_id = aws_instance.dev.id
  state       = data.coder_workspace.me.transition == "start" ? "running" : "stopped"
}

module "windows_dcv" {
  source               = "registry.coder.com/modules/amazon-dcv-windows/coder"
  count                = data.coder_workspace.me.start_count
  agent_id             = try(coder_agent.dev[count.index].id, "")
  subdomain            = false
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = aws_instance.dev.id
  item {
    key   = "region"
    value = data.coder_parameter.region.value
  }
  item {
    key   = "instance type"
    value = aws_instance.dev.instance_type
  }
  item {
    key   = "disk"
    value = "${aws_instance.dev.root_block_device[0].volume_size} GiB"
  }
  item {
    key   = "DCV client instructions"
    value = "Run `coder port-forward ${data.coder_workspace.me.name} -p ${module.windows_dcv[count.index].port}` and connect to **localhost:${module.windows_dcv[count.index].port}${module.windows_dcv[count.index].web_url_path}**"
  }
  item {
    key   = "username"
    value = module.windows_dcv[count.index].username
  }
  item {
    key       = "password"
    value     = module.windows_dcv[count.index].password
    sensitive = true
  }
}
