#!/usr/bin/env bash
set -euo pipefail

# Auto-detect KUBECONFIG (same logic as verify-lab.sh)
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

# Auto-detect checker script (same logic as verify-lab.sh)
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

KUBECONFIG_PATH="$(auto_kubeconfig)"
if [ -z "$KUBECONFIG_PATH" ]; then
  echo "[exam-scoreboard] WARNING: No kubeconfig found. Checker may fail." >&2
  echo "[exam-scoreboard] Expected locations: ./configs/config, /vagrant/configs/config, /etc/kubernetes/admin.conf" >&2
else
  export KUBECONFIG="$KUBECONFIG_PATH"
fi

CHECKER="$(auto_checker)"
if [ -z "$CHECKER" ]; then
  echo "[exam-scoreboard] WARNING: No checker script found." >&2
  echo "[exam-scoreboard] Expected locations: /vagrant/check-exam.sh, ./check-exam.sh" >&2
  CHECKER="/vagrant/check-exam.sh"  # fallback for error messages
fi

INTERVAL="${SCOREBOARD_INTERVAL:-180}"

if [ ! -x "$CHECKER" ]; then
  echo "[exam-scoreboard] Checker not found at $CHECKER; running in stub mode." >&2
fi

tasks=("$@")
cmd=("$CHECKER")
if [ "${#tasks[@]}" -gt 0 ]; then
  cmd+=("${tasks[@]}")
fi

trap 'exit 0' INT TERM

while true; do
  clear
  printf "[exam-scoreboard] %s (as %s)\n\n" "$(date)" "$(whoami)"
  if [ -x "$CHECKER" ]; then
    "${cmd[@]}" || true
  else
    echo "[exam-scoreboard] Checker unavailable. Expected at: $CHECKER"
  fi
  echo
  echo "[exam-scoreboard] Next refresh in ${INTERVAL}s (Ctrl+C to stop)"
  sleep "$INTERVAL"
done
