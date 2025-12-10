#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/vagrant/configs/config}"
CHECKER="${CHECKER:-/vagrant/check-exam.sh}"
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
