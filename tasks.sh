#!/usr/bin/env bash
set -euo pipefail

cat <<'TASKS'
==================== ICA / Istio 1.26 – TRAFFIC MGMT LAB ====================

Cluster workflow:
 1. `vagrant up` (or `vagrant provision controlplane`)
 2. `vagrant ssh controlplane`
 3. Solve tasks (YAML files under /vagrant or kubectl apply -f -)
 4. `/vagrant/check-exam.sh <task-numbers>` to validate
      • Example: `/vagrant/check-exam.sh 1` (just Task 1)
      • `/vagrant/check-exam.sh 1 2 3` (multiple)
      • `/vagrant/check-exam.sh all` (best-effort full suite; remember some tasks supersede previous configs)
 5. Full write-ups + YAML solutions live in `docs/istio-traffic-module.md`.

Namespaces, services, and sample deployments for every task are pre-created in the lab
(orders, catalog, cart, …). Each namespace also has `deploy/client` (curl runner).

------------------------------------------------------------------
Task 1 – Orders weighted split (DestinationRule + VirtualService)
------------------------------------------------------------------
Namespace: `orders`
Service: `orders` (port 8080), Deployments `orders-v1`, `orders-v2`
Goal:
  - DestinationRule `orders-dr` host orders.orders.svc.cluster.local with subsets v1/v2 (labels version=v1/v2).
  - VirtualService `orders-vs` default `/` split 60% subset v1 / 40% subset v2 (this base rule gets replaced in Task 2; the checker focuses on the DR for Task 1).

------------------------------------------------------------------
Task 2 – Orders header-based canary override
------------------------------------------------------------------
Namespace: `orders`
Goal (update `orders-vs`):
  - Match header `x-canary: v2` + `/` → 100% subset v2.
  - Default `/` traffic → 70% subset v1 / 30% subset v2.

------------------------------------------------------------------
Task 3 – Catalog path routing with rewrites
------------------------------------------------------------------
Namespace: `catalog`
Service exposes `/items` only.
Goal:
  - VirtualService `catalog-vs`:
      `/api/v1` rewrite→`/items`, 100% subset v1.
      `/api/v2` rewrite→`/items`, 100% subset v2.
      `/api` rewrite→`/items`, 50/50 split.

------------------------------------------------------------------
Task 4 – Cart timeout + retries
------------------------------------------------------------------
Namespace: `cart`
Goal:
  - VirtualService `cart-vs` `/checkout`: 80% subset v1 / 20% subset v2.
  - timeout 3s; retries attempts=3, perTryTimeout=1s.

------------------------------------------------------------------
Task 5 – Reporting delay fault injection
------------------------------------------------------------------
Namespace: `reporting`
Goal:
  - VirtualService `reporting-vs`:
      `/metrics/slow` fault delay 4s on 20% requests, route subset v1, timeout 5s.
      `/metrics` default split 50/50 subsets v1/v2, timeout 5s.

------------------------------------------------------------------
Task 6 – Profile abort fault injection
------------------------------------------------------------------
Namespace: `profile`
Goal:
  - VirtualService `profile-vs` for `/health`: abort 5% with HTTP 503, rest 100% subset v1, timeout 2s.

------------------------------------------------------------------
Task 7 – Audit mirroring
------------------------------------------------------------------
Namespace: `audit`
Additional service: `audit-shadow`.
Goal:
  - VirtualService `audit-vs` `/events`: 90% subset v1 / 10% subset v2.
  - Mirror 100% traffic to `audit-shadow.audit.svc.cluster.local`.

------------------------------------------------------------------
Task 8 – Inventory three-way split + canary header
------------------------------------------------------------------
Namespace: `inventory`
Goal:
  - VirtualService `inventory-vs`:
      Header `x-canary: v3` + `/stock` → subset v3.
      Default `/stock` → 60% v1 / 30% v2 / 10% v3.

------------------------------------------------------------------
Task 9 – Frontend API CORS policy
------------------------------------------------------------------
Namespace: `frontend`
Service: `frontend-api`
Goal:
  - VirtualService `frontend-api-vs` for `/api`:
      allowOrigins: https://shop.example.com
      allowMethods: GET, POST
      allowHeaders: Authorization, Content-Type
      maxAge: 24h

------------------------------------------------------------------
Task 10 – Shipping sourceLabels routing
------------------------------------------------------------------
Namespace: `shipping`
Service: `shipping` (subsets v1/v2); Deployments `checkout` (app=checkout), `admin` (app=admin)
Goal:
  - VirtualService `shipping-vs`, gateways [`mesh`]:
      Requests from pods with `app=checkout` → 100% subset v2.
      All other `/` traffic → 100% subset v1.

------------------------------------------------------------------
Task 11 – API Gateway ingress + mesh VS
------------------------------------------------------------------
Namespace: `api`
Service: `api-gateway` (subsets v1/v2); Gateway `public-gw` exists in `istio-system`.
Goal:
  - VirtualService `api-gateway-vs` hosts [`api.shop.example.com`], gateways [`public-gw`, `mesh`].
      `/beta` → subset v2 (100%).
      `/` → 90% subset v1 / 10% subset v2.

------------------------------------------------------------------
Task 12 – Multi-host API VS
------------------------------------------------------------------
Namespace: `api`
Goal:
  - Extend `api-gateway-vs` hosts to include `admin.shop.internal`.
  - Add rule `admin.shop.internal` `/` → subset v2.
  - Keep Task 11 routes for `api.shop.example.com`.

------------------------------------------------------------------
Task 13 – Docs redirect
------------------------------------------------------------------
Namespace: `docs`
Gateway: `docs-gw`
Goal:
  - VirtualService `docs-vs`: `/` redirect→`/docs` (302). `/docs` route to docs service.

------------------------------------------------------------------
Task 14 – Egress to external payments API
------------------------------------------------------------------
Namespace: `payments`
External host: `api.external-payments.com`
Goal:
  - ServiceEntry `external-payments` allowing HTTPS (port 443) to that host.
  - VirtualService `external-payments-vs` that forwards TLS (SNI api.external-payments.com).

------------------------------------------------------------------
Task 15 – Billing retries + delay fault
------------------------------------------------------------------
Namespace: `billing`
Goal:
  - VirtualService `billing-vs` `/charge`:
      70% subset v1 / 30% subset v2.
      Fault delay 2s on 30% requests.
      timeout 1.5s; retries attempts=2, perTryTimeout=1s, retryOn connect-failure,5xx.

------------------------------------------------------------------
Task 16 – Webapp AND vs OR header matching
------------------------------------------------------------------
Namespace: `web`
Goal:
  - VirtualService `webapp-vs`:
      `/app` + header `x-user-type: canary` → 100% subset v2.
      Other `/app` requests → 100% subset v1.

------------------------------------------------------------------
Task 17 – Bookinfo VirtualService delegation
------------------------------------------------------------------
Namespace: `bookinfo`
Goal:
  - Parent VirtualService `bookinfo` (hosts `bookinfo.example.com`, gateway `bookinfo-gw`) delegates:
      `/productpage` → delegate `productpage`.
      `/reviews` → delegate `reviews`.
  - Create delegated VirtualServices (`productpage`, `reviews`) that contain actual routes.

------------------------------------------------------------------
Task 18 – Media gRPC vs REST policies
------------------------------------------------------------------
Namespace: `media`
Goal:
  - VirtualService `media-vs`:
      `/grpc.MediaService/` → subset v2, timeout 1s, retries attempts=1.
      `/api` → 70% subset v1 / 30% subset v2, timeout 5s, retries attempts=3 & perTryTimeout 2s.

------------------------------------------------------------------
Task 19 – Analytics DR trafficPolicy
------------------------------------------------------------------
Namespace: `analytics`
Goal:
  - DestinationRule `analytics-dr` subsets v1/v2 with trafficPolicy.retries attempts=3, perTryTimeout=2s.
  - VirtualService `analytics-vs` `/reports` split 50/50 without per-route retries.

------------------------------------------------------------------
Task 20 – Notifications rule ordering fix
------------------------------------------------------------------
Namespace: `notifications`
Goal:
  - VirtualService `notifications-vs`:
      Rule 1 `/api/slow` (delay 5s on 10% requests) → subset v1.
      Rule 2 `/api/` default split 80% subset v1 / 20% subset v2.

------------------------------------------------------------------
Task 21 – Flaky service retry policy
------------------------------------------------------------------
Namespace: `flaky`
Goal:
  - VirtualService `flaky-vs` `/unstable` route 100% to service with retries:
      attempts=3, perTryTimeout=2s, retryOn connect-failure,5xx, timeout 7s.

------------------------------------------------------------------
Task 22 – Experiment timeout fix for retries
------------------------------------------------------------------
Namespace: `experiment`
Goal:
  - VirtualService `experiment-vs` `/test` route 100% to service with retries:
      attempts=3, perTryTimeout=2s, retryOn gateway-error,connect-failure,5xx,
      timeout increased to 10s so Envoy can execute all retries.

Need deeper context or YAML? → `docs/istio-traffic-module.md`

TASKS
