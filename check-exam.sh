#!/usr/bin/env bash
set -euo pipefail

# Auto-detect kubeconfig to keep behavior consistent with verify-lab.sh / exam-scoreboard.sh
auto_kubeconfig() {
  if [ -n "${KUBECONFIG:-}" ] && [ -f "$KUBECONFIG" ]; then
    echo "$KUBECONFIG"
    return
  fi
  if [ -f "$(pwd)/configs/config" ]; then
    echo "$(pwd)/configs/config"
    return
  fi
  if [ -f "/vagrant/configs/config" ]; then
    echo "/vagrant/configs/config"
    return
  fi
  if [ -f "/etc/kubernetes/admin.conf" ]; then
    echo "/etc/kubernetes/admin.conf"
    return
  fi
  echo ""  # not found
}

KUBECONFIG_PATH="$(auto_kubeconfig)"
if [ -z "$KUBECONFIG_PATH" ]; then
  echo "[check-exam] WARNING: No kubeconfig found. Set KUBECONFIG or place configs/config in repo root." >&2
else
  export KUBECONFIG="$KUBECONFIG_PATH"
fi

declare -A TASK_POINTS=(
  [1]=7
  [2]=5
  [3]=9
  [4]=6
  [5]=9
  [6]=7
  [7]=5
  [8]=4
  [9]=6
  [10]=6
  [11]=4
  [12]=5
  [13]=4
  [14]=7
  [15]=7
  [16]=9
)

declare -A TASK_LABELS=(
  [1]="Install Istio control plane"
  [2]="Default ns injection + samples"
  [3]="VirtualService httpbin-vs"
  [4]="Gateway API httpbin-route"
  [5]="Payments weighted routing"
  [6]="Helloworld header routing"
  [7]="Payments timeout + retries"
  [8]="Helloworld fault injection"
  [9]="Helloworld circuit breaker"
  [10]="Fakeservice outlier detection"
  [11]="Prometheus deployment present"
  [12]="Kiali + bookinfo labels"
  [13]="Jaeger + telemetry sampling"
  [14]="PeerAuth strict/permissive"
  [15]="AuthorizationPolicy curl POST"
  [16]="Revision tag latest + swagger"
)

declare -A TASK_STATUS=()
declare -A TASK_EARNED=()

TASK_COUNT=16
PASSING_SCORE=68
TOTAL_AVAILABLE=100
earned=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass_msg() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail_msg() { echo -e "${RED}[FAIL]${NC} $1"; }

run_task() {
  local task_id="$1"
  if ! [[ "$task_id" =~ ^[0-9]+$ ]]; then
    fail_msg "Task ${task_id}: invalid task selector"
    return
  fi
  if (( task_id < 1 || task_id > TASK_COUNT )); then
    fail_msg "Task ${task_id}: outside valid range 1-${TASK_COUNT}"
    return
  fi
  local fn="task_${task_id}"
  local points="${TASK_POINTS[$task_id]:-0}"
  local label="${TASK_LABELS[$task_id]:-Task ${task_id}}"
  if ! declare -f "$fn" >/dev/null 2>&1; then
    TASK_STATUS["$task_id"]="NOCHK"
    TASK_EARNED["$task_id"]=0
    fail_msg "Task ${task_id} (${label}): checker not implemented"
    return
  fi
  if "$fn"; then
    TASK_STATUS["$task_id"]="PASS"
    TASK_EARNED["$task_id"]="$points"
    pass_msg "Task ${task_id} (${label}): +${points} points"
    earned=$((earned + points))
  else
    TASK_STATUS["$task_id"]="FAIL"
    TASK_EARNED["$task_id"]=0
    fail_msg "Task ${task_id} (${label}): requirements not met"
  fi
}

print_summary() {
  echo
  echo "================ ICA EXAM CHECK ================"
  printf "%-4s %-45s %-10s %s\n" "#" "Task" "Status" "Points"
  echo "---------------------------------------------------------------"
  for t in $(seq 1 "$TASK_COUNT"); do
    local label="${TASK_LABELS[$t]:-Task ${t}}"
    local status="${TASK_STATUS[$t]:-SKIP}"
    local earned_pts="${TASK_EARNED[$t]:-0}"
    local max_pts="${TASK_POINTS[$t]:-0}"
    local status_str="$status"
    case "$status" in
      PASS) status_str="${GREEN}${status}${NC}" ;;
      FAIL) status_str="${RED}${status}${NC}" ;;
      NOCHK|SKIP) status_str="${YELLOW}${status}${NC}" ;;
    esac
    printf "%-4s %-45s %-10s %s\n" "$t" "$label" "$status_str" "${earned_pts}/${max_pts}"
  done
  echo "---------------------------------------------------------------"
  echo "Total: ${earned}/${TOTAL_AVAILABLE}  (pass >= ${PASSING_SCORE})"
  echo
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
  kubectl -n default get gateway.networking.istio.io httpbin-gw >/dev/null 2>&1 || return 1
  kubectl -n default get virtualservice httpbin-vs >/dev/null 2>&1 || return 1
  kubectl -n default get virtualservice httpbin-vs -o json | python3 -c "
import json,sys
doc=json.load(sys.stdin)
spec=doc.get('spec',{})
hosts=spec.get('hosts',[])
gws=spec.get('gateways',[])
route=spec.get('http',[{}])[0].get('route',[{}])[0]
dest=route.get('destination',{})
host_ok='httpbin.com' in hosts
gw_ok='httpbin-gw' in gws
host=dest.get('host')
port=dest.get('port',{}).get('number')
sys.exit(0 if host_ok and gw_ok and host=='httpbin.default.svc.cluster.local' and port==8000 else 1)
"
}

task_4() {
  kubectl -n default get gateway.gateway.networking.k8s.io httpbin-kgw >/dev/null 2>&1 || return 1
  kubectl -n default get httproute httpbin-route >/dev/null 2>&1 || return 1
  kubectl -n default get httproute httpbin-route -o json | python3 -c "
import json,sys
doc=json.load(sys.stdin)
spec=doc.get('spec',{})
parents=spec.get('parentRefs',[])
hosts=spec.get('hostnames',[])
rules=spec.get('rules',[])
ok=('httpbin.com' in hosts)
if parents:
    ok = ok and parents[0].get('name')=='httpbin-kgw'
if rules:
    back=rules[0].get('backendRefs',[{}])[0]
    ok = ok and back.get('name')=='httpbin' and back.get('port')==8000
sys.exit(0 if ok else 1)
"
}

task_5() {
  dr_json=$(kubectl -n payments get destinationrule payments-dr -o json 2>/dev/null) || return 1
  [ -n "$dr_json" ] || return 1
  python3 - <<'PY' <<<"$dr_json"
import json,sys
doc=json.load(sys.stdin)
sub=doc.get('spec',{}).get('subsets',[])
labels={item.get('name'):item.get('labels',{}).get('version') for item in sub}
sys.exit(0 if labels.get('v1')=='v1' and labels.get('v2')=='v2' else 1)
PY

  vs_json=$(kubectl -n payments get virtualservice payments-vs -o json 2>/dev/null) || return 1
  [ -n "$vs_json" ] || return 1
  python3 - <<'PY' <<<"$vs_json"
import json,sys
doc=json.load(sys.stdin)
routes=doc.get('spec',{}).get('http',[{}])[0].get('route',[])
weights={(r.get('destination',{}).get('subset'), r.get('weight')) for r in routes}
sys.exit(0 if ('v1',70) in weights and ('v2',30) in weights else 1)
PY
}

task_6() {
  vs_json=$(kubectl -n default get virtualservice helloworld-match-vs -o json 2>/dev/null) || return 1
  [ -n "$vs_json" ] || return 1
  python3 - <<'PY' <<<"$vs_json"
import json,sys
doc=json.load(sys.stdin)
http=doc.get('spec',{}).get('http',[])
reqs={'/v1':('v1','/hello'), '/v2':('v2','/hello')}
found={k:False for k in reqs}
fallback=False
for rule in http:
    matches=rule.get('match',[{}])
    route=rule.get('route',[{}])
    subset=route[0].get('destination',{}).get('subset')
    rewrite=rule.get('rewrite',{}).get('uri')
    for match in matches:
        prefix=match.get('uri',{}).get('prefix')
        if prefix in reqs and rewrite==reqs[prefix][1] and subset==reqs[prefix][0]:
            found[prefix]=True
    if not matches or matches==[{}]:
        fallback = subset=='v1'
sys.exit(0 if all(found.values()) and fallback else 1)
PY
}

task_7() {
  vs_json=$(kubectl -n payments get virtualservice payments-vs -o json 2>/dev/null) || return 1
  [ -n "$vs_json" ] || return 1
  python3 - <<'PY' <<<"$vs_json"
import json,sys
doc=json.load(sys.stdin)
http=doc.get('spec',{}).get('http',[{}])[0]
timeout=http.get('timeout')
retries=http.get('retries',{})
cond = timeout=='2s' and retries.get('attempts')==3 and retries.get('perTryTimeout')=='1s'
cond = cond and retries.get('retryOn')=='5xx,connect-failure,refused-stream'
sys.exit(0 if cond else 1)
PY
}

task_8() {
  vs_json=$(kubectl -n default get virtualservice helloworld-match-vs -o json 2>/dev/null) || return 1
  [ -n "$vs_json" ] || return 1
  python3 - <<'PY' <<<"$vs_json"
import json,sys
doc=json.load(sys.stdin)
rule=doc.get('spec',{}).get('http',[{}])
ok=False
for entry in rule:
    fault=entry.get('fault',{})
    delay=fault.get('delay',{})
    percent=delay.get('percentage',{}).get('value')
    fixed=delay.get('fixedDelay')
    matches=entry.get('match',[{}])
    for match in matches:
        prefix=match.get('uri',{}).get('prefix')
        if prefix=='/v2' and percent==20 and fixed=='2s':
            ok=True
sys.exit(0 if ok else 1)
PY
}

task_9() {
  dr_json=$(kubectl -n default get destinationrule helloworld-cb -o json 2>/dev/null) || return 1
  [ -n "$dr_json" ] || return 1
  python3 - <<'PY' <<<"$dr_json"
import json,sys
doc=json.load(sys.stdin)
http=doc.get('spec',{}).get('trafficPolicy',{}).get('connectionPool',{}).get('http',{})
cond=http.get('http1MaxPendingRequests')==1 and http.get('http2MaxRequests')==1 and http.get('maxRequestsPerConnection')==1
sys.exit(0 if cond else 1)
PY
}

task_10() {
  dr_json=$(kubectl -n default get destinationrule fakeservice-od -o json 2>/dev/null) || return 1
  [ -n "$dr_json" ] || return 1
  python3 - <<'PY' <<<"$dr_json"
import json,sys
doc=json.load(sys.stdin)
od=doc.get('spec',{}).get('trafficPolicy',{}).get('outlierDetection',{})
cond=od.get('consecutive5xxErrors')==1 and od.get('interval')=='5s'
cond=cond and od.get('baseEjectionTime')=='3m' and od.get('maxEjectionPercent')==100
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
  kubectl -n default get peerauthentication httpbin-port-permissive -o json | python3 -c "
import json,sys
doc=json.load(sys.stdin)
port=doc.get('spec',{}).get('portLevelMtls',{}).get('8000',{}).get('mode')
sys.exit(0 if port=='PERMISSIVE' else 1)
"
}

task_15() {
  kubectl -n default get authorizationpolicy allow-nothing >/dev/null 2>&1 || return 1
  kubectl -n default get authorizationpolicy curl-to-httpbin-post-only -o json | python3 -c "
import json,sys
doc=json.load(sys.stdin)
rules=doc.get('spec',{}).get('rules',[])
if not rules:
    sys.exit(1)
rule=rules[0]
principals=rule.get('from',[{}])[0].get('source',{}).get('principals',[])
methods=rule.get('to',[{}])[0].get('operation',{}).get('methods',[])
cond='cluster.local/ns/default/sa/curl' in principals and methods==['POST']
sys.exit(0 if cond else 1)
"
}

task_16() {
  kubectl get mutatingwebhookconfiguration istio-revision-tag-latest >/dev/null 2>&1 || return 1
  kubectl get ns swagger -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null | grep -q 'latest' || return 1
  kubectl -n swagger get pods >/dev/null 2>&1
}

declare -A TASK_SOLUTIONS=(
  [1]="istioctl install --set profile=demo -y"
  [2]="kubectl label ns default istio-injection=enabled --overwrite && kubectl -n default rollout restart deploy"
  [3]="kubectl apply -f /vagrant/manifests/task-03-12.yaml  # httpbin-gw + httpbin-vs"
  [4]="kubectl apply -f /vagrant/manifests/task-03-12.yaml  # httpbin-kgw + httpbin-route (Gateway API)"
  [5]="kubectl apply -f /vagrant/manifests/task-03-12.yaml  # payments-dr + payments-vs with 70/30 weights"
  [6]="kubectl apply -f /vagrant/manifests/task-03-12.yaml  # helloworld-match-vs with /v1, /v2, fallback"
  [7]="kubectl apply -f /vagrant/manifests/task-03-12.yaml  # payments-vs with timeout: 2s and retries"
  [8]="kubectl apply -f /vagrant/manifests/task-03-12.yaml  # helloworld fault injection 2s delay 20%"
  [9]="kubectl apply -f /vagrant/manifests/task-03-12.yaml  # helloworld-cb DestinationRule circuit breaker"
  [10]="kubectl apply -f /vagrant/manifests/task-03-12.yaml  # fakeservice-od DestinationRule outlierDetection"
  [11]="kubectl apply -f /vagrant/manifests/task-11-16.yaml  # prometheus deployment"
  [12]="kubectl apply -f /vagrant/manifests/task-11-16.yaml  # kiali + kubectl label ns bookinfo istio-injection=enabled"
  [13]="kubectl apply -f /vagrant/manifests/task-11-16.yaml && kubectl apply -f /vagrant/manifests/task-13-16.yaml  # jaeger + Telemetry 100%"
  [14]="kubectl apply -f /vagrant/manifests/task-13-16.yaml  # PeerAuthentication default-strict + httpbin-port-permissive"
  [15]="kubectl apply -f /vagrant/manifests/task-13-16.yaml  # AuthorizationPolicy curl POST only"
  [16]="istioctl tag set latest --revision default --overwrite && kubectl label ns swagger istio.io/rev=latest --overwrite"
)

show_solutions() {
  echo
  echo "================ SOLUTIONS FOR FAILED TASKS ================"
  local has_failed=false
  for t in $(seq 1 "$TASK_COUNT"); do
    local status="${TASK_STATUS[$t]:-SKIP}"
    if [[ "$status" == "FAIL" ]]; then
      has_failed=true
      local label="${TASK_LABELS[$t]:-Task ${t}}"
      local solution="${TASK_SOLUTIONS[$t]:-No solution available}"
      echo
      echo -e "${RED}Task ${t}${NC}: ${label}"
      echo "  Solution: ${solution}"
    fi
  done
  if [ "$has_failed" = false ]; then
    echo "  No failed tasks - all checks passed!"
  fi
  echo
  echo "Full manifest files are in /vagrant/manifests/"
  echo "============================================================="
}

usage() {
  echo "Usage: $0 [options] [task-ids...]"
  echo
  echo "Options:"
  echo "  -s, --solutions    Show solutions for failed tasks after checking"
  echo "  -h, --help         Show this help message"
  echo
  echo "Examples:"
  echo "  $0                 Check all tasks"
  echo "  $0 all             Check all tasks"
  echo "  $0 1 2 3           Check specific tasks"
  echo "  $0 -s              Check all tasks and show solutions for failures"
  echo "  $0 -s 5 6 7        Check specific tasks and show solutions for failures"
}

main() {
  local tasks=()
  local show_solutions_flag=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--solutions)
        show_solutions_flag=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        if [[ "$1" =~ ^([Aa][Ll][Ll])$ ]]; then
          for t in $(seq 1 "$TASK_COUNT"); do
            tasks+=("$t")
          done
        else
          tasks+=("$1")
        fi
        shift
        ;;
    esac
  done

  if [ "${#tasks[@]}" -eq 0 ]; then
    for t in $(seq 1 "$TASK_COUNT"); do
      tasks+=("$t")
    done
  fi

  for t in "${tasks[@]}"; do
    run_task "$t"
  done

  print_summary

  if [ "$earned" -ge "$PASSING_SCORE" ]; then
    echo "=== RESULT: PASS THRESHOLD MET ==="
  else
    echo "=== RESULT: BELOW PASS THRESHOLD ==="
  fi

  if [ "$show_solutions_flag" = true ]; then
    show_solutions
  else
    echo
    echo "Tip: Run with -s or --solutions to see solutions for failed tasks"
  fi

  exit 0
}

main "$@"
