# Terraform template for provisioning virtual machines for deploying a kubernetes cluster in Vmware vSphere 

In this repository you can find a ready-to-use terraform template for deploying virtual machines in Vmware vSphere based on the cloud-init image of Ubuntu Server

All you need is:
1. Create library content in VSphere and upload Ubuntu image to it
2. Install provider
3. Change variables
4. Run script

## 🚀 Technologies

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)

## ⚡️ How to deploy:
1. Install Terraform
2. Clone the repo and go to the directory:
```bash
git clone https://github.com/KnYaZ-95/vsphere_vm_deploy_for_kubernetes.git && cd vsphere_vm_deploy_for_kubernetes
```
3. Create your own file terraform.tfvars. Refer to [terraform.tfvars.example](./terraform.tfvars.example) file
4. Note that a pool is created in the [vm.tf](./vm.tf) file. You can use your own pool by commenting out the lines with the creation
```HCL
# this resource

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
```
```HCL
# this string in resource "vsphere_virtual_machine" "vm"

resource_pool_id     = vsphere_resource_pool.pool.id
```   
and uncommenting the lines with the use of the existing pool
```HCL
# this data resource

data "vsphere_resource_pool" "pool" {
  name          = var.pool
  datacenter_id = data.vsphere_datacenter.datacenter.id
}
``` 
```HCL
# this string in resource "vsphere_virtual_machine" "vm"

resource_pool_id     = data.vsphere_resource_pool.pool.id
```
5. Make sure the сd-rom in the [vm.tf](./vm.tf) is commented out
```HCL
# cdrom {
#   client_device = true
# }
``` 
6. Apply
```bash
terraform apply -auto-approve  
```
## 💥 How to destroy:
1. Make sure the сd-rom in the [vm.tf](./vm.tf) is uncommented
```HCL
cdrom {
  client_device = true
}
```
2. Destroy
```bash
terraform destroy -auto-approve  
```
