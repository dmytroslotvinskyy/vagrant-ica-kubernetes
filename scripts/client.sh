#!/usr/bin/env bash
set -euo pipefail

if [ -z "${KUBERNETES_VERSION:-}" ]; then
  if [ -f /vagrant/settings.yaml ]; then
    KUBERNETES_VERSION="$(awk -F': ' '/^[[:space:]]*kubernetes:/ {print $2; exit}' /vagrant/settings.yaml | tr -d '\r')"
  else
    KUBERNETES_VERSION="1.31.0-1.1"
  fi
fi
if [ -z "${KUBERNETES_VERSION_SHORT:-}" ]; then
  KUBERNETES_VERSION_SHORT="${KUBERNETES_VERSION:0:4}"
fi

echo "[client] Preparing lightweight kubectl workstation (${KUBERNETES_VERSION})"

sudo rm -f /etc/apt/sources.list.d/kubernetes-client.list
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg jq bash-completion

if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION_SHORT}/deb/Release.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION_SHORT}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes-client.list

sudo apt-get update -y
sudo apt-get install -y kubectl="${KUBERNETES_VERSION}"

setup_kubeconfig_for_user() {
  local user="$1"
  local home_dir
  home_dir="$(eval echo "~${user}")"
  local kube_dir="${home_dir}/.kube"

  if [ ! -d "$kube_dir" ]; then
    sudo -u "$user" mkdir -p "$kube_dir"
  fi

  if [ -f /vagrant/configs/config ]; then
    sudo cp /vagrant/configs/config "${kube_dir}/config"
    sudo chown "${user}:${user}" "${kube_dir}/config"
    sudo chmod 600 "${kube_dir}/config"
  fi
}

setup_kubeconfig_for_user vagrant
if id student >/dev/null 2>&1; then
  setup_kubeconfig_for_user student
fi

cat <<'EOF' | sudo tee /etc/profile.d/kubectl-cli.sh >/dev/null
if command -v kubectl >/dev/null 2>&1; then
  source <(kubectl completion bash)
fi
EOF

echo "[client] Kubectl workstation ready. Use 'kubectl get nodes' to verify connectivity."
