Để tạo HTTPS cho domain `https://argocd.manhlam.name.vn` trên MicroK8s với ArgoCD bằng **cert-manager** và Let's Encrypt, bạn làm theo các bước sau:

---

## 1. Bật cert-manager trên MicroK8s

```bash
microk8s enable cert-manager
```

Chờ cert-manager được cài đặt xong.

---

## 2. Tạo `ClusterIssuer` cho Let's Encrypt

Tạo file `letsencrypt-clusterissuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Email bạn đăng ký với Let's Encrypt
    email: your-email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    solvers:
      - http01:
          ingress:
            class: traefik
```

> Thay `your-email@example.com` bằng email thật của bạn để nhận thông báo từ Let's Encrypt.

Áp dụng:

```bash
microk8s kubectl apply -f letsencrypt-clusterissuer.yaml
```

---

## 3. Tạo `Certificate` cho domain ArgoCD

Tạo file `argocd-certificate.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-tls
  namespace: argocd
spec:
  secretName: argocd-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: argocd.manhlam.name.vn
  dnsNames:
    - argocd.manhlam.name.vn
```

Áp dụng:

```bash
microk8s kubectl apply -f argocd-certificate.yaml
```

---

## 4. Cập nhật Ingress cho ArgoCD dùng TLS

Sửa Ingress `argocd-ingressroute.yaml` thành:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: 'true'
spec:
  rules:
    - host: argocd.manhlam.name.vn
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
  tls:
    - hosts:
        - argocd.manhlam.name.vn
      secretName: argocd-tls
```

Áp dụng lại:

```bash
microk8s kubectl apply -f argocd-ingressroute.yaml
```

---

## 5. Kiểm tra

- Đảm bảo DNS `argocd.manhlam.name.vn` đã trỏ đúng tới IP của cluster MicroK8s (hoặc IP public, LoadBalancer, v.v).
- Kiểm tra secret chứa cert:

```bash
microk8s kubectl get secret argocd-tls -n argocd
```

- Kiểm tra pod cert-manager, cert-status:

```bash
microk8s kubectl describe certificate argocd-tls -n argocd
```

- Mở trình duyệt truy cập `https://argocd.manhlam.name.vn` và kiểm tra HTTPS hoạt động.

---

Nếu bạn dùng Traefik làm Ingress Controller, `ingress.class` trong ClusterIssuer `solvers` nên là `traefik`, nếu bạn dùng nginx hoặc ingress khác thì thay đổi tương ứng.

Bạn cần hỗ trợ thêm phần nào cứ nói nhé!
