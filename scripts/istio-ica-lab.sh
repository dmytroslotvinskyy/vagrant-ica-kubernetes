#!/usr/bin/env bash
set -euo pipefail

echo "[istio-ica-lab] Starting Istio + lab provisioning"

# Use admin kubeconfig
export KUBECONFIG=/etc/kubernetes/admin.conf

ISTIO_VERSION="1.26.3"
ISTIO_DIR="/opt/istio-${ISTIO_VERSION}"
LAB_NAMESPACES=(
  payments orders catalog cart reporting profile audit inventory frontend
  shipping api docs billing web bookinfo media analytics notifications
  flaky experiment
)
EXAM_NAMESPACES=(default payments swagger)

distribute_kubeconfig() {
  local admin_conf="/etc/kubernetes/admin.conf"
  local vagrant_home="/home/vagrant"
  local vagrant_kube_dir="${vagrant_home}/.kube"
  local vagrant_kubeconfig="${vagrant_kube_dir}/config"
  local shared_configs="/vagrant/configs"

  if [ -f "$admin_conf" ]; then
    mkdir -p "$vagrant_kube_dir"
    cp "$admin_conf" "${vagrant_kubeconfig}.tmp"
    mv "${vagrant_kubeconfig}.tmp" "$vagrant_kubeconfig"
    chown -R vagrant:vagrant "$vagrant_kube_dir"
    chmod 600 "$vagrant_kubeconfig"

    if [ -d "$shared_configs" ]; then
      cp "$admin_conf" "${shared_configs}/config.tmp"
      mv "${shared_configs}/config.tmp" "${shared_configs}/config"
      chmod 600 "${shared_configs}/config" || true
    fi
  fi
}

wait_for_cluster_nodes() {
  local min_nodes=2
  local timeout_seconds=900
  local interval=10
  local waited=0
  local last_node_output=""
  echo "[istio-ica-lab] Waiting for at least ${min_nodes} Kubernetes nodes to be Ready before installing Istio"
  while [ "$waited" -lt "$timeout_seconds" ]; do
    if ! node_output=$(kubectl get nodes --no-headers 2>/dev/null); then
      sleep "$interval"
      waited=$((waited + interval))
      continue
    fi
    last_node_output="$node_output"
    local total_nodes
    total_nodes=$(printf "%s\n" "$node_output" | sed '/^\s*$/d' | wc -l | tr -d ' ')
    if [ "$total_nodes" -lt "$min_nodes" ]; then
      echo "[istio-ica-lab] Detected $total_nodes node(s). Waiting for workers to join..."
      sleep "$interval"
      waited=$((waited + interval))
      continue
    fi
    if printf "%s\n" "$node_output" | awk '$2 != "Ready" {exit 1}'; then
      echo "[istio-ica-lab] All nodes Ready:"
      printf "%s\n" "$node_output"
      return 0
    else
      pending_nodes=$(printf "%s\n" "$node_output" | awk '$2 != "Ready" {print $1}')
      echo "[istio-ica-lab] Waiting for node(s) to become Ready: $pending_nodes"
      sleep "$interval"
      waited=$((waited + interval))
    fi
  done
  echo "[istio-ica-lab] Timed out after ${timeout_seconds}s waiting for all nodes to become Ready."
  if [ -n "$last_node_output" ]; then
    echo "[istio-ica-lab] Last observed node status:"
    printf "%s\n" "$last_node_output"
  fi
  echo "[istio-ica-lab] Proceeding in degraded mode by removing controlplane taints so workloads can schedule there."
  kubectl taint nodes controlplane node-role.kubernetes.io/control-plane- 2>/dev/null || true
  kubectl taint nodes controlplane node-role.kubernetes.io/master- 2>/dev/null || true
  return 0
}

install_istioctl() {
  if command -v istioctl >/dev/null 2>&1; then
    echo "[istio-ica-lab] istioctl already installed"
    return
  fi

  echo "[istio-ica-lab] Downloading Istio ${ISTIO_VERSION}"
  cd /tmp
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION="${ISTIO_VERSION}" sh -
  mv "istio-${ISTIO_VERSION}" "${ISTIO_DIR}"
  chmod -R a+rx "${ISTIO_DIR}"
  ln -sf "${ISTIO_DIR}/bin/istioctl" /usr/local/bin/istioctl

  echo "[istio-ica-lab] istioctl installed at /usr/local/bin/istioctl"
}

install_istio_control_plane() {
  if kubectl get ns istio-system >/dev/null 2>&1; then
    echo "[istio-ica-lab] Re-run detected; Istio control plane already installed. Refreshing workloads and checks only."
    return
  fi

  wait_for_cluster_nodes

  echo "[istio-ica-lab] Installing Istio control plane (demo profile)"
  local attempts=0
  local max_attempts=3
  until istioctl install --set profile=demo -y; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge "$max_attempts" ]; then
      echo "[istio-ica-lab] Failed to install Istio after ${attempts} attempts"
      return 1
    fi
    echo "[istio-ica-lab] Retry Istio install (${attempts}/${max_attempts}) in 30s..."
    sleep 30
  done
}

prepare_namespaces() {
  echo "[istio-ica-lab] Creating namespaces and enabling sidecar injection"
  kubectl label namespace default istio-injection=enabled --overwrite
  for ns in "${LAB_NAMESPACES[@]}"; do
    if ! kubectl get ns "$ns" >/dev/null 2>&1; then
      kubectl create namespace "$ns"
    fi
    kubectl label namespace "$ns" istio-injection=enabled --overwrite
  done
}

install_gateway_api_crds() {
  local crd_url="https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml"
  if kubectl get crd gatewayclasses.gateway.networking.k8s.io >/dev/null 2>&1; then
    echo "[istio-ica-lab] Gateway API CRDs already installed"
    return
  fi
  echo "[istio-ica-lab] Installing Gateway API CRDs (GatewayClass/Gateway/HTTPRoute)..."
  kubectl apply -f "${crd_url}"
  kubectl wait --for=condition=Established crd/gatewayclasses.gateway.networking.k8s.io --timeout=120s
  kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=120s
  kubectl wait --for=condition=Established crd/httproutes.gateway.networking.k8s.io --timeout=120s
}

deploy_http_service() {
  local namespace="$1"
  local name="$2"
  local port="$3"
  shift 3
  local versions=("$@")
  cat <<YAML | kubectl apply -f -
---
apiVersion: v1
kind: Service
metadata:
  name: ${name}
  namespace: ${namespace}
  labels:
    app: ${name}
spec:
  selector:
    app: ${name}
  ports:
  - name: http
    port: ${port}
    targetPort: ${port}
YAML
  for version in "${versions[@]}"; do
    cat <<YAML | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}-${version}
  namespace: ${namespace}
  labels:
    app: ${name}
    version: ${version}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${name}
      version: ${version}
  template:
    metadata:
      labels:
        app: ${name}
        version: ${version}
    spec:
      containers:
      - name: ${name}
        image: hashicorp/http-echo
        args:
        - "-text=Hello from ${name} ${version}"
        - "-listen=:${port}"
        ports:
        - containerPort: ${port}
YAML
  done
}

deploy_singleton_service() {
  local namespace="$1"
  local name="$2"
  local port="$3"
  local text="$4"
  cat <<YAML | kubectl apply -f -
---
apiVersion: v1
kind: Service
metadata:
  name: ${name}
  namespace: ${namespace}
  labels:
    app: ${name}
spec:
  selector:
    app: ${name}
  ports:
  - name: http
    port: ${port}
    targetPort: ${port}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${namespace}
  labels:
    app: ${name}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${name}
  template:
    metadata:
      labels:
        app: ${name}
    spec:
      containers:
      - name: ${name}
        image: hashicorp/http-echo
        args:
        - "-text=${text}"
        - "-listen=:${port}"
        ports:
        - containerPort: ${port}
YAML
}

deploy_client() {
  local namespace="$1"
  local name="${2:-client}"
  local label="${3:-client}"
  cat <<YAML | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${namespace}
  labels:
    app: ${label}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${label}
  template:
    metadata:
      labels:
        app: ${label}
    spec:
      containers:
      - name: ${name}
        image: docker.io/curlimages/curl:8.12.1
        command: ["/bin/sleep", "infinity"]
YAML
}

apply_gateways() {
  cat <<'YAML' | kubectl apply -f -
---
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: public-gw
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - api.shop.example.com
    - admin.shop.internal
---
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: docs-gw
  namespace: docs
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - docs.example.com
---
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: bookinfo-gw
  namespace: bookinfo
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - bookinfo.example.com
YAML
}

deploy_httpbin() {
  echo "[istio-ica-lab] Deploying httpbin (exam tasks 2,3,14,15)"
  cat <<'YAML' | kubectl apply -f -
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  namespace: default
  labels:
    app: httpbin
spec:
  ports:
  - port: 8000
    targetPort: 80
    name: http
  selector:
    app: httpbin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
  namespace: default
  labels:
    app: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: registry.k8s.io/istio/examples/httpbin@sha256:7f16c61f9b0fc25a9d4fa81f5482b5bee255ec4e2db4b2876d3e0f427b37e417
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
YAML
}

deploy_fakeservice() {
  echo "[istio-ica-lab] Deploying fakeservice (exam task 10)"
  cat <<'YAML' | kubectl apply -f -
---
apiVersion: v1
kind: Service
metadata:
  name: fakeservice
  namespace: default
  labels:
    app: fakeservice
spec:
  selector:
    app: fakeservice
  ports:
  - port: 8080
    targetPort: 8080
    name: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fakeservice
  namespace: default
  labels:
    app: fakeservice
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fakeservice
  template:
    metadata:
      labels:
        app: fakeservice
    spec:
      containers:
      - name: fakeservice
        image: hashicorp/http-echo
        args:
        - "-text=fakeservice backend"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
YAML
}

restart_default_ns_workloads() {
  echo "[istio-ica-lab] Restarting default namespace deployments to inject sidecars"
  for deploy in $(kubectl -n default get deploy -o name 2>/dev/null); do
    kubectl -n default rollout restart "$deploy" || true
  done
  echo "[istio-ica-lab] Waiting for default namespace pods to be ready..."
  kubectl -n default wait --for=condition=available deploy --all --timeout=300s || true
}

apply_lab_workloads() {
  echo "[istio-ica-lab] Applying sample workloads for ICA tasks"

  # Core exam workloads in default namespace
  deploy_httpbin
  deploy_fakeservice
  deploy_http_service default helloworld 5000 v1 v2
  deploy_client default curl curl

  deploy_http_service payments payments 8080 v1 v2
  deploy_client payments

  deploy_http_service orders orders 8080 v1 v2
  deploy_client orders

  deploy_http_service catalog catalog 8080 v1 v2
  deploy_client catalog

  deploy_http_service cart cart 8080 v1 v2
  deploy_client cart

  deploy_http_service reporting reporting 8080 v1 v2
  deploy_client reporting

  deploy_singleton_service profile profile 8080 "Hello from profile v1"
  deploy_client profile

  deploy_http_service audit audit 8080 v1 v2
  deploy_singleton_service audit audit-shadow 8080 "Hello from audit shadow"
  deploy_client audit

  deploy_http_service inventory inventory 8080 v1 v2 v3
  deploy_client inventory

  deploy_singleton_service frontend frontend-api 8080 "Hello from frontend API"
  deploy_client frontend

  deploy_http_service shipping shipping 8080 v1 v2
  deploy_client shipping
  deploy_client shipping checkout checkout
  deploy_client shipping admin admin

  deploy_http_service api api-gateway 8080 v1 v2
  deploy_client api

  deploy_singleton_service docs docs 8080 "Hello from docs service"
  deploy_client docs

  deploy_http_service billing billing 8080 v1 v2
  deploy_client billing

  deploy_http_service web webapp 8080 v1 v2
  deploy_client web

  deploy_singleton_service bookinfo productpage 9080 "Hello from productpage"
  deploy_singleton_service bookinfo reviews 9080 "Hello from reviews"
  deploy_client bookinfo

  deploy_http_service media media 8080 v1 v2
  deploy_client media

  deploy_http_service analytics analytics 8080 v1 v2
  deploy_client analytics

  deploy_http_service notifications notifications 8080 v1 v2
  deploy_client notifications

  deploy_singleton_service flaky flaky 8080 "Hello from flaky service"
  deploy_client flaky

  deploy_singleton_service experiment experiment 8080 "Hello from experiment service"
  deploy_client experiment

  apply_gateways
}

chmod_host_scripts() {
  for f in /vagrant/tasks.sh \
           /vagrant/check-exam.sh \
           /vagrant/scripts/tasks-viewer.sh \
           /vagrant/scripts/exam-env.sh \
           /vagrant/scripts/exam-scoreboard.sh \
           /vagrant/scripts/tasks-viewer-tui.sh \
           /vagrant/scripts/exam-env-tui.sh \
           /vagrant/scripts/exam-tui-bun.sh \
           /vagrant/scripts/install-bun.sh \
           /vagrant/scripts/post-provision-bun.sh; do
    if [ -f "$f" ]; then
      chmod +x "$f" || true
    fi
  done
}

verify_lab_health() {
  echo "[istio-ica-lab] Verifying Istio control plane health"
  kubectl wait -n istio-system deploy/istiod --for=condition=Available --timeout=600s
  kubectl wait -n istio-system deploy/istio-ingressgateway --for=condition=Available --timeout=600s
  kubectl get pods -n istio-system

  echo "[istio-ica-lab] Ensuring exam namespaces exist"
  for ns in "${EXAM_NAMESPACES[@]}"; do
    if ! kubectl get ns "$ns" >/dev/null 2>&1; then
      echo "[istio-ica-lab] Creating missing namespace: $ns"
      kubectl create ns "$ns"
    fi
  done
  echo "[istio-ica-lab] Node status summary"
  if node_status=$(kubectl get nodes --no-headers 2>/dev/null); then
    kubectl get nodes
    if printf "%s\n" "$node_status" | awk '$2 != "Ready" {exit 1}'; then
      echo "[istio-ica-lab] All nodes Ready."
    else
      degraded_nodes=$(printf "%s\n" "$node_status" | awk '$2 != "Ready" {print $1 ":" $2}')
      echo "[istio-ica-lab] WARNING: Some nodes are not Ready (degraded mode): $degraded_nodes"
      echo "[istio-ica-lab] Workloads will continue to schedule on controlplane due to the earlier taint removal."
    fi
  else
    echo "[istio-ica-lab] Unable to fetch node status; please manually run 'kubectl get nodes'."
  fi
  echo "[istio-ica-lab] Cluster verification complete. Start the tmux exam helper via: sudo /vagrant/scripts/exam-env.sh"
}

install_istioctl
install_istio_control_plane
distribute_kubeconfig
prepare_namespaces
install_gateway_api_crds
apply_lab_workloads
restart_default_ns_workloads
chmod_host_scripts
verify_lab_health

echo "[istio-ica-lab] Done. Log in with: vagrant ssh controlplane"
echo "[istio-ica-lab] Then run: /vagrant/tasks.sh, /vagrant/check-exam.sh, or /vagrant/scripts/exam-env.sh"
