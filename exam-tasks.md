### Task 1 (7 pts) – Install Istio 1.26 demo profile

Install Istio 1.26.x with the demo profile in namespace `istio-system`. Confirm `istioctl version` shows the 1.26.x control plane and both `istiod` plus `istio-ingressgateway` Deployments report `AVAILABLE`.

---TASK---
### Task 2 (5 pts) – Enable default namespace workloads

Label the `default` namespace for automatic sidecar injection and keep the provided `httpbin` and `curl` deployments running. Verify pods in `default` include the `istio-proxy` container.

---TASK---
### Task 3 (9 pts) – Istio Gateway + VirtualService

Create (or update) `httpbin-gw` and `httpbin-vs` in `default` so that traffic for host `httpbin.com` via the Istio ingress gateway routes to `httpbin.default.svc.cluster.local:8000`.

---TASK---
### Task 4 (6 pts) – Gateway API HTTPRoute

Expose `httpbin` through the Kubernetes Gateway API with `gateway.gateway.networking.k8s.io/httpbin-kgw` and `httproute/httpbin-route` in `default`. Route host `httpbin.com` to service `httpbin` on port 8000.

---TASK---
### Task 5 (9 pts) – Payments weighted routing

In namespace `payments`, create `DestinationRule payments-dr` with subsets `v1`/`v2` and a `VirtualService payments-vs` that splits `/` traffic 70% to subset v1 and 30% to subset v2.

---TASK---
### Task 6 (7 pts) – Header-based routing with rewrites

For the `helloworld` service in `default`, ensure `VirtualService helloworld-match-vs` rewrites `/v1` and `/v2` to `/hello` with subset routing to `v1` and `v2` respectively, while all other traffic falls back to subset `v1`.

---TASK---
### Task 7 (5 pts) – Timeout and retries

Update `payments-vs` so that `/` routes include `timeout: 2s` and retries set to 3 attempts with `perTryTimeout: 1s` and `retryOn: 5xx,connect-failure,refused-stream`.

---TASK---
### Task 8 (4 pts) – Fault injection delay

Inject a 2 second delay on 20% of `/v2` traffic inside `helloworld-match-vs` while keeping normal routing behavior for other paths.

---TASK---
### Task 9 (6 pts) – Circuit breaking policy

Apply `DestinationRule helloworld-cb` so the connection pool for `helloworld` enforces `http1MaxPendingRequests=1`, `http2MaxRequests=1`, and `maxRequestsPerConnection=1`.

---TASK---
### Task 10 (6 pts) – Outlier detection

Add `DestinationRule fakeservice-od` (namespace `default`) with outlier detection configured to eject after one consecutive 5xx, checking every 5s, ejecting for 3m, and allowing 100% ejection.

---TASK---
### Task 11 (4 pts) – Prometheus addon

Deploy the Istio Prometheus addon (`deployment/prometheus` in `istio-system`) to capture metrics for the exam environment.

---TASK---
### Task 12 (5 pts) – Kiali + namespace labels

Deploy `kiali` in `istio-system` and ensure the `bookinfo` namespace is labeled for Istio sidecar injection (revision or `istio-injection=enabled`).

---TASK---
### Task 13 (4 pts) – Tracing and telemetry sampling

Deploy Jaeger (`deployment/jaeger` in `istio-system`) and configure `telemetry/mesh-default` to sample traces at 100%.

---TASK---
### Task 14 (7 pts) – PeerAuthentication strict with port override

Create `PeerAuthentication default-strict` in namespace `default` enforcing STRICT mTLS, plus `httpbin-port-permissive` allowing PERMISSIVE mode only on port 8080 for `httpbin`.

---TASK---
### Task 15 (7 pts) – AuthorizationPolicy POST allow list

Ensure `AuthorizationPolicy allow-nothing` denies all traffic by default in `default`, then add `AuthorizationPolicy curl-to-httpbin-post-only` allowing only the `curl` service account to make POST requests to `httpbin`.

---TASK---
### Task 16 (9 pts) – Revision tag rollout

Install Istio with `--revision 1-26-3`, create the `latest` revision tag, and label the `swagger` namespace with `istio.io/rev=latest`. Confirm the namespace workloads run with that tag.
