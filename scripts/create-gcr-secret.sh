#!/bin/bash
set -euo pipefail

NAMESPACE="${1:-observability}"
KEY_FILE="${2:-gcr-key.json}"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "Error: GCP Service Account JSON key file '$KEY_FILE' not found."
  echo "Usage: ./create-gcr-secret.sh <namespace> <path-to-gcr-key.json>"
  exit 1
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry gcr-json-key \
  --namespace="$NAMESPACE" \
  --docker-server=https://gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat "$KEY_FILE")" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Successfully configured 'gcr-json-key' imagePullSecret in namespace '$NAMESPACE'."
