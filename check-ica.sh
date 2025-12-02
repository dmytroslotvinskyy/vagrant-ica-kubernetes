#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

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

check_cluster_basics() {
  echo "=== Cluster prerequisites ==="
  check_cmd kubectl || true
  check_cmd istioctl || true

  if kubectl version --output=json >/dev/null 2>&1; then
    pass "kubectl can reach the cluster"
  else
    fail "kubectl cannot reach the cluster"
  fi

  if kubectl get ns istio-system >/dev/null 2>&1; then
    pass "Namespace istio-system exists"
  else
    fail "Namespace istio-system missing"
  fi
}

run_task() {
  local task_id="$1"
  if declare -f "task_${task_id}" >/dev/null 2>&1; then
    echo "--- Task ${task_id} ---"
    "task_${task_id}"
  else
    fail "No checker implemented for task ${task_id}"
  fi
}

task_1() {
  local ns="orders"
  local dr="orders-dr"
  if ! kubectl get destinationrule "$dr" -n "$ns" >/dev/null 2>&1; then
    fail "Task 1: DestinationRule ${dr} missing in ${ns}"
    return
  fi
  local host
  host=$(kubectl get destinationrule "$dr" -n "$ns" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
  if [[ "$host" == "orders.orders.svc.cluster.local" ]]; then
    pass "Task 1: DestinationRule host correct"
  else
    fail "Task 1: DestinationRule host is '${host}' (expected orders.orders.svc.cluster.local)"
  fi
  local subsets
  subsets=$(kubectl get destinationrule "$dr" -n "$ns" -o jsonpath='{range .spec.subsets[*]}{.name}{"="}{.labels.version}{" "}{end}' 2>/dev/null || echo "")
  if echo "$subsets" | grep -q "v1=v1" && echo "$subsets" | grep -q "v2=v2"; then
    pass "Task 1: subsets include v1/v2 with proper labels"
  else
    fail "Task 1: subsets incorrect (${subsets})"
  fi
  if kubectl get virtualservice orders-vs -n "$ns" >/dev/null 2>&1; then
    pass "Task 1: VirtualService orders-vs exists (weights checked in Task 2)"
  else
    fail "Task 1: VirtualService orders-vs missing"
  fi
}

task_2() {
  local ns="orders"
  if ! kubectl get virtualservice orders-vs -n "$ns" >/dev/null 2>&1; then
    fail "Task 2: VirtualService orders-vs missing"
    return
  fi
  if kubectl get virtualservice orders-vs -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
header_ok = False
default_ok = False
for rule in http:
    match = rule.get("match", [{}])[0]
    headers = match.get("headers", {})
    uri = match.get("uri", {})
    routes = rule.get("route", [])
    if headers.get("x-canary", {}).get("exact") == "v2" and uri.get("prefix") == "/":
        if len(routes) == 1 and routes[0].get("destination", {}).get("subset") == "v2" and routes[0].get("weight") == 100:
            header_ok = True
    if not headers and uri.get("prefix") == "/":
        weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
        if ("v1", 70) in weights and ("v2", 30) in weights:
            default_ok = True
if not header_ok or not default_ok:
    sys.exit(1)
PY
then
    pass "Task 2: header override + default split detected"
else
    fail "Task 2: VirtualService rules do not match requirements"
fi
}

task_3() {
  local ns="catalog" vs="catalog-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 3: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
required = {"/api/v1": ("v1", 100), "/api/v2": ("v2", 100), "/api": None}
found = {key: False for key in required}
for rule in http:
    prefix = rule.get("match", [{}])[0].get("uri", {}).get("prefix")
    rewrite = rule.get("rewrite", {}).get("uri")
    routes = rule.get("route", [])
    if prefix not in required or rewrite != "/items":
        continue
    if prefix in ("/api/v1", "/api/v2"):
        if len(routes) == 1:
            subset = routes[0].get("destination", {}).get("subset")
            weight = routes[0].get("weight")
            if subset == required[prefix][0] and weight == required[prefix][1]:
                found[prefix] = True
    else:
        weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
        if ("v1", 50) in weights and ("v2", 50) in weights:
            found[prefix] = True
if not all(found.values()):
    sys.exit(1)
PY
then
    pass "Task 3: Path rewrites detected"
else
    fail "Task 3: catalog-vs missing required rules"
fi
}

task_4() {
  local ns="cart" vs="cart-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 4: VirtualService ${vs} missing"
    return
  fi
  local timeout retries pertry
  timeout=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].timeout}' 2>/dev/null || echo "")
  retries=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].retries.attempts}' 2>/dev/null || echo "")
  pertry=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].retries.perTryTimeout}' 2>/dev/null || echo "")
  if [[ "$timeout" == "3s" && "$retries" == "3" && "$pertry" == "1s" ]]; then
    pass "Task 4: timeout/retry settings detected"
  else
    fail "Task 4: timeout/retry mismatch (timeout=$timeout, attempts=$retries, perTry=$pertry)"
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
rule = doc.get("spec", {}).get("http", [])[0]
match = rule.get("match", [{}])[0].get("uri", {}).get("prefix")
routes = rule.get("route", [])
weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
if match != "/checkout" or ("v1", 80) not in weights or ("v2", 20) not in weights:
    sys.exit(1)
PY
then
    pass "Task 4: /checkout weights 80/20"
else
    fail "Task 4: /checkout routing incorrect"
fi
}

task_5() {
  local ns="reporting" vs="reporting-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 5: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
slow_ok = False
default_ok = False
for rule in http:
    prefix = rule.get("match", [{}])[0].get("uri", {}).get("prefix")
    timeout = rule.get("timeout")
    routes = rule.get("route", [])
    fault = rule.get("fault", {})
    if prefix == "/metrics/slow":
        delay = fault.get("delay", {})
        percent = delay.get("percentage", {}).get("value")
        fixed = delay.get("fixedDelay")
        subset = routes[0].get("destination", {}).get("subset")
        if percent == 20 and fixed == "4s" and subset == "v1" and timeout == "5s":
            slow_ok = True
    elif prefix == "/metrics":
        weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
        if ("v1", 50) in weights and ("v2", 50) in weights and timeout == "5s":
            default_ok = True
if not (slow_ok and default_ok):
    sys.exit(1)
PY
then
    pass "Task 5: metrics/slow fault + default split detected"
else
    fail "Task 5: reporting-vs rules incorrect"
fi
}

task_6() {
  local ns="profile" vs="profile-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 6: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
rule = doc.get("spec", {}).get("http", [])[0]
match = rule.get("match", [{}])[0].get("uri", {}).get("prefix")
abort = rule.get("fault", {}).get("abort", {})
timeout = rule.get("timeout")
routes = rule.get("route", [])
subset = routes[0].get("destination", {}).get("subset")
if match != "/health" or abort.get("percentage", {}).get("value") != 5 or abort.get("httpStatus") != 503 or timeout != "2s" or subset != "v1":
    sys.exit(1)
PY
then
    pass "Task 6: abort fault detected"
else
    fail "Task 6: profile-vs missing abort rule"
fi
}

task_7() {
  local ns="audit" vs="audit-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 7: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
rule = doc.get("spec", {}).get("http", [])[0]
match = rule.get("match", [{}])[0].get("uri", {}).get("prefix")
mirror = rule.get("mirror", {}).get("host")
routes = rule.get("route", [])
weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
if match != "/events" or mirror != "audit-shadow.audit.svc.cluster.local" or ("v1", 90) not in weights or ("v2", 10) not in weights:
    sys.exit(1)
PY
then
    pass "Task 7: mirroring configuration detected"
else
    fail "Task 7: audit-vs missing mirror or weights"
fi
}

task_8() {
  local ns="inventory" vs="inventory-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 8: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
header_ok = False
default_ok = False
for rule in http:
    match = rule.get("match", [{}])[0]
    headers = match.get("headers", {})
    prefix = match.get("uri", {}).get("prefix")
    routes = rule.get("route", [])
    if headers.get("x-canary", {}).get("exact") == "v3" and prefix == "/stock":
        if len(routes) == 1 and routes[0].get("destination", {}).get("subset") == "v3":
            header_ok = True
    if not headers and prefix == "/stock":
        weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
        cond = ("v1", 60) in weights and ("v2", 30) in weights and ("v3", 10) in weights
        if cond:
            default_ok = True
if not (header_ok and default_ok):
    sys.exit(1)
PY
then
    pass "Task 8: header override + 60/30/10 split detected"
else
    fail "Task 8: inventory-vs routing incorrect"
fi
}

task_9() {
  local ns="frontend" vs="frontend-api-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 9: VirtualService ${vs} missing"
    return
  fi
  local origin methods headers maxage
  origin=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].corsPolicy.allowOrigins[0].exact}' 2>/dev/null || echo "")
  methods=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].corsPolicy.allowMethods}' 2>/dev/null || echo "")
  headers=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].corsPolicy.allowHeaders}' 2>/dev/null || echo "")
  maxage=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].corsPolicy.maxAge}' 2>/dev/null || echo "")
  if [[ "$origin" == "https://shop.example.com" && "$methods" == "[GET POST]" && "$headers" == "[Authorization Content-Type]" && "$maxage" == "24h" ]]; then
    pass "Task 9: CORS policy configured"
  else
    fail "Task 9: corsPolicy values incorrect"
  fi
}

task_10() {
  local ns="shipping" vs="shipping-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 10: VirtualService ${vs} missing"
    return
  fi
  local gateways
  gateways=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.gateways}' 2>/dev/null || echo "")
  if [[ "$gateways" != *"mesh"* ]]; then
    fail "Task 10: mesh gateway missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
checkout_ok = False
default_ok = False
for rule in http:
    match = rule.get("match", [{}])[0]
    prefix = match.get("uri", {}).get("prefix")
    source = match.get("sourceLabels", {})
    routes = rule.get("route", [])
    if source.get("app") == "checkout" and prefix == "/":
        if len(routes) == 1 and routes[0].get("destination", {}).get("subset") == "v2":
            checkout_ok = True
    elif not source and prefix == "/":
        if len(routes) == 1 and routes[0].get("destination", {}).get("subset") == "v1":
            default_ok = True
if not (checkout_ok and default_ok):
    sys.exit(1)
PY
then
    pass "Task 10: sourceLabels + default routing verified"
else
    fail "Task 10: shipping rules incorrect"
fi
}

task_11() {
  local ns="api" vs="api-gateway-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 11: VirtualService ${vs} missing"
    return
  fi
  local hosts gateways
  hosts=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.hosts}' 2>/dev/null || echo "")
  gateways=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.gateways}' 2>/dev/null || echo "")
  if [[ "$hosts" != *"api.shop.example.com"* ]]; then
    fail "Task 11: host api.shop.example.com missing"
    return
  fi
  if [[ "$gateways" != *"public-gw"* || "$gateways" != *"mesh"* ]]; then
    fail "Task 11: gateways missing public-gw/mesh"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
beta_ok = False
root_ok = False
for rule in http:
    match = rule.get("match", [{}])[0]
    prefix = match.get("uri", {}).get("prefix")
    routes = rule.get("route", [])
    weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
    if prefix == "/beta" and ("v2", 100) in weights:
        beta_ok = True
    if prefix == "/" and ("v1", 90) in weights and ("v2", 10) in weights:
        root_ok = True
if not (beta_ok and root_ok):
    sys.exit(1)
PY
then
    pass "Task 11: beta + root routes detected"
else
    fail "Task 11: routing incorrect"
fi
}

task_12() {
  local ns="api" vs="api-gateway-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 12: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
for rule in http:
    match = rule.get("match", [{}])[0]
    authority = match.get("authority", {}).get("exact")
    prefix = match.get("uri", {}).get("prefix")
    routes = rule.get("route", [])
    if authority == "admin.shop.internal" and prefix == "/" and len(routes) == 1:
        if routes[0].get("destination", {}).get("subset") == "v2":
            sys.exit(0)
sys.exit(1)
PY
then
    pass "Task 12: admin host rule detected"
else
    fail "Task 12: admin.shop.internal rule missing"
fi
}

task_13() {
  local ns="docs" vs="docs-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 13: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
redirect_ok = False
route_ok = False
for rule in http:
    match = rule.get("match", [{}])[0]
    uri = match.get("uri", {})
    redirect = rule.get("redirect")
    routes = rule.get("route", [])
    if uri.get("exact") == "/" and redirect and redirect.get("uri") == "/docs":
        redirect_ok = True
    if uri.get("prefix") == "/docs" and routes:
        dest = routes[0].get("destination", {}).get("host")
        if dest == "docs.docs.svc.cluster.local":
            route_ok = True
if not (redirect_ok and route_ok):
    sys.exit(1)
PY
  then
    pass "Task 13: redirect + docs route detected"
  else
    fail "Task 13: docs-vs incorrect"
  fi
}


task_14() {
  local ns="payments"
  if ! kubectl get serviceentry external-payments -n "$ns" >/dev/null 2>&1; then
    fail "Task 14: ServiceEntry external-payments missing"
    return
  fi
  local host port protocol location
  host=$(kubectl get serviceentry external-payments -n "$ns" -o jsonpath='{.spec.hosts[0]}' 2>/dev/null || echo "")
  port=$(kubectl get serviceentry external-payments -n "$ns" -o jsonpath='{.spec.ports[0].number}' 2>/dev/null || echo "")
  protocol=$(kubectl get serviceentry external-payments -n "$ns" -o jsonpath='{.spec.ports[0].protocol}' 2>/dev/null || echo "")
  location=$(kubectl get serviceentry external-payments -n "$ns" -o jsonpath='{.spec.location}' 2>/dev/null || echo "")
  if [[ "$host" == "api.external-payments.com" && "$port" == "443" && "$protocol" == "HTTPS" && "$location" == "MESH_EXTERNAL" ]]; then
    pass "Task 14: ServiceEntry configuration valid"
  else
    fail "Task 14: ServiceEntry values incorrect"
  fi
  local vs="external-payments-vs"
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
tls = doc.get("spec", {}).get("tls", [])
ok = False
for rule in tls:
    match = rule.get("match", [{}])[0]
    if match.get("port") == 443 and "api.external-payments.com" in match.get("sniHosts", []):
        dest = rule.get("route", [])[0].get("destination", {})
        if dest.get("host") == "api.external-payments.com" and dest.get("port", {}).get("number") == 443:
            ok = True
            break
if not ok:
    sys.exit(1)
PY
  then
    pass "Task 14: TLS VirtualService detected"
  else
    fail "Task 14: VirtualService missing TLS routing"
  fi
}


task_15() {
  local ns="billing" vs="billing-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 15: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
rule = doc.get("spec", {}).get("http", [])[0]
match = rule.get("match", [{}])[0].get("uri", {}).get("prefix")
fault = rule.get("fault", {}).get("delay", {})
percent = fault.get("percentage", {}).get("value")
delay = fault.get("fixedDelay")
timeout = rule.get("timeout")
retries = rule.get("retries", {})
routes = rule.get("route", [])
weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
if match != "/charge" or percent != 30 or delay != "2s" or timeout != "1.5s":
    sys.exit(1)
if retries.get("attempts") != 2 or retries.get("perTryTimeout") != "1s" or retries.get("retryOn") != "connect-failure,5xx":
    sys.exit(1)
if ("v1", 70) not in weights or ("v2", 30) not in weights:
    sys.exit(1)
PY
  then
    pass "Task 15: /charge fault and retries detected"
  else
    fail "Task 15: billing-vs misconfigured"
  fi
}


task_16() {
  local ns="web" vs="webapp-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 16: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
canary = False
normal = False
for rule in http:
    match = rule.get("match", [{}])[0]
    headers = match.get("headers", {})
    prefix = match.get("uri", {}).get("prefix")
    subset = rule.get("route", [])[0].get("destination", {}).get("subset")
    if headers.get("x-user-type", {}).get("exact") == "canary" and prefix == "/app" and subset == "v2":
        canary = True
    if not headers and prefix == "/app" and subset == "v1":
        normal = True
if not (canary and normal):
    sys.exit(1)
PY
  then
    pass "Task 16: header AND + default route detected"
  else
    fail "Task 16: webapp-vs incorrect"
  fi
}


task_17() {
  local ns="bookinfo" vs="bookinfo"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 17: VirtualService bookinfo missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
targets = {"/productpage": "productpage", "/reviews": "reviews"}
found = {k: False for k in targets}
for rule in http:
    match = rule.get("match", [{}])[0]
    prefix = match.get("uri", {}).get("prefix")
    delegate = rule.get("delegate", {}).get("name")
    if prefix in targets and delegate == targets[prefix]:
        found[prefix] = True
if not all(found.values()):
    sys.exit(1)
PY
  then
    pass "Task 17: delegation entries detected"
  else
    fail "Task 17: bookinfo VS lacks delegate rules"
  fi
  for child in productpage reviews; do
    if kubectl get virtualservice "$child" -n "$ns" >/dev/null 2>&1; then
      pass "Task 17: delegate ${child} exists"
    else
      fail "Task 17: delegate ${child} missing"
    fi
  done
}


task_18() {
  local ns="media" vs="media-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 18: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
grpc_ok = False
rest_ok = False
for rule in http:
    match = rule.get("match", [{}])[0]
    prefix = match.get("uri", {}).get("prefix")
    timeout = rule.get("timeout")
    retries = rule.get("retries", {})
    routes = rule.get("route", [])
    weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
    if prefix == "/grpc.MediaService/":
        target = routes[0].get("destination", {}).get("subset")
        if target == "v2" and timeout == "1s" and retries.get("attempts") == 1:
            grpc_ok = True
    if prefix == "/api":
        cond = ("v1", 70) in weights and ("v2", 30) in weights
        if cond and timeout == "5s" and retries.get("attempts") == 3 and retries.get("perTryTimeout") == "2s":
            rest_ok = True
if not (grpc_ok and rest_ok):
    sys.exit(1)
PY
  then
    pass "Task 18: gRPC + REST policies detected"
  else
    fail "Task 18: media-vs incorrect"
  fi
}


task_19() {
  local ns="analytics" dr="analytics-dr" vs="analytics-vs"
  if ! kubectl get destinationrule "$dr" -n "$ns" >/dev/null 2>&1; then
    fail "Task 19: DestinationRule ${dr} missing"
    return
  fi
  local attempts pertry
  attempts=$(kubectl get destinationrule "$dr" -n "$ns" -o jsonpath='{.spec.trafficPolicy.retries.attempts}' 2>/dev/null || echo "")
  pertry=$(kubectl get destinationrule "$dr" -n "$ns" -o jsonpath='{.spec.trafficPolicy.retries.perTryTimeout}' 2>/dev/null || echo "")
  if [[ "$attempts" == "3" && "$pertry" == "2s" ]]; then
    pass "Task 19: DR retry policy configured"
  else
    fail "Task 19: DR retry policy incorrect"
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
routes = doc.get("spec", {}).get("http", [])[0].get("route", [])
weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in routes])
if ("v1", 50) not in weights or ("v2", 50) not in weights:
    sys.exit(1)
PY
  then
    pass "Task 19: /reports split 50/50"
  else
    fail "Task 19: analytics-vs routing incorrect"
  fi
}


task_20() {
  local ns="notifications" vs="notifications-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 20: VirtualService ${vs} missing"
    return
  fi
  if kubectl get virtualservice "$vs" -n "$ns" -o json | python3 - <<'PY'
import json, sys
doc = json.load(sys.stdin)
http = doc.get("spec", {}).get("http", [])
if len(http) < 2:
    sys.exit(1)
slow = http[0]
default = http[1]
def match_prefix(rule):
    return rule.get("match", [{}])[0].get("uri", {}).get("prefix")
if match_prefix(slow) != "/api/slow" or match_prefix(default) != "/api/":
    sys.exit(1)
fault = slow.get("fault", {}).get("delay", {})
if fault.get("fixedDelay") != "5s" or fault.get("percentage", {}).get("value") != 10:
    sys.exit(1)
subset = slow.get("route", [])[0].get("destination", {}).get("subset")
if subset != "v1":
    sys.exit(1)
weights = sorted([(r.get("destination", {}).get("subset"), r.get("weight")) for r in default.get("route", [])])
if ("v1", 80) not in weights or ("v2", 20) not in weights:
    sys.exit(1)
PY
  then
    pass "Task 20: ordering + fault detected"
  else
    fail "Task 20: notifications-vs incorrect"
  fi
}


task_21() {
  local ns="flaky" vs="flaky-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 21: VirtualService ${vs} missing"
    return
  fi
  local timeout attempts pertry retryon
  timeout=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].timeout}' 2>/dev/null || echo "")
  attempts=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].retries.attempts}' 2>/dev/null || echo "")
  pertry=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].retries.perTryTimeout}' 2>/dev/null || echo "")
  retryon=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].retries.retryOn}' 2>/dev/null || echo "")
  if [[ "$timeout" == "7s" && "$attempts" == "3" && "$pertry" == "2s" && "$retryon" == "connect-failure,5xx" ]]; then
    pass "Task 21: flaky-vs retry policy configured"
  else
    fail "Task 21: retry fields incorrect"
  fi
}

task_22() {
  local ns="experiment" vs="experiment-vs"
  if ! kubectl get virtualservice "$vs" -n "$ns" >/dev/null 2>&1; then
    fail "Task 22: VirtualService ${vs} missing"
    return
  fi
  local timeout attempts pertry
  timeout=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].timeout}' 2>/dev/null || echo "")
  attempts=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].retries.attempts}' 2>/dev/null || echo "")
  pertry=$(kubectl get virtualservice "$vs" -n "$ns" -o jsonpath='{.spec.http[0].retries.perTryTimeout}' 2>/dev/null || echo "")
  if [[ "$timeout" == "10s" && "$attempts" == "3" && "$pertry" == "2s" ]]; then
    pass "Task 22: experiment retry/timeout adjusted"
  else
    fail "Task 22: experiment-vs values incorrect"
  fi
}

main() {
  check_cluster_basics

  if [ "$#" -eq 0 ]; then
    set -- all
  fi

  local requested=("$@")
  local tasks=()
  for item in "${requested[@]}"; do
    if [[ "$item" == "all" ]]; then
      for i in $(seq 1 22); do
        tasks+=("$i")
      done
    else
      tasks+=("$item")
    fi
  done

  for t in "${tasks[@]}"; do
    run_task "$t"
  done

  echo
  if [ "$FAILED" -eq 0 ]; then
    echo "=== RESULT: ALL CHECKS PASSED ==="
  else
    echo "=== RESULT: SOME CHECKS FAILED ==="
  fi
  exit "$FAILED"
}

main "$@"
