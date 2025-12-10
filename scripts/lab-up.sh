#!/usr/bin/env bash
# Single entrypoint to bring up Istio lab payload inside the VM.
set -euo pipefail

ISTIO_SCRIPT="/vagrant/scripts/istio-ica-lab.sh"

echo "[lab-up] Starting lab bring-up"

if [ ! -x "$ISTIO_SCRIPT" ]; then
  echo "[lab-up] Missing or non-executable: $ISTIO_SCRIPT" >&2
  echo "[lab-up] Ensure the repository is mounted at /vagrant and provisioning completed." >&2
  exit 1
fi

echo "[lab-up] Running Istio + lab installer..."
sudo bash "$ISTIO_SCRIPT"

echo "[lab-up] Lab payload applied."
echo "[lab-up] Next steps:"
echo "  vagrant ssh controlplane"
echo "  sudo /vagrant/scripts/exam-tui-bun.sh"
echo ""
echo "[lab-up] Legacy helpers:"
echo "  /vagrant/scripts/exam-env.sh    # bash viewer"
echo "  /vagrant/scripts/verify-lab.sh  # one-shot sanity"

