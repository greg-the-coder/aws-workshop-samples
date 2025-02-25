# Documnet the scripts/options used for simple AWS EKS Deployment of Coder for Demo's and Workshops

# Create EKS Cluster using default eksctl generated supporting resources, and leverage auto-mode features for simplicity (change cluster name to your own)
eksctl create cluster --name=gtc-test-podid-eks --enable-auto-mode --region us-east-2

# Depploy new K8S StorageClass for dynamic EBS volume provisioning
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
# Smoke test cluster/app deployment - https://docs.aws.amazon.com/eks/latest/userguide/auto-elb-example.html

# Create Coder Namespace and Deploy In-Cluster PostgreSQL - https://coder.com/docs/install/kubernetes
kubectl create namespace coder

# Install Coder using Helm and supplied coder-core-values-v2.yaml base (replace coder_access_url values with your own)
helm install coder coder-v2/coder \
    --namespace coder \
    --values coder-core-values-v2.yaml \
    --version 2.19.0

# Create IAM Role & Trust Relationship for EC2 Workspace Support (change rolename to your own)
aws iam create-role --role-name gtc-coder-ec2-workspace-eks-role --assume-role-policy-document file://ekspodid-trust-policy.json
aws iam attach-role-policy \
    --role-name gtc-coder-ec2-workspace-eks-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-role-policy \
    --role-name gtc-coder-ec2-workspace-eks-role \
    --policy-arn arn:aws:iam::aws:policy/IAMReadOnlyAccess

# Add and IAM Pod Identify association for EC2 Workspace support (change cluster name to your own)
aws eks create-pod-identity-association \
    --cluster-name gtc-test-podid-eks \
    --namespace coder \
    --service-account coder \
    --role-arn arn:aws:iam::<aws account>:role/gtc-coder-ec2-workspace-eks-role
