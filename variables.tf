#=========== Vcenter access ===========#
variable "vsphere_user" {
  description = "vcenter user"
  type        = string
  sensitive   = false
}

variable "vsphere_password" {
  description = "vcenter password"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "vcenter server"
  type        = string
  sensitive   = false
}

#=========== Environment ===========#
variable "environment_mapping" {
  description = "environment"
  type        = map(object({
                  cluster_name = map(string)
                  datastore_name = map(string)
                  pool = map(string)
                  network = map(string)
                }))
  sensitive   = false
}

variable "cp_addresses" {
  description = "list of control plane addresses"
  type        = list(string)
  sensitive   = false
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
variable "vm_specs" {
  type = map(object({
        type = string
        datacenter = string,
        cluster = string,
        datastore = string,
        pool = string,
        network = string,
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