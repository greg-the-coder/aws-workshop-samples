# AWS Cloud Development Environment Workshop

This repository contains the infrastructure code and workshop content for the AWS Cloud Development Environment Workshop using [Coder](https://coder.com).

## Repository Structure

- `cdk_app/` - AWS CDK application for deploying the workshop infrastructure
- `templates/` - Coder templates for creating development environments
  - `aws-linux-base/` - Template for Linux-based development environments
  - `aws-windows-dcv/` - Template for Windows development environments with NICE DCV
- `workshop_content/` - Workshop modules and exercises
  - `00-setup/` - Setup guide for the workshop
  - `01-introduction/` - Introduction to cloud development environments
  - `02-first-environment/` - Setting up your first development environment
  - `03-aws-services/` - Working with AWS services
  - `04-advanced-environments/` - Advanced development environments
  - `05-best-practices/` - Best practices and security
  - `images/` - Images used in the workshop content

## Getting Started

### Prerequisites

- AWS Account with administrative permissions
- AWS CLI installed and configured
- Node.js 14.x or later
- Python 3.7 or later
- AWS CDK installed (`npm install -g aws-cdk`)

### Deployment

1. Clone this repository:
   ```bash
   git clone https://github.com/your-org/aws-workshop-cdk.git
   cd aws-workshop-cdk
   ```

2. Install dependencies:
   ```bash
   cd cdk_app
   pip install -r requirements.txt
   ```

3. Deploy the infrastructure:
   ```bash
   cdk bootstrap
   cdk deploy --all
   ```

4. Follow the instructions in the CDK outputs to complete the setup.

## Workshop Content

The workshop content is designed to guide participants through using cloud development environments on AWS. The content is organized into modules, each focusing on a different aspect of cloud development environments.

To access the workshop content, navigate to the `workshop_content/` directory and start with the [Introduction](./workshop_content/01-introduction/README.md).

## Contributing

Contributions to this workshop are welcome! Please feel free to submit issues or pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
