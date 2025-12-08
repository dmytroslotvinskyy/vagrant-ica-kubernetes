#!/usr/bin/env bash
# Post-provisioning script to install Bun and prepare the TUI
# Run this manually if you want to add Bun to an already-provisioned VM

set -euo pipefail

echo "=========================================="
echo "  Bun Installation & TUI Setup"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Install Bun for both users
if [ -f /vagrant/scripts/install-bun.sh ]; then
  bash /vagrant/scripts/install-bun.sh
else
  echo "Error: /vagrant/scripts/install-bun.sh not found"
  exit 1
fi

echo ""
echo "=========================================="
echo "  Testing TUI Installation"
echo "=========================================="
echo ""

# Test the TUI setup
if [ -d /vagrant/apps/exam-ui ]; then
  echo "Installing TUI dependencies..."
  
  # Create temp directory
  mkdir -p /tmp/exam-ui
  rsync -a /vagrant/apps/exam-ui/ /tmp/exam-ui/
  
  cd /tmp/exam-ui
  export BUN_INSTALL_CACHE_DIR="/root/.bun-cache"
  mkdir -p "$BUN_INSTALL_CACHE_DIR"
  
  echo "Running: bun install..."
  BUN_INSTALL=copyfile /root/.bun/bin/bun install
  
  echo ""
  echo "✓ TUI dependencies installed"
else
  echo "Warning: /vagrant/apps/exam-ui not found"
  echo "TUI will not be available"
fi

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "To use the TUI:"
echo ""
echo "  As root (or with sudo):"
echo "    sudo /vagrant/scripts/exam-tui-bun.sh"
echo ""
echo "  As vagrant user:"
echo "    source ~/.bashrc"
echo "    cd /vagrant/apps/exam-ui"
echo "    bun run tui"
echo ""
echo "  Or use the web UI:"
echo "    cd /vagrant/apps/exam-ui"
echo "    bun run dev"
echo "    # Then open http://localhost:4173"
echo ""

