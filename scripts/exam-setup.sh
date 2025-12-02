#!/usr/bin/env bash
set -euo pipefail

echo "[exam-setup] Preparing exam-ready environment"

export KUBECONFIG=/etc/kubernetes/admin.conf

ensure_namespace() {
  local ns="$1"
  if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
    kubectl create namespace "$ns"
  fi
}

label_namespace() {
  local ns="$1" key="$2" value="$3"
  kubectl label namespace "$ns" "${key}=${value}" --overwrite
}

deploy_http_service() {
  local namespace="$1" name="$2" port="$3"
  shift 3
  local versions=("$@")
  cat <<YAML | kubectl apply -f -
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
  - port: ${port}
    targetPort: ${port}
    name: http
---
YAML
  for version in "${versions[@]}"; do
    cat <<YAML | kubectl apply -f -
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
        - "-text=${name} ${version}"
        - "-listen=:${port}"
        ports:
        - containerPort: ${port}
YAML
  done
}

deploy_singleton_service() {
  local namespace="$1" name="$2" port="$3" text="$4"
  cat <<YAML | kubectl apply -f -
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
  - port: ${port}
    targetPort: ${port}
    name: http
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

deploy_httpbin() {
  cat <<'YAML' | kubectl apply -f -
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
        image: docker.io/kennethreitz/httpbin
        ports:
        - containerPort: 80
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
      serviceAccountName: default
      containers:
      - name: curl
        image: curlimages/curl
        command: ["/bin/sleep","infinity"]
YAML
}

main() {
  ensure_namespace default
  label_namespace default istio-injection enabled

  deploy_httpbin
  deploy_http_service default helloworld 5000 v1 v2
  cat <<'YAML' | kubectl apply -f -
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

  ensure_namespace payments
  label_namespace payments istio-injection enabled
  deploy_http_service payments payments 8080 v1 v2

  ensure_namespace swagger
  label_namespace swagger istio-injection enabled
  deploy_singleton_service swagger swagger-app 8080 "swagger namespace app"
}

main
echo "[exam-setup] Baseline workloads ready"
