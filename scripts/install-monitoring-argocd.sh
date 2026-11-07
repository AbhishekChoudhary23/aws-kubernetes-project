echo ""
echo "Registering ArgoCD Application 'monitoring-platform'..."

GIT_BRANCH="${1:-aws-prod}"
REPO_URL="${2:-https://github.com/AbhishekChoudhary23/aws-kubernetes-project.git}"

echo "=== Bootstrapping Monitoring ArgoCD GitOps Engine ==="
echo "Target Branch: $GIT_BRANCH"
echo "Repo URL:      $REPO_URL"

kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-platform
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: ${GIT_BRANCH}
    path: k8s/manifests/monitoring
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF