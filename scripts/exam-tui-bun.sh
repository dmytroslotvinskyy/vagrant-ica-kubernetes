#!/usr/bin/env bash
# Convenience wrapper that ensures Bun + TUI dependencies are installed,
# then launches the tmux-based exam environment with the JS task viewer.

set -euo pipefail

REPO_ROOT="/vagrant"
TUI_DIR="${REPO_ROOT}/apps/exam-ui"
LOCAL_TUI_DIR="/tmp/exam-ui"
EXAM_ENV_SCRIPT="${REPO_ROOT}/scripts/exam-env-tui.sh"
BUN_INSTALL_DIR="${BUN_INSTALL:-$HOME/.bun}"
export PATH="${BUN_INSTALL_DIR}/bin:${PATH}"

source /vagrant/scripts/tui-common.sh

if ! kubectl get ns istio-system >/dev/null 2>&1; then
  echo "[exam-tui] istio-system namespace not found. Run lab bring-up first:"
  echo "  sudo /vagrant/scripts/lab-up.sh"
  exit 1
fi

launch_tmux_env() {
  if [ ! -x "$EXAM_ENV_SCRIPT" ]; then
    echo "[exam-tui-bun] ERROR: $EXAM_ENV_SCRIPT is missing or not executable." >&2
    exit 1
  fi
  # Ensure we don't attach to a stale tmux session that might be running the old viewer.
  if command -v tmux >/dev/null 2>&1; then
    tmux kill-session -t exam >/dev/null 2>&1 || true
  fi
  echo "[exam-tui-bun] Launching tmux exam environment with TUI..."
  export TUI_DIR="$LOCAL_TUI_DIR"
  export TASK_FILE="${REPO_ROOT}/exam-tasks.md"
  export FLAG_FILE="${HOME}/.ica-task-flags"
  exec sudo TUI_DIR="$LOCAL_TUI_DIR" TASK_FILE="$TASK_FILE" FLAG_FILE="$FLAG_FILE" "$EXAM_ENV_SCRIPT"
}

ensure_bun
prepare_tui_dir "$TUI_DIR" "$LOCAL_TUI_DIR"
launch_tmux_env
