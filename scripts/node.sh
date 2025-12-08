#!/bin/bash
#
# Setup for Node servers

set -euxo pipefail

config_path="/vagrant/configs"
join_script="${config_path}/join.sh"

if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "[node] kubeadm join already completed on $(hostname -s); skipping re-join."
  exit 0
fi

wait_seconds=0
max_wait=600
until [ -s "$join_script" ] || [ "$wait_seconds" -ge "$max_wait" ]; do
  echo "[node] Waiting for kubeadm join script at ${join_script}..."
  sleep 5
  wait_seconds=$((wait_seconds + 5))
done

if [ ! -s "$join_script" ]; then
  echo "[node] Join script missing after ${max_wait}s; aborting worker bootstrap."
  exit 1
fi

attempt=1
max_attempts=5
while true; do
  if /bin/bash "$join_script" -v; then
    break
  fi
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "[node] kubeadm join failed after ${max_attempts} attempts; aborting."
    exit 1
  fi
  echo "[node] kubeadm join attempt ${attempt} failed; retrying in 15s..."
  attempt=$((attempt + 1))
  sleep 15
done

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker
EOF
