terraform {
  required_version = ">= 1.0.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4.1"
    }
  }
}

# provider "kubernetes" {
#   config_path = "/home/ec2-user/.kube/config"
# }
#
# provider "helm" {
#   kubernetes {
#     config_path = "/home/ec2-user/.kube/config"
#   }
# }