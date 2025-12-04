#!/usr/bin/env bash
set -euo pipefail

SESSION_NAME="${SESSION_NAME:-exam}"
VIEWER_CMD="${VIEWER_CMD:-/vagrant/scripts/tasks-viewer.sh}"
WORK_CMD="${WORK_CMD:-cd ~ && bash}"
SCOREBOARD_CMD="${SCOREBOARD_CMD:-/vagrant/scripts/exam-scoreboard.sh}"
VIEWER_WIDTH="${VIEWER_WIDTH:-48}"
SCOREBOARD_INTERVAL="${SCOREBOARD_INTERVAL:-180}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is required for this helper (run 'sudo apt install tmux')" >&2
  exit 1
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "[exam-env] Session '$SESSION_NAME' already running. Attaching..."
  exec tmux attach -t "$SESSION_NAME"
fi

echo "[exam-env] Launching tmux session '$SESSION_NAME' (tasks viewer | shell | scoreboard)"
tmux new-session -d -s "$SESSION_NAME" "$VIEWER_CMD"
tmux split-window -h -t "${SESSION_NAME}:0" "$WORK_CMD"
tmux split-window -v -t "${SESSION_NAME}:0.1" "SCOREBOARD_INTERVAL=${SCOREBOARD_INTERVAL} $SCOREBOARD_CMD"
tmux select-pane -t "${SESSION_NAME}:0.1"
tmux resize-pane -t "${SESSION_NAME}:0.0" -x "$VIEWER_WIDTH"
tmux select-pane -t "${SESSION_NAME}:0.1"

exec tmux attach -t "$SESSION_NAME"
