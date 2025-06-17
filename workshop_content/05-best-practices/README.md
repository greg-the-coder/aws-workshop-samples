# Best Practices and Security

In this final module, we'll explore best practices for using cloud development environments, security considerations, and cost optimization strategies.

## Security Best Practices

### 1. Least Privilege Access

When configuring IAM roles for your development environments, follow the principle of least privilege:

- Grant only the permissions necessary for development tasks
- Use separate roles for different environments (dev, staging, prod)
- Regularly audit and rotate credentials

Example IAM policy for a development role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::dev-bucket",
        "arn:aws:s3:::dev-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/dev-*"
    }
  ]
}
```

### 2. Network Security

Secure your development environments with proper network controls:

- Use private subnets for workspaces when possible
- Implement security groups with minimal required access
- Use VPC endpoints for AWS services to avoid public internet exposure
- Enable VPC flow logs for network monitoring

Example security group configuration:

```hcl
resource "aws_security_group" "dev_workspace" {
  name        = "coder-${data.coder_workspace.me.id}"
  description = "Coder workspace security group"
  vpc_id      = var.vpc_id

  # SSH access only from specific CIDR blocks
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.company_vpn_cidr]
  }

  # Web IDE access only from specific CIDR blocks
  ingress {
    description = "Web IDE"
    from_port   = 13337
    to_port     = 13337
    protocol    = "tcp"
    cidr_blocks = [var.company_vpn_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### 3. Secrets Management

Never hardcode secrets in your templates or code:

- Use AWS Secrets Manager or Parameter Store for secrets
- Implement secret rotation policies
- Use environment variables for sensitive values
- Consider using temporary credentials when possible

Example of accessing secrets in a template:

```hcl
data "aws_secretsmanager_secret" "db_credentials" {
  name = "dev/db/credentials"
}

data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = data.aws_secretsmanager_secret.db_credentials.id
}

locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)
}

resource "coder_agent" "main" {
  # ... existing configuration ...
  env = {
    DB_HOST     = local.db_credentials.host
    DB_USER     = local.db_credentials.username
    DB_PASSWORD = local.db_credentials.password
    DB_NAME     = local.db_credentials.dbname
  }
}
```

### 4. Data Protection

Protect sensitive data in your development environments:

- Encrypt data at rest using AWS KMS
- Implement automatic backups for important data
- Use secure deletion practices for sensitive information
- Consider using ephemeral workspaces for highly sensitive work

Example of encrypting EBS volumes:

```hcl
resource "aws_ebs_volume" "home_volume" {
  availability_zone = "${var.aws_region}a"
  size              = 50
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn
  
  tags = {
    Name = "coder-${data.coder_workspace.me.id}-home"
  }
}
```

## Cost Optimization Strategies

### 1. Auto-Shutdown Policies

Coder supports automatic shutdown of idle workspaces to save costs:

```hcl
data "coder_parameter" "auto_shutdown_hours" {
  name         = "auto_shutdown_hours"
  display_name = "Auto-shutdown after inactivity"
  description  = "Number of hours of inactivity before workspace is automatically stopped"
  type         = "number"
  default      = 4
  mutable      = true
  validation {
    min = 1
    max = 24
  }
}

resource "coder_agent" "main" {
  # ... existing configuration ...
  
  # Convert hours to minutes
  idle_timeout = data.coder_parameter.auto_shutdown_hours.value * 60 * 60
}
```

### 2. Right-Sizing Resources

Choose appropriate instance types for your workloads:

- Start with smaller instances and scale up as needed
- Use burstable instances (T3) for development work
- Consider Spot instances for non-critical workloads
- Implement instance scheduling for predictable usage patterns

Example of parameterizing instance types:

```hcl
data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance Type"
  description  = "The AWS instance type to use for the workspace"
  type         = "string"
  default      = "t3.medium"
  mutable      = true
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
}

resource "aws_instance" "dev_workspace" {
  instance_type = data.coder_parameter.instance_type.value
  # ... other configuration ...
}
```

### 3. Storage Optimization

Optimize storage costs:

- Use appropriate storage types (gp3 vs io2)
- Implement lifecycle policies for S3 buckets
- Clean up unused volumes and snapshots
- Use volume shrinking for oversized volumes

Example of storage optimization:

```hcl
data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size (GB)"
  description  = "The size of the root disk in GB"
  type         = "number"
  default      = 30
  mutable      = true
  validation {
    min = 20
    max = 100
  }
}

resource "aws_instance" "dev_workspace" {
  # ... other configuration ...
  
  root_block_device {
    volume_size = data.coder_parameter.disk_size.value
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }
}
```

## Implementing GitOps Workflows

GitOps is a methodology that uses Git as the single source of truth for infrastructure and application deployments. Here's how to implement GitOps workflows with Coder:

### 1. Template Version Control

Store your Coder templates in a Git repository:

```bash
# Create a repository for your templates
mkdir -p ~/coder-templates
cd ~/coder-templates
git init

# Add your templates
mkdir -p aws-linux-base
cp -r /path/to/aws-linux-base/* aws-linux-base/

# Commit and push
git add .
git commit -m "Initial commit of Coder templates"
git remote add origin https://github.com/your-org/coder-templates.git
git push -u origin main
```

### 2. CI/CD for Templates

Set up a CI/CD pipeline to validate and deploy templates:

```yaml
# .github/workflows/validate-templates.yml
name: Validate Templates

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        
      - name: Validate Templates
        run: |
          for template in */; do
            cd "$template"
            terraform init
            terraform validate
            cd ..
          done
```

### 3. Template Deployment

Automate template deployment with a CI/CD pipeline:

```yaml
# .github/workflows/deploy-templates.yml
name: Deploy Templates

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Coder CLI
        run: |
          curl -L https://coder.com/install.sh | sh
          
      - name: Login to Coder
        run: |
          coder login https://your-coder-url --token ${{ secrets.CODER_TOKEN }}
          
      - name: Deploy Templates
        run: |
          for template in */; do
            template_name=$(basename "$template")
            coder templates push --ignore-lockfile -d "$template" -y
          done
```

## Exercise: Implement Best Practices

1. Review the security of your current workspace:
   - Check the IAM permissions
   - Review the security group rules
   - Identify any hardcoded secrets

2. Optimize your workspace for cost:
   - Configure auto-shutdown
   - Right-size the instance type
   - Optimize storage configuration

3. Create a Git repository for your templates and set up version control.

## Conclusion

Congratulations on completing the AWS Cloud Development Environment Workshop! You've learned how to:

- Set up and connect to cloud development environments
- Work with AWS services from your development environment
- Build a serverless application
- Use advanced development environments including Windows with NICE DCV
- Implement security best practices and cost optimization strategies

## Next Steps

To continue your journey with cloud development environments:

1. Explore the [Coder documentation](https://coder.com/docs) for more advanced features
2. Join the [Coder community](https://community.coder.com) to connect with other users
3. Contribute to the [Coder open-source project](https://github.com/coder/coder)
4. Implement cloud development environments in your organization

Thank you for participating in this workshop!
