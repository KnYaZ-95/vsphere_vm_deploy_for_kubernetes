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
- curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
- echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
- echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
- apt-get update
- apt-get install -y kubelet kubeadm kubectl helm
- apt-mark hold kubelet kubeadm kubectl
- systemctl enable kubelet
# containerd
- mkdir -p /etc/containerd
- containerd config default | sudo tee /etc/containerd/config.toml
- sed -i 's|SystemdCgroup = false|SystemdCgroup = true|; s|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml
- systemctl restart containerd
- systemctl enable containerd
- shutdown -r now

write_files:
  - path: /home/${user}/readme
    content: |
      This is property of DevOps engineer
    owner: ${user}:${user}
    permissions: '0644'