#!/bin/bash
set -euo pipefail

NAMESPACE="${1:-observability}"
GITHUB_USER="${2:-abhishekchoudhary23}"
GITHUB_PAT="${3:-${GITHUB_TOKEN:-}}"
GITHUB_EMAIL="${4:-abhishek@example.com}"

if [[ -z "$GITHUB_PAT" ]]; then
  echo "Error: GitHub Personal Access Token (with read:packages scope) is required."
  echo "Usage: ./scripts/create-ghcr-secret.sh <namespace> <github-username> <github-pat> [email]"
  echo "   or: export GITHUB_TOKEN=ghp_xxx && ./scripts/create-ghcr-secret.sh <namespace> <github-username>"
  exit 1
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry ghcr-pull-secret \
  --namespace="$NAMESPACE" \
  --docker-server=https://ghcr.io \
  --docker-username="$GITHUB_USER" \
  --docker-password="$GITHUB_PAT" \
  --docker-email="$GITHUB_EMAIL" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Successfully configured 'ghcr-pull-secret' imagePullSecret in namespace '$NAMESPACE' for ghcr.io."
