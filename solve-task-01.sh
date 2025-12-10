#!/bin/bash
# Solve Task 1: Install Istio 1.26 demo profile

set -euo pipefail

echo "=== Installing Istio 1.26.3 with demo profile ==="

# Ensure istioctl is installed
if ! command -v istioctl >/dev/null 2>&1; then
  echo "Installing istioctl..."
  cd /tmp
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION="1.26.3" sh -
  sudo mv istio-1.26.3 /opt/istio-1.26.3
  sudo ln -sf /opt/istio-1.26.3/bin/istioctl /usr/local/bin/istioctl
fi

# Install Istio with demo profile
echo "Installing Istio 1.26.3 with demo profile..."
istioctl install --set profile=demo -y

echo ""
echo "=== Waiting for deployments to be ready ==="
kubectl wait -n istio-system deploy/istiod --for=condition=Available --timeout=600s
kubectl wait -n istio-system deploy/istio-ingressgateway --for=condition=Available --timeout=600s

echo ""
echo "=== Verification ==="
istioctl version

echo ""
kubectl get deploy -n istio-system istiod istio-ingressgateway

echo ""
echo "=== Running exam checker for Task 1 ==="
/vagrant/check-exam.sh 1

