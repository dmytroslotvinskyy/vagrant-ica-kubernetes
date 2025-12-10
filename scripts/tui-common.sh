#!/usr/bin/env bash
# Shared helpers for Bun-based TUIs (install + rsync workspace)
set -euo pipefail

ensure_bun() {
  local bin="${BUN_INSTALL_DIR:-$HOME/.bun}/bin/bun"
  if command -v bun >/dev/null 2>&1; then
    return 0
  fi
  echo "[tui-common] Installing Bun runtime..."
  if ! command -v unzip >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y unzip
  fi
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  if [ ! -x "$bin" ]; then
    echo "[tui-common] Bun install failed (expected at $bin)" >&2
    return 1
  fi
}

prepare_tui_dir() {
  local src="${1:-/vagrant/apps/exam-ui}"
  local dst="${2:-/tmp/exam-ui}"
  if [ ! -d "$src" ]; then
    echo "[tui-common] TUI source not found at $src" >&2
    return 1
  fi
  mkdir -p "$dst"
  rsync -a --delete "$src"/ "$dst"/
  pushd "$dst" >/dev/null
  export BUN_INSTALL_CACHE_DIR="${HOME}/.bun-cache"
  mkdir -p "$BUN_INSTALL_CACHE_DIR"
  BUN_INSTALL=copyfile bun install >/dev/null
  popd >/dev/null
}

