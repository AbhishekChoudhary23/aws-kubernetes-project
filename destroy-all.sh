#!/bin/bash
# ==============================================================================
# AWS EKS Project Safe Teardown & Cost-Saving Script (destroy-all.sh)
# ==============================================================================
# Tears down Kubernetes Ingress/ALBs, eksctl IRSA stacks, the EKS CloudFormation
# stack, and Terraform networking/NAT Gateway resources in strict reverse order
# so no orphaned Load Balancers, ENIs, or Security Groups block VPC deletion.
#
# Usage:
#   ./scripts/destroy-all.sh                  # Full teardown (keeps ECR images by default)
#   ./scripts/destroy-all.sh --destroy-ecr    # Full teardown including ECR repositories
# ==============================================================================

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-observability-eks}"
CFN_STACK_NAME="${CFN_STACK_NAME:-observability-eks-stack}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
TERRAFORM_DIR="${TERRAFORM_DIR:-terraform}"
DESTROY_ECR=false

for arg in "$@"; do
  case $arg in
    --destroy-ecr)
      DESTROY_ECR=true
      shift
      ;;
  esac
done

echo "=================================================================="
echo " Starting Safe Teardown for AWS EKS Project"
echo " Cluster:          $CLUSTER_NAME"
echo " CloudFormation:   $CFN_STACK_NAME"
echo " Region:           $AWS_REGION"
echo " Destroy ECR:      $DESTROY_ECR"
echo "=================================================================="

# ------------------------------------------------------------------------------
# STEP 1: Delete ArgoCD App & K8s Ingress (Triggers AWS ALB Controller to delete
#         external AWS Application Load Balancers, Target Groups & ENIs)
# ------------------------------------------------------------------------------
echo ""
echo "[1/5] Cleaning up Kubernetes Ingress & ArgoCD resources..."
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1 || true

  # Remove ArgoCD application first so it doesn't recreate the Ingress
  if kubectl get application observability-app -n argocd >/dev/null 2>&1; then
    echo "  -> Deleting ArgoCD application (observability-app)..."
    kubectl delete application observability-app -n argocd --timeout=60s || true
  fi

  # Delete Ingress & TargetGroupBindings so AWS Load Balancer Controller deletes the AWS ALB
  if kubectl get ns observability >/dev/null 2>&1; then
    echo "  -> Deleting Ingress in namespace 'observability' to deprovision AWS ALB..."
    kubectl delete ingress --all -n observability --timeout=120s || true
    kubectl delete svc --all -n observability --timeout=60s || true
    echo "  -> Waiting 45 seconds for AWS Load Balancer Controller to finish deleting the ALB & ENIs..."
    sleep 45
  fi
else
  echo "  -> EKS cluster '$CLUSTER_NAME' is not active or already deleted. Skipping kubectl cleanup."
fi

# ------------------------------------------------------------------------------
# STEP 2: Delete eksctl IAM ServiceAccount (IRSA) CloudFormation Stack
# ------------------------------------------------------------------------------
echo ""
echo "[2/5] Removing eksctl IAM ServiceAccount (IRSA) stack if present..."
if command -v eksctl >/dev/null 2>&1; then
  eksctl delete iamserviceaccount \
    --cluster="$CLUSTER_NAME" \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --region="$AWS_REGION" 2>/dev/null || true
fi

# Also check for any leftover eksctl-* CloudFormation stacks for this cluster
EKSCTL_STACKS=$(aws cloudformation list-stacks \
  --region "$AWS_REGION" \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE \
  --query "StackSummaries[?starts_with(StackName, 'eksctl-${CLUSTER_NAME}-')].StackName" \
  --output text 2>/dev/null || true)

for stack in $EKSCTL_STACKS; do
  echo "  -> Deleting eksctl stack: $stack"
  aws cloudformation delete-stack --stack-name "$stack" --region "$AWS_REGION"
  aws cloudformation wait stack-delete-complete --stack-name "$stack" --region "$AWS_REGION" || true
done

# ------------------------------------------------------------------------------
# STEP 3: Delete the EKS CloudFormation Stack (Nodegroup, Add-ons, Control Plane)
# ------------------------------------------------------------------------------
echo ""
echo "[3/5] Deleting EKS CloudFormation stack '$CFN_STACK_NAME'..."
if aws cloudformation describe-stacks --stack-name "$CFN_STACK_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  aws cloudformation delete-stack --stack-name "$CFN_STACK_NAME" --region "$AWS_REGION"
  echo "  -> Waiting for CloudFormation stack '$CFN_STACK_NAME' to finish deleting (takes ~10-12 mins)..."
  aws cloudformation wait stack-delete-complete --stack-name "$CFN_STACK_NAME" --region "$AWS_REGION"
  echo "  -> CloudFormation stack '$CFN_STACK_NAME' deleted."
else
  echo "  -> CloudFormation stack '$CFN_STACK_NAME' not found. Skipping."
fi

# ------------------------------------------------------------------------------
# STEP 4: Clean Up Any Orphaned ALB / Security Groups Tagged by Kubernetes in VPC
# ------------------------------------------------------------------------------
echo ""
echo "[4/5] Checking for any orphaned Load Balancers or Security Groups in the VPC..."
if [[ -d "$TERRAFORM_DIR" ]]; then
  VPC_ID=$(terraform -chdir="$TERRAFORM_DIR" output -raw vpc_id 2>/dev/null || true)
  if [[ -n "$VPC_ID" && "$VPC_ID" != *"No outputs"* ]]; then
    # Delete any orphaned ALBs in the VPC
    ORPHAN_ALBS=$(aws elbv2 describe-load-balancers \
      --region "$AWS_REGION" \
      --query "LoadBalancers[?VpcId=='${VPC_ID}'].LoadBalancerArn" \
      --output text 2>/dev/null || true)

    for alb_arn in $ORPHAN_ALBS; do
      echo "  -> Deleting orphaned ALB: $alb_arn"
      aws elbv2 delete-load-balancer --load-balancer-arn "$alb_arn" --region "$AWS_REGION" || true
    done

    if [[ -n "$ORPHAN_ALBS" ]]; then
      echo "  -> Waiting 30 seconds for orphaned ALB network interfaces to detach..."
      sleep 30
    fi

    # Delete any orphaned Target Groups in the VPC
    ORPHAN_TGS=$(aws elbv2 describe-target-groups \
      --region "$AWS_REGION" \
      --query "TargetGroups[?VpcId=='${VPC_ID}'].TargetGroupArn" \
      --output text 2>/dev/null || true)

    for tg_arn in $ORPHAN_TGS; do
      echo "  -> Deleting orphaned Target Group: $tg_arn"
      aws elbv2 delete-target-group --target-group-arn "$tg_arn" --region "$AWS_REGION" || true
    done

    # Delete any orphaned k8s-created security groups (excluding default)
    ORPHAN_SGS=$(aws ec2 describe-security-groups \
      --region "$AWS_REGION" \
      --filters "Name=vpc-id,Values=${VPC_ID}" \
      --query "SecurityGroups[?GroupName!='default'].GroupId" \
      --output text 2>/dev/null || true)

    for sg_id in $ORPHAN_SGS; do
      echo "  -> Deleting leftover security group in VPC: $sg_id"
      aws ec2 delete-security-group --group-id "$sg_id" --region "$AWS_REGION" 2>/dev/null || true
    done
  fi
fi

# Also remove standalone AWSLoadBalancerControllerIAMPolicy if created by install-lb-controller.sh
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)
if [[ -n "$ACCOUNT_ID" ]]; then
  aws iam delete-policy \
    --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy" >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# STEP 5: Destroy Terraform Resources (NAT Gateway, Elastic IP, VPC, IAM)
# ------------------------------------------------------------------------------
echo ""
echo "[5/5] Destroying Terraform infrastructure..."
if [[ -d "$TERRAFORM_DIR" ]]; then
  if [[ "$DESTROY_ECR" == "true" ]]; then
    echo "  -> Running full 'terraform destroy' (including ECR repositories)..."
    terraform -chdir="$TERRAFORM_DIR" destroy -auto-approve
  else
    echo "  -> Destroying VPC, NAT Gateway, Subnets, and IAM roles while preserving ECR images for tomorrow..."
    terraform -chdir="$TERRAFORM_DIR" destroy -auto-approve \
      -target=module.vpc \
      -target=module.iam
  fi
fi

echo ""
echo "=================================================================="
echo " Teardown Complete! All hourly-billed resources (EKS Control Plane,"
echo " EC2 Worker Nodes, Application Load Balancer, and NAT Gateway)"
echo " have been terminated."
echo "=================================================================="