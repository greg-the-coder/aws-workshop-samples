# AWS Cloud Development Environment Workshop

Welcome to the AWS Cloud Development Environment Workshop! This workshop will guide you through using Coder to create and manage cloud development environments on AWS.

## Workshop Modules

This workshop is divided into several modules, each focusing on a different aspect of cloud development environments:

1. **Introduction to Cloud Development Environments**
   - What are Cloud Development Environments?
   - Benefits of Cloud Development Environments
   - Introduction to Coder

2. **Setting Up Your First Development Environment**
   - Creating a Linux-based development environment
   - Connecting to your environment
   - Installing and configuring development tools

3. **Working with AWS Services**
   - Setting up AWS CLI and credentials
   - Interacting with AWS services from your development environment
   - Building a simple serverless application

4. **Advanced Development Environments**
   - Windows development with NICE DCV
   - GPU-accelerated environments for ML/AI workloads
   - Customizing your development environment

5. **Best Practices and Security**
   - Security best practices for cloud development environments
   - Cost optimization strategies
   - Implementing GitOps workflows

## Prerequisites

Before starting this workshop, you should have:

1. An AWS account with appropriate permissions
2. Basic familiarity with AWS services
3. Basic understanding of Git and software development workflows
4. A modern web browser (Chrome, Firefox, Edge, or Safari)

## Getting Started

To begin the workshop, navigate to the first module: [Introduction to Cloud Development Environments](./01-introduction/README.md)

## Workshop Architecture

This workshop uses the following AWS services:

- Amazon EC2 for compute resources
- Amazon EKS for container orchestration
- AWS IAM for access management
- Amazon Cognito for authentication
- AWS CloudFront for content delivery
- Amazon Route 53 for DNS management

The infrastructure for this workshop is defined using AWS CDK and can be deployed using the instructions in the [deployment guide](./00-setup/README.md).

## Additional Resources

- [Coder Documentation](https://coder.com/docs)
- [AWS Documentation](https://docs.aws.amazon.com/)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/latest/guide/home.html)
- [Terraform Documentation](https://www.terraform.io/docs)
