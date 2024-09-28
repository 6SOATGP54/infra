provider "aws" {
  region = "us-east-1"
}

locals {
  name   = "food-cluster"

  vpc_cidr = "172.16.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["172.16.64.0/20", "172.16.144.0/20"]
  private_subnets = ["172.16.48.0/20", "172.16.0.0/20"]
  intra_subnets   = ["172.16.80.0/20", "172.16.32.0/20"]

  tags = {
    Name        = local.name
    Environment = "production"  # Defina o ambiente de forma adequada
  }
}

data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-name"
    values = ["aurora-sg"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name             = local.name
  cidr             = local.vpc_cidr
  azs              = local.azs
  private_subnets  = local.private_subnets
  public_subnets   = local.public_subnets
  intra_subnets    = local.intra_subnets

  enable_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  # Ative o mapeamento de IPs públicos nas sub-redes públicas
  map_public_ip_on_launch = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 9.15.1"  # Considere atualizar para uma versão mais recente

  cluster_name                   = local.name
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni = { most_recent = true }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  cluster_security_group_additional_rules = {
    "allow_db_access" = {
      type                            = "ingress"
      description                     = "Allow access to DB"
      from_port                        = 5432
      to_port                          = 5432
      protocol                         = "tcp"
      cidr_blocks                      = ["172.16.0.0/16"]  # Restringir o acesso
      security_group_id                = [data.aws_security_group.existing_sg.id]
      source_cluster_security_group    = false
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t2.medium"]  # Ajuste o tipo de instância conforme necessidade
    attach_cluster_primary_security_group = true
  }

  eks_managed_node_groups = {
    ascode-cluster-wg = {
      min_size     = 1
      max_size     = 9
      desired_size = 3  # Ajuste conforme necessário
      instance_types = ["t2.medium"]  # Instâncias ajustadas para carga de trabalho
      capacity_type  = "ON_DEMAND"
      tags = local.tags
    }
  }

  tags = local.tags
}

# Saídas para informações úteis
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_id
}
