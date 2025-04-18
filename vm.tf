data "vsphere_datacenter" "datacenters" {
  for_each = var.environment_mapping
  name = each.key
}


data "vsphere_datastore" "datastores" {
  for_each = {for datastore in local.datastores: datastore.datastore_name => datastore}
  name          = each.value.datastore_name
  datacenter_id = data.vsphere_datacenter.datacenters[each.value.datacenter_name].id
}


data "vsphere_compute_cluster" "clusters" {
  for_each = {for cluster in local.clusters: cluster.cluster_name => cluster}
  name          = each.value.cluster_name
  datacenter_id = data.vsphere_datacenter.datacenters[each.value.datacenter_name].id
}


data "vsphere_network" "networks" {
  for_each = {for network in local.networks: network.network_name => network}
  name           = each.value.network_name
  datacenter_id  = data.vsphere_datacenter.datacenters[each.value.datacenter_name].id
}


data "vsphere_content_library" "content_library" {
  name = var.content_library
}

data "vsphere_content_library_item" "template" {
  name       = var.template
  type       = "ovf"
  library_id = data.vsphere_content_library.content_library.id
}


resource "vsphere_resource_pool" "pools" {
  for_each = {for pool in local.pools: "${pool.cluster}_${pool.pool}" => pool}
  name                    = each.value.pool
  parent_resource_pool_id = data.vsphere_compute_cluster.clusters[each.value.cluster].resource_pool_id

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


resource "vsphere_virtual_machine" "vms" {
  for_each = var.vm_specs

  name                 = each.value.name
  datastore_id         = data.vsphere_datastore.datastores[each.value.datastore].id
  resource_pool_id     = vsphere_resource_pool.pools["${each.value.cluster}_${each.value.pool}"].id
  num_cpus             = each.value.cpus
  memory               = each.value.memory
  firmware             = each.value.firmware

  network_interface {
    network_id = data.vsphere_network.networks[each.value.network].id
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
    ignore_changes = [clone[0].template_uuid]
  }

  extra_config = {
    "guestinfo.metadata"          = base64encode(templatefile("${path.module}/network_config.yml.tpl", {hostname = each.value.name, 
                                                                                                        ip_address = each.value.address, 
                                                                                                        gateway = each.value.gateway, 
                                                                                                        nameserver = each.value.nameserver
                                                                                                        }
                                                              )
                                                )
    "guestinfo.userdata"          = base64encode(templatefile("${path.module}/cloud_config.yml.tpl", {type = each.value.type,
                                                                                                      cp_ips = var.cp_addresses,
                                                                                                      vip = var.virtual_ip,
                                                                                                      hostname = each.value.name, 
                                                                                                      user = each.value.login, 
                                                                                                      password = each.value.password, 
                                                                                                      authorized_key = each.value.ssh_public_key, 
                                                                                                      timezone = each.value.timezone, 
                                                                                                      fqdn = each.value.fqdn
                                                                                                      }
                                                              )
                                                )
    "guestinfo.userdata.encoding" = "base64"
    "guestinfo.metadata.encoding" = "base64"
  }
}


output "CreatedVMs" {
  value = <<-EOT
    Virtual Machines Summary:
    ${join("\n", [
      for name, vm in vsphere_virtual_machine.vms : 
      format("  ✓ %-15s | IP: %-15s", name, vm.default_ip_address)
    ])}
    Total created: ${length(vsphere_virtual_machine.vms)}
  EOT
}