# Full Exam-Style Practice (16 Tasks, 100 pts)

This branch delivers a self-contained Istio 1.26.x mock exam: the cluster provisions all workloads automatically, 16 hands-on tasks mirror the ICA blueprint, and `check-exam.sh` reports a zch-style scoreboard so you can track progress at a glance.

## Workflow

1. `vagrant up` (or `vagrant provision controlplane`). The control plane runs:
   - `scripts/istio-ica-lab.sh` (core lab workloads, helper scripts, task viewer)
   - `scripts/exam-setup.sh` (exam namespaces/services)
2. `vagrant ssh controlplane`
3. Solve tasks using `manifests/` or your own YAML (see `/vagrant/exam-tasks.md` for the full text)
4. Run `/vagrant/check-exam.sh <task-ids>` (e.g., `1 2 3`) or no arguments/`all` to grade every task

`check-exam.sh` targets the ICA passing bar (68/100). Each task contributes weighted points derived from the real exam’s percentages, and the script stores PASS/FAIL/SKIP to print a scoreboard summary with totals.

### Optional: zch-style task viewer

Inside the control plane VM, launch:

```bash
sudo /vagrant/scripts/exam-env.sh
```

This opens a tmux layout where:

- Left pane runs `/vagrant/scripts/tasks-viewer.sh` with a built-in navigator so you can jump between the 16 prompts (keys: `1-16` to jump, `Enter`/`n`/`j` for next, `p`/`k` for previous, `f` to flag/unflag, `c` to clear all flags, `q` to exit)
- Right pane is your working shell for kubectl, istioctl, editors, and the checker

## Task List (weighted to 100 pts)

| # | Points | Description |
| - | -----: | ----------- |
| 1 | 7 | Install Istio (demo profile) and verify `istiod` + `istio-ingressgateway` |
| 2 | 5 | Enable injection in `default` and keep the `httpbin` + `curl` pods with sidecars |
| 3 | 9 | Expose httpbin via Istio Gateway + VirtualService for host `httpbin.com` |
| 4 | 6 | Publish httpbin through Gateway API (`httpbin-kgw` + `httpbin-route`) |
| 5 | 9 | `payments` DestinationRule/VirtualService splitting 70/30 between v1/v2 |
| 6 | 7 | `helloworld` URI matches `/v1` `/v2` with rewrites plus default fallback |
| 7 | 5 | Payments timeout (2s) + retries (3 attempts, per-try 1s, 5xx/connect/refused) |
| 8 | 4 | Fault injection: add a 2s delay to 20% of `/v2` traffic |
| 9 | 6 | Circuit breaking for helloworld (limit pending requests/max requests per connection) |
| 10 | 6 | Outlier detection for `fakeservice` (consecutive5xx=1, interval 5s, base 3m, 100%) |
| 11 | 4 | Prometheus addon deployed in `istio-system` |
| 12 | 5 | Deploy Kiali and label `bookinfo` for injection |
| 13 | 4 | Deploy Jaeger and configure Telemetry sampling at 100% |
| 14 | 7 | PeerAuthentication: STRICT namespace + port-level PERMISSIVE for httpbin 8080 |
| 15 | 7 | AuthorizationPolicy allowing only the `curl` SA to POST to httpbin |
| 16 | 9 | Revision canary: install `--revision 1-26-3`, tag `latest`, migrate `swagger` namespace |

Total possible points: 100. Passing score: 68.

## Tips

- All tasks use Istio v1 APIs: `networking.istio.io/v1`, `security.istio.io/v1`, `gateway.networking.k8s.io/v1`, `telemetry.istio.io/v1`.
- Baseline namespaces: `default`, `payments`, and `swagger`; add-ons (Prometheus, Kiali, Jaeger) should be installed as part of the tasks.
- `check-exam.sh` only inspects resources. Recreate the exam experience by running your own `kubectl exec` or `curl` smoke tests.
- Extending the exam? Add manifests under `manifests/exam/`, update `exam-tasks.md`, and tweak the `TASK_POINTS` map in `check-exam.sh`.
