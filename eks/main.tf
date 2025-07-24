provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name                 = "${var.env}-vpc"
  cidr                 = var.vpc_cidr_block
  azs                  = var.availability_zones
  public_subnets       = var.public_subnet_cidrs
  private_subnets      = var.private_subnet_cidrs
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.env
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5" # latest compatible version

  cluster_name    = var.cluster_name
  cluster_version = var.eks_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  subnet_ids     = module.vpc.private_subnets
  vpc_id         = module.vpc.vpc_id

  eks_managed_node_groups = {
    default = {
      desired_size = var.desired_capacity
      min_size     = var.min_size
      max_size     = var.max_size

      instance_types = var.instance_types
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = var.env
  }
}
