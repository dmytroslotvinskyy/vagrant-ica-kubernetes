#!/bin/bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODENAME=$(hostname -s)
ADMIN_KUBECONFIG=/etc/kubernetes/admin.conf

cluster_initialized=false
if [ -f "$ADMIN_KUBECONFIG" ]; then
  if kubectl --kubeconfig="$ADMIN_KUBECONFIG" get node "$NODENAME" >/dev/null 2>&1; then
    cluster_initialized=true
    echo "[master] kubeadm already initialized on ${NODENAME}; skipping control-plane bootstrap."
  fi
fi

if [ "$cluster_initialized" = false ]; then
  sudo kubeadm config images pull

  echo "Preflight Check Passed: Downloaded All Required Images"

  sudo kubeadm init --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors Swap

  mkdir -p "$HOME"/.kube
  sudo cp -i $ADMIN_KUBECONFIG "$HOME"/.kube/config
  sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

  # Install Calico Network Plugin
  curl https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml -O
  kubectl apply -f calico.yaml

  sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

  # Install Metrics Server
  kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml
else
  echo "[master] Skipping kubeadm init/Calico/metrics install; cluster already configured."
fi

# Save Configs to shared /Vagrant location

# For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.

config_path="/vagrant/configs"

if [ -d "$config_path" ]; then
  rm -f "$config_path"/*
else
  mkdir -p "$config_path"
fi

cp -i /etc/kubernetes/admin.conf "$config_path/config"
touch "$config_path/join.sh"
chmod +x "$config_path/join.sh"

kubeadm token create --print-join-command > "$config_path/join.sh"

# Install Bun runtime for TUI (optional but recommended)
if [ -f /vagrant/scripts/install-bun.sh ]; then
  echo "[master] Installing Bun runtime for exam TUI..."
  bash /vagrant/scripts/install-bun.sh
fi

