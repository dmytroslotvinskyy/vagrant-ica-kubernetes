# Agents Guide

This repository benefits from a clear split of responsibilities when multiple automation or human agents collaborate. Use the roles below as a checklist when coordinating work so hand-offs stay lightweight and reproducible.

## Provisioner Agent
- **Mission:** Bring up and refresh the base Kubernetes cluster defined in `Vagrantfile`, `settings.yaml`, `scripts/common.sh`, `scripts/master.sh`, and `scripts/node.sh`.
- **Workflow:**
  1. Validate that `vagrant`, `virtualbox`, and required CPU/RAM are available on the host.
 2. Run `vagrant up` (or `vagrant provision controlplane`) until all nodes report `Ready` via `kubectl get nodes`. The control plane provisioners now invoke `scripts/istio-ica-lab.sh` automatically on every boot, so Istio + sample workloads are present without a manual SSH step.
 3. Copy the generated kubeconfig from `configs/config` to the operator's machine or export `KUBECONFIG=$(pwd)/configs/config`.
- **Health checks:**
  - `bash -n scripts/common.sh scripts/master.sh scripts/node.sh` (syntax).
  - `kubectl get nodes -o wide` and `kubectl -n kube-system get pods` for component readiness.
- **Exit criteria:** Cluster is reachable with admin kubeconfig and the shared `/vagrant` mount includes executable `tasks.sh` and `check-ica.sh` (chmod enforced by `scripts/istio-ica-lab.sh`).

## Istio Lab Agent
- **Mission:** Install Istio 1.26.x, prepare namespaces, and seed the sample workloads via `scripts/istio-ica-lab.sh` inside the control plane VM.
- **Key actions:**
 1. Confirm the auto-run provisioner completed (look for `[istio-ica-lab]` log lines in `vagrant up` output); when troubleshooting or refreshing, rerun manually via `vagrant ssh controlplane -c 'sudo /vagrant/scripts/istio-ica-lab.sh'`.
  2. Confirm `istioctl version`, `kubectl get ns istio-system`, and `kubectl get pods -n istio-system` all succeed.
  3. Spot-check generated workloads: e.g., `kubectl get deploy --all-namespaces | grep orders` and `kubectl -n orders get deploy/orders-v1 -oyaml` for labels.
- **Verification quick list:**
  - `bash -n scripts/istio-ica-lab.sh` (ensures helpers such as `deploy_http_service` remain parseable).
  - `kubectl get gateway --all-namespaces` to confirm `public-gw`, `docs-gw`, and `bookinfo-gw` exist.
  - Random namespace sampling: ensure every namespace in the `LAB_NAMESPACES` array contains a `client` deployment plus the expected service/deployments.
- **Exit criteria:** All namespaces listed in the README exist, sidecar injection is enabled, and the helper clients (`deploy/client`) are running for smoke tests.

## Scenario QA Agent
- **Mission:** Validate traffic-management tasks via `/vagrant/check-ica.sh` and keep `tasks.sh` plus the docs consistent.
- **Steps:**
 1. Inside the control plane VM, run `/vagrant/check-ica.sh <task-ids>` or `all` after authors apply their Istio resources (baseline manifests now live under `/vagrant/manifests`, e.g., `manifests/task-01-orders.yaml`).
  2. When updating validations, run `bash -n check-ica.sh` and, if available, `shellcheck check-ica.sh` before committing.
  3. Record mismatches or gaps directly in pull-request reviews and propose doc improvements.
- **Deliverables:**
  - Pass/fail output copied into issues/PRs.
  - Regression notes whenever behavior changes (e.g., new task ordering or namespace additions).
- **Exit criteria:** The checker script runs without syntax errors, and any failing tasks have actionable feedback.

## Documentation Agent
- **Mission:** Keep `README.md`, `docs/istio-traffic-module.md`, and this `agents.md` aligned with the automation.
- **Focus areas:**
  - Update task descriptions when workloads or namespaces change.
  - Link to upstream references (Istio docs, Linux Foundation coupons) and prune outdated codes.
  - Capture troubleshooting tips (e.g., metrics server wait loop for the dashboard, MAC VirtualBox networking expectations).
- **Exit criteria:** Docs mention the current Kubernetes/Istio versions, provide a reliable study workflow, and reflect any new validation logic.

## Hand-off Template
When switching agents, include:
1. **State:** Commands already executed (e.g., `vagrant up`, `scripts/istio-ica-lab.sh` run at <timestamp>). 
2. **Context:** Namespaces or tasks affected plus log excerpts for any failures.
3. **Next Steps:** The single most valuable action the next agent should take (run checker, update docs, rerun provisioner, etc.).

Keeping these roles explicit lets contributors parallelize without stepping on each other, even when operating under restricted shells or sandbox rules.
