
# ----------- variables -----------

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}


variable "kubernetes_namespace" {
  description = "Kubernetes namespace to deploy resources"
  type        = string
  default     = "web-app"
}


variable "key_pair_name" {
  default     = "eks-key"
  description = "EC2 key pair name"
}


variable "key_pair_bucket_name" {
  default     = "eks-key-bucket-143"  # must be globally unique
  description = "S3 bucket to store EC2 private key"
}

# variable "instanc_type" {
#   description = "Instance type"
#   default     = ["t4g.small"]
# }
# variable "ami_type" {
#   description = "ami type which is of arch arm64"
#   default     = ["AL2_ARM_64"]
# }
#  ----------------- Data -------------------

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}


data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}



# Note: Based on Helm conventions, the service created will be named:
# release-name + -ingress-nginx-controller, so in our case: external-ingress-nginx-controller.

data "kubernetes_service" "nginx_lb" {
  metadata {
    name      = "external-ingress-nginx-controller"
    namespace = var.kubernetes_namespace
  }

  depends_on = [helm_release.external_nginx]
}




# --------- Locals ----------------

locals {
  cluster_name = "chan-eks-${random_string.suffix.result}"
    # Ensure the generated bucket name is globally unique and adheres to S3 naming rules
  key_pair_s3_name = "${var.key_pair_bucket_name}-${random_string.suffix.result}"
  keypair_name = "${var.key_pair_name}-${random_string.suffix.result}"
}



# ----------- Resource ----------

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
