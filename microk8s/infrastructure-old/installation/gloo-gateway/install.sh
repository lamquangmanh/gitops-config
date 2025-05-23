# https://docs.solo.io/gloo-mesh-gateway/latest/setup/install/single-cluster/
helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update

helm install gloo gloo/gloo \
  --namespace gloo-system \
  --create-namespace \
  -f gloo-values.yaml \
  --set gatewayProxies.gatewayProxy.service.type=NodePort
  # Or use NodePort if you're in Minikube/k3s
