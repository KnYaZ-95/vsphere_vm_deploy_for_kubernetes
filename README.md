# vSphere VM Deploy for Kubernetes

[![Validate](https://github.com/KnYaZ-95/vsphere_vm_deploy_for_kubernetes/actions/workflows/terraform.yaml/badge.svg)](https://github.com/KnYaZ-95/vsphere_vm_deploy_for_kubernetes/actions/workflows/terraform.yaml)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.10-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![vSphere](https://img.shields.io/badge/VMware_vSphere-7.0%2B-607078?logo=vmware&logoColor=white)](https://www.vmware.com/products/vsphere.html)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-ready-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Terraform module for automated virtual machine provisioning for a Kubernetes cluster on VMware vSphere. Supports multi-datacenter topology, HA control-plane via keepalived + HAProxy, and full node configuration through cloud-init.

## Architecture

```
vSphere
├── Datacenter A
│   ├── Cluster / Resource Pool
│   ├── Datastore
│   └── Network
└── Datacenter B (optional)
    └── ...

Kubernetes
├── Control-plane nodes (keepalived VIP + HAProxy :8888)
│   └── kube-apiserver ← load-balanced through VIP
└── Worker nodes
    └── /mnt/longhorn (extra disk, optional)
```

## Features

- **Multi-datacenter** — resources are described via `environment_mapping`
- **HA Control-plane** — keepalived VRRP + HAProxy round-robin on all CP nodes
- **Cloud-init** — full automation: users, SSH keys, networking, Kubernetes packages
- **Longhorn-ready** — worker nodes automatically mount a second disk at `/mnt/longhorn`
- **Proxy support** — optional HTTP proxy for corporate environments
- **Flexible disks** — thin/thick provisioning, eagerly scrub per disk

## Requirements

| Tool | Version |
|---|---|
| Terraform | >= 1.10.0 |
| vSphere Provider | 2.12.0 |
| vCenter | 7.0+ |
| Ubuntu OVF template | 24.04 (cloud-init) |

The Ubuntu template must be uploaded to a vSphere Content Library as OVF.

## Quick Start

```bash
git clone https://github.com/KnYaZ-95/vsphere_vm_deploy_for_kubernetes
cd vsphere_vm_deploy_for_kubernetes

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars

terraform init
terraform plan
terraform apply
```

## Configuration

### `environment_mapping` structure

```hcl
environment_mapping = {
  "MyDatacenter" = {
    cluster_name   = { main = "MyCluster" }
    datastore_name = { main = "datastore1" }
    pool           = { main = "k8s-pool" }
    network        = { main = "VM Network" }
  }
}
```

### `vm_specs` structure

```hcl
vm_specs = {
  "cp-01" = {
    type              = "cp"                     # "cp" or "worker"
    datacenter        = "MyDatacenter"
    cluster           = "MyCluster"
    datastore         = "datastore1"
    pool              = "k8s-pool"
    network           = "VM Network"
    name              = "k8s-cp-01"
    cpus              = 4
    memory            = 8192
    firmware          = "efi"
    address           = "192.168.1.10/24"
    gateway           = "192.168.1.1"
    nameserver        = "192.168.1.1"
    network_interface = "ens192"
    ssh_public_key    = "ssh-ed25519 AAAA..."
    login             = "admin"
    password          = "$6$rounds=..."          # SHA-512 hash
    timezone          = "Europe/Moscow"
    fqdn              = "k8s-cp-01.example.com"
    disks = [
      { size = 50, thin_provisioned = true, eagerly_scrub = false }
    ]
  }

  "worker-01" = {
    type = "worker"
    # ...
    disks = [
      { size = 50, thin_provisioned = true, eagerly_scrub = false },
      { size = 100, thin_provisioned = true, eagerly_scrub = false }  # Longhorn
    ]
  }
}
```

### Variables reference

| Variable | Required | Description |
|---|---|---|
| `vsphere_user` | yes | vCenter login |
| `vsphere_password` | yes | vCenter password (sensitive) |
| `vsphere_server` | yes | vCenter FQDN or IP |
| `hardware_version` | yes | VM hardware version (see [KB2007240](https://kb.vmware.com/s/article/2007240)) |
| `environment_mapping` | yes | Datacenter and resource mapping |
| `vm_specs` | yes | Virtual machine specifications |
| `virtual_ip` | yes | VIP for keepalived (HA endpoint) |
| `content_library` | yes | vSphere Content Library name |
| `template` | yes | Ubuntu OVF template name |
| `keepalived_auth_pass` | yes | VRRP password (min 6 characters) |
| `k8s_version` | no | Kubernetes version (default: `1.35`) |
| `pause_image_version` | no | Pause image version (default: `3.10.1`) |
| `http_proxy` | no | HTTP proxy URL (default: `""`) |
| `no_proxy` | no | No-proxy exclusions |

### Remote state with S3

The `versions.tf` contains a commented-out S3 backend. To enable it:

```hcl
backend "s3" {
  bucket = "my-terraform-state"
  key    = "vsphere-k8s/terraform.tfstate"
  region = "us-east-1"
}
```

## After `terraform apply`

All nodes will be ready for cluster initialization. On the first control-plane node:

```bash
kubeadm init \
  --control-plane-endpoint "<VIP>:8888" \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16
```

Remaining CP nodes and workers join via `kubeadm join`.

## Destroy

```bash
terraform destroy -auto-approve
```

## Security

- Sensitive variables (`vsphere_password`, `keepalived_auth_pass`) are not written to logs
- User passwords are stored as SHA-512 hashes
- CI validates configuration with tfsec
- SSL verification is enabled by default (`allow_unverified_ssl = false`)

## CI/CD

GitHub Actions runs on every Pull Request and on push to `main`:

| Step | Tool |
|---|---|
| Formatting | `terraform fmt -check` |
| Validation | `terraform validate` |
| Linting | TFLint |
| Security | TFSec |

## Outputs

After apply, a VM summary is printed:

```
Virtual Machines Summary:
  ✓ cp-01          | IP: 192.168.1.10
  ✓ cp-02          | IP: 192.168.1.11
  ✓ worker-01      | IP: 192.168.1.20
Total created: 3
```

## License

MIT
