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
    echo "[istio-ica-lab] Istio control plane already installed"
    return
  fi

  echo "[istio-ica-lab] Installing Istio control plane (demo profile)"
  istioctl install --set profile=demo -y
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
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
YAML
}

apply_gateways() {
  cat <<'YAML' | kubectl apply -f -
---
apiVersion: networking.istio.io/v1beta1
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
apiVersion: networking.istio.io/v1beta1
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
apiVersion: networking.istio.io/v1beta1
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

apply_lab_workloads() {
  echo "[istio-ica-lab] Applying sample workloads for ICA tasks"

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
  for f in /vagrant/tasks.sh /vagrant/check-ica.sh; do
    if [ -f "$f" ]; then
      chmod +x "$f" || true
    fi
  done
}

install_istioctl
install_istio_control_plane
prepare_namespaces
apply_lab_workloads
chmod_host_scripts

echo "[istio-ica-lab] Done. Log in with: vagrant ssh controlplane"
echo "[istio-ica-lab] Then run: /vagrant/tasks.sh  and  /vagrant/check-ica.sh"
