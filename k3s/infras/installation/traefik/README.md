❌ Bỏ bản mặc định

```
kubectl delete deployment traefik -n kube-system
```

✅ Cài bản mới trong namespace riêng:

```
helm repo add traefik https://traefik.github.io/charts
helm repo update
kubectl create namespace traefik

# option 1
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set ping.enabled=true \
  --set entryPoints.traefik.address=":9020" \
  --set service.ports.traefikPort.port=9020 \
  --set service.ports.traefikPort.targetPort=9020 \
  --set service.ports.traefikPort.name=traefik \
  --set ports.web.port=80 \
  --set ports.websecure.port=443 \
  --set ingressRoute.dashboard.enabled=true \
  --set service.type=LoadBalancer \
  --set metrics.prometheus.enabled=true \
  --set logs.general.level=DEBUG \
  --set healthcheck.enabled=true

# option 2
```

🩺 Kiểm tra health
Sau khi cài, bạn có thể kiểm tra health của Traefik qua:

```
curl http://<traefik-ip>/ping
```

Còn nếu có Prometheus, bạn sẽ thấy các metrics tại:

```
http://<traefik-ip>/metrics
```

Cập nhật traefik service

```
helm upgrade traefik traefik/traefik --namespace traefik -f values.yaml

helm upgrade traefik traefik/traefik --namespace traefik --create-namespace -f values.yaml

```

---

Lỗi `unknown field "spec.basicAuth.users"` cho thấy CRD Middleware của Traefik không nhận `users` dưới dạng danh sách như bạn khai báo.

## Nguyên nhân chính

- Phiên bản CRD Middleware bạn đang dùng (v1alpha1) **không hỗ trợ trường `users` nữa**.
- Traefik Middleware `basicAuth` hiện tại dùng **`secret` để lấy danh sách user**, không khai trực tiếp `users` trong spec.

---

## Cách xử lý chuẩn

### Bước 1: Tạo Secret chứa BasicAuth user (đã mã hóa)

Ví dụ tạo Secret (thay `admin:123456` bằng user\:password bạn muốn):

```bash
kubectl create secret generic traefik-dashboard-auth-secret \
  --from-literal=users=admin:$2y$05$B5zdmRzlyWno5GJzpcPYW.szTL01g1qSeHfIntrVn9ew.4qYuFcYG \
  -n traefik
```

### Bước 2: Tạo Middleware YAML tham chiếu Secret

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-auth
  namespace: traefik
spec:
  basicAuth:
    realm: 'Traefik Dashboard'
    secret: traefik-dashboard-auth-secret
```

### Bước 3: Áp dụng middleware vào IngressRoute (hoặc Ingress tùy cách bạn cấu hình)

Ví dụ trích đoạn IngressRoute:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: traefik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`dashboard.example.com`)
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
      middlewares:
        - name: dashboard-auth
```

---

## Tóm lại:

- **Không khai `users` trực tiếp trong Middleware spec nữa.**
- Phải tạo `Secret` chứa user đã mã hóa (bcrypt).
- Middleware tham chiếu Secret đó qua `secret: <secret-name>`.
- Middleware gắn vào route để bật BasicAuth.
