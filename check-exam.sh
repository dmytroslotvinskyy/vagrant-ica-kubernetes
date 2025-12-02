#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

declare -A TASK_POINTS=(
  [1]=8
  [2]=5
  [3]=10
  [4]=7
  [5]=10
  [6]=8
  [7]=6
  [8]=4
  [9]=7
  [10]=6
  [11]=4
  [12]=5
  [13]=4
  [14]=8
  [15]=8
  [16]=10
)

PASSING_SCORE=68
TOTAL_AVAILABLE=100
earned=0

pass_msg() { echo "[PASS] $1"; }
fail_msg() { echo "[FAIL] $1"; }

run_task() {
  local task_id="$1"
  local fn="task_${task_id}"
  local points="${TASK_POINTS[$task_id]:-0}"
  if ! declare -f "$fn" >/dev/null 2>&1; then
    fail_msg "Task ${task_id}: checker not implemented"
    return
  fi
  if "$fn"; then
    pass_msg "Task ${task_id}: +${points} points"
    earned=$((earned + points))
  else
    fail_msg "Task ${task_id}: requirements not met"
  fi
}

check_resource_ready() {
  local ns="$1" label_selector="$2"
  local field='.items[*].status.containerStatuses[*].ready'
  local readiness
  readiness=$(kubectl -n "$ns" get pods -l "$label_selector" -o jsonpath="$field" 2>/dev/null || true)
  [[ -n "$readiness" ]] && [[ "$readiness" != *"false"* ]]
}

task_1() {
  command -v istioctl >/dev/null 2>&1 || return 1
  kubectl get ns istio-system >/dev/null 2>&1 || return 1
  kubectl -n istio-system get deploy istiod >/dev/null 2>&1 || return 1
  kubectl -n istio-system get deploy istio-ingressgateway >/dev/null 2>&1 || return 1
  istioctl version >/dev/null 2>&1
}

task_2() {
  local label
  label=$(kubectl get ns default -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "")
  [[ "$label" == "enabled" ]] || return 1
  kubectl -n default get deploy httpbin >/dev/null 2>&1 || return 1
  kubectl -n default get deploy curl >/dev/null 2>&1 || return 1
  kubectl -n default get pod -l app=httpbin -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].name}' >/dev/null 2>&1
}

task_3() {
  kubectl -n default get gateway httpbin-gw >/dev/null 2>&1 || return 1
  kubectl -n default get virtualservice httpbin-vs >/dev/null 2>&1 || return 1
  kubectl -n default get virtualservice httpbin-vs -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
hosts=doc.get("spec",{}).get("hosts",[])
gws=doc.get("spec",{}).get("gateways",[])
route=doc.get("spec",{}).get("http",[{}])[0].get("route",[{}])[0]
dest=route.get("destination",{})
host_ok="httpbin.com" in hosts
gw_ok="httpbin-gw" in gws
host=dest.get("host")
port=dest.get("port",{}).get("number")
sys.exit(0 if host_ok and gw_ok and host=="httpbin.default.svc.cluster.local" and port==8000 else 1)
PY
}

task_4() {
  kubectl -n default get gateway.gateway.networking.k8s.io httpbin-kgw >/dev/null 2>&1 || return 1
  kubectl -n default get httproute httpbin-route >/dev/null 2>&1 || return 1
  kubectl -n default get httproute httpbin-route -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
parents=doc.get("spec",{}).get("parentRefs",[])
hosts=doc.get("spec",{}).get("hostnames",[])
rules=doc.get("spec",{}).get("rules",[])
ok=("httpbin.com" in hosts)
if parents:
    ok = ok and parents[0].get("name")=="httpbin-kgw"
if rules:
    back=rules[0].get("backendRefs",[{}])[0]
    ok = ok and back.get("name")=="httpbin" and back.get("port")==8000
sys.exit(0 if ok else 1)
PY
}

task_5() {
  kubectl -n payments get destinationrule payments-dr >/dev/null 2>&1 || return 1
  kubectl -n payments get virtualservice payments-vs >/dev/null 2>&1 || return 1
  kubectl -n payments get destinationrule payments-dr -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
sub=doc.get("spec",{}).get("subsets",[])
labels={item.get("name"):item.get("labels",{}).get("version") for item in sub}
sys.exit(0 if labels.get("v1")=="v1" and labels.get("v2")=="v2" else 1)
PY
  kubectl -n payments get virtualservice payments-vs -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
routes=doc.get("spec",{}).get("http",[{}])[0].get("route",[])
weights={(r.get("destination",{}).get("subset"), r.get("weight")) for r in routes}
sys.exit(0 if ("v1",70) in weights and ("v2",30) in weights else 1)
PY
}

task_6() {
  kubectl -n default get virtualservice helloworld-match-vs >/dev/null 2>&1 || return 1
  kubectl -n default get virtualservice helloworld-match-vs -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
http=doc.get("spec",{}).get("http",[])
reqs={"/v1":("v1","/hello"), "/v2":("v2","/hello")}
found={k:False for k in reqs}
fallback=False
for rule in http:
    matches=rule.get("match",[{}])
    route=rule.get("route",[{}])
    subset=route[0].get("destination",{}).get("subset")
    rewrite=rule.get("rewrite",{}).get("uri")
    for match in matches:
        prefix=match.get("uri",{}).get("prefix")
        if prefix in reqs and rewrite==reqs[prefix][1] and subset==reqs[prefix][0]:
            found[prefix]=True
    if not matches or matches==[{}]:
        fallback = subset=="v1"
sys.exit(0 if all(found.values()) and fallback else 1)
PY
}

task_7() {
  kubectl -n payments get virtualservice payments-vs -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
http=doc.get("spec",{}).get("http",[{}])[0]
timeout=http.get("timeout")
retries=http.get("retries",{})
cond = timeout=="2s" and retries.get("attempts")==3 and retries.get("perTryTimeout")=="1s"
cond = cond and retries.get("retryOn")=="5xx,connect-failure,refused-stream"
sys.exit(0 if cond else 1)
PY
}

task_8() {
  kubectl -n default get virtualservice helloworld-match-vs -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
rule=doc.get("spec",{}).get("http",[{}])
ok=False
for entry in rule:
    fault=entry.get("fault",{})
    delay=fault.get("delay",{})
    percent=delay.get("percentage",{}).get("value")
    fixed=delay.get("fixedDelay")
    matches=entry.get("match",[{}])
    for match in matches:
        prefix=match.get("uri",{}).get("prefix")
        if prefix=="/v2" and percent==20 and fixed=="2s":
            ok=True
sys.exit(0 if ok else 1)
PY
}

task_9() {
  kubectl -n default get destinationrule helloworld-cb -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
http=doc.get("spec",{}).get("trafficPolicy",{}).get("connectionPool",{}).get("http",{})
cond=http.get("http1MaxPendingRequests")==1 and http.get("http2MaxRequests")==1 and http.get("maxRequestsPerConnection")==1
sys.exit(0 if cond else 1)
PY
}

task_10() {
  kubectl -n default get destinationrule fakeservice-od -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
od=doc.get("spec",{}).get("trafficPolicy",{}).get("outlierDetection",{})
cond=od.get("consecutive5xxErrors")==1 and od.get("interval")=="5s"
cond=cond and od.get("baseEjectionTime")=="3m" and od.get("maxEjectionPercent")==100
sys.exit(0 if cond else 1)
PY
}

task_11() {
  kubectl -n istio-system get deploy prometheus >/dev/null 2>&1
}

task_12() {
  kubectl -n istio-system get deploy kiali >/dev/null 2>&1 || return 1
  local label
  label=$(kubectl get ns bookinfo -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "")
  [[ "$label" == "enabled" ]]
}

task_13() {
  kubectl -n istio-system get deploy jaeger >/dev/null 2>&1 || return 1
  kubectl -n istio-system get telemetry mesh-default -o jsonpath='{.spec.tracing[0].randomSamplingPercentage}' 2>/dev/null | grep -q '^100$'
}

task_14() {
  kubectl -n default get peerauthentication default-strict >/dev/null 2>&1 || return 1
  kubectl -n default get peerauthentication httpbin-port-permissive -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
port=doc.get("spec",{}).get("portLevelMtls",{}).get("8080",{}).get("mode")
sys.exit(0 if port=="PERMISSIVE" else 1)
PY
}

task_15() {
  kubectl -n default get authorizationpolicy allow-nothing >/dev/null 2>&1 || return 1
  kubectl -n default get authorizationpolicy curl-to-httpbin-post-only -o json | python3 - <<'PY'
import json,sys
doc=json.load(sys.stdin)
rules=doc.get("spec",{}).get("rules",[])
if not rules:
    sys.exit(1)
rule=rules[0]
principals=rule.get("from",[{}])[0].get("source",{}).get("principals",[])
methods=rule.get("to",[{}])[0].get("operation",{}).get("methods",[])
cond="cluster.local/ns/default/sa/curl" in principals and methods==["POST"]
sys.exit(0 if cond else 1)
PY
}

task_16() {
  kubectl get mutatingwebhookconfiguration istio-revision-tag-latest >/dev/null 2>&1 || return 1
  kubectl get ns swagger -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null | grep -q 'latest' || return 1
  kubectl -n swagger get pods >/dev/null 2>&1
}

main() {
  local tasks=()
  if [ "$#" -eq 0 ]; then
    tasks=($(seq 1 16))
  else
    tasks=("$@")
  fi
  for t in "${tasks[@]}"; do
    run_task "$t"
  done
  echo
  echo "Score: ${earned}/${TOTAL_AVAILABLE} (pass >= ${PASSING_SCORE})"
  if [ "$earned" -ge "$PASSING_SCORE" ]; then
    echo "=== RESULT: PASS THRESHOLD MET ==="
  else
    echo "=== RESULT: BELOW PASS THRESHOLD ==="
  fi
  exit 0
}

main "$@"
