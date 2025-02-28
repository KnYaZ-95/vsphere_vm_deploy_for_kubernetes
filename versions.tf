terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.10.0"
    }
  }
  required_version = ">= 1.10.0"
}