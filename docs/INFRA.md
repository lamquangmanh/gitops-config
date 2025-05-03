```bash
[ Developer ]
     |
     v
[ Push to gitops-config repo ]
     |
     v
[ GitHub Actions ]
     |
     v
[ ArgoCD (in Minikube) ]
     |
     v
+-------------------+
|   Kubernetes      |
| +---------------+ |         +------------------+
| | Gloo Gateway  |<--------->| OPA (Auth Policy)|
| +-------+-------+ |               |
|         |         |               v
|         v         |         [ HTTP call ]
|   +-----------+   |         to User Service
|   | Services  |   |               |
|   +-----------+   |               v
|                   |      [ Response: Allow/Deny ]
+-------------------+

```
