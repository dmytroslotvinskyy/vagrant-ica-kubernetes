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

# Wait for the API server endpoint referenced in the join script to be reachable
# before attempting kubeadm join. This avoids early failures when the control
# plane is still starting up.
api_host=$(awk '{print $3}' "$join_script" | cut -d: -f1)
api_port=$(awk '{print $3}' "$join_script" | cut -d: -f2)
api_waited=0
api_max_wait=900
api_poll=10
echo "[node] Waiting for API server ${api_host}:${api_port} to become reachable..."
while ! timeout 5 bash -c "echo >/dev/tcp/${api_host}/${api_port}" >/dev/null 2>&1; do
  if [ "$api_waited" -ge "$api_max_wait" ]; then
    echo "[node] API server not reachable after ${api_max_wait}s; aborting worker bootstrap."
    exit 1
  fi
  sleep "$api_poll"
  api_waited=$((api_waited + api_poll))
done
echo "[node] API server is reachable; proceeding with kubeadm join."

attempt=1
max_attempts=20
retry_sleep=20
while true; do
  if /bin/bash "$join_script" -v; then
    break
  fi
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "[node] kubeadm join failed after ${max_attempts} attempts; aborting."
    exit 1
  fi
  echo "[node] kubeadm join attempt ${attempt} failed; retrying in ${retry_sleep}s..."
  attempt=$((attempt + 1))
  sleep "$retry_sleep"
done

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i "$config_path/config" /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node "$NODENAME" node-role.kubernetes.io/worker=worker
echo "[node] kubeadm join succeeded on attempt ${attempt}"
kubectl get nodes -o wide | sed 's/^/[node] /'
EOF
