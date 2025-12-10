#!/usr/bin/env bash
# Quick-start script to launch the exam TUI after vagrant up
# Usage: ./start-exam.sh

set -euo pipefail

echo "=========================================="
echo "  Starting ICA Istio Lab Exam"
echo "=========================================="
echo ""

# Check if controlplane VM is running
if ! vagrant status controlplane | grep -q "running"; then
  echo "❌ Error: controlplane VM is not running"
  echo ""
  echo "Please start the VM first:"
  echo "  vagrant up controlplane"
  exit 1
fi

echo "✓ Controlplane VM is running"
echo ""

# Check if Istio is installed
echo "Checking Istio installation..."
if ! vagrant ssh controlplane -c "kubectl get ns istio-system >/dev/null 2>&1" 2>/dev/null; then
  echo "⚠️  Warning: Istio namespace not found. Lab may not be fully provisioned."
  echo "   This is normal if you just ran 'vagrant up' - wait a few minutes for"
  echo "   the lab provisioning to complete, then run this script again."
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo "✓ Istio namespace found"
echo ""

# Launch exam TUI
echo "Launching exam TUI..."
echo ""
echo "This will:"
echo "  1. SSH into the controlplane VM"
echo "  2. Start the exam TUI in tmux"
echo ""
echo "To reconnect later: vagrant ssh controlplane -c 'tmux attach -t exam'"
echo ""

# Use exec to replace this process with SSH, so Ctrl+C works properly
exec vagrant ssh controlplane -c "sudo /vagrant/scripts/exam-tui-bun.sh"

