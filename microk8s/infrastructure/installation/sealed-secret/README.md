Based on `.env`, here's how you can manage these environment variables **securely** in Kubernetes using a `SealedSecret`.

---

### ✅ Example: Convert `.env` to `Secret` and then `SealedSecret`

#### Step 1: Create a Kubernetes `Secret` from `.env`

First, create a Kubernetes Secret using the `.env`:

```bash
kubectl create secret generic app-env-secret \
  --from-env-file=.env \
  --dry-run=client -o yaml > app-secret.yaml
```

#### Step 2: Convert it to `SealedSecret`

Now encrypt it using `kubeseal`:

```bash
kubeseal --format yaml < app-secret.yaml > sealed-app-secret.yaml
```

You now have a file `sealed-app-secret.yaml` like this:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: app-env-secret
  namespace: default
spec:
  encryptedData:
    NODE_ENV: AgByFj...
    PORT: AgCfs8...
    GRPC_HOST: AgB2r...
    # ...
    REDIS_PASSWORD: AgAF9p...
  template:
    metadata:
      name: app-env-secret
      namespace: default
    type: Opaque
```

> **Note:** Any empty values like `DB_PASS=` or `REDIS_PASSWORD=` will still be included as empty strings unless omitted.

---

### ✅ Use Secret in your Deployment

Then in your deployment YAML:

```yaml
envFrom:
  - secretRef:
      name: app-env-secret
```

This will load all variables from the secret into the container environment, just like a `.env` file.

---

Here's a **ready-to-use script** that converts a `.env` file into a **Kubernetes SealedSecret** YAML, using Bitnami’s `kubeseal` and `kubectl`.

### ✅ Prerequisites

1. You have `kubectl` configured and access to the cluster.
2. `kubeseal` CLI installed (from [https://github.com/bitnami-labs/sealed-secrets](https://github.com/bitnami-labs/sealed-secrets)).
3. The **Sealed Secrets controller** is already installed in your cluster.

---

### 🛠️ Script: `.env` → SealedSecret YAML

Save this as `generate-sealed-secret.sh`:

```bash
#!/bin/bash

set -e

ENV_FILE=".env"
SECRET_NAME="my-sealed-secret"
NAMESPACE="default"
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
  --format=yaml \
  --controller-namespace kube-system \
  --controller-name sealed-secrets-controller \
  -o yaml < "$TEMP_SECRET_FILE" > "$SEALED_SECRET_FILE"

echo "✅ SealedSecret YAML created: $SEALED_SECRET_FILE"

# Clean up temp file
rm "$TEMP_SECRET_FILE"
```

---

### 📦 Example Output

This script will generate a `sealed-secret.yaml` file like:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-sealed-secret
  namespace: default
spec:
  encryptedData:
    NODE_ENV: AgBz...
    PORT: AgBz...
```

---

### 🧪 Apply with ArgoCD or Kubectl

You can:

- Commit `sealed-secret.yaml` to your GitOps repo (for ArgoCD to sync)
- Or apply it directly:

  ```bash
  kubectl apply -f sealed-secret.yaml
  ```
