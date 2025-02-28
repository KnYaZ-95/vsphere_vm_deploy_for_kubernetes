#=========== vcenter access ===========#
variable "vsphere_user" {
  description = "vcenter_user"
  type        = string
  sensitive   = false
}

variable "vsphere_password" {
  description = "vcenter_password"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "vcenter_server"
  type        = string
  sensitive   = false
}

#=========== Environment ===========#
variable "datacenter" {
  description = "vcenter_datacenter"
  type        = string
  sensitive   = false
}

variable "datastore" {
  description = "vcenter_datastore"
  type        = string
  sensitive   = false
}

variable "cluster" {
  description = "vcenter_cluster"
  type        = string
  sensitive   = false
}

variable "pool" {
  description = "vcenter_pool"
  type        = string
  sensitive   = false
}

variable "network" {
  description = "vcenter_pool"
  type        = string
  sensitive   = false
}

variable "content_library" {
  description = "vcenter_content_library"
  type        = string
  sensitive   = false
}

variable "template" {
  description = "deploying_template"
  type        = string
  sensitive   = false
}

#=========== VM Settings ===========#
variable "vm_specs" {
  type = map(object({
      name = string,
      cpus = number,
      memory = number,
      firmware = string,
      disk = number,
      address = string,
      gateway = string,
      nameserver = string,
      ssh_public_key = string,
      login = string,
      password = string,
      fqdn = string,
      timezone = string
    }))
}