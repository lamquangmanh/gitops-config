❌ Bỏ bản mặc định

```
kubectl delete deployment traefik -n kube-system
```

✅ Cài bản mới trong namespace riêng:

```
helm repo add traefik https://traefik.github.io/charts
helm repo update
kubectl create namespace traefik

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
