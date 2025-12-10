#!/bin/bash
# Quick exam environment verification

echo "=== CLUSTER STATUS ==="
kubectl get nodes

echo ""
echo "=== ISTIO STATUS ==="
if kubectl get ns istio-system >/dev/null 2>&1; then
  echo "✓ Istio namespace exists"
  kubectl get pods -n istio-system | head -5
else
  echo "✗ Istio not installed yet"
fi

echo ""
echo "=== BUN STATUS ==="
if which bun >/dev/null 2>&1; then
  echo "✓ Bun installed: $(bun --version)"
else
  echo "✗ Bun not installed"
fi

echo ""
echo "=== EXAM FILES ==="
if [ -f /vagrant/exam-tasks.md ]; then
  echo "✓ exam-tasks.md exists"
else
  echo "✗ exam-tasks.md missing"
fi

if [ -x /vagrant/scripts/exam-tui-bun.sh ]; then
  echo "✓ exam-tui-bun.sh is executable"
else
  echo "✗ exam-tui-bun.sh not executable"
fi

echo ""
echo "=== SAMPLE WORKLOADS ==="
kubectl get pods --all-namespaces | grep -E "(httpbin|fakeservice|orders|payments)" | head -5 || echo "No sample workloads found yet"

echo ""
echo "=== EXAM UI CHECK ==="
if [ -d /vagrant/apps/exam-ui ]; then
  echo "✓ exam-ui directory exists"
  if [ -f /vagrant/apps/exam-ui/package.json ]; then
    echo "✓ package.json exists"
  fi
else
  echo "✗ exam-ui directory missing"
fi

