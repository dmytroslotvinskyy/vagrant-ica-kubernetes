#!/usr/bin/env bash
# Terminal UI wrapper for the Bun-based task navigator
# This script is designed to run in a tmux pane as a replacement for tasks-viewer.sh

set -euo pipefail

# Auto-detect lab root (for Vagrant and bare-metal usage)
auto_lab_root() {
  # If explicitly set, use it
  if [ -n "${LAB_ROOT:-}" ] && [ -d "$LAB_ROOT" ]; then
    echo "$LAB_ROOT"
    return
  fi
  # Check for /vagrant mount (Vagrant)
  if [ -d "/vagrant" ] && [ -f "/vagrant/exam-tasks.md" ]; then
    echo "/vagrant"
    return
  fi
  # Try git root (bare-metal)
  if command -v git >/dev/null 2>&1; then
    local git_root
    git_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
    if [ -n "$git_root" ] && [ -f "$git_root/exam-tasks.md" ]; then
      echo "$git_root"
      return
    fi
  fi
  # Try current directory
  if [ -f "./exam-tasks.md" ]; then
    echo "$(pwd)"
    return
  fi
  # Fallback to /vagrant for backward compatibility
  echo "/vagrant"
}

LAB_ROOT="$(auto_lab_root)"

# Always use absolute path for task file to avoid path resolution issues
TASK_FILE="${TASK_FILE:-${LAB_ROOT}/exam-tasks.md}"
FLAG_FILE="${FLAG_FILE:-$HOME/.ica-task-flags}"
TUI_DIR="${TUI_DIR:-${LAB_ROOT}/apps/exam-ui}"

# Ensure Bun binaries are discoverable even for non-login shells (tmux panes, sudo, etc.)
export PATH="/root/.bun/bin:/home/vagrant/.bun/bin:${PATH}"

# Shared helper for Bun/TUI setup
TUI_COMMON="${LAB_ROOT}/scripts/tui-common.sh"
if [ -f "$TUI_COMMON" ]; then
  source "$TUI_COMMON"
fi

# Verify task file exists
if [ ! -f "$TASK_FILE" ]; then
  echo "Error: Task file not found at $TASK_FILE"
  echo "Looking in alternate locations..."
  
  # Try alternate locations
  for alt in "${LAB_ROOT}/exam-tasks.md" "$TUI_DIR/../../exam-tasks.md" "./exam-tasks.md"; do
    if [ -f "$alt" ]; then
      echo "Found task file at $alt"
      TASK_FILE="$alt"
      break
    fi
  done
  
  if [ ! -f "$TASK_FILE" ]; then
    echo "Fatal: Could not find exam-tasks.md"
    echo "Falling back to bash viewer..."
    FALLBACK_VIEWER="${LAB_ROOT}/scripts/tasks-viewer.sh"
    if [ -x "$FALLBACK_VIEWER" ]; then
      exec "$FALLBACK_VIEWER"
    else
      echo "Fallback viewer not found at $FALLBACK_VIEWER"
      exit 1
    fi
  fi
fi

# Check if bun is available
if ! command -v bun >/dev/null 2>&1; then
  echo "Error: Bun is not installed. Please install it first:"
  echo "  curl -fsSL https://bun.sh/install | bash"
  echo ""
  echo "Falling back to bash viewer..."
  FALLBACK_VIEWER="${LAB_ROOT}/scripts/tasks-viewer.sh"
  if [ -x "$FALLBACK_VIEWER" ]; then
    exec "$FALLBACK_VIEWER"
  else
    echo "Fallback viewer not found. Set LAB_ROOT or run from /vagrant"
    exit 1
  fi
fi

# Check if the TUI directory exists
if [ ! -d "$TUI_DIR" ]; then
  echo "Error: TUI directory not found at $TUI_DIR"
  echo "Falling back to bash viewer..."
  FALLBACK_VIEWER="${LAB_ROOT}/scripts/tasks-viewer.sh"
  if [ -x "$FALLBACK_VIEWER" ]; then
    exec "$FALLBACK_VIEWER"
  else
    echo "Fallback viewer not found. Set LAB_ROOT or run from /vagrant"
    exit 1
  fi
fi

# Stage and install dependencies using shared helper when available
if declare -F prepare_tui_dir >/dev/null 2>&1; then
  LOCAL_TUI_DIR="${LOCAL_TUI_DIR:-/tmp/exam-ui}"
  prepare_tui_dir "$TUI_DIR" "$LOCAL_TUI_DIR"
  cd "$LOCAL_TUI_DIR"
else
  cd "$TUI_DIR"
  export BUN_INSTALL_CACHE_DIR="${HOME}/.bun-cache"
  mkdir -p "$BUN_INSTALL_CACHE_DIR"
  if [ ! -d "node_modules" ]; then
    echo "Installing TUI dependencies..."
    BUN_INSTALL=copyfile bun install
    echo ""
  fi
fi

# Export environment variables
export TASK_FILE
export FLAG_FILE

# Run the TUI
exec bun run tui
