#!/usr/bin/env bash
set -u

# Simple animated banner for ICA Istio lab
TITLE="ICA ISTIO TRAINING LAB"
AUTHOR="by Dmytro Slotvinskyi"

# If not a TTY (e.g., piping to file), just print a static banner
if [ ! -t 1 ]; then
  echo "==========================================="
  echo "  $TITLE"
  echo "  $AUTHOR"
  echo "==========================================="
  exit 0
fi

# Colors
RESET="\033[0m"
BOLD="\033[1m"
CYAN="\033[38;5;45m"
MAGENTA="\033[38;5;213m"
YELLOW="\033[38;5;220m"

# Layout
INNER_WIDTH=40  # text area width inside the box

# Build borders dynamically
upper_border="╔$(printf '═%.0s' $(seq 1 $((INNER_WIDTH + 2))))╗"
lower_border="╚$(printf '═%.0s' $(seq 1 $((INNER_WIDTH + 2))))╝"

# Hide cursor while animating
if command -v tput >/dev/null 2>&1; then
  tput civis || true
  trap 'tput cnorm 2>/dev/null || true; printf "%b" "$RESET"' EXIT
else
  trap 'printf "%b" "$RESET"' EXIT
fi

# Helper: animated line inside the box
animate_line() {
  local text="$1"
  local color="$2"
  local i partial
  for (( i=0; i<=${#text}; i++ )); do
    partial="${text:0:i}"
    printf "\r  ${YELLOW}║ ${color}${BOLD}%-*s${RESET}${YELLOW} ║${RESET}" "$INNER_WIDTH" "$partial"
    sleep 0.03
  done
  printf "\n"
}

# Draw banner
printf "\n"
printf "  ${YELLOW}%s${RESET}\n" "$upper_border"

# First line (title)
printf "  ${YELLOW}║ %-*s ║${RESET}\n" "$INNER_WIDTH" " "
printf "\033[1A"  # move cursor one line up
animate_line "$TITLE" "$CYAN"

# Second line (author)
printf "  ${YELLOW}║ %-*s ║${RESET}\n" "$INNER_WIDTH" " "
printf "\033[1A"
animate_line "$AUTHOR" "$MAGENTA"

printf "  ${YELLOW}%s${RESET}\n\n" "$lower_border"

