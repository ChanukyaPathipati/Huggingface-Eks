

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "chaneks-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  map_public_ip_on_launch = true  # ✅ This enables auto-assign public IPs on public subnets

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true


  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type = "AL2_ARM_64"
    key_name = local.keypair_name  

    iam_role_additional_policies = {
      AmazonEKSWorkerNodePolicy             = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      AmazonEC2ContainerRegistryReadOnly   = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      AmazonEKS_CNI_Policy                 = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      CloudWatchAgentServerPolicy          = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      SSMManagedInstanceCore    = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }


  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t4g.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "node-group-2"

      instance_types = ["t4g.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
  depends_on = [ aws_key_pair.this ]
}


# this resource is used to update your kubeconfig file in your local environment, 
# which is required to interact with your Amazon EKS cluster via kubectl.

resource "null_resource" "update_kubeconfig" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
  }
} 


# ----------------- Ec2 Key-Pair creation ---------------------------
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = local.keypair_name
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# ------------------ creating S3 bucket and uploading the keypair in s3 -----------

resource "aws_s3_bucket" "key_bucket" {
  bucket        = local.key_pair_s3_name
  force_destroy = true
}

resource "aws_s3_object" "private_key_upload" {
  bucket = aws_s3_bucket.key_bucket.bucket
  key    = "${local.keypair_name}.pem"
  content = tls_private_key.ec2_key.private_key_pem
  content_type = "text/plain"

  depends_on = [ aws_s3_bucket.key_bucket , aws_key_pair.this]
}



# --------- Creating Nginx controller with NLB & deploying staticweb using Helm -------------------



resource "helm_release" "external_nginx" {
  name       = "external"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = var.kubernetes_namespace
  version    = "4.10.1"

  create_namespace = true

  values = [
    file("${path.module}/my-webapp/nginx-nlb-values.yaml"),
    <<EOF
controller:
  admissionWebhooks:
    enabled: false
EOF
  ]

  depends_on = [ null_resource.update_kubeconfig , module.eks  ]
}



resource "helm_release" "webapp" {
  name       = "webapp"
  chart      = "./my-webapp"
  namespace  = var.kubernetes_namespace
  create_namespace = true 
  
  set {
    name  = "ingress.className"
    value = "external-nginx"
  }
  force_update = true  # <--- Add this line
  recreate_pods = true # <--- Optional: force pod restart if templates changed
  
  depends_on = [ null_resource.update_kubeconfig, module.eks ]
}


# ------------ Monitoring ------------

resource "helm_release" "monitoring" {
  name       = "kube-prom-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "56.7.0"

  create_namespace = true

  values = [
    file("${path.module}/monitoring/prometheus-values.yaml")
  ]

  depends_on = [null_resource.update_kubeconfig, module.eks]
}
