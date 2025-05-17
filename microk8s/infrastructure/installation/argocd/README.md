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

Nếu bạn muốn **expose ArgoCD trực tiếp qua Cloudflare Tunnel mà không cần đi qua Traefik**, hoàn toàn có thể làm được — thậm chí đơn giản hơn nếu bạn không cần routing nâng cao.

Dưới đây là hướng dẫn chi tiết để làm điều đó.

---

## 🧩 Mô hình

```text
Internet
   ▼
Cloudflare (DNS + Tunnel)
   ▼
Cloudflared daemon
   ▼
ArgoCD Service (NodePort hoặc LoadBalancer)
```

---

## ✅ Cách thực hiện

### ✅ Bước 1: Expose ArgoCD ra ngoài bằng LoadBalancer (dễ nhất)

Bạn cần chỉnh service `argocd-server`:

```bash
kubectl -n argocd edit svc argocd-server
```

Sửa lại thành:

```yaml
spec:
  type: LoadBalancer
  ports:
    - name: https
      port: 443
      targetPort: 8080 # Cổng mặc định của ArgoCD server
```

> ✅ `targetPort: 8080` là cổng mà container ArgoCD lắng nghe (TLS)
> Nếu bạn không dùng HTTPS, đổi `port: 80` và `targetPort: 8080` cũng được

Sau đó chờ vài giây:

```bash
kubectl get svc -n argocd
```

Bạn sẽ thấy:

```bash
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)
argocd-server   LoadBalancer   10.x.x.x         192.168.1.201   443:xxxxx/TCP
```

---

### ✅ Bước 2: Cấu hình Cloudflared trỏ tới IP đó

Giả sử EXTERNAL-IP là `192.168.1.201`, ta tạo hoặc sửa file `/etc/cloudflared/config.yml` như sau:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /etc/cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: argocd.manhlam.name.vn
    service: https://192.168.1.201:443
    originServerName: argocd.manhlam.name.vn
    originRequest:
      noTLSVerify: true # vì ArgoCD tự ký SSL

  - service: http_status:404
```

**Lưu ý:**

- `originServerName` phải trùng với `hostname` để tránh lỗi SNI.
- `noTLSVerify: true` để bỏ qua SSL tự ký của ArgoCD (nếu bạn chưa gắn TLS cert chuẩn).

---

### ✅ Bước 3: Restart `cloudflared`

```bash
sudo systemctl restart cloudflared
```

---

### ✅ Bước 4: Kiểm tra DNS

Trong Cloudflare → DNS → Bạn cần có:

| Type  | Name   | Target                         | Proxy        |
| ----- | ------ | ------------------------------ | ------------ |
| CNAME | argocd | `<TUNNEL_ID>.cfargotunnel.com` | ☁️ (Proxied) |

---

## ✅ Kiểm tra

- Truy cập: [https://argocd.manhlam.name.vn](https://argocd.manhlam.name.vn)
- Nếu báo lỗi SSL → dùng `noTLSVerify: true` hoặc gắn SSL cert chuẩn cho ArgoCD.

---

## 🧪 Bonus: Sử dụng NodePort nếu không muốn LoadBalancer

```bash
kubectl -n argocd edit svc argocd-server
```

```yaml
spec:
  type: NodePort
  ports:
    - name: https
      port: 443
      targetPort: 8080
      nodePort: 31443
```

Rồi trong `cloudflared`:

```yaml
- hostname: argocd.manhlam.name.vn
  service: https://127.0.0.1:31443
  originRequest:
    noTLSVerify: true
```

---

## ✅ Tóm lại

| Lựa chọn                  | Ưu điểm                       | Nhược điểm                         |
| ------------------------- | ----------------------------- | ---------------------------------- |
| Qua Traefik               | Dễ quản lý, routing linh hoạt | Phức tạp hơn, cần cấu hình Ingress |
| Trực tiếp qua Cloudflared | Nhanh, đơn giản, dễ test      | Không kiểm soát routing linh hoạt  |
