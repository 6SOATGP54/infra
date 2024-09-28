provider "aws" {
  region = local.region
}

locals {
  name   = "food-cluster"
  region = "us-east-1"

  vpc_cidr = "172.31.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["subnet-056aa0bda01905c8f", "subnet-073805c092643f2f3"]
  private_subnets = ["subnet-056f9754ec5f40f32", "subnet-0a8a347d1a8d57ff9"]
  intra_subnets   = ["subnet-05f43d62fa98a1a89", "subnet-041f0830fe1737b2e"]

  tags = {

  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.1"

  cluster_name                   = local.name
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets


 cluster_security_group_additional_rules = [{
    description                     = "Allow access to DB"
    from_port                        = 5432
    to_port                          = 5432
    protocol                         = "tcp"
    cidr_blocks                      = ["0.0.0.0/0"]
    security_group_id                = aws_security_group.aurora_sg.id
    source_cluster_security_group    = false
  }]


  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t2.micro"]

    attach_cluster_primary_security_group = true
  }

  eks_managed_node_groups = {
    ascode-cluster-wg = {
      min_size     = 1
      max_size     = 9
      desired_size = 1

      instance_types = ["t2.micro"]
      capacity_type  = "ON_DEMAND"

      tags = {
        
      }
    }
  }

  tags = local.tags
}