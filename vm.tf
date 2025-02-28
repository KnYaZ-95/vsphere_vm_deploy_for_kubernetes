data "vsphere_datacenter" "datacenter" {
  name = var.datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

# data "vsphere_resource_pool" "pool" {
#   name          = var.pool
#   datacenter_id = data.vsphere_datacenter.datacenter.id
# }

data "vsphere_network" "network" {
  name           = var.network
  datacenter_id  = data.vsphere_datacenter.datacenter.id
}

data "vsphere_content_library" "content_library" {
  name = var.content_library
}

data "vsphere_content_library_item" "template" {
  name       = var.template
  type       = "ovf"
  library_id = data.vsphere_content_library.content_library.id
}

# if pool exists uncomment pool data source and comment this resource
resource "vsphere_resource_pool" "pool" {
  name                    = var.pool
  parent_resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id

  cpu_share_level    = "normal"
  cpu_reservation    = 60
  cpu_limit          = -1
  cpu_expandable     = true
  cpu_shares         = 4000

  memory_share_level = "normal"
  memory_reservation = 102400
  memory_limit       = -1
  memory_expandable  = true
  memory_shares      = 163840
}  

resource "vsphere_virtual_machine" "vm" {
  for_each = var.vm_specs

  name                 = each.value.name
  datastore_id         = data.vsphere_datastore.datastore.id
  # resource_pool_id     = data.vsphere_resource_pool.pool.id
  resource_pool_id     = vsphere_resource_pool.pool.id
  num_cpus             = each.value.cpus
  memory               = each.value.memory
  firmware             = each.value.firmware

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label            = "disk0"
    size             = each.value.disk
    thin_provisioned = true
    eagerly_scrub    = false
  }

  # uncomment to destroy
  # cdrom {
  #   client_device = true
  # }

  clone {
    template_uuid = data.vsphere_content_library_item.template.id
  }

  lifecycle {
    ignore_changes = [
      clone[0].template_uuid,
    ]
  }

  extra_config = {
    "guestinfo.metadata"          = base64encode(templatefile("${path.module}/network_config.yml.tpl", {hostname = each.value.name, 
                                                                                                        ip_address = each.value.address, 
                                                                                                        gateway = each.value.gateway, 
                                                                                                        nameserver = each.value.nameserver
                                                                                                        }))
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode(templatefile("${path.module}/cloud_config.yml.tpl", {hostname = each.value.name, 
                                                                                                      user = each.value.login, 
                                                                                                      password = each.value.password, 
                                                                                                      authorized_key = each.value.ssh_public_key, 
                                                                                                      timezone = each.value.timezone, 
                                                                                                      fqdn = each.value.fqdn
                                                                                                      }))
    "guestinfo.userdata.encoding" = "base64"
  }
}