#!/usr/bin/env bash
# Backward compatibility wrapper
# The canonical exam checker is now check-exam.sh
# This script exists for backward compatibility with older scripts/docs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -x "${SCRIPT_DIR}/check-exam.sh" ]; then
  echo "[check-ica] ERROR: check-exam.sh not found at ${SCRIPT_DIR}/check-exam.sh" >&2
  exit 1
fi

# Forward all arguments to check-exam.sh
exec "${SCRIPT_DIR}/check-exam.sh" "$@"
