provider "aws" {
  region = local.region
}

locals {
  name   = "food-cluster"
  region = "us-east-1"

  vpc_cidr = "172.31.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["172.31.64.0/20", "172.31.144.0/20"]
  private_subnets = ["172.31.48.0/20", "172.31.0.0/20"]
  intra_subnets   = ["172.31.80.0/20", "172.31.32.0/20"]

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

resource "aws_security_group" "aurora_sg" {
  name = "aurora-sg"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
    security_group_id                = [aws_security_group.aurora_sg.id]
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