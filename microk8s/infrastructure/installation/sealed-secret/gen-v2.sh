#!/bin/bash

set -e

# ===== CONFIGURATION =====
ENV_FILE="${ENV_FILE:-.env}"
SECRET_NAME="${SECRET_NAME:-backend-dev-sealed-secret}"
NAMESPACE="${NAMESPACE:-backend-dev}"
TEMP_SECRET_FILE="temp-secret.yaml"
SEALED_SECRET_FILE="sealed-secret.yaml"
CERT_FILE="sealed-secrets.pem"
CONTROLLER_NAME="sealed-secrets"
CONTROLLER_NAMESPACE="kube-system"

# ===== CHECK DEPENDENCIES =====
for cmd in kubeseal; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ $cmd not found, please install it first."
    exit 1
  fi
done

# ===== FETCH CERT IF NOT EXISTS =====
if [[ ! -f "$CERT_FILE" ]]; then
  echo "📥 Fetching sealed secret cert..."
  kubeseal --fetch-cert \
    --controller-name="$CONTROLLER_NAME" \
    --controller-namespace="$CONTROLLER_NAMESPACE" \
    -o yaml > "$CERT_FILE"
  echo "✅ Cert saved to $CERT_FILE"
fi

# ===== CHECK .env FILE =====
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ $ENV_FILE not found in current directory."
  exit 1
fi

echo "🔄 Converting $ENV_FILE to Kubernetes Secret..."

# ===== BUILD TEMP SECRET FILE =====
cat <<EOF > "$TEMP_SECRET_FILE"
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
stringData:
EOF

while IFS='=' read -r key value; do
  if [[ "$key" != "" && "$key" != \#* ]]; then
    echo "  $key: \"$value\"" >> "$TEMP_SECRET_FILE"
  fi
done < "$ENV_FILE"

echo "🔐 Sealing the Secret..."

# ===== SEAL THE SECRET =====
kubeseal \
  --cert "$CERT_FILE" \
  --format yaml \
  -o yaml < "$TEMP_SECRET_FILE" > "$SEALED_SECRET_FILE"

echo "✅ SealedSecret YAML created: $SEALED_SECRET_FILE"

# ===== CLEAN UP =====
rm "$TEMP_SECRET_FILE"

# chmod +x gen-sealed-secret.sh
# ./gen-sealed-secret.sh

# ENV_FILE=".env.dev" SECRET_NAME="my-secret" NAMESPACE="my-namespace" ./gen-sealed-secret.sh
