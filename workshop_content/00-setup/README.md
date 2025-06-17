# Workshop Setup Guide

This guide will walk you through setting up the infrastructure needed for the AWS Cloud Development Environment Workshop.

## Prerequisites

Before you begin, make sure you have the following:

1. An AWS account with administrative permissions
2. AWS CLI installed and configured with your credentials
3. Node.js 14.x or later installed
4. Python 3.7 or later installed
5. AWS CDK installed (`npm install -g aws-cdk`)

## Deployment Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-repo/aws-workshop-cdk.git
cd aws-workshop-cdk
```

### 2. Install Dependencies

```bash
# Install Python dependencies
pip install -r requirements.txt

# Install CDK dependencies
cd cdk_app
npm install
```

### 3. Configure Deployment Parameters

Create a `.env` file in the `cdk_app` directory with the following parameters:

```
AWS_REGION=us-east-1
DOMAIN_NAME=workshop.example.com
CREATE_CERTIFICATE=false
```

Adjust these values according to your needs:
- `AWS_REGION`: The AWS region where you want to deploy the workshop infrastructure
- `DOMAIN_NAME`: The domain name you want to use for the workshop (you must own this domain)
- `CREATE_CERTIFICATE`: Set to `true` if you want to create an ACM certificate for your domain

### 4. Deploy the Infrastructure

```bash
# Bootstrap CDK (if you haven't done this before in this AWS account/region)
cdk bootstrap

# Deploy the infrastructure
cdk deploy --all
```

This will deploy the following resources:
- VPC with public and private subnets
- EKS cluster with managed node groups
- Cognito User Pool for authentication
- IAM roles and policies for Coder workspaces
- (Optional) ACM certificate for your domain

### 5. Configure Coder

After the infrastructure is deployed, you'll need to:

1. Update the `coder-core-values-v2.yaml` file with the outputs from the CDK deployment
2. Deploy Coder to the EKS cluster using Helm
3. Create the necessary secrets for Cognito integration

Follow the commands provided in the CDK outputs to complete these steps.

### 6. Access Coder

Once Coder is deployed, you can access it at:

```
https://your-domain-name
```

Log in with the admin credentials you configured during setup.

### 7. Upload Templates

Upload the provided Coder templates to your Coder instance:

```bash
# From the repository root
cd templates
coder templates push --ignore-lockfile -d aws-linux-base
coder templates push --ignore-lockfile -d aws-windows-dcv
```

## Cleanup

When you're done with the workshop, you can clean up all resources by running:

```bash
cdk destroy --all
```

This will delete all resources created by the CDK deployment, but note that any data stored in persistent volumes will be lost.
