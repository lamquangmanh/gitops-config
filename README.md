# Gitops

## How it works

Perfect — wrapping your `ApplicationSet` inside an **App of Apps** is the best way to GitOps-manage all your applications with ArgoCD 🚀

---

## 🧱 Folder Structure (GitOps Style)

```
github-config/
├── apps/
│   ├── app-of-apps.yaml              # ← The parent ArgoCD Application
│   └── application-set.yaml          # ← Manages all frontend/backend/env apps
├── overlays/
│   └── [frontend|backend]/
│       └── [dev|test]/               # ← Kustomize overlays
└── base/                             # ← Kustomize base
```

---

## 🔁 1. `application-set.yaml`

**`github-config/apps/application-set.yaml`**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: all-apps
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/your-org/github-config.git # 👈 replace this
        revision: HEAD
        directories:
          - path: overlays/*/*
  template:
    metadata:
      name: '{{path.basename}}-{{path.split("/")[1]}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/github-config.git # 👈 same repo as above
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}' # e.g., dev/test
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
```

---

## 🌳 2. `app-of-apps.yaml` (Parent App)

**`github-config/apps/app-of-apps.yaml`**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/github-config.git # 👈 your GitOps repo
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

---

## 🚀 3. Apply Once

To bootstrap everything:

```bash
kubectl apply -f apps/app-of-apps.yaml -n argocd
```

This will make ArgoCD sync `application-set.yaml` → which auto-creates all apps under `overlays/*/*`.
