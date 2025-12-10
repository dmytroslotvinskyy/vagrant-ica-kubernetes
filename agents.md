# Agents Guide

This repository benefits from a clear split of responsibilities when multiple automation or human agents collaborate. Use the roles below as a checklist when coordinating work so hand-offs stay lightweight and reproducible.

## Provisioner Agent
- **Mission:** Bring up and refresh the base Kubernetes cluster defined in `Vagrantfile`, `settings.yaml`, `scripts/common.sh`, `scripts/master.sh`, and `scripts/node.sh`.
- **Workflow:**
  1. Validate that `vagrant`, `virtualbox`, and required CPU/RAM are available on the host.
  2. Run `vagrant up` (no arguments) to bring up all VMs sequentially. The Vagrantfile is configured to start all nodes in the correct order automatically.
  3. **Auto-start behavior:** The controlplane has triggers configured for `:reload` and `:provision` actions (but not `:up` to avoid conflicts). This means:
     - `vagrant up` - Brings up all VMs without conflicts ✅
     - `vagrant reload controlplane` - Reloads controlplane and auto-starts workers
     - `vagrant provision controlplane` - Re-provisions controlplane and auto-starts workers
  4. A lightweight client VM `node02` boots with the rest of the lab; it ships with `kubectl` preinstalled and automatically consumes `/vagrant/configs/config` so you can run `kubectl get nodes` without sudo. Use it for scenario tasks if you don't want to work directly on `controlplane`.
  5. Copy the generated kubeconfig from `configs/config` to the operator's machine or export `KUBECONFIG=$(pwd)/configs/config`.
- **Health checks:**
  - `bash -n scripts/common.sh scripts/master.sh scripts/node.sh` (syntax).
  - `vagrant ssh controlplane -c "kubectl get nodes -o wide"` to verify all nodes are `Ready`.
  - `vagrant ssh controlplane -c "kubectl -n kube-system get pods"` for component readiness.
  - **Three-VM sanity:** expect `controlplane`, `node01`, and `node02` all `Ready` or reachable. `node02` is a client VM and should reach `kubectl get nodes` via the shared kubeconfig.
- **Exit criteria:** Cluster is reachable with admin kubeconfig and the shared `/vagrant` mount includes executable `tasks.sh` and `check-exam.sh` (chmod enforced by `scripts/istio-ica-lab.sh`).

## Istio Lab Agent
- **Mission:** Install Istio 1.26.x, prepare namespaces, and seed the sample workloads via `scripts/istio-ica-lab.sh` inside the control plane VM.
- **Key actions:**
  1. The lab provisioning is triggered automatically after the last worker node finishes via `scripts/lab-up.sh`, which orchestrates the Istio installation. Check `vagrant up` output for `[istio-ica-lab]` log lines.
  2. **Manual refresh:** If needed, rerun via `vagrant ssh controlplane -c 'sudo bash /vagrant/scripts/lab-up.sh'`
  3. Confirm Istio installation: `vagrant ssh controlplane -c "istioctl version && kubectl get ns istio-system && kubectl get pods -n istio-system"`
  4. Spot-check generated workloads: e.g., `kubectl get deploy --all-namespaces | grep orders` and `kubectl -n orders get deploy/orders-v1 -oyaml` for labels.
- **Verification quick list:**
  - `bash -n scripts/istio-ica-lab.sh` (ensures helpers such as `deploy_http_service` remain parseable).
  - `kubectl get gateway --all-namespaces` to confirm `public-gw`, `docs-gw`, and `bookinfo-gw` exist.
  - Random namespace sampling: ensure every namespace in the `LAB_NAMESPACES` array contains a `client` deployment plus the expected service/deployments.
  - **Traffic smoke:** run `kubectl -n orders exec deploy/client -- curl -s http://orders` (adjust namespace/service) to ensure sidecars and services are reachable.
- **Exit criteria:** All namespaces listed in the README exist, sidecar injection is enabled, and the helper clients (`deploy/client`) are running for smoke tests.

## Scenario QA Agent
- **Mission:** Validate traffic-management tasks via `/vagrant/check-exam.sh` and keep `tasks.sh` plus the docs consistent.
- **Steps:**
  1. **From host:** `vagrant ssh controlplane -c "bash /vagrant/check-exam.sh all"` to run all checks
  2. **From within VM:** `/vagrant/check-exam.sh <task-ids>` or `all` after applying Istio resources (baseline manifests live under `/vagrant/manifests`, e.g., `manifests/task-01-orders.yaml`)
  3. **Show solutions:** Use `-s` flag: `/vagrant/check-exam.sh -s all` to see solutions for failed tasks
  4. When updating validations, run `bash -n check-exam.sh` and, if available, `shellcheck check-exam.sh` before committing
  5. Record mismatches or gaps directly in pull-request reviews and propose doc improvements
- **Helper scripts:**
  - `./scripts/verify-lab.sh [task-ids]` - Runs cluster/Istio sanity plus exam checks (defaults to `all`)
  - `./start-exam.cmd` (Windows) or `./start-exam.sh` (Linux/Mac) - Launches exam TUI interface
- **Deliverables:**
  - Pass/fail output copied into issues/PRs
  - Regression notes whenever behavior changes (e.g., new task ordering or namespace additions)
- **Exit criteria:** The checker script runs without syntax errors, and any failing tasks have actionable feedback.

## Documentation Agent
- **Mission:** Keep `README.md`, `docs/istio-traffic-module.md`, and this `agents.md` aligned with the automation.
- **Focus areas:**
  - Update task descriptions when workloads or namespaces change.
  - Link to upstream references (Istio docs, Linux Foundation coupons) and prune outdated codes.
  - Capture troubleshooting tips (e.g., metrics server wait loop for the dashboard, MAC VirtualBox networking expectations).
- **Exit criteria:** Docs mention the current Kubernetes/Istio versions, provide a reliable study workflow, and reflect any new validation logic.

## Troubleshooting Common Issues

### VM Provisioning Conflicts
- **Symptom:** Authentication failures or duplicate VM startup attempts during `vagrant up`
- **Cause:** Older versions had an auto-start trigger on `:up` action that conflicted with the main vagrant process
- **Fix:** The Vagrantfile now only triggers auto-start on `:reload` and `:provision` actions
- **Resolution:** If VMs are stuck, run `vagrant destroy -f && vagrant up` for a clean start

### Checking VM Status
- **List all VMs:** `vagrant global-status --prune`
- **Check specific VM:** `vagrant status controlplane`
- **SSH into VM:** `vagrant ssh controlplane`
- **Check cluster health:** `vagrant ssh controlplane -c "kubectl get nodes"`

### Reset Scenarios
- **Soft reset (keep VMs):** `vagrant reload`
- **Re-provision only:** `vagrant provision`
- **Clean slate:** `vagrant destroy -f && vagrant up`
- **Istio lab refresh:** `vagrant ssh controlplane -c 'sudo bash /vagrant/scripts/lab-up.sh'`

## Hand-off Template
When switching agents, include:
1. **State:** Commands already executed (e.g., `vagrant up`, `scripts/istio-ica-lab.sh` run at <timestamp>). 
2. **Context:** Namespaces or tasks affected plus log excerpts for any failures.
3. **Next Steps:** The single most valuable action the next agent should take (run checker, update docs, rerun provisioner, etc.).

Keeping these roles explicit lets contributors parallelize without stepping on each other, even when operating under restricted shells or sandbox rules.

## Exam tmux helper quick keys
- `vagrant ssh controlplane -c 'tmux attach -t exam'` to join; helper auto-starts on boot.
- Keys inside session: `F1` tasks viewer, `F2` shell, `F3` scoreboard, `F5` restart scoreboard pane. Mouse is enabled for pane selection.
