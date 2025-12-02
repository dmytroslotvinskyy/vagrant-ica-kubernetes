# Full Exam-Style Practice (16 Tasks, 100 pts)

This branch includes a self-contained Istio 1.26.x practice scenario that mirrors the ICA format (hands-on tasks with scoring). Provisioning now loads both the default ICA lab _and_ exam resources so you can switch between them at will.

## Workflow

1. `vagrant up` (or `vagrant provision controlplane`). The control plane runs:
   - `scripts/istio-ica-lab.sh` (original workloads)
   - `scripts/exam-setup.sh` (exam baseline namespaces/services)
2. `vagrant ssh controlplane`
3. Solve tasks using the manifests in `manifests/` or your own YAML.
4. Run `/vagrant/check-exam.sh <task-ids>` (e.g. `1 2 3`) or `all` (default) to score your work.

`check-exam.sh` models the ICA passing threshold (≥68 points). Every task has a weight and is validated individually, so you can focus on weak spots.

## Task List

| # | Points | Description |
| - | -----: | ----------- |
| 1 | 8 | Install Istio (demo profile) and verify istiod + ingressgateway |
| 2 | 5 | Enable injection in `default` and deploy `httpbin` + `curl` |
| 3 | 10 | Istio Gateway + VirtualService exposing httpbin on host `httpbin.com` |
| 4 | 7 | Kubernetes Gateway API (Gateway + HTTPRoute) routing to httpbin |
| 5 | 10 | `payments` subsets (v1/v2) + VirtualService 70/30 split |
| 6 | 8 | `helloworld` URI match + rewrite + subset routing (v1/v2 + fallback) |
| 7 | 6 | Add timeout (2s) + retries (3 attempts, perTry 1s, 5xx/connect/refused) |
| 8 | 4 | Fault injection: 2s delay on `/v2` for 20% traffic |
| 9 | 7 | Circuit breaking (http1MaxPendingRequests/http2MaxRequests/maxRequestsPerConnection = 1) |
|10 | 6 | Outlier detection on `fakeservice` (consecutive5xx=1, interval 5s, base 3m, 100%) |
|11 | 4 | Prometheus addon deployed |
|12 | 5 | Kiali addon deployed + `bookinfo` namespace labeled for injection |
|13 | 4 | Jaeger addon + Telemetry with 100% sampling |
|14 | 8 | PeerAuthentication STRICT namespace + httpbin port-level PERMISSIVE override |
|15 | 8 | AuthorizationPolicy: allowlist POSTs from `curl` SA only |
|16 | 10 | Revision canary: install `--revision 1-26-3`, tag `latest`, migrate `swagger` ns |

Total possible points: 100. Passing score: 68 (mirrors ICA FAQ guidance).

## Tips

- All tasks use Istio v1 CRDs: `networking.istio.io/v1`, `security.istio.io/v1`, `gateway.networking.k8s.io/v1`, `telemetry.istio.io/v1`.
- The baseline workloads deployed by `scripts/exam-setup.sh` cover `default`, `payments`, and `swagger` namespaces. Add-ons (Prometheus, Kiali, Jaeger) are intentionally _not_ installed so you can practice enabling them.
- `check-exam.sh` only validates resource state. It does **not** run traffic or apply manifests for you—just like the exam, you must build the YAML and any curl tests.

You can extend the list by adding manifests under `manifests/exam/` and updating the checker with new point allocations.#
