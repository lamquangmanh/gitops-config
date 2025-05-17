Let's walk through **deploying ArgoCD on MicroK8s** step by step.

## ✅ Step 1: Enable Required MicroK8s Add-ons

Make sure the following add-ons are enabled:

```bash
microk8s enable dns storage
microk8s enable ingress or traefik
```

You may also want to enable `rbac`:

```bash
microk8s enable rbac
```

---

## ✅ Step 2: Install ArgoCD (in `argocd` namespace)

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

---

## ✅ Step 3: Expose ArgoCD UI (Option 1: via Ingress with MicroK8s Ingress)

### 3.1 Create an Ingress for ArgoCD Server

Create a file `argocd-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
spec:
  rules:
    - host: argocd.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
```

Apply it:

```bash
kubectl apply -f argocd-ingress.yaml
```

### 3.2 Add Host Entry

Edit your `/etc/hosts` file:

```bash
sudo nano /etc/hosts
```

Add:

```
127.0.0.1 argocd.local
```

Now visit: [http://argocd.local](http://argocd.local)

---

## ✅ Step 4: Get the ArgoCD Admin Password

Get the initial password (auto-generated and stored in a secret):

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo
```

Username is always `admin`.

---

## ✅ Step 5: (Optional) Access via `argocd` CLI

Install the ArgoCD CLI:
[https://argo-cd.readthedocs.io/en/stable/cli_installation/](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

Then login:

```bash
argocd login argocd.local:80 --username admin --password <the-password>
```

---

## ✅ Optional Step 6: Secure with HTTPS (via cert-manager or Cloudflare Tunnel)

If you want HTTPS:

- Use **cert-manager + Let's Encrypt**
- Or expose via **Cloudflare Tunnel**
