To test your Horizontal Pod Autoscaler (HPA), you need to simulate a load on your application to trigger scaling. Here's how you can test it step by step:

1. Verify HPA is Configured
   First, ensure the HPA is applied and running:

```bash
kubectl get hpa -n frontend-dev
```

You should see your HPA listed with its current and desired replica counts.

2. Expose the Service
   Ensure your hello-app-svc service is accessible. If it's not already exposed, you can use kubectl port-forward to forward the service to your local machine:

```bash
kubectl port-forward svc/hello-app-svc 3001:3001 -n frontend-dev
```

This will make the service available at http://localhost:3001.

3. Generate Load
   Use a tool like curl, ab (Apache Benchmark), or hey to generate traffic and load on your application. For example:

Using hey (recommended for load testing):
Install hey if you don't have it:

```bash
brew install hey
```

Run the load test:

```bash
hey -z 30s -c 50 http://localhost:3001
```

This will send requests for 30 seconds with 50 concurrent users.

Using curl in a loop:

```bash
while true; do curl http://localhost:3001; done
```

4. Monitor HPA Behavior
   While the load is running, monitor the HPA to see if it scales the pods:

```bash
kubectl get hpa -n frontend-dev --watch
```

You should see the CURRENT and DESIRED replica counts change as the HPA adjusts the number of pods.

5. Check Pods
   Verify that new pods are being created:

```bash
kubectl get pods -n frontend-dev
```

You should see additional pods being created to handle the load.

6. Stop the Load
   Once you've confirmed the HPA is working, stop the load test. The HPA should eventually scale the pods back down to the minReplicas value.
