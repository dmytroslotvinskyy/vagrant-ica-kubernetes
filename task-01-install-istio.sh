#!/bin/bash
# Task 1: Install Istio 1.26 demo profile and verify

set -euo pipefail

echo "=== Task 1: Install Istio 1.26 Demo Profile ==="
echo ""

# Check if istioctl is available
if ! command -v istioctl >/dev/null 2>&1; then
  echo "ERROR: istioctl not found. Installing Istio 1.26.3..."
  cd /tmp
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION="1.26.3" sh -
  sudo mv istio-1.26.3 /opt/istio-1.26.3
  sudo ln -sf /opt/istio-1.26.3/bin/istioctl /usr/local/bin/istioctl
  echo "✓ istioctl installed"
else
  echo "✓ istioctl already available"
fi

# Check current version
echo ""
echo "=== Checking istioctl version ==="
istioctl version --remote=false || echo "No local version info"

# Check if Istio is already installed
if kubectl get ns istio-system >/dev/null 2>&1; then
  echo ""
  echo "=== Istio namespace exists, checking installation ==="
  istioctl version
  echo ""
  echo "=== Checking deployments ==="
  kubectl get deploy -n istio-system istiod istio-ingressgateway
  
  ISTIOD_AVAILABLE=$(kubectl get deploy -n istio-system istiod -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "False")
  INGRESS_AVAILABLE=$(kubectl get deploy -n istio-system istio-ingressgateway -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "False")
  
  if [ "$ISTIOD_AVAILABLE" = "True" ] && [ "$INGRESS_AVAILABLE" = "True" ]; then
    echo ""
    echo "✓ Task 1 VERIFIED: Istio 1.26 is installed and both deployments are AVAILABLE"
    exit 0
  else
    echo ""
    echo "⚠ Istio installed but deployments not fully available yet"
    echo "  istiod Available: $ISTIOD_AVAILABLE"
    echo "  istio-ingressgateway Available: $INGRESS_AVAILABLE"
  fi
else
  echo ""
  echo "=== Installing Istio 1.26.3 with demo profile ==="
  istioctl install --set profile=demo -y
  
  echo ""
  echo "=== Waiting for deployments to be available ==="
  kubectl wait -n istio-system deploy/istiod --for=condition=Available --timeout=600s
  kubectl wait -n istio-system deploy/istio-ingressgateway --for=condition=Available --timeout=600s
fi

echo ""
echo "=== Final Verification ==="
echo "1. istioctl version:"
istioctl version

echo ""
echo "2. Deployments status:"
kubectl get deploy -n istio-system istiod istio-ingressgateway

echo ""
echo "3. Pods status:"
kubectl get pods -n istio-system

echo ""
ISTIOD_AVAILABLE=$(kubectl get deploy -n istio-system istiod -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
INGRESS_AVAILABLE=$(kubectl get deploy -n istio-system istio-ingressgateway -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
VERSION=$(istioctl version -o json 2>/dev/null | grep -o '"version":"[^"]*' | head -1 | cut -d'"' -f4 || echo "")

if [[ "$VERSION" == "1.26"* ]] && [ "$ISTIOD_AVAILABLE" = "True" ] && [ "$INGRESS_AVAILABLE" = "True" ]; then
  echo "✓✓✓ Task 1 COMPLETE: Istio 1.26.x installed with demo profile"
  echo "  - Control plane version: $VERSION"
  echo "  - istiod: AVAILABLE"
  echo "  - istio-ingressgateway: AVAILABLE"
else
  echo "✗ Task 1 INCOMPLETE:"
  echo "  - Version: $VERSION (expected 1.26.x)"
  echo "  - istiod Available: $ISTIOD_AVAILABLE"
  echo "  - istio-ingressgateway Available: $INGRESS_AVAILABLE"
  exit 1
fi

