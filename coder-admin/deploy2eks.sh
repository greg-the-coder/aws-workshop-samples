# Document the scripts/options used for simple AWS EKS Deployment of Coder for Demo's and Workshops
# Prereqs: AWS Account/Access with appropriate permissions and latest AWS, eksctl, kubectl, helm cli's installed.

# Create EKS Cluster using default eksctl generated supporting resources, and leverage auto-mode features for simplicity (change cluster name to your own)
eksctl create cluster --name=gtc-test-podid-eks --enable-auto-mode --region us-east-2

# Deploy new K8S StorageClass for dynamic EBS volume provisioning
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

# Smoke test cluster/app deployment (if desired) - https://docs.aws.amazon.com/eks/latest/userguide/auto-elb-example.html

# Create Coder Namespace and Deploy In-Cluster PostgreSQL - https://coder.com/docs/install/kubernetes
kubectl create namespace coder
# Install PostgreSQL
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install coder-db bitnami/postgresql \
    --namespace coder \
    --set auth.username=coder \
    --set auth.password=coder \
    --set auth.database=coder \
    --set persistence.size=10Gi

#Create secret used by std Coder Deployment
kubectl create secret generic coder-db-url -n coder \
  --from-literal=url="postgres://coder:coder@coder-db-postgresql.coder.svc.cluster.local:5432/coder?sslmode=disable"

# Install Coder using Helm and supplied coder-core-values-v2.yaml base 
helm repo add coder-v2 https://helm.coder.com/v2
helm install coder coder-v2/coder \
    --namespace coder \
    --values coder-core-values-v2.yaml \
    --version 2.19.0

# Perform helm upgrade to update Coder with actual K8S Service endpoints created for use with CODER_ACCESS_URL and CODER_WILDCARD_ACCESS_URL after updating coder-core-values-v2.yaml
helm upgrade coder coder-v2/coder \
    --namespace coder \
    --values coder-core-values-v2.yaml \
    --version 2.19.0

# Create IAM Role & Trust Relationship for EC2 Workspace Support (change rolename to your own name)
aws iam create-role --role-name gtc-coder-ec2-workspace-eks-role --assume-role-policy-document file://ekspodid-trust-policy.json
aws iam attach-role-policy \
    --role-name gtc-coder-ec2-workspace-eks-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-role-policy \
    --role-name gtc-coder-ec2-workspace-eks-role \
    --policy-arn arn:aws:iam::aws:policy/IAMReadOnlyAccess

# Add and IAM Pod Identify association for EC2 Workspace support (change cluster and role name to your own)
aws eks create-pod-identity-association \
    --cluster-name gtc-test-podid-eks \
    --namespace coder \
    --service-account coder \
    --role-arn arn:aws:iam::<aws account>:role/gtc-coder-ec2-workspace-eks-role

# TODO:  Need to add step to create Cloudfront distribution in front of K8S Loadbalancer to support easy https/SSL connection to workspaces + code-server 
# Current test CF Endpoint - https://d1wpz86e557hjj.cloudfront.net/
