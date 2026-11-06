# AWS EKS Observability Project (GHCR + Terraform + CloudFormation + Kubernetes)

## Architecture Overview
- **Infrastructure Layer (`terraform/`)**: Provisions the AWS VPC, public/private subnets across 2 Availability Zones, NAT Gateway, and least-privilege IAM roles (`eks-cluster-role` and `eks-node-role`).
- **EKS Cluster Layer (`cloudformation/observability-eks.yaml`)**: Provisions the Amazon EKS control plane, control plane security group, pre-node networking add-ons (`vpc-cni`, `kube-proxy`, `eks-pod-identity-agent`), managed node group (`AL2023_x86_64_STANDARD`), post-node add-ons (`coredns`, `eks-node-monitoring-agent`), and the `AWSLoadBalancerControllerIAMPolicy`.
- **Container Registry (GitHub Container Registry - `ghcr.io`)**: Application images are built and pushed to `ghcr.io/abhishekchoudhary23/...` and pulled into EKS using a `kubernetes.io/dockerconfigjson` secret (`ghcr-pull-secret`).
- **Kubernetes Workloads (`k8s/manifests/`)**: Production-hardened deployments, ClusterIP services, HorizontalPodAutoscalers, and an AWS ALB Ingress resource routing `/api` to the Node.js backend and `/` to the Nginx frontend.

## Step-by-Step Deployment

### 1. Build & Push Images to GitHub Container Registry (GHCR)
```bash
export GITHUB_TOKEN="ghp_your_personal_access_token"
echo "$GITHUB_TOKEN" | docker login ghcr.io -u abhishekchoudhary23 --password-stdin

docker build -t ghcr.io/abhishekchoudhary23/observability-backend:latest ./application/backend
docker push ghcr.io/abhishekchoudhary23/observability-backend:latest

docker build -t ghcr.io/abhishekchoudhary23/observability-frontend:latest ./application/frontend
docker push ghcr.io/abhishekchoudhary23/observability-frontend:latest
```

### 2. Provision Base Network & IAM via Terraform
```bash
cd terraform
terraform init
terraform apply
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

### 4. Configure GHCR Image Pull Secret & Deploy Manifests
```bash
aws eks update-kubeconfig --region ap-south-1 --name observability-eks
./scripts/create-ghcr-secret.sh observability abhishekchoudhary23 "$GITHUB_TOKEN"
kubectl apply -f k8s/manifests/namespace.yaml
kubectl apply -f k8s/manifests/backend/
kubectl apply -f k8s/manifests/frontend/
kubectl apply -f k8s/manifests/ingress.yaml
```
