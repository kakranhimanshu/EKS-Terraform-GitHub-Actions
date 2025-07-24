data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc-cidr-block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc-name
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = var.igw-name
  }
}

# PUBLIC SUBNETS
resource "aws_subnet" "public" {
  count                   = var.pub-subnet-count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.pub-cidr-block[count.index]
  availability_zone       = var.pub-availability-zone[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.pub-sub-name}-${count.index + 1}"
  }
}

# PRIVATE SUBNETS
resource "aws_subnet" "private" {
  count             = var.pri-subnet-count
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.pri-cidr-block[count.index]
  availability_zone = var.pri-availability-zone[count.index]
  tags = {
    Name = "${var.pri-sub-name}-${count.index + 1}"
  }
}

resource "aws_eip" "ngw" {
  domain = "vpc"
  tags = {
    Name = var.eip-name
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.ngw.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = var.ngw-name
  }
}

# ROUTE TABLES
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = var.public-rt-name
  }
}

resource "aws_route_table_association" "public" {
  count          = var.pub-subnet-count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = var.private-rt-name
  }
}

resource "aws_route_table_association" "private" {
  count          = var.pri-subnet-count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

# SECURITY GROUP
resource "aws_security_group" "eks" {
  name        = var.eks-sg
  description = "EKS Cluster security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.eks-sg
  }
}

# EKS CLUSTER
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster-name
  cluster_version = var.cluster-version
  cluster_endpoint_private_access = var.endpoint-private-access
  cluster_endpoint_public_access  = var.endpoint-public-access

  vpc_id     = aws_vpc.this.id
  subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)

  eks_managed_node_groups = {
    on_demand = {
      instance_types = var.ondemand_instance_types
      min_size       = var.min_capacity_on_demand
      max_size       = var.max_capacity_on_demand
      desired_size   = var.desired_capacity_on_demand
    }
    spot = {
      instance_types = var.spot_instance_types
      capacity_type  = "SPOT"
      min_size       = var.min_capacity_spot
      max_size       = var.max_capacity_spot
      desired_size   = var.desired_capacity_spot
    }
  }

  tags = {
    Environment = var.env
  }

  manage_aws_auth = true
  enable_irsa     = true
  create_cloudwatch_log_group = true

  cluster_addons = var.addons
}
