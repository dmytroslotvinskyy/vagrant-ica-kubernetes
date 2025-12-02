#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

FAILED=0

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1"
  FAILED=1
}

check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Command '$1' not found in PATH"
    return 1
  fi
  pass "Command '$1' available"
}

echo "=== ICA Istio Traffic Management – Verification ==="

# 1. Basic tools / connectivity
check_cmd kubectl || true
check_cmd istioctl || true

if ! kubectl version --short >/dev/null 2>&1; then
  fail "kubectl cannot talk to the cluster"
else
  pass "kubectl can talk to the cluster"
fi

# 2. Istio control plane
if ! kubectl get ns istio-system >/dev/null 2>&1; then
  fail "Namespace istio-system is missing (Istio not installed?)"
else
  pass "Namespace istio-system exists"
fi

if kubectl get pods -n istio-system 2>/dev/null | grep -q 'istiod'; then
  if kubectl get pods -n istio-system | grep istiod | grep -q Running; then
    pass "istiod pod is running"
  else
    fail "istiod pod exists but is not Running"
  fi
else
  fail "No istiod pod found in istio-system"
fi

# 3. Namespaces & injection labels
for ns in default payments; do
  if ! kubectl get ns "$ns" >/dev/null 2>&1; then
    fail "Namespace '$ns' is missing"
    continue
  fi

  label=$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "")
  if [ "$label" = "enabled" ]; then
    pass "Namespace '$ns' has istio-injection=enabled"
  else
    fail "Namespace '$ns' does NOT have istio-injection=enabled (label=$label)"
  fi
done

# 4. Workloads exist
if kubectl get deploy helloworld-v1 -n default >/dev/null 2>&1 \
   && kubectl get deploy helloworld-v2 -n default >/dev/null 2>&1; then
  pass "helloworld-v1 and helloworld-v2 deployments exist in default"
else
  fail "helloworld-v1/v2 deployments missing in default"
fi

if kubectl get deploy payments-v1 -n payments >/dev/null 2>&1 \
   && kubectl get deploy payments-v2 -n payments >/dev/null 2>&1; then
  pass "payments-v1 and payments-v2 deployments exist in payments"
else
  fail "payments-v1/v2 deployments missing in payments"
fi

if kubectl get deploy curl -n default >/dev/null 2>&1; then
  pass "curl client deployment exists in default"
else
  fail "curl client deployment missing in default"
fi

# 5. Task 1 – helloworld-dr
if kubectl get destinationrule helloworld-dr -n default >/dev/null 2>&1; then
  host=$(kubectl get destinationrule helloworld-dr -n default -o jsonpath='{.spec.host}' || echo "")
  if [ "$host" = "helloworld.default.svc.cluster.local" ]; then
    pass "helloworld-dr host is correct"
  else
    fail "helloworld-dr host is '$host' (expected helloworld.default.svc.cluster.local)"
  fi

  subsets=$(kubectl get destinationrule helloworld-dr -n default -o jsonpath='{range .spec.subsets[*]}{.name}{"="}{.labels.version}{" "}{end}' || echo "")
  # we expect v1=v1 and v2=v2 somewhere
  if echo "$subsets" | grep -q "v1=v1" && echo "$subsets" | grep -q "v2=v2"; then
    pass "helloworld-dr subsets v1/v2 with labels version=v1/v2"
  else
    fail "helloworld-dr subsets incorrect: $subsets"
  fi
else
  fail "DestinationRule helloworld-dr not found in default"
fi

# 6. Task 2 – helloworld-vs
if kubectl get virtualservice helloworld-vs -n default >/dev/null 2>&1; then
  hosts=$(kubectl get virtualservice helloworld-vs -n default -o jsonpath='{.spec.hosts[*]}' || echo "")
  if echo "$hosts" | grep -q "helloworld.default.svc.cluster.local"; then
    pass "helloworld-vs hosts contain helloworld.default.svc.cluster.local"
  else
    fail "helloworld-vs hosts incorrect: $hosts"
  fi

  # Check default /hello split weights if present as 4th http route (index 3)
  default_w1=$(kubectl get virtualservice helloworld-vs -n default -o jsonpath='{.spec.http[3].route[0].weight}' 2>/dev/null || echo "")
  default_w2=$(kubectl get virtualservice helloworld-vs -n default -o jsonpath='{.spec.http[3].route[1].weight}' 2>/dev/null || echo "")
  if [ "$default_w1" = "80" ] && [ "$default_w2" = "20" ]; then
    pass "helloworld-vs default /hello split 80/20 detected (http[3])"
  else
    echo "      (If you chose a different order, this check can be ignored.)"
    fail "helloworld-vs default route weights not 80/20 at http[3] (w1=$default_w1, w2=$default_w2)"
  fi
else
  fail "VirtualService helloworld-vs not found in default"
fi

# 7. Task 3 – payments-dr
if kubectl get destinationrule payments-dr -n payments >/dev/null 2>&1; then
  host=$(kubectl get destinationrule payments-dr -n payments -o jsonpath='{.spec.host}' || echo "")
  if [ "$host" = "payments.payments.svc.cluster.local" ]; then
    pass "payments-dr host is correct"
  else
    fail "payments-dr host is '$host' (expected payments.payments.svc.cluster.local)"
  fi

  subsets=$(kubectl get destinationrule payments-dr -n payments -o jsonpath='{range .spec.subsets[*]}{.name}{"="}{.labels.version}{" "}{end}' || echo "")
  if echo "$subsets" | grep -q "v1=v1" && echo "$subsets" | grep -q "v2=v2"; then
    pass "payments-dr subsets v1/v2 with labels version=v1/v2"
  else
    fail "payments-dr subsets incorrect: $subsets"
  fi
else
  fail "DestinationRule payments-dr not found in payments"
fi

# 8. Task 4 – payments-vs basic presence + host
if kubectl get virtualservice payments-vs -n payments >/dev/null 2>&1; then
  hosts=$(kubectl get virtualservice payments-vs -n payments -o jsonpath='{.spec.hosts[*]}' || echo "")
  if echo "$hosts" | grep -q "payments.payments.svc.cluster.local"; then
    pass "payments-vs hosts contain payments.payments.svc.cluster.local"
  else
    fail "payments-vs hosts incorrect: $hosts"
  fi
else
  fail "VirtualService payments-vs not found in payments"
fi

# 9. Task 5 – retry VS (optional, but we check it)
if kubectl get virtualservice payments-retry-vs -n payments >/dev/null 2>&1; then
  attempts=$(kubectl get virtualservice payments-retry-vs -n payments -o jsonpath='{.spec.http[0].retries.attempts}' 2>/dev/null || echo "")
  pertry=$(kubectl get virtualservice payments-retry-vs -n payments -o jsonpath='{.spec.http[0].retries.perTryTimeout}' 2>/dev/null || echo "")
  timeout=$(kubectl get virtualservice payments-retry-vs -n payments -o jsonpath='{.spec.http[0].timeout}' 2>/dev/null || echo "")
  if [ "$attempts" = "3" ] && [ "$pertry" = "2s" ] && [ "$timeout" = "7s" ]; then
    pass "payments-retry-vs retry policy looks correct (attempts=3, perTryTimeout=2s, timeout=7s)"
  else
    fail "payments-retry-vs retry policy unexpected: attempts=$attempts, perTryTimeout=$pertry, timeout=$timeout"
  fi
else
  echo "[INFO] VirtualService payments-retry-vs not found (Task 5 is bonus)"
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "=== RESULT: ALL CHECKS PASSED ==="
  exit 0
else
  echo "=== RESULT: SOME CHECKS FAILED ==="
  exit 1
fi
