How to install Gloo Gateway

```
# https://docs.solo.io/gloo-mesh-gateway/latest/setup/install/single-cluster/
helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update

helm install gloo gloo/gloo \
  --namespace gloo-system \
  --create-namespace \
  -f gloo-values.yaml \
  # Default using bellow for LoadBalancer
  --set gatewayProxies.gatewayProxy.service.type=LoadBalancer

  # Or use NodePort if you're in Minikube/k3s
  --set gatewayProxies.gatewayProxy.service.type=NodePort


INSTALLATION FAILED: cannot re-use a name that is still in use

means that **a Helm release named `gloo` already exists** in the `gloo-system` namespace, and you're trying to install it again with the same name.

### ✅ To fix it, you have a few options:
---

### 🔸 **Option 1: Upgrade the existing release**

If you want to apply new config values (e.g., `gloo-values.yaml`), use:

helm upgrade gloo gloo/gloo \
  --namespace gloo-system \
  -f gloo-values.yaml \
  --set gatewayProxies.gatewayProxy.service.type=NodePort

---

### 🔸 **Option 2: Uninstall the existing release and reinstall**

If you want a clean reinstall:

helm uninstall gloo --namespace gloo-system

Then reinstall:

helm install gloo gloo/gloo \
  --namespace gloo-system \
  --create-namespace \
  -f gloo-values.yaml \
  --set gatewayProxies.gatewayProxy.service.type=NodePort

---

### 🔸 **Option 3: Use a different release name**

helm install gloo-new gloo/gloo \
  --namespace gloo-system \
  --create-namespace \
  -f gloo-values.yaml \
  --set gatewayProxies.gatewayProxy.service.type=NodePort


```

## I aiming to use **Gloo Gateway as an API Gateway** with the following **routing + security policy**:

### ✅ My goal:

1. **All GraphQL/API requests** → must go through **OPA** for authorization (RBAC check).
2. **All public page requests (Next.js)** → should go **directly to the frontend service**, bypassing OPA.
3. I want to define this routing **via Gloo Gateway**.

---

This is **absolutely achievable** with Gloo Gateway + OPA using **WASM filters or an external authorization service**, and I’ll break it into **2 major parts**.

---

## ✅ Option 1: Gloo Gateway with OPA via External Auth (Recommended Approach)

### 🎯 Architecture Overview:

```plaintext
                      ┌──────────────┐
                      │  Cloudflare  │
                      └─────┬────────┘
                            │ demo-dev.manhlam.name.vn
                            ▼
                   ┌─────────────────────┐
                   │   Gloo Gateway      │
                   └─────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        ▼                                       ▼
┌────────────────────┐              ┌────────────────────┐
│  AuthZ via OPA     │              │  Frontend (Next.js) │
│  (GraphQL only)    │              │  (Static/SSR pages) │
└────────────────────┘              └────────────────────┘
```

---

## 🧩 Step-by-Step Setup

### 1. **Install Gloo Gateway with ExtAuth enabled**

Update your `gloo-values.yaml`:

```yaml
gatewayProxies:
  gatewayProxy:
    service:
      type: NodePort
      httpPort: 32080
      httpsPort: 32443

gloo:
  gateway:
    validation:
      alwaysAcceptResources: true
    proxyServiceAccount:
      create: true

    enableRestEds: true

settings:
  create: true

extauth:
  enabled: true
  allowPartialRouteMatch: true
```

Then install:

```bash
helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update

# Run install if not install gloo before
helm install gloo gloo/gloo \
  --namespace gloo-system \
  --create-namespace \
  -f gloo-values.yaml

# Run upgrade if you already install gloo
helm upgrade gloo gloo/gloo \
  --namespace gloo-system \
  -f gloo-values.yaml

```

---

### 2. **Deploy OPA as an external auth server**

You’ll run OPA with a policy like this (e.g. `authz.rego`):

```rego
package authz

default allow = false

allow {
  input.method == "POST"
  startswith(input.path[0], "graphql")
  input.user.role == "admin"
}
```

OPA should expose `/v1/data/authz/allow` to be used by Gloo.

---

### 3. **Create an `ExtAuthConfig` in Gloo**

```yaml
apiVersion: enterprise.gloo.solo.io/v1
kind: ExtAuthConfig
metadata:
  name: opa-auth
  namespace: gloo-system
spec:
  grpc:
    serverRef:
      name: opa-auth-service
      namespace: gloo-system
```

Or use REST if your OPA uses HTTP.

---

### 4. **VirtualService Example**

```yaml
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: frontend-vs
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - demo-dev.manhlam.name.vn
    routes:
      # GraphQL requests go through OPA
      - matchers:
          - prefix: /graphql
        options:
          extauth:
            configRef:
              name: opa-auth
              namespace: gloo-system
        routeAction:
          single:
            upstream:
              name: backend-dev-demo-be-svc-3000
              namespace: gloo-system

      # Frontend app (Next.js)
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: frontend-dev-frontend-svc-3000
              namespace: gloo-system
```

---

## ✅ Result:

- Requests to `/graphql` are forwarded to backend **only if OPA allows**.
- Other requests (e.g., `/about`, `/login`, `/`) go straight to **Next.js frontend**, no OPA check.
