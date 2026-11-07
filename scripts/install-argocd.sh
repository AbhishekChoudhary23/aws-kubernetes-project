#!/bin/bash
# ==============================================================================
# Production-Grade ArgoCD GitOps Bootstrapper (scripts/install-argocd.sh)
# ==============================================================================
# Run this script ONCE per cluster creation. After this runs, you NEVER need
# to run manual 'kubectl apply' commands for your app or monitoring stack again!
# Pushing changes to 'aws-prod' on GitHub will automatically deploy to EKS.
# ==============================================================================

set -euo pipefail

export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

CLUSTER_NAME="${1:-observability-eks}"
AWS_REGION="${2:-ap-south-1}"
GIT_BRANCH="${3:-aws-prod}"
REPO_URL="${4:-https://github.com/AbhishekChoudhary23/aws-kubernetes-project.git}"

echo "=== Bootstrapping ArgoCD GitOps Engine ==="
echo "Cluster:       $CLUSTER_NAME"
echo "Region:        $AWS_REGION"
echo "Target Branch: $GIT_BRANCH"
echo "Repo URL:      $REPO_URL"

# 1. Ensure kubeconfig is pointed at the cluster
echo ""
echo "[1/5] Updating kubeconfig..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# 2. Create argocd namespace and install ArgoCD
echo ""
echo "[2/5] Installing ArgoCD in namespace 'argocd'..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Wait for ArgoCD deployments to become ready
echo ""
echo "[3/5] Waiting for ArgoCD control plane to become Ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd

# 4. Tune ArgoCD polling interval to 30 seconds (default is 180s) for faster GitOps syncs
echo ""
echo "[4/5] Configuring 30-second Git polling interval on argocd-cm..."
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"timeout.reconciliation":"30s"}}' || true

# 5. Register the GitOps Application (watches k8s/manifests recursively on $GIT_BRANCH)
echo ""
echo "[5/5] Registering ArgoCD Application 'observability-platform' (branch: $GIT_BRANCH)..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-platform
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: ${GIT_BRANCH}
    path: k8s/manifests
    directory:
      recurse: true
    exclude: 'monitoring/**'
  destination:
    server: https://kubernetes.default.svc
    namespace: observability
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | tr -d '\r')

echo ""
echo "=================================================================="
echo " ArgoCD GitOps Engine Bootstrapped Successfully!"
echo "=================================================================="
echo "ArgoCD is now watching '$REPO_URL' (branch: '$GIT_BRANCH', path: 'k8s/manifests')."
echo "Every commit pushed to '$GIT_BRANCH' will automatically sync:"
echo "  - Namespaces:  observability & monitoring"
echo "  - Workloads:   frontend, backend, HPA, ALB Ingress"
echo "  - Monitoring:  Prometheus & Grafana (with pre-loaded SRE Dashboard)"
echo ""
echo "ArgoCD UI Login Details:"
echo "  Username: admin"
echo "  Password: $ADMIN_PASSWORD"
echo "  Command:  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  URL:      https://localhost:8080"
echo "=================================================================="