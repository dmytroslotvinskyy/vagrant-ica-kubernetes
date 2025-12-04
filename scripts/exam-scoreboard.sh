#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"
CHECKER="${CHECKER:-/vagrant/check-exam.sh}"
INTERVAL="${SCOREBOARD_INTERVAL:-180}"

if [ ! -x "$CHECKER" ]; then
  echo "[exam-scoreboard] Checker not found or not executable: $CHECKER" >&2
  exit 1
fi

tasks=("$@")
cmd=("$CHECKER")
if [ "${#tasks[@]}" -gt 0 ]; then
  cmd+=("${tasks[@]}")
fi

trap 'exit 0' INT TERM

while true; do
  clear
  printf "[exam-scoreboard] %s\n\n" "$(date)"
  "${cmd[@]}" || true
  echo
  echo "[exam-scoreboard] Next refresh in ${INTERVAL}s (Ctrl+C to stop)"
  sleep "$INTERVAL"
done
