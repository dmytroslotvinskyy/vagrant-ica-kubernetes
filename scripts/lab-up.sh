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

echo "[lab-up] Phase 1: Istio + lab workloads"
sudo bash "$ISTIO_SCRIPT"

echo "[lab-up] Lab payload applied."
if [ -x /vagrant/scripts/verify-lab.sh ]; then
  echo "[lab-up] Phase 2: Sanity check (verify-lab.sh)"
  /vagrant/scripts/verify-lab.sh || echo "[lab-up] verify-lab detected issues; review output above."
fi

if [ -x /vagrant/scripts/ica-banner.sh ]; then
  echo "[lab-up] Installing login banner (/etc/profile.d/ica-lab.sh)"
  cat <<'EOF' | sudo tee /etc/profile.d/ica-lab.sh >/dev/null
#!/usr/bin/env bash
# ICA lab greeting banner
if [ -t 1 ] && [ -x /vagrant/scripts/ica-banner.sh ]; then
  /vagrant/scripts/ica-banner.sh
fi
EOF
  sudo chmod +x /etc/profile.d/ica-lab.sh || true
fi

echo "[lab-up] Next steps:"
echo "  vagrant ssh controlplane"
echo "  sudo /vagrant/scripts/exam-tui-bun.sh"
echo ""
echo "[lab-up] Legacy helpers:"
echo "  /vagrant/scripts/exam-env.sh    # bash viewer"
echo "  /vagrant/scripts/verify-lab.sh  # one-shot sanity"

