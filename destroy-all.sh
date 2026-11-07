#!/bin/bash
# ==============================================================================
# AWS EKS Project Safe Teardown & Cost-Saving Script (destroy-all.sh)
# ==============================================================================
# Tears down ALL project resources in strict reverse-dependency order:
#   1. ArgoCD Applications (prevents re-creation of resources during teardown)
#   2. Kubernetes workloads, Ingress/ALBs, monitoring stack, ArgoCD itself
#   3. AWS Load Balancer Controller (Helm release + IRSA IAM role)
#   4. eksctl IRSA CloudFormation stacks
#   5. EKS CloudFormation stack (nodegroup, add-ons, control plane)
#   6. Orphaned AWS ALBs, Target Groups, Security Groups in the VPC
#   7. Terraform infrastructure (NAT Gateway, VPC, IAM, optionally ECR)
#
# Usage:
#   ./destroy-all.sh                  # Full teardown (keeps ECR images)
#   ./destroy-all.sh --destroy-ecr    # Full teardown including ECR repositories
# ==============================================================================

set -euo pipefail

export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

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

# ==============================================================================
# STEP 1: Delete ArgoCD Applications (stops GitOps from recreating resources)
# ==============================================================================
echo ""
echo "[1/7] Removing ArgoCD Applications & all Kubernetes workloads..."
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1 || true

  # --- Delete ALL ArgoCD Applications so ArgoCD doesn't re-sync while we tear down ---
  # The finalizer 'resources-finalizer.argocd.argoproj.io' on each Application
  # tells ArgoCD to cascade-delete the child resources (deployments, services, etc.)
  for APP_NAME in observability-platform monitoring-platform observability-app; do
    if kubectl get application "$APP_NAME" -n argocd >/dev/null 2>&1; then
      echo "  -> Deleting ArgoCD Application '$APP_NAME' (cascade-deletes managed resources)..."
      kubectl delete application "$APP_NAME" -n argocd --timeout=120s || true
    fi
  done

  # Catch any other ArgoCD Applications we may have missed
  REMAINING_APPS=$(kubectl get applications -n argocd -o name 2>/dev/null || true)
  if [[ -n "$REMAINING_APPS" ]]; then
    echo "  -> Deleting remaining ArgoCD applications..."
    kubectl delete applications --all -n argocd --timeout=120s || true
  fi

  echo "  -> Waiting 15 seconds for ArgoCD cascade deletions to propagate..."
  sleep 15
else
  echo "  -> EKS cluster '$CLUSTER_NAME' is not active or already deleted. Skipping kubectl cleanup."
fi

# ==============================================================================
# STEP 2: Clean up Ingress, Monitoring, and ArgoCD namespaces
# ==============================================================================
echo ""
echo "[2/7] Cleaning up Kubernetes Ingress, Monitoring stack, and ArgoCD..."
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then

  # --- Delete Ingress first so AWS LB Controller deprovisions the ALB ---
  if kubectl get ns observability >/dev/null 2>&1; then
    echo "  -> Deleting Ingress in namespace 'observability' to deprovision AWS ALB..."
    kubectl delete ingress --all -n observability --timeout=120s || true
    kubectl delete svc --all -n observability --timeout=60s || true
    kubectl delete deployments --all -n observability --timeout=60s || true
    kubectl delete hpa --all -n observability --timeout=30s || true
  fi

  # --- Delete Monitoring stack (Helm-based or declarative) ---
  if kubectl get ns monitoring >/dev/null 2>&1; then
    echo "  -> Removing Helm-based monitoring stack (if installed)..."
    helm uninstall monitoring -n monitoring --wait --timeout=120s 2>/dev/null || true

    echo "  -> Deleting all resources in 'monitoring' namespace..."
    kubectl delete deployments --all -n monitoring --timeout=60s || true
    kubectl delete svc --all -n monitoring --timeout=60s || true
    kubectl delete configmaps --all -n monitoring --timeout=30s || true
    kubectl delete serviceaccount prometheus -n monitoring --ignore-not-found=true || true
  fi

  # --- Delete ClusterRole/ClusterRoleBinding created by monitoring stack ---
  kubectl delete clusterrole prometheus-discovery-role --ignore-not-found=true || true
  kubectl delete clusterrolebinding prometheus-discovery-binding --ignore-not-found=true || true

  echo "  -> Waiting 45 seconds for AWS Load Balancer Controller to finish deleting ALB & ENIs..."
  sleep 45

  # --- Delete ArgoCD namespace ---
  if kubectl get ns argocd >/dev/null 2>&1; then
    echo "  -> Deleting ArgoCD namespace..."
    kubectl delete namespace argocd --timeout=120s || true
  fi

  # --- Delete workload namespaces ---
  for NS in observability monitoring; do
    if kubectl get ns "$NS" >/dev/null 2>&1; then
      echo "  -> Deleting namespace '$NS'..."
      kubectl delete namespace "$NS" --timeout=120s || true
    fi
  done
fi

# ==============================================================================
# STEP 3: Remove AWS Load Balancer Controller (Helm + IRSA IAM Role)
# ==============================================================================
echo ""
echo "[3/7] Removing AWS Load Balancer Controller..."
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  # Uninstall Helm release
  if helm status aws-load-balancer-controller -n kube-system >/dev/null 2>&1; then
    echo "  -> Uninstalling aws-load-balancer-controller Helm release..."
    helm uninstall aws-load-balancer-controller -n kube-system --wait --timeout=120s || true
  fi
fi

# Delete the IRSA IAM role created by install-lb-controller.sh
ROLE_NAME="${CLUSTER_NAME}-alb-controller-irsa-role"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null | tr -d '\r' || true)

if [[ -n "$ACCOUNT_ID" ]]; then
  if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "  -> Detaching policies and deleting IRSA role '$ROLE_NAME'..."
    # Detach all managed policies before deleting the role
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
      --role-name "$ROLE_NAME" \
      --query "AttachedPolicies[].PolicyArn" \
      --output text 2>/dev/null || true)
    for policy_arn in $ATTACHED_POLICIES; do
      aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy_arn" || true
    done
    aws iam delete-role --role-name "$ROLE_NAME" || true
  fi

  # Delete the standalone AWSLoadBalancerControllerIAMPolicy (if created by install-lb-controller.sh)
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
  if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
    echo "  -> Deleting IAM policy 'AWSLoadBalancerControllerIAMPolicy'..."
    aws iam delete-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1 || true
  fi
fi

# ==============================================================================
# STEP 4: Delete eksctl IAM ServiceAccount (IRSA) CloudFormation Stacks
# ==============================================================================
echo ""
echo "[4/7] Removing eksctl IAM ServiceAccount (IRSA) stacks if present..."
if command -v eksctl >/dev/null 2>&1; then
  eksctl delete iamserviceaccount \
    --cluster="$CLUSTER_NAME" \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --region="$AWS_REGION" 2>/dev/null || true
fi

# Delete any leftover eksctl-* CloudFormation stacks for this cluster
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

# ==============================================================================
# STEP 5: Delete the EKS CloudFormation Stack (Nodegroup, Add-ons, Control Plane)
# ==============================================================================
echo ""
echo "[5/7] Deleting EKS CloudFormation stack '$CFN_STACK_NAME'..."
if aws cloudformation describe-stacks --stack-name "$CFN_STACK_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  aws cloudformation delete-stack --stack-name "$CFN_STACK_NAME" --region "$AWS_REGION"
  echo "  -> Waiting for CloudFormation stack '$CFN_STACK_NAME' to finish deleting (takes ~10-12 mins)..."
  aws cloudformation wait stack-delete-complete --stack-name "$CFN_STACK_NAME" --region "$AWS_REGION"
  echo "  -> CloudFormation stack '$CFN_STACK_NAME' deleted."
else
  echo "  -> CloudFormation stack '$CFN_STACK_NAME' not found. Skipping."
fi

# ==============================================================================
# STEP 6: Clean Up Orphaned ALBs / Target Groups / Security Groups in VPC
# ==============================================================================
echo ""
echo "[6/7] Checking for any orphaned Load Balancers or Security Groups in the VPC..."
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
      # Delete listeners first to release target groups
      LISTENERS=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$alb_arn" \
        --region "$AWS_REGION" \
        --query "Listeners[].ListenerArn" \
        --output text 2>/dev/null || true)
      for listener_arn in $LISTENERS; do
        aws elbv2 delete-listener --listener-arn "$listener_arn" --region "$AWS_REGION" || true
      done
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

    # Delete any orphaned ENIs in the VPC (leftover from ALB/EKS)
    ORPHAN_ENIS=$(aws ec2 describe-network-interfaces \
      --region "$AWS_REGION" \
      --filters "Name=vpc-id,Values=${VPC_ID}" "Name=status,Values=available" \
      --query "NetworkInterfaces[].NetworkInterfaceId" \
      --output text 2>/dev/null || true)

    for eni_id in $ORPHAN_ENIS; do
      echo "  -> Deleting orphaned ENI: $eni_id"
      aws ec2 delete-network-interface --network-interface-id "$eni_id" --region "$AWS_REGION" 2>/dev/null || true
    done
  fi
fi

# ==============================================================================
# STEP 7: Destroy Terraform Resources (NAT Gateway, Elastic IP, VPC, IAM)
# ==============================================================================
echo ""
echo "[7/7] Destroying Terraform infrastructure..."
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
echo " Teardown Complete! All hourly-billed resources have been terminated:"
echo "   ✓ ArgoCD Applications (observability-platform, monitoring-platform)"
echo "   ✓ Monitoring Stack (Prometheus & Grafana)"
echo "   ✓ Application workloads (frontend, backend, HPA, Ingress)"
echo "   ✓ AWS Load Balancer Controller (Helm + IRSA IAM role)"
echo "   ✓ EKS Cluster (Control Plane, Node Group, Add-ons)"
echo "   ✓ CloudFormation & eksctl stacks"
echo "   ✓ Terraform resources (NAT Gateway, VPC, IAM)"
if [[ "$DESTROY_ECR" == "true" ]]; then
  echo "   ✓ ECR Repositories (destroyed)"
else
  echo "   ○ ECR Repositories (preserved — pass --destroy-ecr to remove)"
fi
echo "=================================================================="
