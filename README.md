# aws-workshop-samples
This project is designed to help you quickly spin up Cloud Development Environments for Demos, Labs, Workshops, Hackathons, or simple POC's in AWS using [Coder](https://coder.com/cde). These templates and basic Coder admin scripts can be used in any Coder deployment, but are focused on using either the [Coder AWS Marketplace](https://coder.com/docs/install/cloud/ec2) AWS EC2 single VM deployment or an AWS EKS deployment.

## Deployment Options

### Option 1: AWS EC2 Single VM Deployment

1) Follow the steps in the [AWS EC2 Installation Guide](https://coder.com/docs/install/cloud/ec2). Complete the optional step to provide Developers EC2 Workspaces, as the AWS Specific templates provided rely on this capability.
2) Login using the provided public IP, and setup your first Coder user.
3) After successfully logging in, clone this Github repo locally so that the provided AWS Workshop Admin template can be uploaded.

### Option 2: AWS EKS Deployment

This guide walks you through deploying Coder on AWS EKS for workshops or demonstrations.

#### Prerequisites
- AWS Account with appropriate permissions
- Latest versions of the following CLI tools installed:
  - AWS CLI
  - eksctl
  - kubectl
  - helm

#### Step 1: Create an EKS Cluster
```bash
# Create EKS Cluster (customize the cluster name and region as needed)
eksctl create cluster --name=your-cluster-name --enable-auto-mode --region your-region
```

#### Step 2: Configure Storage for the Cluster
```bash
# Deploy a K8S StorageClass for dynamic EBS volume provisioning
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-csi
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.eks.amazonaws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
allowVolumeExpansion: true
EOF
```

#### Step 3: Set Up Coder with PostgreSQL Database
```bash
# Create Coder namespace
kubectl create namespace coder

# Install PostgreSQL using Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install coder-db bitnami/postgresql \
    --namespace coder \
    --set auth.username=coder \
    --set auth.password=coder \
    --set auth.database=coder \
    --set persistence.size=10Gi

# Create database connection secret for Coder
kubectl create secret generic coder-db-url -n coder \
  --from-literal=url="postgres://coder:coder@coder-db-postgresql.coder.svc.cluster.local:5432/coder?sslmode=disable"
```

#### Step 4: Install Coder
```bash
# Add Coder Helm repository
helm repo add coder-v2 https://helm.coder.com/v2

# Install Coder using the provided values file
# Make sure the coder-core-values-v2.yaml file is in your current directory
helm install coder coder-v2/coder \
    --namespace coder \
    --values coder-core-values-v2.yaml \
    --version 2.19.0
```

#### Step 5: Update Coder Configuration
```bash
# Update the coder-core-values-v2.yaml file with your specific configuration:
# - Update CODER_ACCESS_URL with your actual domain or load balancer URL
# - Update CODER_WILDCARD_ACCESS_URL with your wildcard domain
# - Update CODER_OIDC_ISSUER_URL with your Cognito User Pool URL
# - Update any other settings as needed

# Apply the updated configuration
helm upgrade coder coder-v2/coder \
    --namespace coder \
    --values coder-core-values-v2.yaml \
    --version 2.19.0
```

#### Step 6: Configure IAM for EC2 Workspace Support
```bash
# Create IAM Role & Trust Relationship for EC2 Workspace Support
# First, make sure you have the ekspodid-trust-policy.json file in your current directory
aws iam create-role --role-name your-coder-ec2-workspace-role --assume-role-policy-document file://ekspodid-trust-policy.json

# Attach necessary policies to the role
aws iam attach-role-policy \
    --role-name your-coder-ec2-workspace-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy \
    --role-name your-coder-ec2-workspace-role \
    --policy-arn arn:aws:iam::aws:policy/IAMReadOnlyAccess

# Add IAM Pod Identity association for EC2 Workspace support
aws eks create-pod-identity-association \
    --cluster-name your-cluster-name \
    --namespace coder \
    --service-account coder \
    --role-arn arn:aws:iam::your-aws-account-id:role/your-coder-ec2-workspace-role
```

#### Step 7: Access Your Coder Deployment
After completing the setup, you can access your Coder deployment using the Load Balancer URL provided by the Kubernetes service. For production use, it's recommended to:

1. Set up a CloudFront distribution in front of the Kubernetes Load Balancer to support HTTPS/SSL connections
2. Configure a custom domain name pointing to your CloudFront distribution
3. Update the Coder configuration with your custom domain

## Additional Configuration

### Customizing the Coder Deployment
The `coder-core-values-v2.yaml` file in the [coder_admin](./coder_admin) directory contains various configuration options for your Coder deployment, including:

- Access URLs and wildcard domains
- Authentication settings (password, OIDC)
- Resource limits and requests
- Service configurations
- High availability settings

Review and modify this file to match your specific requirements before deploying or upgrading Coder.

### Template Management
After deploying Coder, you can use the templates provided in this repository to create standardized development environments for your workshops or demonstrations.
