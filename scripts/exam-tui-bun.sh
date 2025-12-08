#!/usr/bin/env bash
# Convenience wrapper that ensures Bun + TUI dependencies are installed,
# then launches the tmux-based exam environment with the JS task viewer.

set -euo pipefail

REPO_ROOT="/vagrant"
TUI_DIR="${REPO_ROOT}/apps/exam-ui"
EXAM_ENV_SCRIPT="${REPO_ROOT}/scripts/exam-env-tui.sh"
BUN_INSTALL_DIR="${BUN_INSTALL:-$HOME/.bun}"
export PATH="${BUN_INSTALL_DIR}/bin:${PATH}"

need_bun_install() {
  command -v bun >/dev/null 2>&1 || return 0
  return 1
}

install_bun() {
  echo "[exam-tui-bun] Installing Bun runtime..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="${BUN_INSTALL_DIR}/bin:${PATH}"
}

ensure_bun() {
  if need_bun_install; then
    install_bun
  else
    echo "[exam-tui-bun] Bun already installed at $(command -v bun)"
  fi
}

ensure_tui_deps() {
  if [ ! -d "$TUI_DIR" ]; then
    echo "[exam-tui-bun] ERROR: TUI directory not found at $TUI_DIR" >&2
    exit 1
  fi

  pushd "$TUI_DIR" >/dev/null
  if [ ! -d node_modules ]; then
    echo "[exam-tui-bun] Installing TUI dependencies..."
    bun install
  else
    echo "[exam-tui-bun] Updating TUI dependencies (bun install)..."
    bun install >/dev/null
  fi
  popd >/dev/null
}

launch_tmux_env() {
  if [ ! -x "$EXAM_ENV_SCRIPT" ]; then
    echo "[exam-tui-bun] ERROR: $EXAM_ENV_SCRIPT is missing or not executable." >&2
    exit 1
  fi
  echo "[exam-tui-bun] Launching tmux exam environment with TUI..."
  exec sudo "$EXAM_ENV_SCRIPT"
}

ensure_bun
ensure_tui_deps
launch_tmux_env
