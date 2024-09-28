provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-vpc-food"
  }
}

resource "aws_subnet" "public_subnet" {
  count = 2

  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = element(var.public_subnets_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "eks-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  count = 2

  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = element(var.private_subnets_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "eks-food-private-subnet-${count.index + 1}"
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = aws_subnet.private_subnet[*].id
  }

  depends_on = [aws_iam_role_policy_attachment.eks_policy]
}


data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-name"
    values = ["aurora-sg"]
  }
}


resource "aws_security_group_rule" "allow_aurora_access" {
  type             = "ingress"
  from_port        = 5432  # Porta padrão para PostgreSQL
  to_port          = 5432
  protocol         = "tcp"
  security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = data.aws_security_group.existing_sg.id

  description = "Allow access from aurora-sg to EKS cluster"
}

resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role-food"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node_role.arn

  subnet_ids = aws_subnet.private_subnet[*].id

  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_size
    min_size     = var.min_size
  }

  depends_on = [aws_eks_cluster.eks_cluster]
}

resource "aws_iam_role" "node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
