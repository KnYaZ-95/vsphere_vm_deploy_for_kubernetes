#=========== Vcenter access ===========#
variable "vsphere_user" {
  description = "vCenter user"
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "vCenter password"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "vCenter server"
  type        = string
  sensitive   = false
}

variable "hardware_version" {
  description = "vSphere compatibility version (https://kb.vmware.com/s/article/2007240)"
  type        = number
  sensitive   = false
}

variable "allow_unverified_ssl" {
  description = "disable vCenter TLS-certificate verification"
  type        = bool
  default     = false
}

variable "vsphere_api_timeout" {
  description = "API vCenter timeout (minutes)"
  type        = number
  default     = 10
}

variable "keepalived_auth_pass" {
  description = "VRRP password for keepalived"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.keepalived_auth_pass) >= 6
    error_message = "keepalived auth_pass should be longer than 6 symbols"
  }
}

#=========== Environment ===========#
variable "environment_mapping" {
  description = "environment"
  type = map(object({
    cluster_name   = map(string)
    datastore_name = map(string)
    pool           = map(string)
    network        = map(string)
  }))
  sensitive = false
}

variable "virtual_ip" {
  description = "ip for keepalived"
  type        = string
  sensitive   = false
}

variable "content_library" {
  description = "vcenter content library"
  type        = string
  sensitive   = false
}

variable "template" {
  description = "deploying template"
  type        = string
  sensitive   = false
}

#=========== VM Settings ===========#
variable "http_proxy" {
  description = "HTTP proxy (empty string - without proxy)"
  type        = string
  default     = ""
}

variable "no_proxy" {
  description = "No proxy"
  type        = string
  default     = "localhost,127.0.0.1,.svc,.svc.cluster.local,.cluster.local,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12"
}

variable "vm_specs" {
  description = <<-EOT
    VM description.
    Map key — identificator for VM (cp_1, worker_1, ...).
    type — "cp" (control-plane) or "worker".
    firmware — "efi" or "bios".
  EOT
  type = map(object({
    type       = string
    datacenter = string
    cluster    = string
    datastore  = string
    pool       = string
    network    = string
    name       = string
    cpus       = number
    memory     = number
    firmware   = string
    disks = list(object({
      size             = number
      eagerly_scrub    = bool
      thin_provisioned = bool
    }))
    network_interface = optional(string, "ens192")
    address           = string
    gateway           = string
    nameserver        = string
    ssh_public_key    = string
    login             = string
    password          = string
    fqdn              = string
    timezone          = string
  }))
  validation {
    condition     = alltrue([for k, v in var.vm_specs : contains(["cp", "worker"], v.type)])
    error_message = "vm_specs[*].type should be 'cp' or 'worker'."
  }
  validation {
    condition     = alltrue([for k, v in var.vm_specs : contains(["efi", "bios"], v.firmware)])
    error_message = "vm_specs[*].firmware should be 'efi' or 'bios'."
  }
  validation {
    condition     = alltrue([for k, v in var.vm_specs : v.cpus >= 2 && v.memory >= 2048])
    error_message = "k8s-node need 2 CPU and 2048 MB RAM at least (kubeadm requirement)."
  }
  validation {
    condition     = alltrue([for k, v in var.vm_specs : can(cidrnetmask(split("/", v.address)[0] == "" ? "0.0.0.0/0" : v.address))])
    error_message = "address should be in CIDR-format (for example, 192.168.0.3/24)."
  }
  validation {
    condition     = length([for k, v in var.vm_specs : v.name]) == length(toset([for k, v in var.vm_specs : v.name]))
    error_message = "VM (name) should be unique."
  }
}

#=========== K8s parameters ===========#
variable "k8s_version" {
  description = "k8s major.minor (for example, 1.35)"
  type        = string
  default     = "1.35"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.k8s_version))
    error_message = "Format: major.minor, for example 1.35"
  }
}

variable "pause_image_version" {
  description = "Pause-image version of containerd"
  type        = string
  default     = "3.10.1"
}
