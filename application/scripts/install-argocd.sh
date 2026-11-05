#!/bin/bash
set -e

echo "=== Installing ArgoCD ==="

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Use --server-side --force-conflicts to bypass annotation size limits on large CRDs
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "=== ArgoCD installed successfully ==="
echo ""
echo "Get initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo ""
echo "Port forward to access UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Now create your ArgoCD Application pointing to:"
echo "  https://github.com/AbhishekChoudhary23/DevOps-Observability-k8s-gitops-manifest"