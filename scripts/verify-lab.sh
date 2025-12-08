#!/usr/bin/env bash
set -euo pipefail

# One-shot verifier for cluster health, Istio basics, and exam tasks.
# Usage:
#   ./scripts/verify-lab.sh            # runs full suite with "all" tasks
#   ./scripts/verify-lab.sh 1 2 3      # runs only selected exam tasks
#
# Environment:
#   KUBECONFIG   Path to kubeconfig (defaults to ./configs/config or /etc/kubernetes/admin.conf)
#   CHECKER      Exam checker script (defaults to /vagrant/check-exam.sh or ./check-exam.sh)
#   API_RETRIES  Retry attempts for API reachability (default: 5)
#   API_DELAY    Seconds between retries (default: 3)

section() { printf "\n== %s ==\n" "$*"; }

auto_kubeconfig() {
  if [ -n "${KUBECONFIG:-}" ] && [ -f "$KUBECONFIG" ]; then
    echo "$KUBECONFIG"
    return
  fi
  if [ -f "$(pwd)/configs/config" ]; then
    echo "$(pwd)/configs/config"
    return
  fi
  if [ -f "/vagrant/configs/config" ]; then
    echo "/vagrant/configs/config"
    return
  fi
  if [ -f "/etc/kubernetes/admin.conf" ]; then
    echo "/etc/kubernetes/admin.conf"
    return
  fi
  echo ""  # not found
}

auto_checker() {
  if [ -n "${CHECKER:-}" ] && [ -x "$CHECKER" ]; then
    echo "$CHECKER"
    return
  fi
  if [ -x "/vagrant/check-exam.sh" ]; then
    echo "/vagrant/check-exam.sh"
    return
  fi
  if [ -x "./check-exam.sh" ]; then
    echo "./check-exam.sh"
    return
  fi
  echo ""  # not found
}

wait_for_api() {
  local retries="${API_RETRIES:-5}"
  local delay="${API_DELAY:-3}"
  local i
  for i in $(seq 1 "$retries"); do
    if kubectl version --short >/dev/null 2>&1; then
      return 0
    fi
    echo "[verify-lab] API not reachable yet (attempt ${i}/${retries}); sleeping ${delay}s..."
    sleep "$delay"
  done
  return 1
}

main() {
  KUBECONFIG_PATH="$(auto_kubeconfig)"
  if [ -z "$KUBECONFIG_PATH" ]; then
    echo "[verify-lab] No kubeconfig found. Set KUBECONFIG or run 'vagrant up controlplane' to generate configs/config." >&2
    exit 1
  fi
  export KUBECONFIG="$KUBECONFIG_PATH"

  CHECKER_PATH="$(auto_checker)"
  TASK_ARGS=("$@")
  if [ ${#TASK_ARGS[@]} -eq 0 ]; then
    TASK_ARGS=(all)
  fi

  section "API reachability"
  if ! wait_for_api; then
    echo "[verify-lab] Kubernetes API unreachable after retries. Is the cluster up? Try 'vagrant up controlplane'." >&2
    exit 1
  fi

  section "kubectl get nodes"
  kubectl get nodes -o wide

  section "kube-system pods"
  kubectl get pods -n kube-system

  section "Istio control plane"
  kubectl get ns istio-system
  kubectl get pods -n istio-system -o wide || true
  istioctl version || true
  if kubectl get pods -n istio-system | grep -E 'CrashLoopBackOff|Error' >/dev/null 2>&1; then
    echo "[verify-lab] WARNING: Istio control plane has unhealthy pods."
  fi

  section "Istio gateways"
  kubectl get gateway --all-namespaces || true

  section "Client pods present?"
  kubectl get deploy --all-namespaces | grep client || true

  if kubectl -n orders get deploy/client >/dev/null 2>&1; then
    section "Traffic smoke (orders)"
    kubectl -n orders exec deploy/client -- curl -s http://orders || true
  fi

  if kubectl -n bookinfo get deploy/client >/dev/null 2>&1; then
    section "Traffic smoke (bookinfo productpage)"
    kubectl -n bookinfo exec deploy/client -- curl -s http://productpage.bookinfo:9080/productpage || true
  fi

  if kubectl get gateway -A | grep -q docs-gw; then
    section "Gateway smoke (docs-gw)"
    kubectl -n docs exec deploy/client -- curl -s http://docs.bookinfo.svc.cluster.local || true
  fi

  if [ -n "$CHECKER_PATH" ]; then
    section "Exam checker (${TASK_ARGS[*]})"
    "$CHECKER_PATH" "${TASK_ARGS[@]}" || true
  else
    echo "[verify-lab] Checker script not found; skipped exam validation." >&2
  fi
}

main "$@"

