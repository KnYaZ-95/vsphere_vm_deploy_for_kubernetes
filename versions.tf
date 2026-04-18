terraform {
  # backend "s3" {
  #   bucket         = "company-tf-state"
  #   key            = "vsphere/k8s/terraform.tfstate"
  #   region         = "some-region"
  #   encrypt        = true
  #   dynamodb_table = "tf-state-lock" 
  # }
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "= 2.12.0"
    }
  }
  required_version = ">= 1.10.0"
}