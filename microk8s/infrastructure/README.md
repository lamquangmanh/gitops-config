### 🔁 Infrastructure Flow

1. **GitHub Repo (`gitops-config`)**
   → Stores all Kubernetes manifests (microk8s/microservices, microk8s/infrastructure).

2. **GitHub Actions**
   → Triggered on changes to `gitops-config` repo (e.g., push to `main`).
   → Deploys changes to ArgoCD (via `kubectl apply` or ArgoCD CLI).

3. **ArgoCD**
   → Syncs the manifests into your local K3s Kubernetes cluster.
   → Deploys:

   - Traefik
   - OPA (Open Policy Agent)
   - Your microservices (e.g., User Service (FE, BFF, BE), etc.)

4. **Traefik**
   → Acts as the API gateway for all incoming traffic.
   → Forwards requests to OPA for authorization.

5. **OPA (Open Policy Agent)**
   → Runs Rego policies to make authorization decisions.
   → Calls the User Service over HTTP to validate the user/token/roles.

6. **User Service**
   → Responds to OPA with permission check results.

7. **Microservice**
   → Request proceeds to the appropriate backend if authorized.

---

### 🗂️ Text-Based Flow Diagram

```text
[ Developer ]
     |
     v
[ Push to gitops-config repo ]
     |
     v
[ GitHub Actions ]
     |
     v
[ ArgoCD (in Microk8s) ]
     |
     v
+-------------------+
|   Kubernetes      |
| +---------------+ |         +------------------+
| |    Traefik    |<--------->| OPA (Auth Policy)|
| +-------+-------+ |               |
|         |         |               v
|         v         |         [ HTTP call ]
|   +-----------+   |         to User Service
|   | Services  |   |               |
|   +-----------+   |               v
|                   |      [ Response: Allow/Deny ]
+-------------------+
```

### 🔧 **Architecture Overview**

1. **GitHub (gitops-config repo)**: Stores all Kubernetes manifests.
2. **GitHub Actions**: Triggers deployment by updating ArgoCD configuration.
3. **ArgoCD**: Deploys all components to Microk8s.
4. **Gloo Gateway** or **Traefik**: Handles ingress traffic.
5. **OPA (Open Policy Agent)**: Enforces access control.
6. **User Service**: Provides user permissions for OPA.
7. **Destination Microservices**: E.g., Order Service, Product Service, etc.

---

### 🗂️ **Directory Structure in `gitops-config`**

```
gitops-config/
├── apps/
│   ├── gloo-gateway/
│   ├── opa/
│   ├── microservices/
│   │   ├── order-service/
│   │   ├── user-service/
│   │   └── product-service/
├── base/
│   ├── gloo-gateway/
│   ├── opa/
│   ├── user-service/
│   ├── order-service/
│   └── product-service/
└── argocd/
    ├── app-of-apps.yaml
```

---

### 🧩 **1. App of Apps (ArgoCD)**

```yaml
# argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://github.com/your-username/gitops-config.git
    targetRevision: HEAD
    path: apps
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

### 🧭 **2. Gloo Gateway App or Traefik**

```yaml
# apps/gloo-gateway/gloo.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gloo-gateway
  namespace: argocd
spec:
  destination:
    namespace: gloo-system
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://github.com/your-username/gitops-config.git
    targetRevision: HEAD
    path: base/gloo-gateway
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

> Gloo Gateway should be installed via Helm or its manifest under `base/gloo-gateway`.

---

### 🔒 **3. OPA Policy Enforcement**

OPA ConfigMap with policy:

```rego
# base/opa/policy.rego
package authz

default allow = false

allow {
  input.method = "GET"
  input.path = ["orders"]
  user_has_permission
}

user_has_permission {
  http.send({
    "method": "GET",
    "url": "http://user-service.default.svc.cluster.local/check",
    "headers": {
      "Authorization": input.headers.Authorization
    }
  }).body.allowed == true
}
```

OPA Deployment should mount this policy.

---

### 👤 **4. User Service (Mock)**

- Create a simple service that listens on `/check` and returns user permissions.
- You can write this in NestJS or Express.

---

### 🔀 **5. Routing Example with Gloo Gateway**

Define a `VirtualService` in Gloo that routes to OPA:

```yaml
# base/gloo-gateway/virtual-service.yaml
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: default
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /orders
        options:
          extauth:
            config:
              name: opa-auth-config
              namespace: gloo-system
        routeAction:
          single:
            upstream:
              name: default-order-service-8080
              namespace: gloo-system
```

OPA Auth Config in Gloo:

```yaml
# base/gloo-gateway/opa-auth-config.yaml
apiVersion: enterprise.gloo.solo.io/v1
kind: ExtAuthConfig
metadata:
  name: opa-auth-config
  namespace: gloo-system
spec:
  opaAuth:
    modules:
      - name: authz
        namespace: default
        configMapRef:
          name: opa-policy
```

Great — since your client might send **HTTP** or **GraphQL** requests, and you want OPA to **check user permissions via an external User Service**, here’s how you can write a versatile `policy.rego` file that handles both cases:

---

### ✅ Assumptions:

- The client request includes a JWT in the `Authorization` header.
- For **GraphQL**, the body will contain a `{ "query": "..." }` payload.
- You forward the raw request (method, path, headers, body) to OPA.
- OPA makes an HTTP call to the **User Service** to validate permissions.

---

### 📜 `policy.rego`

```rego
package authz

default allow = false

# Main rule
allow {
  is_valid_user
  user_has_permission
}

# Validate token with User Service
is_valid_user {
  some resp
  resp := http.send({
    "method": "GET",
    "url": "http://user-service.default.svc.cluster.local/check",
    "headers": {
      "Authorization": input.headers.Authorization
    }
  })
  resp.status_code == 200
}

# Define user permissions based on route or GraphQL operation
user_has_permission {
  is_http_request
  allowed_http_route
}

user_has_permission {
  is_graphql_request
  allowed_graphql_operation
}

# Detect HTTP request
is_http_request {
  not is_graphql_request
}

# Detect GraphQL by looking for a body with "query"
is_graphql_request {
  input.parsed_body.query
}

# Match based on HTTP method and path
allowed_http_route {
  input.method == "GET"
  input.path == ["orders"]
}

allowed_http_route {
  input.method == "POST"
  input.path == ["orders"]
}

# Match GraphQL operation name or content
allowed_graphql_operation {
  contains(lower(input.parsed_body.query), "query getorders")
}

allowed_graphql_operation {
  contains(lower(input.parsed_body.query), "mutation createorder")
}
```

---

### 📌 Notes:

- `contains` and `lower()` help match GraphQL operations without parsing the full AST.
- OPA requires **`parsed_body`** to be passed from your Envoy/Gloo middleware.
- The policy is **flexible** to expand — you can later include roles, resources, etc.

Here’s how to create a working `ExtAuthConfig` in **Gloo Gateway** to use your `policy.rego` from **OPA**, and authorize requests based on HTTP or GraphQL logic:

---

### 🧱 **1. Prerequisites**

Ensure:

- Gloo Edge or Gloo Gateway is installed.
- OPA is deployed and running in your cluster (e.g., as `opa.opa.svc.cluster.local:8181`).
- OPA is serving your `policy.rego` under the `/v1/data/authz/allow` endpoint.

---

### 📄 **2. Gloo `ExtAuthConfig` Example**

```yaml
apiVersion: admin.gloo.solo.io/v2
kind: ExtAuthConfig
metadata:
  name: opa-auth
  namespace: gloo-mesh
spec:
  glooAuth:
    configs:
      - opaAuth:
          requestBody:
            includedBody:
              maxRequestBytes: 2048
              allowPartial: true
              # This is needed to support GraphQL parsing in policy.rego
              contentTypes:
                - application/json
          headersToAppendToRequest:
            - header: x-user-id
              valueFromBody: parsed_body.user_id
          query: 'data.authz.allow'
          url: 'http://opa.opa.svc.cluster.local:8181/v1/data/authz/allow'
```

---

### ⚙️ **3. Explanation**

| Section                    | Purpose                                                    |
| -------------------------- | ---------------------------------------------------------- |
| `opaAuth.requestBody`      | Sends body to OPA (needed for GraphQL parsing).            |
| `contentTypes`             | OPA will only parse requests with these content types.     |
| `headersToAppendToRequest` | Optionally forwards info (like `user_id`) from OPA result. |
| `query`                    | The OPA decision document (i.e. `data.authz.allow`).       |
| `url`                      | The OPA service endpoint.                                  |

---

### 🚦 **4. Apply this Policy to a Route**

If you're using **Gloo RouteTables**, attach this to your `RouteOption` or `VirtualService`:

```yaml
virtualHost:
  domains:
    - '*'
  routes:
    - matchers:
        - prefix: /
      options:
        extauth:
          configRef:
            name: opa-auth
            namespace: gloo-mesh
```

Great question. If your **frontend (Next.js)** app is serving full pages (HTML) and OPA (via Gloo Gateway) is handling authorization, then the flow depends on where the **authorization check** happens:

---

### 🔁 **Use Case: OPA Authorization at Gloo Gateway**

You're enforcing authorization **before** the frontend gets the request.

#### ✅ Pros:

- Centralized.
- Uniform logic for all routes (REST, GraphQL, etc.).

#### ⚠️ Limitation:

This works **only** if the Gloo Gateway directly handles the incoming request (before it reaches the frontend). However, **Next.js SSR or static pages** often don’t carry a rich enough request body for OPA (e.g., they might not contain a user role or JWT in a parseable format).

---

### 💡 **Solution: Use JWTs for AuthZ**

Have your frontend client **attach a JWT** (from login) in requests. Then OPA can decode and inspect claims (like role, user ID, etc.).

#### Example Flow:

1. Client requests: `GET /dashboard` with `Authorization: Bearer <JWT>`
2. Gloo Gateway receives the request.
3. Gloo’s ExtAuth (via OPA) intercepts and sends the JWT to OPA.
4. OPA policy (e.g., `policy.rego`) checks claims:

   ```rego
   default allow = false
   allow {
     input.parsed_token.payload.role == "admin"
     input.method == "GET"
     input.path == [ "dashboard" ]
   }
   ```

5. If allowed, the request reaches Next.js frontend → renders page.

---

### 🧰 For this to work:

- Your **Next.js app must require auth** and issue a JWT at login.
- Gloo Gateway must **pass the JWT to OPA** (via headers).
- OPA must **decode and validate** the token (often using [`io.jwt.decode_verify`](https://www.openpolicyagent.org/docs/latest/policy-reference/#iojwtdecode_verify)).
