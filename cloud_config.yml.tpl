#cloud-config
users:
  - default
  - name: ${user}
    primary_group: ${user}
    passwd: ${password}
    shell: /bin/bash
    lock-passwd: false
    ssh_pwauth: True
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo, ${user}
    ssh_authorized_keys:
      - ${authorized_key}
  - name: ansible
    groups: users,admin,wheel
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
     - ${authorized_key}

%{ if type == "cp" ~}
write_files:
  - path: /etc/haproxy/haproxy.cfg
    content: |
      #---------------------------------------------------------------------
      # Global settings
      #---------------------------------------------------------------------
      global
          log /dev/log local0 info alert
          log /dev/log local1 notice alert
          daemon

      #---------------------------------------------------------------------
      # common defaults that all the 'listen' and 'backend' sections will
      # use if not designated in their block
      #---------------------------------------------------------------------
      defaults
          mode                    http
          log                     global
          option                  httplog
          option                  dontlognull
          option http-server-close
          option forwardfor       except 127.0.0.0/8
          option                  redispatch
          retries                 1
          timeout http-request    10s
          timeout queue           20s
          timeout connect         5s
          timeout client          20s
          timeout server          20s
          timeout http-keep-alive 10s
          timeout check           10s

      #---------------------------------------------------------------------
      # apiserver frontend which proxys to the control plane nodes
      #---------------------------------------------------------------------
      frontend apiserver
          bind *:8888
          mode tcp
          option tcplog
          default_backend apiserver

      #---------------------------------------------------------------------
      # round robin balancing for apiserver
      #---------------------------------------------------------------------
      backend apiserver
          option httpchk GET /healthz
          http-check expect status 200
          mode tcp
          option ssl-hello-chk
          balance     roundrobin
      %{~ for index, ip in cp_ips ~}
              server node${index + 1} ${ip}:6443 check
      %{~ endfor ~}
    permissions: '0644'
    owner: root:root
  - path: /etc/keepalived/keepalived.conf
    content: |
      global_defs {
          enable_script_security
          script_user nobody
      }

      vrrp_script check_apiserver {
        script "/etc/keepalived/check_apiserver.sh"
        interval 3
      }

      vrrp_instance VI_1 {
          state BACKUP
          interface ens192
          virtual_router_id 5
          priority 100
          advert_int 1
          nopreempt
          authentication {
              auth_type PASS
              auth_pass ZqSj#f1G
          }
          virtual_ipaddress {
              ${vip}
          }
          track_script {
              check_apiserver
          }
      }
    permissions: '0644'
    owner: root:root
  - path: /etc/keepalived/check_apiserver.sh
    content: |
      #!/bin/sh

      errorExit() {
          echo "*** $*" 1>&2
          exit 1
      }

      curl --silent --max-time 2 --insecure http://localhost:8888/ -o /dev/null || errorExit "Error GET http://localhost:8888/"
      if ip addr | grep -q ${vip}; then
          curl --silent --max-time 2 --insecure http://${vip}:8888/ -o /dev/null || errorExit "Error GET http:/${vip}:8888/"
      fi
    permissions: '0755'
    owner: root:root
%{ endif ~}

package_update: true
package_upgrade: true
packages:
  - curl
  - wget
  - gpg
  - iptables
  - apt-transport-https
  - ca-certificates
  - containerd
%{ if type == "cp" ~}
  - haproxy
  - keepalived
  - jq
%{ endif ~}

timezone: ${timezone}
hostname: ${hostname}
fqdn: ${fqdn}

runcmd:
# preparing VM
- mkdir /home/${user}/.kube
- chown -R ${user}:${user} /home/${user}
- swapoff -a
- sed -i '/ swap / s/^/#/' /etc/fstab
- echo "net.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1" > /etc/sysctl.d/10-k8s.conf
- echo "overlay\nbr_netfilter\n" > /etc/modules-load.d/k8s.conf
- modprobe overlay
- modprobe br_netfilter
- sysctl -f /etc/sysctl.d/10-k8s.conf
# kubeadm, kubelet, kubectl, helm installation
- curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
%{ if type == "cp" ~}
- curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
- echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
%{ endif ~}
- echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
- apt-get update
%{ if type == "cp" ~}
- apt-get install -y kubelet kubeadm kubectl helm
%{ else ~}
- apt-get install -y kubelet kubeadm kubectl
%{ endif ~}
- apt-mark hold kubelet kubeadm kubectl
- systemctl enable kubelet
# containerd
- mkdir -p /etc/containerd
- containerd config default | sudo tee /etc/containerd/config.toml
- sed -i 's|SystemdCgroup = false|SystemdCgroup = true|; s|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml
- systemctl restart containerd
- systemctl enable containerd
- shutdown -r now