#!/usr/bin/env bash
# Install Bun runtime for both root and vagrant users
# Can be called during VM provisioning or run manually

set -euo pipefail

echo "[install-bun] Installing prerequisites (unzip)..."
apt-get update -qq
apt-get install -y unzip curl

install_bun_for_user() {
  local username="$1"
  local homedir
  
  if [ "$username" = "root" ]; then
    homedir="/root"
  else
    homedir="/home/$username"
  fi
  
  echo "[install-bun] Installing Bun for user: $username (home: $homedir)"
  
  # Check if already installed
  if [ -f "$homedir/.bun/bin/bun" ]; then
    echo "[install-bun] Bun already installed for $username at $homedir/.bun/bin/bun"
    return 0
  fi
  
  # Install as the target user
  if [ "$username" = "root" ]; then
    curl -fsSL https://bun.sh/install | bash
  else
    su - "$username" -c 'curl -fsSL https://bun.sh/install | bash'
  fi
  
  # Add to PATH in bashrc if not already there
  local bashrc="$homedir/.bashrc"
  if [ -f "$bashrc" ]; then
    if ! grep -q "/.bun/bin" "$bashrc"; then
      echo "[install-bun] Adding Bun to PATH in $bashrc"
      cat >> "$bashrc" << 'EOF'

# Bun runtime
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
EOF
    fi
  fi
  
  echo "[install-bun] ✓ Bun installed for $username"
}

# Install for root (used by sudo scripts)
install_bun_for_user root

# Install for vagrant user (used for manual testing)
if id vagrant >/dev/null 2>&1; then
  install_bun_for_user vagrant
fi

# Verify installations
echo ""
echo "[install-bun] Verification:"
if [ -f /root/.bun/bin/bun ]; then
  /root/.bun/bin/bun --version | sed 's/^/  root:    /'
fi
if [ -f /home/vagrant/.bun/bin/bun ]; then
  # Ensure PATH includes Bun for the vagrant user during verification to avoid false failures.
  su - vagrant -c 'export PATH="$HOME/.bun/bin:$PATH"; bun --version' | sed 's/^/  vagrant: /' || true
fi

echo ""
echo "[install-bun] ✓ Installation complete!"
echo "[install-bun] To use as vagrant: source ~/.bashrc"
echo "[install-bun] To use as root:    export PATH=\"/root/.bun/bin:\$PATH\""

