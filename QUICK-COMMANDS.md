# Quick Copy-Paste Commands for All Tasks

## Task 1: Install Istio 1.26 Demo Profile (7pts)
```bash
istioctl install --set profile=demo -y
kubectl wait -n istio-system deploy/istiod --for=condition=Available --timeout=600s
kubectl wait -n istio-system deploy/istio-ingressgateway --for=condition=Available --timeout=600s
```

## Task 2: Default ns injection + samples (5pts)
```bash
kubectl label ns default istio-injection=enabled --overwrite
kubectl -n default rollout restart deploy
```

## Tasks 3-10: Traffic Management (50pts)
```bash
# Apply all traffic management resources
kubectl apply -f /vagrant/manifests/task-03-12.yaml
```

**Individual tasks:**
- Task 3: VirtualService httpbin-vs (9pts)
- Task 4: Gateway API httpbin-route (6pts)
- Task 5: Payments weighted routing (9pts)
- Task 6: Helloworld header routing (7pts)
- Task 7: Payments timeout + retries (5pts)
- Task 8: Helloworld fault injection (4pts)
- Task 9: Helloworld circuit breaker (6pts)
- Task 10: Fakeservice outlier detection (6pts)

## Tasks 11-13: Observability (13pts)
```bash
# Apply observability resources
kubectl apply -f /vagrant/manifests/task-11-16.yaml

# Enable injection for bookinfo namespace (Task 12)
kubectl label ns bookinfo istio-injection=enabled
```

**Individual tasks:**
- Task 11: Prometheus deployment (4pts)
- Task 12: Kiali + bookinfo labels (5pts)
- Task 13: Jaeger + telemetry sampling (4pts)
```bash
# Additional for Task 13
kubectl apply -f /vagrant/manifests/task-13-16.yaml
```

## Tasks 14-15: Security (14pts)
```bash
# Apply security resources
kubectl apply -f /vagrant/manifests/task-13-16.yaml
```

**Individual tasks:**
- Task 14: PeerAuth strict/permissive (7pts) - Creates:
  - `PeerAuthentication default-strict` (STRICT mTLS)
  - `PeerAuthentication httpbin-port-permissive` (PERMISSIVE on port 8000)
- Task 15: AuthorizationPolicy curl POST (7pts)

## Task 16: Revision tag latest + swagger (9pts)
```bash
istioctl tag set latest --revision default --overwrite
kubectl label ns swagger istio.io/rev=latest --overwrite
```

## Verification Commands

### Check specific task:
```bash
/vagrant/check-exam.sh 1
/vagrant/check-exam.sh 14
```

### Check all tasks:
```bash
/vagrant/check-exam.sh all
```

### Check with solutions:
```bash
/vagrant/check-exam.sh -s all
```

### Check istiod status:
```bash
kubectl get pods -n istio-system
kubectl get deploy -n istio-system istiod
```

### Wait for istiod to be ready:
```bash
kubectl wait -n istio-system deploy/istiod --for=condition=Available --timeout=600s
```

## Troubleshooting

### If webhook validation fails:
```bash
# Wait for istiod to be ready first
kubectl wait -n istio-system deploy/istiod --for=condition=Available --timeout=600s
kubectl wait -n istio-system pod -l app=istiod --for=condition=Ready --timeout=600s

# Then retry applying manifests
kubectl apply -f /vagrant/manifests/task-03-12.yaml
```

### View manifest contents:
```bash
cat /vagrant/manifests/task-13-16.yaml
cat /vagrant/manifests/task-03-12.yaml
```

