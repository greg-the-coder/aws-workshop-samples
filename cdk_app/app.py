#!/usr/bin/env python3
import os
from aws_cdk import (
    App,
    Environment,
    Stack,
    aws_ec2 as ec2,
    aws_eks as eks,
    aws_iam as iam,
    aws_cognito as cognito,
    aws_cloudfront as cloudfront,
    aws_cloudfront_origins as origins,
    aws_certificatemanager as acm,
    aws_route53 as route53,
    aws_route53_targets as targets,
    CfnOutput
)
from constructs import Construct

class CoderInfrastructureStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Parameters (these could be passed in from a config file or environment variables)
        cluster_name = "coder-workshop-cluster"
        region = os.environ.get("AWS_REGION", "us-east-1")
        domain_name = os.environ.get("DOMAIN_NAME", "workshop.example.com")
        create_certificate = os.environ.get("CREATE_CERTIFICATE", "false").lower() == "true"
        
        # Create VPC for EKS cluster
        vpc = ec2.Vpc(
            self, "CoderVPC",
            max_azs=2,
            nat_gateways=1,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24
                )
            ]
        )
        
        # Create IAM role for EKS cluster
        cluster_role = iam.Role(
            self, "ClusterRole",
            assumed_by=iam.ServicePrincipal("eks.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name("AmazonEKSClusterPolicy")
            ]
        )
        
        # Create EKS cluster
        cluster = eks.Cluster(
            self, "CoderCluster",
            cluster_name=cluster_name,
            version=eks.KubernetesVersion.V1_27,
            vpc=vpc,
            default_capacity=0,
            role=cluster_role
        )
        
        # Add managed node group
        cluster.add_nodegroup_capacity(
            "CoderNodeGroup",
            instance_types=[ec2.InstanceType("t3.large")],
            min_size=2,
            max_size=4,
            disk_size=50
        )
        
        # Create IAM role for EC2 workspaces
        ec2_workspace_role = iam.Role(
            self, "EC2WorkspaceRole",
            assumed_by=iam.ServicePrincipal("eks-pod-identity.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name("AmazonEC2FullAccess"),
                iam.ManagedPolicy.from_aws_managed_policy_name("IAMReadOnlyAccess")
            ]
        )
        
        # Create Cognito User Pool for authentication
        user_pool = cognito.UserPool(
            self, "CoderUserPool",
            user_pool_name="coder-workshop-users",
            self_sign_up_enabled=True,
            auto_verify=cognito.AutoVerify(email=True),
            standard_attributes=cognito.StandardAttributes(
                email=cognito.StandardAttribute(required=True, mutable=True)
            ),
            password_policy=cognito.PasswordPolicy(
                min_length=8,
                require_lowercase=True,
                require_uppercase=True,
                require_digits=True,
                require_symbols=True
            )
        )
        
        # Create Cognito App Client for Coder
        app_client = user_pool.add_client(
            "CoderClient",
            generate_secret=True,
            o_auth=cognito.OAuthSettings(
                flows=cognito.OAuthFlows(
                    authorization_code_grant=True,
                    implicit_code_grant=True
                ),
                scopes=[cognito.OAuthScope.EMAIL, cognito.OAuthScope.OPENID, cognito.OAuthScope.PROFILE],
                callback_urls=[f"https://{domain_name}/api/v2/users/oidc/callback"],
                logout_urls=[f"https://{domain_name}/api/v2/users/oidc/logout"]
            )
        )
        
        # Optional: Create ACM certificate if requested
        certificate = None
        if create_certificate:
            # This requires a hosted zone in Route53
            hosted_zone = route53.HostedZone.from_lookup(
                self, "HostedZone",
                domain_name=domain_name.split(".", 1)[1]  # Extract the parent domain
            )
            
            certificate = acm.Certificate(
                self, "CoderCertificate",
                domain_name=domain_name,
                validation=acm.CertificateValidation.from_dns(hosted_zone)
            )
        
        # Outputs
        CfnOutput(self, "ClusterName", value=cluster.cluster_name)
        CfnOutput(self, "UserPoolId", value=user_pool.user_pool_id)
        CfnOutput(self, "AppClientId", value=app_client.user_pool_client_id)
        CfnOutput(self, "EC2WorkspaceRoleArn", value=ec2_workspace_role.role_arn)

class CoderDeploymentStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, cluster, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        
        # This stack would contain the Helm chart deployment for Coder
        # Since CDK doesn't directly support Helm charts without custom resources,
        # we'll provide the kubectl commands as outputs
        
        CfnOutput(self, "InstallPostgresCommand", value="""
kubectl create namespace coder
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install coder-db bitnami/postgresql \\
    --namespace coder \\
    --set auth.username=coder \\
    --set auth.password=coder \\
    --set auth.database=coder \\
    --set persistence.size=10Gi
        """)
        
        CfnOutput(self, "CreateDbSecretCommand", value="""
kubectl create secret generic coder-db-url -n coder \\
  --from-literal=url="postgres://coder:coder@coder-db-postgresql.coder.svc.cluster.local:5432/coder?sslmode=disable"
        """)
        
        CfnOutput(self, "InstallCoderCommand", value="""
helm repo add coder-v2 https://helm.coder.com/v2
helm install coder coder-v2/coder \\
    --namespace coder \\
    --values coder-core-values-v2.yaml \\
    --version 2.19.0
        """)

app = App()

# Create the infrastructure stack
infra_stack = CoderInfrastructureStack(app, "CoderInfrastructureStack")

# Create the deployment stack
deployment_stack = CoderDeploymentStack(app, "CoderDeploymentStack", 
                                       cluster=infra_stack.cluster)

app.synth()
