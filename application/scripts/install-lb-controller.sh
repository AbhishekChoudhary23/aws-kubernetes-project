# #!/bin/bash
# set -e

# CLUSTER_NAME="${1:-observability-eks}"
# AWS_REGION="${2:-ap-south-1}"
# ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# echo "=== Installing AWS Load Balancer Controller ==="
# echo "Cluster: $CLUSTER_NAME | Region: $AWS_REGION | Account: $ACCOUNT_ID"

# # Create IAM policy for LB Controller
# curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# aws iam create-policy \
#   --policy-name AWSLoadBalancerControllerIAMPolicy \
#   --policy-document file://iam-policy.json 2>/dev/null || echo "Policy already exists"

# # Create service account with IRSA
# eksctl create iamserviceaccount \
#   --cluster=$CLUSTER_NAME \
#   --namespace=kube-system \
#   --name=aws-load-balancer-controller \
#   --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
#   --override-existing-serviceaccounts \
#   --region=$AWS_REGION \
#   --approve 2>/dev/null || echo "Service account may already exist"

# # Install using Helm
# helm repo add eks https://aws.github.io/eks-charts
# helm repo update

# helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
#   -n kube-system \
#   --set clusterName=$CLUSTER_NAME \
#   --set serviceAccount.create=false \
#   --set serviceAccount.name=aws-load-balancer-controller \
#   --set region=$AWS_REGION

# echo "=== AWS Load Balancer Controller installed ==="



#!/bin/bash
set -e

# Pass parameters or use defaults
CLUSTER_NAME="${1:-observability-eks}"
AWS_REGION="${2:-ap-south-1}"

echo "=== AWS Load Balancer Controller Installation ==="
echo "Cluster : $CLUSTER_NAME"
echo "Region  : $AWS_REGION"

# 1. Fetch AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account : $ACCOUNT_ID"

# 2. Fetch VPC ID (Fixed syntax: --output text)
echo "Fetching Cluster VPC ID..."
VPC_ID=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)
echo "VPC ID  : $VPC_ID"

# 3. Create IAM Policy
echo "Checking IAM Policy..."
curl -s -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json 2>/dev/null || echo "Policy 'AWSLoadBalancerControllerIAMPolicy' already exists."

# 4. Create ServiceAccount & IRSA
echo "Configuring IRSA ServiceAccount via eksctl..."
eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy" \
  --override-existing-serviceaccounts \
  --region="$AWS_REGION" \
  --approve

# 5. Helm Repository Setup
echo "Updating Helm Repositories..."
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

# 6. Helm Install / Upgrade
echo "Deploying Helm Chart..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID"

# 7. Rollout Check
echo "Waiting for pods to become ready..."
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s

echo "=== Installation complete! ==="