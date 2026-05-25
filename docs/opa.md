```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: opa
---
# configmap-policy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: opa-policy
  namespace: opa
data:
  authz.rego: |
    package authz

    default allow := false

    allow if {
      input.action in input.user.permissions
    }

    allow if {
      input.user.role == "super_admin"
    }

  ownership.rego: |
    package ownership

    is_owner if {
      input.resource.owner_id == input.user.id
    }
---
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opa
  namespace: opa
  labels:
    app: opa
spec:
  replicas: 2
  selector:
    matchLabels:
      app: opa
  template:
    metadata:
      labels:
        app: opa
    spec:
      containers:
        - name: opa
          image: openpolicyagent/opa:0.70.0
          args:
            - 'run'
            - '--server'
            - '--addr=0.0.0.0:8181'
            - '--log-level=info'
            - '/policies'
          ports:
            - containerPort: 8181
              name: http
          volumeMounts:
            - name: opa-policy
              mountPath: /policies
          readinessProbe:
            httpGet:
              path: /health?plugins
              port: 8181
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health?plugins
              port: 8181
            initialDelaySeconds: 10
            periodSeconds: 20
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi

      volumes:
        - name: opa-policy
          configMap:
            name: opa-policy
---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: opa
  namespace: opa
spec:
  selector:
    app: opa
  ports:
    - name: http
      port: 8181
      targetPort: 8181
  type: ClusterIP
---
# networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: opa-allow-bff
  namespace: opa
spec:
  podSelector:
    matchLabels:
      app: opa
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: backend
          podSelector:
            matchLabels:
              app: bff
      ports:
        - protocol: TCP
          port: 8181
---
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: opa

resources:
  - namespace.yaml
  - configmap-policy.yaml
  - deployment.yaml
  - service.yaml
  - networkpolicy.yaml
```

Cấu trúc repo GitOps khuyên dùng:

```text
gitops-config/
└── apps/
    └── opa/
        ├── namespace.yaml
        ├── configmap-policy.yaml
        ├── deployment.yaml
        ├── service.yaml
        ├── networkpolicy.yaml
        └── kustomization.yaml
```

BFF gọi OPA:

```bash
http://opa.opa.svc.cluster.local:8181/v1/data/authz/allow
```

Ví dụ request:

```json
{
  "input": {
    "user": {
      "id": "123",
      "role": "user",
      "permissions": ["user.read", "user.update"]
    },
    "action": "user.update",
    "resource": {
      "owner_id": "123"
    }
  }
}
```

Response:

```json
{
  "result": true
}
```

Test local:

```bash
kubectl port-forward -n opa svc/opa 8181:8181
```

```bash
curl -X POST http://localhost:8181/v1/data/authz/allow \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "user": {
        "id": "123",
        "permissions": ["user.update"]
      },
      "action": "user.update"
    }
  }'
```

ArgoCD Application ví dụ:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: opa
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/your-org/gitops-config.git
    targetRevision: main
    path: apps/opa

  destination:
    server: https://kubernetes.default.svc
    namespace: opa

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

    syncOptions:
      - CreateNamespace=true
```
