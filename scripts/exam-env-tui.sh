#!/usr/bin/env bash
# Exam environment launcher with JavaScript-based TUI
# This is a variant of exam-env.sh that uses the Bun TUI instead of the bash viewer

set -euo pipefail

SESSION_NAME="${SESSION_NAME:-exam}"
VIEWER_CMD="${VIEWER_CMD:-/vagrant/scripts/tasks-viewer-tui.sh}"
WORK_CMD="${WORK_CMD:-cd ~ && bash}"
SCOREBOARD_CMD="${SCOREBOARD_CMD:-/vagrant/scripts/exam-scoreboard.sh}"
VIEWER_WIDTH="${VIEWER_WIDTH:-50}"
SCOREBOARD_INTERVAL="${SCOREBOARD_INTERVAL:-180}"
SCOREBOARD_PANE="${SCOREBOARD_PANE:-${SESSION_NAME}:0.2}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is required for this helper (run 'sudo apt install tmux')" >&2
  exit 1
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "[exam-env] Session '$SESSION_NAME' already running. Attaching..."
  exec tmux attach -t "$SESSION_NAME"
fi

echo "[exam-env] Launching tmux session '$SESSION_NAME' with JavaScript TUI"
tmux new-session -d -s "$SESSION_NAME" "$VIEWER_CMD"
tmux split-window -h -t "${SESSION_NAME}:0" "$WORK_CMD"
tmux split-window -v -t "${SESSION_NAME}:0.1" "SCOREBOARD_INTERVAL=${SCOREBOARD_INTERVAL} $SCOREBOARD_CMD"
tmux select-pane -t "${SESSION_NAME}:0.1"
tmux resize-pane -t "${SESSION_NAME}:0.0" -x "$VIEWER_WIDTH"
tmux select-pane -t "${SESSION_NAME}:0.1"

# Make the session friendlier: mouse navigation, quick pane jump keys, and a
# one-key scoreboard restart (F5) if the checker crashed or you updated tasks.
tmux set-option -t "$SESSION_NAME" mouse on
tmux set-option -t "$SESSION_NAME" status-left "[exam-tui] #{session_name}"
tmux set-option -t "$SESSION_NAME" status-right "F1 tasks | F2 shell | F3 score | F5 restart"
tmux bind-key -n F1 select-pane -t "${SESSION_NAME}:0.0"
tmux bind-key -n F2 select-pane -t "${SESSION_NAME}:0.1"
tmux bind-key -n F3 select-pane -t "$SCOREBOARD_PANE"
tmux bind-key -n F5 respawn-pane -k -t "$SCOREBOARD_PANE" "SCOREBOARD_INTERVAL=${SCOREBOARD_INTERVAL} $SCOREBOARD_CMD"
tmux display-message "[exam-env] TUI Keys: j/k navigate | f flag | / search | q quit | F1-F3 panes | F5 restart scoreboard"

exec tmux attach -t "$SESSION_NAME"

