# AWS EKS Observability Project (Amazon ECR + Terraform + CloudFormation + Kubernetes)

## Architecture Overview
- **Infrastructure Layer (`terraform/`)**: Provisions the AWS VPC, public/private subnets across 2 Availability Zones, NAT Gateway, Amazon ECR repositories (`observability-backend` and `observability-frontend`), and least-privilege IAM roles (`eks-cluster-role` and `eks-node-role`).
- **EKS Cluster Layer (`cloudformation/observability-eks.yaml`)**: Provisions the Amazon EKS control plane, control plane security group, pre-node networking add-ons (`vpc-cni`, `kube-proxy`, `eks-pod-identity-agent`), managed node group (`AL2023_x86_64_STANDARD`), post-node add-ons (`coredns`, `eks-node-monitoring-agent`), and the `AWSLoadBalancerControllerIAMPolicy`.
- **Container Registry (Amazon ECR)**: Application images are stored in Amazon ECR (`<account-id>.dkr.ecr.<region>.amazonaws.com/observability-backend` and `observability-frontend`). Because the EKS Worker Node IAM Role includes `AmazonEC2ContainerRegistryReadOnly`, nodes pull images natively from ECR without requiring Kubernetes `imagePullSecrets`.
- **Kubernetes Workloads (`k8s/manifests/`)**: Production-hardened deployments, ClusterIP services, HorizontalPodAutoscalers, and an AWS ALB Ingress resource routing `/api` to the Node.js backend and `/` to the Nginx frontend.

## Step-by-Step Deployment

### 1. Provision Base Network, ECR & IAM via Terraform
```bash
cd terraform
terraform init
terraform apply
```

### 2. Build & Push Images to Amazon ECR
```bash
AWS_REGION="ap-south-1"
BACKEND_ECR_URI=$(terraform -chdir=terraform output -raw ecr_backend_repository_uri)
FRONTEND_ECR_URI=$(terraform -chdir=terraform output -raw ecr_frontend_repository_uri)

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "${BACKEND_ECR_URI%/*}"

docker build -t $BACKEND_ECR_URI:latest ./application/backend
docker push $BACKEND_ECR_URI:latest

docker build -t $FRONTEND_ECR_URI:latest ./application/frontend
docker push $FRONTEND_ECR_URI:latest
```

### 3. Provision EKS Cluster via CloudFormation
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

### 4. Deploy Kubernetes Manifests on EKS
```bash
aws eks update-kubeconfig --region ap-south-1 --name observability-eks
./scripts/install-lb-controller.sh observability-eks ap-south-1
kubectl apply -f k8s/manifests/namespace.yaml
kubectl apply -f k8s/manifests/backend/
kubectl apply -f k8s/manifests/frontend/
kubectl apply -f k8s/manifests/ingress.yaml
```
