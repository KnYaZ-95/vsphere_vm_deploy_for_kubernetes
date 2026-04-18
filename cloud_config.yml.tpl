#cloud-config
users:
  - default
  - name: ${user}
    primary_group: ${user}
    passwd: ${password}
    shell: /bin/bash
    lock-passwd: true
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

bootcmd:
 - mkdir -p /etc/systemd/system/containerd.service.d /etc/apt/keyrings
%{ if type == "worker" ~}
 - mkdir -p /mnt/longhorn
%{ endif ~}

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter
    permissions: '0644'
  - path: /etc/sysctl.d/10-k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1
    permissions: '0644'
%{ if type == "cp" ~}
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
          timeout client          35s
          timeout server          35s
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
          option httpchk

          http-check connect ssl
          http-check send meth GET uri /healthz
          http-check expect status 200

          mode tcp
          balance     roundrobin
      %{~ for index, ip in cp_ips ~}
              server k8s-cp-${index + 1} ${ip}:6443 check verify none
      %{~ endfor ~}
    permissions: '0644'
    owner: root:root
  - path: /etc/keepalived/keepalived.conf
    content: |
      global_defs {
          router_id LVS_DEVEL
      }

      vrrp_script check_apiserver {
        script "/etc/keepalived/check_apiserver.sh"
        interval 3
        weight -2
        fall 10
        rise 2
      }

      vrrp_instance VI_1 {
          state BACKUP
          interface ${network_interface}
          virtual_router_id 51
          priority 100
          authentication {
              auth_type PASS
              auth_pass ${keepalived_auth_pass}
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

      curl -sfk --max-time 2 https://localhost:8888/healthz -o /dev/null || errorExit "Error GET https://localhost:8888/healthz"

    permissions: '0755'
    owner: root:root
%{ endif ~}
%{ if http_proxy != "" ~}
  - path: /etc/environment
    append: true
    content: |
      http_proxy=${http_proxy}
      https_proxy=${http_proxy}
      no_proxy="${no_proxy}"
      HTTP_PROXY=${http_proxy}
      HTTPS_PROXY=${http_proxy}
      NO_PROXY="{no_proxy}"
    permissions: '0644'
    owner: root:root  
  - path: /etc/systemd/system/containerd.service.d/http-proxy.conf
    content: |
      [Service]
      Environment="HTTP_PROXY=${http_proxy}
      Environment="HTTPS_PROXY=${http_proxy}"
      Environment="NO_PROXY={no_proxy}"
    permissions: '0644'
    owner: root:root

apt:
  proxy: "${http_proxy}"
  http_proxy: "${http_proxy}"
  https_proxy: "${http_proxy}"
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

%{ if type == "worker" ~}
disk_setup:
  /dev/sdb:
    table_type: gpt
    layout: true
    overwrite: false

fs_setup:
  - label: longhorn
    filesystem: ext4
    device: /dev/sdb
    partition: auto

mounts:
  - [ /dev/sdb, /mnt/longhorn, ext4, "defaults", "0", "2" ]
%{ endif ~}

runcmd:
  # preparing VM
  - swapoff -a
  - sed -i '/ swap / s/^/#/' /etc/fstab
  - modprobe overlay
  - modprobe br_netfilter
  - sysctl -f /etc/sysctl.d/10-k8s.conf
  # kubeadm, kubelet, kubectl, helm installation
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
%{ if type == "cp" ~}
  - mkdir /home/${user}/.kube
  - chown -R ${user}:${user} /home/${user}
  - curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  - echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
%{ endif ~}
  - echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
%{ if type == "cp" ~}
  - apt-get install -y kubelet kubeadm kubectl helm
%{ else ~}
  - apt-get install -y kubelet kubeadm kubectl
%{ endif ~}
  - apt-mark hold kubelet kubeadm kubectl
  - systemctl enable kubelet
  # containerd
  - mkdir /etc/containerd
  - containerd config default | sudo tee /etc/containerd/config.toml
  - sed -i 's|SystemdCgroup = false|SystemdCgroup = true|; s|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:${pause_image_version}"|' /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd
  - shutdown -r now