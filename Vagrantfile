
require "yaml"
vagrant_root = File.dirname(File.expand_path(__FILE__))
settings = YAML.load_file "#{vagrant_root}/settings.yaml"
MIN_MEMORY_MB = 2048

IP_SECTIONS = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/)
# First 3 octets including the trailing dot:
IP_NW = IP_SECTIONS.captures[0]
# Last octet excluding all dots:
IP_START = Integer(IP_SECTIONS.captures[1])
NUM_WORKER_NODES = settings["nodes"]["workers"]["count"]

Vagrant.configure("2") do |config|
  config.vm.provision "shell", env: { "IP_NW" => IP_NW, "IP_START" => IP_START, "NUM_WORKER_NODES" => NUM_WORKER_NODES }, inline: <<-SHELL
      apt-get update -y
      echo "$IP_NW$((IP_START)) controlplane" >> /etc/hosts
      for i in `seq 1 ${NUM_WORKER_NODES}`; do
        echo "$IP_NW$((IP_START+i)) node0${i}" >> /etc/hosts
      done
  SHELL

  if `uname -m`.strip == "aarch64"
    config.vm.box = settings["software"]["box"] + "-arm64"
  else
    config.vm.box = settings["software"]["box"]
  end
  config.vm.box_check_update = true

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
    controlplane.vm.provision "shell", run: "always", path: "scripts/istio-ica-lab.sh"
    if settings["exam_mode"]
      controlplane.vm.provision "shell", run: "always", path: "scripts/exam-setup.sh"
    end
    controlplane.vm.provision "shell", run: "always", inline: <<-SHELL
      echo "[exam-env] Preparing tmux helper session (requires tmux inside the VM)"
      if command -v tmux >/dev/null 2>&1; then
        sudo /vagrant/scripts/exam-env.sh >/var/log/exam-env.log 2>&1 || true
        echo "[exam-env] Tmux helper ready. Attach with: tmux attach -t exam"
      else
        echo "[exam-env] tmux not installed; install with 'sudo apt install tmux' then run /vagrant/scripts/exam-env.sh"
      fi
    SHELL
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
    end

  end
end 
