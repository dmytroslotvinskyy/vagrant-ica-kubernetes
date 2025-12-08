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

ensure_prerequisites() {
  # Ensure unzip is installed (required by Bun installer)
  if ! command -v unzip >/dev/null 2>&1; then
    echo "[exam-tui-bun] Installing prerequisite: unzip..."
    apt-get update -qq
    apt-get install -y unzip
  fi
}

need_bun_install() {
  command -v bun >/dev/null 2>&1 || return 0
  return 1
}

install_bun() {
  echo "[exam-tui-bun] Installing Bun runtime..."
  ensure_prerequisites
  curl -fsSL https://bun.sh/install | bash
  export PATH="${BUN_INSTALL_DIR}/bin:${PATH}"
  
  # Verify installation
  if ! command -v bun >/dev/null 2>&1; then
    echo "[exam-tui-bun] ERROR: Bun installation failed!" >&2
    exit 1
  fi
  echo "[exam-tui-bun] ✓ Bun installed: $(bun --version)"
}

ensure_bun() {
  if need_bun_install; then
    install_bun
  else
    echo "[exam-tui-bun] Bun already installed: $(command -v bun) ($(bun --version))"
  fi
}

ensure_tui_deps() {
  if [ ! -d "$TUI_DIR" ]; then
    echo "[exam-tui-bun] ERROR: TUI directory not found at $TUI_DIR" >&2
    exit 1
  fi

  mkdir -p "$LOCAL_TUI_DIR"
  rsync -a --delete "$TUI_DIR"/ "$LOCAL_TUI_DIR"/

  pushd "$LOCAL_TUI_DIR" >/dev/null
  export BUN_INSTALL_CACHE_DIR="${HOME}/.bun-cache"
  mkdir -p "$BUN_INSTALL_CACHE_DIR"
  if [ ! -d node_modules ]; then
    echo "[exam-tui-bun] Installing TUI dependencies..."
    BUN_INSTALL=copyfile bun install
  else
    echo "[exam-tui-bun] Updating TUI dependencies (bun install)..."
    BUN_INSTALL=copyfile bun install >/dev/null
  fi
  popd >/dev/null
}

launch_tmux_env() {
  if [ ! -x "$EXAM_ENV_SCRIPT" ]; then
    echo "[exam-tui-bun] ERROR: $EXAM_ENV_SCRIPT is missing or not executable." >&2
    exit 1
  fi
  echo "[exam-tui-bun] Launching tmux exam environment with TUI..."
  export TUI_DIR="$LOCAL_TUI_DIR"
  export TASK_FILE="${REPO_ROOT}/exam-tasks.md"
  export FLAG_FILE="${HOME}/.ica-task-flags"
  exec sudo TUI_DIR="$LOCAL_TUI_DIR" TASK_FILE="$TASK_FILE" FLAG_FILE="$FLAG_FILE" "$EXAM_ENV_SCRIPT"
}

ensure_bun
ensure_tui_deps
launch_tmux_env
