#!/usr/bin/env bash
# Terminal UI wrapper for the Bun-based task navigator
# This script is designed to run in a tmux pane as a replacement for tasks-viewer.sh

set -euo pipefail

# Always use absolute path for task file to avoid path resolution issues
TASK_FILE="${TASK_FILE:-/vagrant/exam-tasks.md}"
FLAG_FILE="${FLAG_FILE:-$HOME/.ica-task-flags}"
TUI_DIR="${TUI_DIR:-/vagrant/apps/exam-ui}"

# Ensure Bun binaries are discoverable even for non-login shells (tmux panes, sudo, etc.)
export PATH="/root/.bun/bin:/home/vagrant/.bun/bin:${PATH}"

# Shared helper for Bun/TUI setup
if [ -f /vagrant/scripts/tui-common.sh ]; then
  source /vagrant/scripts/tui-common.sh
fi

# Verify task file exists
if [ ! -f "$TASK_FILE" ]; then
  echo "Error: Task file not found at $TASK_FILE"
  echo "Looking in alternate locations..."
  
  # Try alternate locations
  for alt in "/vagrant/exam-tasks.md" "$TUI_DIR/../../exam-tasks.md" "./exam-tasks.md"; do
    if [ -f "$alt" ]; then
      echo "Found task file at $alt"
      TASK_FILE="$alt"
      break
    fi
  done
  
  if [ ! -f "$TASK_FILE" ]; then
    echo "Fatal: Could not find exam-tasks.md"
    echo "Falling back to bash viewer..."
    exec /vagrant/scripts/tasks-viewer.sh
  fi
fi

# Check if bun is available
if ! command -v bun >/dev/null 2>&1; then
  echo "Error: Bun is not installed. Please install it first:"
  echo "  curl -fsSL https://bun.sh/install | bash"
  echo ""
  echo "Falling back to bash viewer..."
  exec /vagrant/scripts/tasks-viewer.sh
fi

# Check if the TUI directory exists
if [ ! -d "$TUI_DIR" ]; then
  echo "Error: TUI directory not found at $TUI_DIR"
  echo "Falling back to bash viewer..."
  exec /vagrant/scripts/tasks-viewer.sh
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
