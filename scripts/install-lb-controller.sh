#!/bin/bash
# ==============================================================================
# Bulletproof AWS Load Balancer Controller Installer (install-lb-controller.sh)
# ==============================================================================
# Compatible with Windows Git Bash (MINGW64), macOS, and Linux:
# 1. Sets MSYS_NO_PATHCONV=1 and passes JSON policies inline via variables
#    (avoiding Windows AWS CLI file:///tmp/... path translation errors).
# 2. Strips Windows CR (\r) from AWS CLI outputs on Git Bash.
# 3. Creates the IAM OIDC Provider on the cluster if missing.
# 4. Creates/Updates the IAM Role directly via AWS CLI (bypassing eksctl's
#    "1 existing iamserviceaccount will be excluded -> no tasks" issue).
# 5. Passes --set vpcId=<VPC_ID> to Helm so the controller never crashes on
#    AL2023 nodes with IMDSv2 hop-limit=1 metadata errors.
# 6. Cleans up any stuck/failed Helm release before installing and lets Helm
#    manage the Kubernetes ServiceAccount natively.
# ==============================================================================

set -euo pipefail

# Prevent Git Bash (MINGW64) from mangling Linux paths or arguments
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

CLUSTER_NAME="${1:-observability-eks}"
AWS_REGION="${2:-ap-south-1}"
NAMESPACE="kube-system"
SA_NAME="aws-load-balancer-controller"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
ROLE_NAME="${CLUSTER_NAME}-alb-controller-irsa-role"

# Strip any trailing \r from AWS CLI outputs on Windows Git Bash (MINGW64)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text | tr -d '\r')
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "=== Installing AWS Load Balancer Controller ==="
echo "Cluster: $CLUSTER_NAME"
echo "Region:  $AWS_REGION"
echo "Account: $ACCOUNT_ID"

# --------------------------------------------------
# 1. Verify Kubernetes connectivity & get VPC_ID + OIDC
# --------------------------------------------------
echo ""
echo "[1/7] Checking EKS connectivity & cluster metadata..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl get nodes

VPC_ID=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text | tr -d '\r')

OIDC_ISSUER=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" \
  --output text | tr -d '\r')

OIDC_ID="${OIDC_ISSUER##*/}"
OIDC_PROVIDER="${OIDC_ISSUER#https://}"

echo "  -> VPC ID:        $VPC_ID"
echo "  -> OIDC Provider: $OIDC_PROVIDER"

# --------------------------------------------------
# 2. Ensure IAM OIDC Provider is associated with EKS
# --------------------------------------------------
echo ""
echo "[2/7] Checking IAM OIDC Provider for cluster..."
if ! aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?ends_with(Arn, '${OIDC_ID}')].Arn" --output text | grep -q "$OIDC_ID"; then
  echo "  -> Associating IAM OIDC provider via eksctl..."
  eksctl utils associate-iam-oidc-provider \
    --region="$AWS_REGION" \
    --cluster="$CLUSTER_NAME" \
    --approve
else
  echo "  -> IAM OIDC Provider already exists."
fi

# --------------------------------------------------
# 3. Create IAM Policy if it does not exist (Inline JSON, no /tmp file issues)
# --------------------------------------------------
echo ""
echo "[3/7] Checking IAM Policy ($POLICY_NAME)..."
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  echo "  -> Downloading and creating $POLICY_NAME..."
  IAM_POLICY_JSON=$(curl -fsSL https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "$IAM_POLICY_JSON" >/dev/null
else
  echo "  -> IAM Policy already exists: $POLICY_ARN"
fi

# --------------------------------------------------
# 4. Create or Update IRSA IAM Role & Trust Policy (Inline JSON, no /tmp file issues)
# --------------------------------------------------
echo ""
echo "[4/7] Configuring IAM Role ($ROLE_NAME) with OIDC trust policy..."
TRUST_POLICY_JSON=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com",
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${NAMESPACE}:${SA_NAME}"
        }
      }
    }
  ]
}
EOF
)

if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "  -> Creating IAM Role $ROLE_NAME..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY_JSON" >/dev/null
else
  echo "  -> Updating AssumeRole trust policy on $ROLE_NAME for current cluster OIDC..."
  aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document "$TRUST_POLICY_JSON"
fi

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "$POLICY_ARN"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "  -> IAM Role ready: $ROLE_ARN"

# --------------------------------------------------
# 5. Clean up any broken/stuck Helm release or Deployment
# --------------------------------------------------
echo ""
echo "[5/7] Checking for stuck previous deployment..."
if helm status aws-load-balancer-controller -n "$NAMESPACE" >/dev/null 2>&1; then
  if ! kubectl rollout status deployment/aws-load-balancer-controller -n "$NAMESPACE" --timeout=5s >/dev/null 2>&1; then
    echo "  -> Removing previous failed/stuck aws-load-balancer-controller release..."
    helm uninstall aws-load-balancer-controller -n "$NAMESPACE" --wait || true
    kubectl delete serviceaccount "$SA_NAME" -n "$NAMESPACE" --ignore-not-found=true || true
  fi
else
  # Remove any manually created ServiceAccount so Helm can own it cleanly with labels
  kubectl delete serviceaccount "$SA_NAME" -n "$NAMESPACE" --ignore-not-found=true || true
fi

# --------------------------------------------------
# 6. Install AWS Load Balancer Controller via Helm
# --------------------------------------------------
echo ""
echo "[6/7] Installing AWS Load Balancer Controller via Helm..."
helm repo add eks https://aws.github.io/eks-charts --force-update
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace "$NAMESPACE" \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=true \
  --set serviceAccount.name="$SA_NAME" \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${ROLE_ARN}" \
  --wait \
  --timeout=5m

# --------------------------------------------------
# 7. Verify Rollout & Webhook Readiness
# --------------------------------------------------
echo ""
echo "[7/7] Verifying controller deployment & pods..."
kubectl rollout status deployment/aws-load-balancer-controller -n "$NAMESPACE" --timeout=120s
kubectl get serviceaccount "$SA_NAME" -n "$NAMESPACE" -o yaml | grep -A 2 "annotations:" || true
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=aws-load-balancer-controller

echo "=== AWS Load Balancer Controller installed and Running! ==="