resource "aws_kms_key" "eks" {
  description             = "EKS Secrets Encryption Key"
  deletion_window_in_days = 7       //Gives recovery window after deletion
  enable_key_rotation     = true    //KMS automatically rotates the key once per year
}

//behind the scenes
/*
1) kube secret created
2) api server sends secrets to KMS
3) KMS encrypts it
4) encrypted blob is stored in etcd
5) when pod reads secret KMS decrypts
*/

variable "cluster_name" {}
variable "vpc_id" {}
variable "private_subnets" {}



module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  # 🔐 Private API only
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # 🔐 Restrict API server access
  cluster_endpoint_public_access_cidrs = []

  # 🔐 Enable control plane logs
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # 🔐 Enable IRSA
  enable_irsa = true      //Allows pods to assume IAM roles ->You give permissions per service account

  # 🔐 Secrets encryption
  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]

  # Default security group hardening
  cluster_security_group_additional_rules = {
    ingress_nodes = {
      description                = "Allow nodes to talk to control plane"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  eks_managed_node_groups = {

    general = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 2
      max_size     = 5
      desired_size = 3

      subnet_ids = var.private_subnets

      labels = {
        role = "general"
      }

      taints = []

      update_config = {
        max_unavailable = 1
      }
    }

    spot_workers = {
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 5
      desired_size = 2

      subnet_ids = var.private_subnets

      labels = {
        role = "spot"
      }

      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

# example for vpc endpoint for STS
resource "aws_vpc_endpoint" "sts" {
  service_name = "com.amazonaws.ap-south-1.sts"
  vpc_id       = var.vpc_id
}

/*
without endpoint
pod -> node -> Nat Gateway ->public AWS STS endpoint
encrypted but goes through Nat
*/

/*
with endpoint
Pod → Private VPC Endpoint → STS
No NAT required & No public internet traversal
*/