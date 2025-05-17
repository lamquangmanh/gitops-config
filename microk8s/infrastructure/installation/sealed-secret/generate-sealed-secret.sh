#!/bin/bash

# kubeseal --fetch-cert --controller-name=sealed-secrets-controller --controller-namespace=kube-system -o yaml > sealed-secrets.pem
kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=kube-system -o yaml > sealed-secrets.pem

set -e

ENV_FILE=".env"
SECRET_NAME="backend-dev-sealed-secret"
NAMESPACE="backend-dev"
TEMP_SECRET_FILE="temp-secret.yaml"
SEALED_SECRET_FILE="sealed-secret.yaml"

# Check for dependencies
for cmd in kubectl kubeseal; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ $cmd not found, please install it first."
    exit 1
  fi
done

# Validate .env file
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ .env file not found in current directory."
  exit 1
fi

echo "🔄 Converting .env to Kubernetes Secret..."

# Build stringData from .env
echo "apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
stringData:" > "$TEMP_SECRET_FILE"

while IFS='=' read -r key value; do
  if [[ "$key" != "" && "$key" != \#* ]]; then
    echo "  $key: \"$value\"" >> "$TEMP_SECRET_FILE"
  fi
done < "$ENV_FILE"

echo "🔐 Sealing the Secret..."

kubeseal \
  --cert sealed-secrets.pem \
  --format yaml \
  -o yaml < "$TEMP_SECRET_FILE" > sealed-secret.yaml

# kubeseal \
  # --cert cert.pem \
  # --format=yaml \
  # --controller-namespace kube-system \
  # --controller-name sealed-secrets-controller \
  # -o yaml < "$TEMP_SECRET_FILE" > "$SEALED_SECRET_FILE"

echo "✅ SealedSecret YAML created: $SEALED_SECRET_FILE"

# Clean up temp file
rm "$TEMP_SECRET_FILE"