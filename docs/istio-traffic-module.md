# ICA Istio Traffic-Management Module

Level up Istio traffic skills with a 20-task progression designed for ICA-style practice labs. Every task builds on networking.istio.io/v1 APIs (Istio 1.26.x) and includes cluster context, goals, YAML, explanations, quick verification ideas, and doc links for cross-checking.

---

## Task 1 - Basic Weighted Split for Orders

**Cluster context**

- Namespace `orders`
- Service `orders` (ClusterIP, port 8080)
- Deployments: `orders-v1` (version=v1) and `orders-v2` (version=v2)

**Goal**

- Create `DestinationRule` `orders-dr` with subsets v1/v2.
- Create `VirtualService` `orders-vs` routing `/` with a 60/40 split (v1/v2).

```yaml
# DestinationRule
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: orders-dr
  namespace: orders
spec:
  host: orders.orders.svc.cluster.local
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
---
# VirtualService
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: orders-vs
  namespace: orders
spec:
  hosts:
  - orders.orders.svc.cluster.local
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: orders.orders.svc.cluster.local
        subset: v1
      weight: 60
    - destination:
        host: orders.orders.svc.cluster.local
        subset: v2
      weight: 40
```

**Explanation / pitfalls**

- Subsets must reuse exact `version` labels from pods. See [DestinationRule reference][ref-dr].
- HTTP rules evaluate top-down; here a single rule catches all `/` traffic per [VirtualService reference][ref-vs].

**Quick verification**

```bash
kubectl exec deploy/client -n orders -- \
  sh -c 'for i in $(seq 1 20); do curl -s orders:8080/; done' | sort | uniq -c
```

Expect roughly 60/40 distribution across v1/v2 responses.

---

## Task 2 - Header-Based Canary Override for Orders

**Cluster context**

- Same as Task 1; `orders-dr` already exists.

**Goal**

- Update `orders-vs`:
  - Requests with header `x-canary: v2` go 100% to subset v2.
  - All other `/` traffic splits 70% v1 / 30% v2.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: orders-vs
  namespace: orders
spec:
  hosts:
  - orders.orders.svc.cluster.local
  http:
  - name: canary-header
    match:
    - headers:
        x-canary:
          exact: "v2"
      uri:
        prefix: /
    route:
    - destination:
        host: orders.orders.svc.cluster.local
        subset: v2
      weight: 100
  - name: default-split
    match:
    - uri:
        prefix: /
    route:
    - destination:
        host: orders.orders.svc.cluster.local
        subset: v1
      weight: 70
    - destination:
        host: orders.orders.svc.cluster.local
        subset: v2
      weight: 30
```

**Explanation / pitfalls**

- Fields under a single match entry are ANDed (both header and URI must match). [See GitHub discussion on AND behavior][ref-match].
- Place the specific canary rule before the default so it can trigger. [VirtualService order notes][ref-vs].

**Quick verification**

```bash
# Default split
kubectl exec deploy/client -n orders -- \
  sh -c 'for i in $(seq 1 20); do curl -s orders:8080/; done' | sort | uniq -c

# Canary header (always v2)
kubectl exec deploy/client -n orders -- \
  sh -c 'for i in $(seq 1 10); do curl -s -H "x-canary: v2" orders:8080/; done'
```

---

## Task 3 - Path Routing + Rewrite for Catalog

**Cluster context**

- Namespace `catalog`, service `catalog` (port 8080).
- `catalog-dr` defines subsets v1/v2.
- Backend only exposes `/items`.

**Goal**

- `/api/v1` -> rewrite to `/items`, 100% v1.
- `/api/v2` -> rewrite to `/items`, 100% v2.
- `/api` -> rewrite to `/items`, split 50/50.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: catalog-vs
  namespace: catalog
spec:
  hosts:
  - catalog.catalog.svc.cluster.local
  http:
  - name: v1-path
    match:
    - uri:
        prefix: /api/v1
    rewrite:
      uri: /items
    route:
    - destination:
        host: catalog.catalog.svc.cluster.local
        subset: v1
      weight: 100
  - name: v2-path
    match:
    - uri:
        prefix: /api/v2
    rewrite:
      uri: /items
    route:
    - destination:
        host: catalog.catalog.svc.cluster.local
        subset: v2
      weight: 100
  - name: api-default
    match:
    - uri:
        prefix: /api
    rewrite:
      uri: /items
    route:
    - destination:
        host: catalog.catalog.svc.cluster.local
        subset: v1
      weight: 50
    - destination:
        host: catalog.catalog.svc.cluster.local
        subset: v2
      weight: 50
```

**Explanation / pitfalls**

- URI rewrites replace the matched path entirely. [Request routing task docs][ref-routing].
- List specific prefixes before generic `/api` to prevent shadowing. [Traffic management concepts][ref-traffic].

**Quick verification**

```bash
curl -s catalog.catalog.svc.cluster.local:8080/api/v1
curl -s catalog.catalog.svc.cluster.local:8080/api/v2
for i in $(seq 1 20); do curl -s catalog.catalog.svc.cluster.local:8080/api; done | sort | uniq -c
```

---

## Task 4 - Add Timeouts and Retries for Cart

**Cluster context**

- Namespace `cart`, service `cart` (port 8080), subsets v1/v2.
- Endpoint `/checkout`.

**Goal**

- `/checkout`: 80% v1 / 20% v2 with `timeout: 3s`, `retries: attempts 3`, `perTryTimeout: 1s`.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: cart-vs
  namespace: cart
spec:
  hosts:
  - cart.cart.svc.cluster.local
  http:
  - name: checkout-split
    match:
    - uri:
        prefix: /checkout
    route:
    - destination:
        host: cart.cart.svc.cluster.local
        subset: v1
      weight: 80
    - destination:
        host: cart.cart.svc.cluster.local
        subset: v2
      weight: 20
    timeout: 3s
    retries:
      attempts: 3
      perTryTimeout: 1s
```

**Explanation / pitfalls**

- `timeout` limits whole call; `perTryTimeout` affects each attempt. [VirtualService reference][ref-vs].
- Retries apply only when upstream returns retriable codes.

**Quick verification**

```bash
kubectl exec deploy/client -n cart -- \
  curl -v cart.cart.svc.cluster.local:8080/checkout
```

Trigger backend delays/failures to observe retry logs.

---

## Task 5 - Delay Fault Injection for Reporting

**Cluster context**

- Namespace `reporting`, service `reporting` (8080), subsets v1/v2.
- Endpoint `/metrics`.

**Goal**

- `/metrics/slow`: 4s fixed delay on 20% of requests, 100% to v1.
- `/metrics`: 50/50 split.
- Both rules use `timeout: 5s`.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reporting-vs
  namespace: reporting
spec:
  hosts:
  - reporting.reporting.svc.cluster.local
  http:
  - name: metrics-slow
    match:
    - uri:
        prefix: /metrics/slow
    fault:
      delay:
        percentage:
          value: 20
        fixedDelay: 4s
    route:
    - destination:
        host: reporting.reporting.svc.cluster.local
        subset: v1
      weight: 100
    timeout: 5s
  - name: metrics-default
    match:
    - uri:
        prefix: /metrics
    route:
    - destination:
        host: reporting.reporting.svc.cluster.local
        subset: v1
      weight: 50
    - destination:
        host: reporting.reporting.svc.cluster.local
        subset: v2
      weight: 50
    timeout: 5s
```

**Explanation / pitfalls**

- Faults live under `http[*].fault`. [Fault injection task][ref-fault].
- Combine with timeouts carefully: set `timeout` > `fixedDelay` for success.

**Quick verification**

```bash
for i in $(seq 1 20); do
  kubectl exec deploy/client -n reporting -- \
    curl -w ' time=%{time_total}\n' -s reporting.reporting.svc.cluster.local:8080/metrics/slow
done
```

Expect ~20% slow calls.

---

## Task 6 - Abort Fault Injection for /health

**Cluster context**

- Namespace `profile`, service `profile` (8080), subsets v1/v2.
- Endpoint `/health`.

**Goal**

- `/health`: inject 503 abort on 5% of requests; rest route 100% to v1 with `timeout: 2s`.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: profile-vs
  namespace: profile
spec:
  hosts:
  - profile.profile.svc.cluster.local
  http:
  - name: health-fault
    match:
    - uri:
        prefix: /health
    fault:
      abort:
        percentage:
          value: 5
        httpStatus: 503
    route:
    - destination:
        host: profile.profile.svc.cluster.local
        subset: v1
      weight: 100
    timeout: 2s
```

**Explanation / pitfalls**

- Abort faults are separate from delay faults. [Fault injection doc][ref-fault].
- Useful for validating client resilience.

**Quick verification**

```bash
for i in $(seq 1 50); do
  kubectl exec deploy/client -n profile -- \
    curl -s -o /dev/null -w '%{http_code}\n' profile.profile.svc.cluster.local:8080/health
done | sort | uniq -c
```

---

## Task 7 - Shadow Traffic for Audit

**Cluster context**

- Namespace `audit`.
- Primary service `audit` (subsets v1/v2) and shadow service `audit-shadow`.
- Endpoint `/events`.

**Goal**

- `/events`: 90% v1 / 10% v2.
- Mirror every request to `audit-shadow.audit.svc.cluster.local`.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: audit-vs
  namespace: audit
spec:
  hosts:
  - audit.audit.svc.cluster.local
  http:
  - name: events-with-mirror
    match:
    - uri:
        prefix: /events
    route:
    - destination:
        host: audit.audit.svc.cluster.local
        subset: v1
      weight: 90
    - destination:
        host: audit.audit.svc.cluster.local
        subset: v2
      weight: 10
    mirror:
      host: audit-shadow.audit.svc.cluster.local
```

**Explanation / pitfalls**

- `mirror` sends a copy but response always comes from the primary route. [VirtualService reference][ref-vs].
- Shadow service does not require subsets.

**Quick verification**

Generate traffic and confirm logs on both the primary and shadow deployments reflect each request.

---

## Task 8 - Three-Way Split + Canary Header for Inventory

**Cluster context**

- Namespace `inventory`, service `inventory` (8080), subsets v1/v2/v3.
- Endpoint `/stock`.

**Goal**

- Header `x-canary: v3` -> 100% v3.
- Default `/stock` -> 60% v1 / 30% v2 / 10% v3.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: inventory-vs
  namespace: inventory
spec:
  hosts:
  - inventory.inventory.svc.cluster.local
  http:
  - name: v3-canary
    match:
    - headers:
        x-canary:
          exact: "v3"
      uri:
        prefix: /stock
    route:
    - destination:
        host: inventory.inventory.svc.cluster.local
        subset: v3
      weight: 100
  - name: stock-default
    match:
    - uri:
        prefix: /stock
    route:
    - destination:
        host: inventory.inventory.svc.cluster.local
        subset: v1
      weight: 60
    - destination:
        host: inventory.inventory.svc.cluster.local
        subset: v2
      weight: 30
    - destination:
        host: inventory.inventory.svc.cluster.local
        subset: v3
      weight: 10
```

**Explanation / pitfalls**

- Weights should sum to 100 for clarity. [Traffic shifting doc][ref-shift].
- Prioritize the header rule before the default.

**Quick verification**

```bash
kubectl exec deploy/client -n inventory -- \
  sh -c 'for i in $(seq 1 50); do curl -s inventory:8080/stock; done' | sort | uniq -c

kubectl exec deploy/client -n inventory -- \
  sh -c 'for i in $(seq 1 10); do curl -s -H "x-canary: v3" inventory:8080/stock; done'
```

---

## Task 9 - Add CORS Policy for Frontend API

**Cluster context**

- Namespace `frontend`, service `frontend-api` (8080), single version.

**Goal**

- Configure CORS for `/api` allowing origin `https://shop.example.com`, methods GET/POST, headers Authorization/Content-Type, `maxAge: 24h`.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: frontend-api-vs
  namespace: frontend
spec:
  hosts:
  - frontend-api.frontend.svc.cluster.local
  http:
  - match:
    - uri:
        prefix: /api
    corsPolicy:
      allowOrigins:
      - exact: "https://shop.example.com"
      allowMethods:
      - GET
      - POST
      allowHeaders:
      - Authorization
      - Content-Type
      maxAge: 24h
    route:
    - destination:
        host: frontend-api.frontend.svc.cluster.local
      weight: 100
```

**Explanation / pitfalls**

- `allowOrigins` entries are StringMatch objects (use `exact`, `prefix`, or `regex`). [VirtualService reference][ref-vs].

**Quick verification**

Use curl with custom Origin:

```bash
kubectl exec deploy/client -n frontend -- \
  curl -I -H "Origin: https://shop.example.com" \
  frontend-api.frontend.svc.cluster.local:8080/api
```

Observe `access-control-allow-origin` headers.

---

## Task 10 - Source-Based Routing with sourceLabels

**Cluster context**

- Namespace `shipping`, service `shipping` (8080), subsets v1/v2.
- Sources:
  - Deployment `checkout` (app=checkout).
  - Deployment `admin` (app=admin).

**Goal**

- Requests from `app=checkout` -> 100% v2.
- Others -> 100% v1.
- VirtualService must include `gateways: [mesh]`.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: shipping-vs
  namespace: shipping
spec:
  hosts:
  - shipping.shipping.svc.cluster.local
  gateways:
  - mesh
  http:
  - name: checkout-to-v2
    match:
    - sourceLabels:
        app: checkout
      uri:
        prefix: /
    route:
    - destination:
        host: shipping.shipping.svc.cluster.local
        subset: v2
      weight: 100
  - name: others-to-v1
    match:
    - uri:
        prefix: /
    route:
    - destination:
        host: shipping.shipping.svc.cluster.local
        subset: v1
      weight: 100
```

**Explanation / pitfalls**

- `sourceLabels` only works for in-mesh traffic when `gateways` includes `mesh`. [Source label example][ref-sourcelabels].
- Keep the specific source rule first.

**Quick verification**

```bash
kubectl exec deploy/checkout -n shipping -- curl -s shipping.shipping.svc.cluster.local:8080/
kubectl exec deploy/admin -n shipping -- curl -s shipping.shipping.svc.cluster.local:8080/
```

---

## Task 11 - Ingress Gateway + Internal Mesh Routing

**Cluster context**

- Namespace `api`, service `api-gateway` (8080), subsets v1/v2.
- Ingress Gateway `public-gw` in `istio-system`, host `api.shop.example.com`.

**Goal**

- `VirtualService` hosts `api.shop.example.com`, gateways `public-gw` and `mesh`.
- `/beta` -> 100% v2.
- `/` -> 90% v1 / 10% v2.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: api-gateway-vs
  namespace: api
spec:
  hosts:
  - api.shop.example.com
  gateways:
  - public-gw
  - mesh
  http:
  - name: beta
    match:
    - uri:
        prefix: /beta
    route:
    - destination:
        host: api-gateway.api.svc.cluster.local
        subset: v2
      weight: 100
  - name: root
    match:
    - uri:
        prefix: /
    route:
    - destination:
        host: api-gateway.api.svc.cluster.local
        subset: v1
      weight: 90
    - destination:
        host: api-gateway.api.svc.cluster.local
        subset: v2
      weight: 10
```

**Explanation / pitfalls**

- For ingress, `hosts` must match the incoming Host header. [Gateway reference][ref-gateway].
- Adding `mesh` enables the same rules internally.

**Quick verification**

```bash
curl -H "Host: api.shop.example.com" http://<INGRESS_IP>/beta
curl api-gateway.api.svc.cluster.local:8080/
```

---

## Task 12 - Multi-Host VirtualService for Admin + Public API

**Cluster context**

- Same as Task 11 plus hostname `admin.shop.internal` (mesh only).

**Goal**

- Single `VirtualService` with hosts `api.shop.example.com` and `admin.shop.internal`.
- `admin.shop.internal` -> `/` 100% v2.
- Public host retains beta/root rules.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: api-gateway-vs
  namespace: api
spec:
  hosts:
  - api.shop.example.com
  - admin.shop.internal
  gateways:
  - public-gw
  - mesh
  http:
  - name: admin-host-v2
    match:
    - authority:
        exact: admin.shop.internal
      uri:
        prefix: /
    route:
    - destination:
        host: api-gateway.api.svc.cluster.local
        subset: v2
      weight: 100
  - name: beta-public
    match:
    - authority:
        exact: api.shop.example.com
      uri:
        prefix: /beta
    route:
    - destination:
        host: api-gateway.api.svc.cluster.local
        subset: v2
      weight: 100
  - name: root-public
    match:
    - authority:
        exact: api.shop.example.com
      uri:
        prefix: /
    route:
    - destination:
        host: api-gateway.api.svc.cluster.local
        subset: v1
      weight: 90
    - destination:
        host: api-gateway.api.svc.cluster.local
        subset: v2
      weight: 10
```

**Explanation / pitfalls**

- Match host via `authority` for HTTP/1.1/2 host header. [VirtualService reference][ref-vs].
- Order host-specific rules carefully.

**Quick verification**

```bash
curl -H "Host: admin.shop.internal" http://<INGRESS_IP>/
curl -H "Host: api.shop.example.com" http://<INGRESS_IP>/
```

---

## Task 13 - Redirect / -> /docs

**Cluster context**

- Namespace `docs`, service `docs` (8080), gateway `docs-gw`, host `docs.example.com`.

**Goal**

- `/` redirects (302) to `/docs`.
- `/docs` routes to backend.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: docs-vs
  namespace: docs
spec:
  hosts:
  - docs.example.com
  gateways:
  - docs-gw
  http:
  - name: root-redirect
    match:
    - uri:
        exact: /
    redirect:
      uri: /docs
      redirectCode: 302
  - name: docs-route
    match:
    - uri:
        prefix: /docs
    route:
    - destination:
        host: docs.docs.svc.cluster.local
      weight: 100
```

**Explanation / pitfalls**

- `redirect` and `route` are mutually exclusive in a single HTTP entry. [VirtualService reference][ref-vs].

**Quick verification**

```bash
curl -I -H "Host: docs.example.com" http://<INGRESS_IP>/
curl -I -H "Host: docs.example.com" http://<INGRESS_IP>/docs
```

---

## Task 14 - Egress Control for External Payments API

**Cluster context**

- Namespace `payments`.
- Need to reach `api.external-payments.com` over HTTPS (port 443) via mesh egress.

**Goal**

- Create `ServiceEntry` allowing that host.
- Create `VirtualService` routing TLS traffic (SNI match) to the external host (optionally rewrite to `/payments/v2` if TLS termination occurs).

```yaml
# ServiceEntry
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-payments
  namespace: payments
spec:
  hosts:
  - api.external-payments.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
  location: MESH_EXTERNAL
---
# VirtualService
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: external-payments-vs
  namespace: payments
spec:
  hosts:
  - api.external-payments.com
  tls:
  - match:
    - port: 443
      sniHosts:
      - api.external-payments.com
    route:
    - destination:
        host: api.external-payments.com
        port:
          number: 443
```

**Explanation / pitfalls**

- ServiceEntries are required for mesh-aware egress. [Egress control doc][ref-egress].
- HTTPS without terminating TLS uses `tls` blocks with SNI matches.

**Quick verification**

```bash
kubectl exec deploy/client -n payments -- \
  curl -v https://api.external-payments.com/
```

---

## Task 15 - Combining Retries with Delay Faults

**Cluster context**

- Namespace `billing`, service `billing` (8080), subsets v1/v2, endpoint `/charge`.

**Goal**

- `/charge`: 70% v1 / 30% v2.
- Inject 2s delay on 30% of requests.
- `timeout: 1.5s`, `retries: attempts 2`, `perTryTimeout: 1s`.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: billing-vs
  namespace: billing
spec:
  hosts:
  - billing.billing.svc.cluster.local
  http:
  - name: charge-with-fault
    match:
    - uri:
        prefix: /charge
    fault:
      delay:
        percentage:
          value: 30
        fixedDelay: 2s
    route:
    - destination:
        host: billing.billing.svc.cluster.local
        subset: v1
      weight: 70
    - destination:
        host: billing.billing.svc.cluster.local
        subset: v2
      weight: 30
    timeout: 1.5s
    retries:
      attempts: 2
      perTryTimeout: 1s
```

**Explanation / pitfalls**

- Client-side faults can conflict with aggressive timeouts/retries, intentionally highlighting resilience misconfigs. [VirtualService doc][ref-vs].

**Quick verification**

Send traffic and watch for timeouts in client logs; adjust timeouts later as a follow-up.

---

## Task 16 - AND vs OR Matching for Canary Users

**Cluster context**

- Namespace `web`, service `webapp` (8080), subsets v1/v2.

**Goal**

- `/app` with header `x-user-type: canary` -> 100% v2.
- Other `/app` traffic -> 100% v1.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: webapp-vs
  namespace: web
spec:
  hosts:
  - webapp.web.svc.cluster.local
  http:
  - name: canary-users
    match:
    - uri:
        prefix: /app
      headers:
        x-user-type:
          exact: canary
    route:
    - destination:
        host: webapp.web.svc.cluster.local
        subset: v2
      weight: 100
  - name: normal-users
    match:
    - uri:
        prefix: /app
    route:
    - destination:
        host: webapp.web.svc.cluster.local
        subset: v1
      weight: 100
```

**Explanation / pitfalls**

- Combining `uri` + `headers` under one match enforces AND logic; multiple list entries would OR them. [Match behavior discussion][ref-match].

**Quick verification**

```bash
curl -s -H "x-user-type: canary" webapp.web.svc.cluster.local:8080/app
curl -s webapp.web.svc.cluster.local:8080/app
```

---

## Task 17 - Delegating VirtualServices

**Cluster context**

- Namespace `bookinfo`.
- Parent VirtualService `bookinfo` delegates to `productpage` and `reviews`.

**Goal**

- Main VS matches `/productpage` and `/reviews` and delegates to respective child VirtualServices.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: bookinfo
  namespace: bookinfo
spec:
  hosts:
  - bookinfo.example.com
  gateways:
  - bookinfo-gw
  http:
  - match:
    - uri:
        prefix: /productpage
    delegate:
      name: productpage
      namespace: bookinfo
  - match:
    - uri:
        prefix: /reviews
    delegate:
      name: reviews
      namespace: bookinfo
```

**Explanation / pitfalls**

- Delegated VS definitions (`productpage`, `reviews`) must share the same hosts and define their own routes. [Networking v1 API][ref-delegate].

**Quick verification**

Apply delegate VS resources, curl `/productpage` and `/reviews`, and inspect proxy routes:

```bash
istioctl proxy-config routes <pod> -n bookinfo
```

---

## Task 18 - Different Policies for gRPC vs HTTP

**Cluster context**

- Namespace `media`, service `media` (8080), subsets v1/v2.
- gRPC path `/grpc.MediaService/*`, REST `/api/*`.

**Goal**

- gRPC path -> 100% v2, `timeout: 1s`, `retries: attempts 1`.
- REST path -> 70% v1 / 30% v2, `timeout: 5s`, `retries: attempts 3`, `perTryTimeout: 2s`.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: media-vs
  namespace: media
spec:
  hosts:
  - media.media.svc.cluster.local
  http:
  - name: grpc-route
    match:
    - uri:
        prefix: /grpc.MediaService/
    route:
    - destination:
        host: media.media.svc.cluster.local
        subset: v2
      weight: 100
    timeout: 1s
    retries:
      attempts: 1
  - name: rest-route
    match:
    - uri:
        prefix: /api
    route:
    - destination:
        host: media.media.svc.cluster.local
        subset: v1
      weight: 70
    - destination:
        host: media.media.svc.cluster.local
        subset: v2
      weight: 30
    timeout: 5s
    retries:
      attempts: 3
      perTryTimeout: 2s
```

**Explanation / pitfalls**

- gRPC is just HTTP/2; Istio VirtualServices treat it like HTTP routing with path prefixes. [Traffic management concepts][ref-traffic].

**Quick verification**

Use gRPC client for `/grpc.MediaService/` and curl for `/api`, ensuring timeouts/retries align with expectations.

---

## Task 19 - DR trafficPolicy + VS Routing

**Cluster context**

- Namespace `analytics`, service `analytics` (8080), subsets v1/v2.

**Goal**

- DestinationRule `analytics-dr` sets subsets and global retry policy (attempts 3, perTryTimeout 2s).
- VirtualService `analytics-vs` routes `/reports` 50/50 without overriding retries.

```yaml
# DestinationRule
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: analytics-dr
  namespace: analytics
spec:
  host: analytics.analytics.svc.cluster.local
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  trafficPolicy:
    retries:
      attempts: 3
      perTryTimeout: 2s
---
# VirtualService
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: analytics-vs
  namespace: analytics
spec:
  hosts:
  - analytics.analytics.svc.cluster.local
  http:
  - match:
    - uri:
        prefix: /reports
    route:
    - destination:
        host: analytics.analytics.svc.cluster.local
        subset: v1
      weight: 50
    - destination:
        host: analytics.analytics.svc.cluster.local
        subset: v2
      weight: 50
```

**Explanation / pitfalls**

- Retry policies in DR apply per-destination unless overridden in VS. [DestinationRule reference][ref-dr].

**Quick verification**

```bash
kubectl exec deploy/client -n analytics -- \
  curl -s analytics.analytics.svc.cluster.local:8080/reports
```

(Optional) Induce failures to confirm retries via Envoy stats.

---

## Task 20 - Fix Misordered Rules for /api/slow

**Cluster context**

- Namespace `notifications`, service `notifications` (8080), subsets v1/v2.
- Existing VS had `/api/` before `/api/slow`, causing slow rule to never match.

**Goal**

- Reorder rules so `/api/slow` (5s delay on 10% requests, v1 only) is first, followed by `/api/` default 80/20 split.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: notifications-vs
  namespace: notifications
spec:
  hosts:
  - notifications.notifications.svc.cluster.local
  http:
  - name: api-slow
    match:
    - uri:
        prefix: /api/slow
    fault:
      delay:
        percentage:
          value: 10
        fixedDelay: 5s
    route:
    - destination:
        host: notifications.notifications.svc.cluster.local
        subset: v1
      weight: 100
  - name: api-default
    match:
    - uri:
        prefix: /api/
    route:
    - destination:
        host: notifications.notifications.svc.cluster.local
        subset: v1
      weight: 80
    - destination:
        host: notifications.notifications.svc.cluster.local
        subset: v2
      weight: 20
```

**Explanation / pitfalls**

- Always place more specific matches before generic ones; Istio evaluates HTTP routes in order. [Traffic management concepts][ref-traffic].

**Quick verification**

```bash
curl -s notifications.notifications.svc.cluster.local:8080/api/slow
curl -s notifications.notifications.svc.cluster.local:8080/api/foo
```

---

## Task 21 - Explicit Retry Policy for a Flaky Service

**Cluster context**

- Namespace `flaky`, service `flaky` (ClusterIP, port 8080).
- Single deployment; pods labeled `app=flaky`.
- Endpoint `/unstable` intermittently fails with HTTP 503 or connection errors.

**Goal**

- Create `VirtualService` `flaky-vs` (no DestinationRule needed) that:
  - Matches `/unstable`.
  - Routes 100% to `flaky.flaky.svc.cluster.local`.
  - Configures retries: `attempts: 3`, `perTryTimeout: 2s`, `retryOn: connect-failure,5xx`.
  - Sets route-level `timeout: 7s` so Envoy can perform all attempts.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: flaky-vs
  namespace: flaky
spec:
  hosts:
  - flaky.flaky.svc.cluster.local
  http:
  - name: unstable-with-retries
    match:
    - uri:
        prefix: /unstable
    route:
    - destination:
        host: flaky.flaky.svc.cluster.local
      weight: 100
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: connect-failure,5xx
    timeout: 7s
```

**Explanation / pitfalls**

- `http[*].retries` exposes Envoy’s retry policy knobs (`attempts`, `perTryTimeout`, `retryOn`). [VirtualService reference][ref-vs].
- The route-level `timeout` bounds the entire call; if it is shorter than `(attempts * perTryTimeout)`, Envoy will stop retrying early.
- Since there’s only one backend version, no subsets are required.

**Quick verification**

```bash
kubectl exec deploy/client -n flaky -- \
  sh -c 'for i in $(seq 1 10); do curl -s -o /dev/null -w "code=%{http_code} time=%{time_total}\n" flaky.flaky.svc.cluster.local:8080/unstable; sleep 1; done'
```

Expect some calls taking longer (due to retries) yet eventually succeeding instead of failing immediately with 5xx/connection errors.

---

## Task 22 - Bonus: Fix a Misconfigured Retry Route

**Cluster context**

- Namespace `experiment`, service `experiment` (8080), single version.
- Endpoint `/test` responds with HTTP 500 after ~500ms every time.
- Existing VirtualService sets retries but only gives the route `timeout: 3s`, so Envoy performs at most one retry.

**Goal**

- Update the VirtualService time budget so Envoy can honor `attempts: 3` with `perTryTimeout: 2s`.
- Keep `retryOn: gateway-error,connect-failure,5xx`.
- Increase `timeout` to ~10s.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: experiment-vs
  namespace: experiment
spec:
  hosts:
  - experiment.experiment.svc.cluster.local
  http:
  - name: test-with-retries-fixed
    match:
    - uri:
        prefix: /test
    route:
    - destination:
        host: experiment.experiment.svc.cluster.local
      weight: 100
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: gateway-error,connect-failure,5xx
    timeout: 10s
```

**Explanation / pitfalls**

- Per the VirtualService docs, `timeout` directly limits how many retries can actually occur; a 3s timeout with 2s per-try leaves room for only ~1 retry. Raising the timeout to 10s affords three full attempts plus backoff jitter.
- This fix mirrors Istio’s canonical retry examples (attempts + perTryTimeout + generous timeout).

**Quick verification**

```bash
kubectl exec deploy/client -n experiment -- \
  sh -c 'for i in $(seq 1 5); do curl -s -o /dev/null -w "code=%{http_code} time=%{time_total}\n" experiment.experiment.svc.cluster.local:8080/test; echo "---"; done'
```

You should observe total times >2s and, if logging is enabled, multiple upstream attempts before the final response.

---

## References

- [ref-dr]: https://istio.io/latest/docs/reference/config/networking/destination-rule/
- [ref-vs]: https://istio.io/latest/docs/reference/config/networking/virtual-service/
- [ref-match]: https://github.com/istio/istio/issues/16959
- [ref-traffic]: https://istio.io/latest/docs/concepts/traffic-management/
- [ref-routing]: https://istio.io/latest/docs/tasks/traffic-management/request-routing/
- [ref-fault]: https://istio.io/latest/docs/tasks/traffic-management/fault-injection/
- [ref-shift]: https://istio.io/latest/docs/tasks/traffic-management/traffic-shifting/
- [ref-sourcelabels]: https://www.lisenet.com/2021/blue-green-deployment-with-istio-match-host-header-and-sourcelabels-for-pod-to-pod-communication/
- [ref-gateway]: https://istio.io/latest/docs/reference/config/networking/gateway/
- [ref-egress]: https://istio.io/latest/docs/tasks/traffic-management/egress/egress-control/
- [ref-delegate]: https://pkg.go.dev/istio.io/api/networking/v1
