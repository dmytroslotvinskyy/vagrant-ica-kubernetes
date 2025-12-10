# ICA Exam - All Tasks Summary

## Current Status: All Tasks Failing (0/100 points)

### Task Breakdown

| # | Task | Points | Status | Solution |
|---|------|--------|--------|----------|
| 1 | Install Istio control plane | 7 | FAIL | `istioctl install --set profile=demo -y` |
| 2 | Default ns injection + samples | 5 | FAIL | `kubectl label ns default istio-injection=enabled --overwrite && kubectl -n default rollout restart deploy` |
| 3 | VirtualService httpbin-vs | 9 | FAIL | `kubectl apply -f /vagrant/manifests/task-03-12.yaml` |
| 4 | Gateway API httpbin-route | 6 | FAIL | `kubectl apply -f /vagrant/manifests/task-03-12.yaml` |
| 5 | Payments weighted routing | 9 | FAIL | `kubectl apply -f /vagrant/manifests/task-03-12.yaml` |
| 6 | Helloworld header routing | 7 | FAIL | `kubectl apply -f /vagrant/manifests/task-03-12.yaml` |
| 7 | Payments timeout + retries | 5 | FAIL | `kubectl apply -f /vagrant/manifests/task-03-12.yaml` |
| 8 | Helloworld fault injection | 4 | FAIL | `kubectl apply -f /vagrant/manifests/task-03-12.yaml` |
| 9 | Helloworld circuit breaker | 6 | FAIL | `kubectl apply -f /vagrant/manifests/task-03-12.yaml` |
| 10 | Fakeservice outlier detection | 6 | FAIL | `kubectl apply -f /vagrant/manifests/task-03-12.yaml` |
| 11 | Prometheus deployment present | 4 | FAIL | `kubectl apply -f /vagrant/manifests/task-11-16.yaml` |
| 12 | Kiali + bookinfo labels | 5 | FAIL | `kubectl apply -f /vagrant/manifests/task-11-16.yaml` + `kubectl label ns bookinfo istio-injection=enabled` |
| 13 | Jaeger + telemetry sampling | 4 | FAIL | `kubectl apply -f /vagrant/manifests/task-11-16.yaml && kubectl apply -f /vagrant/manifests/task-13-16.yaml` |
| 14 | PeerAuth strict/permissive | 7 | FAIL | `kubectl apply -f /vagrant/manifests/task-13-16.yaml` |
| 15 | AuthorizationPolicy curl POST | 7 | FAIL | `kubectl apply -f /vagrant/manifests/task-13-16.yaml` |
| 16 | Revision tag latest + swagger | 9 | FAIL | `istioctl tag set latest --revision default --overwrite && kubectl label ns swagger istio.io/rev=latest --overwrite` |

**Total Points:** 0/100  
**Passing Score:** 68/100

## Quick Start Commands

### 1. Install Istio (Task 1)
```bash
istioctl install --set profile=demo -y
kubectl wait -n istio-system deploy/istiod --for=condition=Available --timeout=600s
kubectl wait -n istio-system deploy/istio-ingressgateway --for=condition=Available --timeout=600s
```

### 2. Enable Sidecar Injection (Task 2)
```bash
kubectl label ns default istio-injection=enabled --overwrite
kubectl -n default rollout restart deploy
```

### 3. Apply Traffic Management (Tasks 3-10)
```bash
kubectl apply -f /vagrant/manifests/task-03-12.yaml
```

### 4. Apply Observability (Tasks 11-13)
```bash
kubectl apply -f /vagrant/manifests/task-11-16.yaml
kubectl apply -f /vagrant/manifests/task-13-16.yaml
kubectl label ns bookinfo istio-injection=enabled
```

### 5. Apply Security (Tasks 14-15)
```bash
kubectl apply -f /vagrant/manifests/task-13-16.yaml
```

### 6. Revision Tags (Task 16)
```bash
istioctl tag set latest --revision default --overwrite
kubectl label ns swagger istio.io/rev=latest --overwrite
```

## Verification

After completing tasks, verify with:
```bash
/vagrant/check-exam.sh all        # Check all tasks
/vagrant/check-exam.sh -s all     # Check with solutions for failures
/vagrant/check-exam.sh 1          # Check specific task
```

## Manifest Files Location

All required manifests are in `/vagrant/manifests/`:
- `task-01-orders.yaml`
- `task-03-12.yaml`
- `task-11-16.yaml`
- `task-13-16.yaml`

