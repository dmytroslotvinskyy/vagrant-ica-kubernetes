#!/usr/bin/env bash
set -euo pipefail

cat << 'TASKS'
==================== ICA / Istio 1.26 – TRAFFIC MGMT LAB ====================

Cluster:
  - kubeadm CKA-style cluster (vagrant-kubeadm-kubernetes)
  - Istio 1.26.3 demo profile installed
  - Sidecar injection enabled for:
      - default
      - payments
  - Sample workloads:
      - helloworld.default.svc.cluster.local:5000
          - Deployments helloworld-v1 (version=v1), helloworld-v2 (version=v2)
      - payments.payments.svc.cluster.local:8080
          - Deployments payments-v1 (version=v1), payments-v2 (version=v2)
      - curl client in default (Deployment: curl)

You will solve the following tasks and then run: /vagrant/check-ica.sh

------------------------------------------------------------------
Task 1 – DestinationRule for helloworld (subsets v1/v2)
------------------------------------------------------------------
Namespace: default
Service: helloworld (port 5000)

Create a DestinationRule named helloworld-dr in namespace default:

  - apiVersion: networking.istio.io/v1
  - spec.host: helloworld.default.svc.cluster.local
  - subsets:
      - name: v1, labels: version=v1
      - name: v2, labels: version=v2

------------------------------------------------------------------
Task 2 – VirtualService for helloworld (weights + canary header + rewrite)
------------------------------------------------------------------
Create a VirtualService helloworld-vs in namespace default (v1 API) that:

  - hosts: ["helloworld.default.svc.cluster.local"]
  - For requests to /hello:
      - Default split: 80% to subset v1, 20% to subset v2
  - For requests with header x-canary: true to /hello:
      - Route 100% to subset v2 (override default split)
  - For path prefix /v1:
      - Rewrite URI to /hello
      - Route 100% to subset v1
  - For path prefix /v2:
      - Rewrite URI to /hello
      - Route 100% to subset v2

------------------------------------------------------------------
Task 3 – DestinationRule for payments (subsets v1/v2)
------------------------------------------------------------------
Namespace: payments
Service: payments (port 8080)

Create a DestinationRule named payments-dr in namespace payments:

  - apiVersion: networking.istio.io/v1
  - spec.host: payments.payments.svc.cluster.local
  - subsets:
      - name: v1, labels: version=v1
      - name: v2, labels: version=v2

------------------------------------------------------------------
Task 4 – Advanced VirtualService for payments (header + path + rewrite + weights)
------------------------------------------------------------------
Create a VirtualService named payments-vs (v1 API) in namespace payments that:

  - hosts:
      - payments.payments.svc.cluster.local

  HTTP rules (in order, first match wins):

  1) Header-based canary override:
     - If header X-Canary: v2 is present
       and URI prefix is /api/
     - Route 100% to subset v2

  2) /api/v2/ → URI rewrite + weighted:
     - match uri prefix: /api/v2/
     - rewrite uri: /api/
     - route:
         - 80% → subset v2
         - 20% → subset v1

  3) default /api/ traffic:
     - match uri prefix: /api/
     - route:
         - 70% → subset v1
         - 30% → subset v2

  4) /api/slow fault injection:
     - match uri prefix: /api/slow
     - fault:
         - delay:
             fixedDelay: 5s
             percentage: 10
     - route 100% to subset v1

  Global HTTP settings PER RULE (set on each http entry):
     - timeout: 2s
     - retries:
         attempts: 3
         perTryTimeout: 1s

------------------------------------------------------------------
Task 5 – Retry-focused VirtualService for a flaky service (bonus)
------------------------------------------------------------------
Namespace: payments
Service: payments (same as above)
Endpoint: /api/unstable  (assume backend sometimes returns 5xx)

Create an additional VirtualService in namespace payments named payments-retry-vs
(OR extend payments-vs if you prefer, but keep config valid) that:

  - hosts: ["payments.payments.svc.cluster.local"]
  - For uri prefix /api/unstable:
      - Route 100% to subset v1
      - Configure retries:
          - attempts: 3
          - perTryTimeout: 2s
          - retryOn: "connect-failure,5xx"
      - Route timeout: 7s

Verification hints (what a grader would run):

  - Use curl from the curl deployment in default:
      kubectl exec deploy/curl -n default -- \
        curl -s helloworld.default.svc.cluster.local:5000/hello

      kubectl exec deploy/curl -n default -- \
        curl -s payments.payments.svc.cluster.local:8080/api/

  - Inspect Istio config:
      istioctl proxy-config routes <helloworld-pod> -n default
      istioctl proxy-config routes <payments-pod> -n payments

When ready, run:

    /vagrant/check-ica.sh

TASKS
