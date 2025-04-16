# Provisioning virtual machines via terraform for deploying a kubernetes cluster in Vmware vSphere

In this repository you can find a ready-to-use terraform template for deploying virtual machines in Vmware vSphere based on the cloud-init image of Ubuntu Server

All you need is:
1. Create content library in VSphere and upload Ubuntu cloud-init image to it
2. Install provider
3. Change variables
4. Run the script
5. Customize your kubernetes installation on hosts that you created

## 🚀 Technologies

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Cloud-Init](https://img.shields.io/badge/Cloud--Init-00AEEF?style=for-the-badge&logo=cloud-init&logoColor=white)

## ⚡️ How to deploy:
1. Install Terraform
2. Clone the repo and go to the directory:
```bash
git clone https://github.com/KnYaZ-95/vsphere_vm_deploy_for_kubernetes.git && cd vsphere_vm_deploy_for_kubernetes
```
3. Create your own file `terraform.tfvars`. Refer to [terraform.tfvars.example](./terraform.tfvars.example) file. The number of pools must be equal to the number of networks, otherwise the script will not work. Also you have to set the IP addresses of the control nodes and determine which address will be common for them (this is necessary for keepalived and haproxy)
4. Check [cloud.config.yml.tpl](./cloud.config.yml.tpl). It designed for keepalived and haproxy installation
4. Make sure the сd-rom in the [vm.tf](./vm.tf) is commented out
```HCL
# cdrom {
#   client_device = true
# }
``` 
6. Apply the manifests
```bash
terraform apply -auto-approve  
```
7. Initialize cluster using `kubeadm`. Check virtual ip that you assigned
```bash
kubeadm init \
               --pod-network-cidr=10.244.0.0/16 \
               --control-plane-endpoint "<your-vip>:8888" \
               --upload-certs  
```
8. Join control plane and worker nodes

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
