Nếu bạn thường xuyên dùng nhiều namespace, có thể chỉnh mặc định của dashboard để hiển thị **all namespaces** bằng cách sửa deployment (ít cần thiết nhưng có thể nếu bạn muốn customize).

---

Nếu bạn cần **token admin để login**, bạn có thể tạo như sau:

### ✅ Tạo token đăng nhập full quyền cho dashboard

```bash
kubectl create serviceaccount dashboard-admin-sa -n kube-system

kubectl create clusterrolebinding dashboard-admin-sa \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:dashboard-admin-sa
```

Lấy token:

```bash
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep dashboard-admin-sa | awk '{print $1}')
```

Copy token và dùng để login tại màn hình login của Dashboard.

Nếu bạn chạy lệnh sau nhưng **không thấy gì**:

```bash
kubectl -n kube-system get secret $(kubectl -n kube-system get secret | grep dashboard-admin-sa | awk '{print $1}') -o jsonpath="{.data.token}" | base64 --decode
```

Thì có thể là vì:

---

## 🔍 Nguyên nhân có thể

1. **ServiceAccount `dashboard-admin-sa` chưa có Secret gắn với nó**
   Điều này đôi khi xảy ra với các phiên bản Kubernetes mới (>=1.24) khi bạn **phải tạo `Secret` kiểu `ServiceAccount token` thủ công**.

---

## ✅ Giải pháp: Tạo Secret kiểu token liên kết với ServiceAccount

### 🛠️ Bước 1: Tạo Secret kiểu token

```yaml
# dashboard-admin-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: dashboard-admin-sa-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: dashboard-admin-sa
type: kubernetes.io/service-account-token
```

Áp dụng lệnh:

```bash
kubectl apply -f dashboard-admin-secret.yaml
```

---

### 🛠️ Bước 2: Lấy token từ Secret mới

```bash
kubectl -n kube-system get secret dashboard-admin-sa-token -o jsonpath="{.data.token}" | base64 --decode
```

---

## ✅ Sau khi có token

1. Truy cập `https://kubernetes.manhlam.name.vn`
2. Dán token vừa lấy
3. Bây giờ bạn sẽ thấy đầy đủ namespace, workloads,...
