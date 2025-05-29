# Deploying Coder on AWS EKS with Amazon Q

This document provides a step-by-step guide for deploying Coder on AWS EKS for workshops or demonstrations, based on the `deploy2eks.sh` script in this repository.

## Prerequisites

Before you begin, ensure you have:

- An AWS account with appropriate permissions
- The following CLI tools installed:
  - AWS CLI (configured with your credentials)
  - eksctl
  - kubectl
  - helm

## Deployment Steps

### 1. Create an EKS Cluster

```bash
# Create an EKS cluster with auto-mode enabled for simplicity
eksctl create cluster --name=your-cluster-name --enable-auto-mode --region your-region
```

Replace `your-cluster-name` with your desired cluster name and `your-region` with your preferred AWS region.

### 2. Configure Storage for the Cluster

Deploy a Kubernetes StorageClass for dynamic EBS volume provisioning:

```bash
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

### 3. Set Up Coder with PostgreSQL Database

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

### 4. Install Coder

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

### 5. Set Up Authentication with AWS Cognito (Optional)

```bash
# Create Cognito User Pool
aws cognito-idp create-user-pool \
  --pool-name your-user-pool-name \
  --auto-verified-attributes email

# Note the User Pool ID from the output for use in the next command

# Create Coder OIDC App Client
aws cognito-idp create-user-pool-client \
  --user-pool-id your-user-pool-id \
  --client-name your-client-name \
  --generate-secret \
  --allowed-o-auth-flows code implicit \
  --allowed-o-auth-scopes openid email profile \
  --callback-urls "https://your-coder-domain.com/api/v2/users/oidc/callback" \
  --logout-urls "https://your-coder-domain.com/api/v2/users/oidc/logout"

# Create Kubernetes secrets for Cognito credentials
kubectl create secret generic aws-cognito-id -n coder \
  --from-literal=client-id="your-client-id"

kubectl create secret generic aws-cognito-secret -n coder \
  --from-literal=client-secret="your-client-secret"
```

### 6. Update Coder Configuration

Before updating Coder, modify the `coder-core-values-v2.yaml` file with your specific configuration:

- Update `CODER_ACCESS_URL` with your actual domain or load balancer URL
- Update `CODER_WILDCARD_ACCESS_URL` with your wildcard domain
- Update `CODER_OIDC_ISSUER_URL` with your Cognito User Pool URL
- Update any other settings as needed

Then apply the updated configuration:

```bash
helm upgrade coder coder-v2/coder \
    --namespace coder \
    --values coder-core-values-v2.yaml \
    --version 2.19.0
```

### 7. Configure IAM for EC2 Workspace Support

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

### 8. Set Up CloudFront for HTTPS Access (Recommended)

For production use, it's recommended to:

1. Set up a CloudFront distribution in front of the Kubernetes Load Balancer
2. Configure a custom domain name pointing to your CloudFront distribution
3. Update the Coder configuration with your custom domain

## Customizing Your Deployment

### The coder-core-values-v2.yaml File

The `coder-core-values-v2.yaml` file contains various configuration options for your Coder deployment, including:

- Access URLs and wildcard domains
- Authentication settings (password, OIDC)
- Resource limits and requests
- Service configurations
- High availability settings

Review and modify this file to match your specific requirements before deploying or upgrading Coder.

### Trust Policy for EKS Pod Identity

The `ekspodid-trust-policy.json` file contains the IAM trust relationship that allows EKS pods to assume the IAM role for EC2 workspace provisioning:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowEksAuthToAssumeRoleForPodIdentity",
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
```

## Next Steps

After deploying Coder, you can:

1. Upload and configure templates from this repository
2. Create standardized development environments for your workshops or demonstrations
3. Invite users to your Coder instance
