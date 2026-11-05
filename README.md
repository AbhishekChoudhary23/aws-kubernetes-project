# AWS EKS Observability Project (GCR + Terraform + CloudFormation + Kubernetes)

## Architecture Overview
- **Infrastructure Layer (`terraform/`)**: Provisions the AWS VPC, public/private subnets across 2 Availability Zones, NAT Gateway, and least-privilege IAM roles (`eks-cluster-role` and `eks-node-role`).
- **EKS Cluster Layer (`cloudformation/observability-eks.yaml`)**: Provisions the Amazon EKS control plane, control plane security group, pre-node networking add-ons (`vpc-cni`, `kube-proxy`, `eks-pod-identity-agent`), managed node group (`AL2023_x86_64_STANDARD`), post-node add-ons (`coredns`, `eks-node-monitoring-agent`), and the `AWSLoadBalancerControllerIAMPolicy`.
- **Container Registry (Google Container Registry - GCR)**: Application images are built and pushed to `gcr.io/<gcp-project-id>/...` and pulled into EKS using a `kubernetes.io/dockerconfigjson` secret (`gcr-json-key`).
- **Kubernetes Workloads (`k8s/manifests/`)**: Production-hardened deployments, ClusterIP services, HorizontalPodAutoscalers, and an AWS ALB Ingress resource routing `/api` to the Node.js backend and `/` to the Nginx frontend.

## Step-by-Step Deployment

### 1. Provision Base Network & IAM via Terraform
```bash
cd terraform
terraform init
terraform apply
```

### 2. Provision EKS Cluster via CloudFormation
```bash
aws cloudformation deploy \
  --template-file cloudformation/observability-eks.yaml \
  --stack-name observability-eks-stack \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    VpcId=$(terraform -chdir=terraform output -raw vpc_id) \
    PublicSubnet1=$(terraform -chdir=terraform output -json public_subnet_ids | jq -r '.[0]') \
    PublicSubnet2=$(terraform -chdir=terraform output -json public_subnet_ids | jq -r '.[1]') \
    PrivateSubnet1=$(terraform -chdir=terraform output -json private_subnet_ids | jq -r '.[0]') \
    PrivateSubnet2=$(terraform -chdir=terraform output -json private_subnet_ids | jq -r '.[1]') \
    ClusterRoleArn=$(terraform -chdir=terraform output -raw eks_cluster_role_arn) \
    NodeRoleArn=$(terraform -chdir=terraform output -raw eks_node_role_arn)
```

### 3. Configure GCR Image Pull Secret & Deploy Manifests
```bash
aws eks update-kubeconfig --region ap-south-1 --name observability-eks
./scripts/create-gcr-secret.sh observability /path/to/gcr-key.json
kubectl apply -f k8s/manifests/namespace.yaml
kubectl apply -f k8s/manifests/backend/
kubectl apply -f k8s/manifests/frontend/
kubectl apply -f k8s/manifests/ingress.yaml
```
