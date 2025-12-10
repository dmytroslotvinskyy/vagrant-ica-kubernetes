
require "yaml"
vagrant_root = File.dirname(File.expand_path(__FILE__))
settings = YAML.load_file "#{vagrant_root}/settings.yaml"
MIN_MEMORY_MB = 2048
EXAM_MODE = settings["exam_mode"] != false
puts "[VAGRANT] exam_mode=#{EXAM_MODE ? 'true' : 'false'}"

IP_SECTIONS = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/)
# First 3 octets including the trailing dot:
IP_NW = IP_SECTIONS.captures[0]
# Last octet excluding all dots:
IP_START = Integer(IP_SECTIONS.captures[1])
NUM_WORKER_NODES = settings["nodes"]["workers"]["count"]
WORKER_VM_NAMES = (1..NUM_WORKER_NODES).map { |i| "node0#{i}" }
CLIENT_SETTINGS = settings.dig("nodes", "client") || {}
CLIENT_ENABLED = !!CLIENT_SETTINGS["enabled"]
CLIENT_VM_NAME = CLIENT_SETTINGS["name"] || "node02"
CLIENT_VM_IP = settings.dig("network", "client_ip") || (IP_NW + "#{IP_START + NUM_WORKER_NODES + 1}")
AUTO_START_TARGETS = WORKER_VM_NAMES.dup
AUTO_START_TARGETS << CLIENT_VM_NAME if CLIENT_ENABLED

Vagrant.configure("2") do |config|
  client_enabled_env = CLIENT_ENABLED ? "1" : "0"
  config.vm.provision "shell", env: { "IP_NW" => IP_NW, "IP_START" => IP_START, "NUM_WORKER_NODES" => NUM_WORKER_NODES, "CLIENT_ENABLED" => client_enabled_env, "CLIENT_VM_IP" => CLIENT_VM_IP, "CLIENT_VM_NAME" => CLIENT_VM_NAME }, inline: <<-SHELL
      apt-get update -y
      grep -q "$IP_NW$((IP_START)) controlplane" /etc/hosts || echo "$IP_NW$((IP_START)) controlplane" >> /etc/hosts
      for i in `seq 1 ${NUM_WORKER_NODES}`; do
        host_line="$IP_NW$((IP_START+i)) node0${i}"
        grep -q "$host_line" /etc/hosts || echo "$host_line" >> /etc/hosts
      done
      if [ "$CLIENT_ENABLED" = "1" ] && [ -n "$CLIENT_VM_IP" ] && [ -n "$CLIENT_VM_NAME" ]; then
        host_line="$CLIENT_VM_IP $CLIENT_VM_NAME"
        grep -q "$host_line" /etc/hosts || echo "$host_line" >> /etc/hosts
      fi
  SHELL

  if `uname -m`.strip == "aarch64"
    config.vm.box = settings["software"]["box"] + "-arm64"
  else
    config.vm.box = settings["software"]["box"]
  end
  config.vm.box_check_update = true
  # Allow slower hosts to finish booting before SSH times out.
  config.vm.boot_timeout = 600

  config.vm.define "controlplane" do |controlplane|
    controlplane.vm.hostname = "controlplane"
    controlplane.vm.network "private_network", ip: settings["network"]["control_ip"]
    if settings["shared_folders"]
      settings["shared_folders"].each do |shared_folder|
        controlplane.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
      end
    end
    controlplane.vm.provider "virtualbox" do |vb|
        vb.cpus = settings["nodes"]["control"]["cpu"]
        requested_memory = settings["nodes"]["control"]["memory"].to_i
        if requested_memory < MIN_MEMORY_MB
          warn "Requested control-plane memory #{requested_memory}MB is below the supported minimum of #{MIN_MEMORY_MB}MB. Using #{MIN_MEMORY_MB}MB instead."
          requested_memory = MIN_MEMORY_MB
        end
        vb.memory = requested_memory
        if settings["cluster_name"] and settings["cluster_name"] != ""
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
        end
    end
    if AUTO_START_TARGETS.any?
      # Only trigger on reload/provision, not :up, to avoid conflicts with "vagrant up" (no args)
      # which brings up all VMs. The trigger is useful for "vagrant reload controlplane" scenarios.
      [:reload, :provision].each do |action|
        controlplane.trigger.after action do |trigger|
          trigger.name = "auto-start-workers"
          trigger.info = "[controlplane] Auto-starting lab nodes after controlplane #{action}: #{AUTO_START_TARGETS.join(', ')}"
          trigger.run = {
            env: { "VAGRANT_CWD" => vagrant_root },
            inline: "vagrant up #{AUTO_START_TARGETS.join(' ')}"
          }
        end
      end
    end
    controlplane.vm.provision "shell",
      env: {
        "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
        "ENVIRONMENT" => settings["environment"],
        "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
        "KUBERNETES_VERSION_SHORT" => settings["software"]["kubernetes"][0..3],
        "OS" => settings["software"]["os"]
      },
      path: "scripts/common.sh"
    controlplane.vm.provision "shell",
      env: {
        "CALICO_VERSION" => settings["software"]["calico"],
        "CONTROL_IP" => settings["network"]["control_ip"],
        "POD_CIDR" => settings["network"]["pod_cidr"],
        "SERVICE_CIDR" => settings["network"]["service_cidr"]
      },
      path: "scripts/master.sh"
    # Note: exam-setup.sh removed; all workloads now deployed by istio-ica-lab.sh
    # after Istio is installed so pods get sidecars automatically.
    if EXAM_MODE
      controlplane.vm.provision "shell", run: "always", inline: <<-SHELL
        echo "[exam-env] exam_mode=true → ICA lab enabled."
        echo "           To start the exam UI: sudo /vagrant/scripts/exam-tui-bun.sh"
        echo "           Legacy: /vagrant/scripts/exam-env.sh (bash viewer)"
      SHELL
    else
      controlplane.vm.provision "shell", run: "always", inline: <<-SHELL
        echo "[exam-env] exam_mode=false → Skipping Istio/ICA lab payload."
      SHELL
    end
    controlplane.vm.provision "shell",
      env: {
        "SSH_USER" => "student",
        "SSH_BANNER_MESSAGE" => "Authorized access only. Student lab node."
      },
      path: "scripts/ssh-setup.sh"
    controlplane.vm.provision "shell",
      env: {
        "SSH_USER" => "vagrant",
        "SSH_BANNER_MESSAGE" => "Authorized access only. Student lab node."
      },
      path: "scripts/ssh-setup.sh"
  end

  (1..NUM_WORKER_NODES).each do |i|

    config.vm.define "node0#{i}" do |node|
      node.vm.hostname = "node0#{i}"
      node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}"
      if settings["shared_folders"]
        settings["shared_folders"].each do |shared_folder|
          node.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
        end
      end
      node.vm.provider "virtualbox" do |vb|
          vb.cpus = settings["nodes"]["workers"]["cpu"]
          requested_memory = settings["nodes"]["workers"]["memory"].to_i
          if requested_memory < MIN_MEMORY_MB
            warn "Requested worker memory #{requested_memory}MB is below the supported minimum of #{MIN_MEMORY_MB}MB. Using #{MIN_MEMORY_MB}MB instead."
            requested_memory = MIN_MEMORY_MB
          end
          vb.memory = requested_memory
          if settings["cluster_name"] and settings["cluster_name"] != ""
            vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
          end
      end
      node.vm.provision "shell",
        env: {
          "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
          "ENVIRONMENT" => settings["environment"],
          "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
          "KUBERNETES_VERSION_SHORT" => settings["software"]["kubernetes"][0..3],
          "OS" => settings["software"]["os"]
        },
        path: "scripts/common.sh"
      node.vm.provision "shell", path: "scripts/node.sh"
      node.vm.provision "shell",
        env: {
          "SSH_USER" => "student",
          "SSH_BANNER_MESSAGE" => "Authorized access only. Student lab node."
        },
        path: "scripts/ssh-setup.sh"
      node.vm.provision "shell",
        env: {
          "SSH_USER" => "vagrant",
          "SSH_BANNER_MESSAGE" => "Authorized access only. Student lab node."
        },
        path: "scripts/ssh-setup.sh"

      # Only install the dashboard after provisioning the last worker (and when enabled).
      if i == NUM_WORKER_NODES and settings["software"]["dashboard"] and settings["software"]["dashboard"] != ""
        node.vm.provision "shell", path: "scripts/dashboard.sh"
      end

      # Run Istio + exam lab provisioning only after the last worker finishes so
      # Kubernetes is up and nodes are joined before installing the lab payload.
      if i == NUM_WORKER_NODES && EXAM_MODE
        node.trigger.after :provision do |trigger|
          trigger.name = "istio-after-workers"
          trigger.info = "[istio-ica-lab] Installing Istio after workers are ready"
          trigger.run = {
            env: { "VAGRANT_CWD" => vagrant_root },
            inline: "vagrant ssh controlplane -c 'sudo bash /vagrant/scripts/lab-up.sh'"
          }
        end
      end
    end

  end

  if CLIENT_ENABLED
    client_cpu = CLIENT_SETTINGS["cpu"] || 1
    client_memory = CLIENT_SETTINGS["memory"] || MIN_MEMORY_MB
    config.vm.define CLIENT_VM_NAME do |client|
      client.vm.hostname = CLIENT_VM_NAME
      client.vm.network "private_network", ip: CLIENT_VM_IP
      if settings["shared_folders"]
        settings["shared_folders"].each do |shared_folder|
          client.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
        end
      end
      client.vm.provider "virtualbox" do |vb|
        vb.cpus = client_cpu
        requested_memory = client_memory.to_i
        if requested_memory < MIN_MEMORY_MB
          warn "Requested client memory #{requested_memory}MB is below the supported minimum of #{MIN_MEMORY_MB}MB. Using #{MIN_MEMORY_MB}MB instead."
          requested_memory = MIN_MEMORY_MB
        end
        vb.memory = requested_memory
        if settings["cluster_name"] and settings["cluster_name"] != ""
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
        end
      end
      client.vm.provision "shell",
        env: {
          "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
          "KUBERNETES_VERSION_SHORT" => settings["software"]["kubernetes"][0..3]
        },
        path: "scripts/client.sh"
      client.vm.provision "shell",
        env: {
          "SSH_USER" => "student",
          "SSH_BANNER_MESSAGE" => "Authorized access only. Student lab node."
        },
        path: "scripts/ssh-setup.sh"
      client.vm.provision "shell",
        env: {
          "SSH_USER" => "vagrant",
          "SSH_BANNER_MESSAGE" => "Authorized access only. Student lab node."
        },
        path: "scripts/ssh-setup.sh"
    end
  end
end 
