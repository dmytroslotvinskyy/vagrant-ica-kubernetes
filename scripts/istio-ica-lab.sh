#!/usr/bin/env bash
set -euo pipefail

echo "[istio-ica-lab] Starting Istio + lab provisioning"

# Use admin kubeconfig
export KUBECONFIG=/etc/kubernetes/admin.conf

ISTIO_VERSION="1.26.3"
ISTIO_DIR="/opt/istio-${ISTIO_VERSION}"

install_istioctl() {
  if command -v istioctl >/dev/null 2>&1; then
    echo "[istio-ica-lab] istioctl already installed"
    return
  fi

  echo "[istio-ica-lab] Downloading Istio ${ISTIO_VERSION}"
  cd /tmp
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION="${ISTIO_VERSION}" sh -
  mv "istio-${ISTIO_VERSION}" "${ISTIO_DIR}"
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
  echo "[istio-ica-lab] Labeling namespaces for sidecar injection"

  kubectl label namespace default istio-injection=enabled --overwrite
  if ! kubectl get ns payments >/dev/null 2>&1; then
    kubectl create namespace payments
  fi
  kubectl label namespace payments istio-injection=enabled --overwrite
}

apply_lab_workloads() {
  echo "[istio-ica-lab] Applying sample helloworld + payments workloads"
  cat << 'YAML' | kubectl apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: payments
  labels:
    istio-injection: "enabled"
---
apiVersion: v1
kind: Service
metadata:
  name: helloworld
  namespace: default
  labels:
    app: helloworld
spec:
  selector:
    app: helloworld
  ports:
  - name: http
    port: 5000
    targetPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-v1
  namespace: default
  labels:
    app: helloworld
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: helloworld
      version: v1
  template:
    metadata:
      labels:
        app: helloworld
        version: v1
    spec:
      containers:
      - name: helloworld
        image: hashicorp/http-echo
        args:
        - "-text=Hello from helloworld v1"
        - "-listen=:5000"
        ports:
        - containerPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-v2
  namespace: default
  labels:
    app: helloworld
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: helloworld
      version: v2
  template:
    metadata:
      labels:
        app: helloworld
        version: v2
    spec:
      containers:
      - name: helloworld
        image: hashicorp/http-echo
        args:
        - "-text=Hello from helloworld v2"
        - "-listen=:5000"
        ports:
        - containerPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: curl
  namespace: default
  labels:
    app: curl
spec:
  replicas: 1
  selector:
    matchLabels:
      app: curl
  template:
    metadata:
      labels:
        app: curl
    spec:
      containers:
      - name: curl
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
---
apiVersion: v1
kind: Service
metadata:
  name: payments
  namespace: payments
  labels:
    app: payments
spec:
  selector:
    app: payments
  ports:
  - name: http
    port: 8080
    targetPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-v1
  namespace: payments
  labels:
    app: payments
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments
      version: v1
  template:
    metadata:
      labels:
        app: payments
        version: v1
    spec:
      containers:
      - name: payments
        image: hashicorp/http-echo
        args:
        - "-text=Hello from payments v1"
        - "-listen=:5000"
        ports:
        - containerPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-v2
  namespace: payments
  labels:
    app: payments
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments
      version: v2
  template:
    metadata:
      labels:
        app: payments
        version: v2
    spec:
      containers:
      - name: payments
        image: hashicorp/http-echo
        args:
        - "-text=Hello from payments v2"
        - "-listen=:5000"
        ports:
        - containerPort: 5000
YAML
}

chmod_host_scripts() {
  # /vagrant is the synced folder with the repo on the host
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
