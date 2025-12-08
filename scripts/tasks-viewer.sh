#!/usr/bin/env bash
set -euo pipefail

TASK_FILE="${TASK_FILE:-/vagrant/exam-tasks.md}"
FLAG_FILE="${FLAG_FILE:-$HOME/.ica-task-flags}"

declare -A TASK_TITLES
declare -A TASK_BODIES
declare -A FLAGGED
TASK_COUNT=0
STATUS_MESSAGE=""

load_tasks() {
  local -a raw_tasks=()
  if [ -f "$TASK_FILE" ]; then
    mapfile -d '' -t raw_tasks < <(awk 'BEGIN{RS="---TASK---"; ORS="\0"}{gsub(/\r/, ""); gsub(/^[[:space:]]+/, "", $0); gsub(/[[:space:]]+$/, "", $0); if(length($0)>0) print}' "$TASK_FILE")
  fi
  if [ "${#raw_tasks[@]}" -eq 0 ]; then
    TASK_COUNT=1
    TASK_TITLES[1]="Task file missing"
    TASK_BODIES[1]="Task list not found or empty: ${TASK_FILE}"
    return
  fi
  TASK_COUNT="${#raw_tasks[@]}"
  local idx title
  for i in "${!raw_tasks[@]}"; do
    idx=$((i + 1))
    TASK_BODIES[$idx]="${raw_tasks[$i]}"
    title=$(printf "%s\n" "${raw_tasks[$i]}" | sed -n 's/^#\{1,\}[[:space:]]*//p' | head -n1)
    if [ -z "$title" ]; then
      title="Task ${idx}"
    fi
    TASK_TITLES[$idx]="$title"
  done
}

load_flags() {
  [ -f "$FLAG_FILE" ] || return
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[0-9]+$ ]] || continue
    FLAGGED["$line"]=1
  done < "$FLAG_FILE"
}

save_flags() {
  local dir tmp
  dir=$(dirname "$FLAG_FILE")
  mkdir -p "$dir"
  tmp=$(mktemp)
  if [ "${#FLAGGED[@]}" -gt 0 ]; then
    printf "%s\n" "${!FLAGGED[@]}" | sort -n > "$tmp"
  else
    : > "$tmp"
  fi
  mv "$tmp" "$FLAG_FILE"
}

flag_summary() {
  if [ "${#FLAGGED[@]}" -eq 0 ]; then
    echo "Flagged: none"
    return
  fi
  local sorted summary="" value
  mapfile -t sorted < <(printf "%s\n" "${!FLAGGED[@]}" | sort -n)
  for value in "${sorted[@]}"; do
    if [ -n "$summary" ]; then
      summary+=", "
    fi
    summary+="$value"
  done
  echo "Flagged: ${summary}"
}

is_flagged() {
  local idx="$1"
  [[ -n "${FLAGGED[$idx]+x}" ]]
}

toggle_flag() {
  local idx="$1"
  if is_flagged "$idx"; then
    unset "FLAGGED[$idx]"
    STATUS_MESSAGE="Unflagged task ${idx}."
  else
    FLAGGED["$idx"]=1
    STATUS_MESSAGE="Flagged task ${idx}."
  fi
  save_flags
}

clear_flags() {
  FLAGGED=()
  STATUS_MESSAGE="Cleared all flags."
  save_flags
}

render_summary() {
  local current="$1"
  echo "Navigator"
  printf '%0.s-' {1..40}
  echo
  local i pointer flag title
  for ((i=1; i<=TASK_COUNT; i++)); do
    pointer=" "
    [ "$i" -eq "$current" ] && pointer=">"
    flag=" "
    is_flagged "$i" && flag="*"
    title="${TASK_TITLES[$i]}"
    printf " %s %2d [%s] %s\n" "$pointer" "$i" "$flag" "$title"
  done
  echo
  flag_summary
  echo
}

render_task() {
  local idx="$1"
  clear
  echo "Istio Mock Exam Tasks (${idx}/${TASK_COUNT})"
  echo "==========================================="
  echo
  render_summary "$idx"
  echo "-------------------------------------------"
  printf "Task %d\n" "$idx"
  echo "-------------------------------------------"
  echo
  printf "%s\n" "${TASK_BODIES[$idx]}"
  echo
  if [ -n "$STATUS_MESSAGE" ]; then
    echo "$STATUS_MESSAGE"
  fi
  echo "Controls: [Enter|n|j]=next  [p|k]=prev  digits=jump  f=flag  c=clear flags  q=quit"
  echo
}

next_task() {
  local idx="$1"
  printf "%d" $(( (idx % TASK_COUNT) + 1 ))
}

prev_task() {
  local idx="$1"
  printf "%d" $(( (idx + TASK_COUNT - 2) % TASK_COUNT + 1 ))
}

main_loop() {
  local current=1 input
  load_tasks
  load_flags
  while true; do
    render_task "$current"
    printf "Choice: "
    if ! IFS= read -r input; then
      break
    fi
    case "$input" in
      ''|[Nn]|[Jj])
        current=$(next_task "$current")
        STATUS_MESSAGE=""
        ;;
      [Pp]|[Kk])
        current=$(prev_task "$current")
        STATUS_MESSAGE=""
        ;;
      [Qq])
        break
        ;;
      [Ff])
        toggle_flag "$current"
        ;;
      [Cc])
        clear_flags
        ;;
      *)
        if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= TASK_COUNT )); then
          current="$input"
          STATUS_MESSAGE=""
        else
          STATUS_MESSAGE="Unknown command: $input"
        fi
        ;;
    esac
  done
}

main_loop "$@"
