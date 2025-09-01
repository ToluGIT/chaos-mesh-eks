# Chaos Engineering EKS Cluster - Modern Configuration
# Based on the chaos-mesh-eks-guide.md requirements


provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["--region", local.region, "eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  name   = "chaos-engineering-lab"  # Following the guide's naming
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Environment = "chaos-lab"
    Purpose     = "safely-breaking-things"  # Following the guide's labels
    Project     = "chaos-engineering"
    ManagedBy   = "Terraform"
  }
}

# Security variable for IP access control
variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks that can access the cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Change this to your IP for production!
  sensitive   = true
}

################################################################################
# VPC Configuration
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = true  # Cost optimization for demo
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.tags
}

################################################################################
# EKS Cluster - Modern Configuration for Chaos Engineering
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"  

  cluster_name    = local.name
  cluster_version = "1.31" # Current stable as per guide

  # Network configuration
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Endpoint access
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # Enable cluster creator admin permissions (required for initial access)
  enable_cluster_creator_admin_permissions = true

  # Access entries for additional users/roles
  access_entries = {
    cluster_creator = {
      principal_arn = data.aws_caller_identity.current.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Essential add-ons for modern EKS (per guide recommendations)
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
    aws-ebs-csi-driver = { 
      most_recent = true 
    }
  }

  # EKS Managed Node Group - Optimized for Chaos Engineering
  eks_managed_node_groups = {
    chaos_workers = {
      min_size     = 2
      max_size     = 4
      desired_size = 3

      instance_types = ["t3.medium"]  # As per guide recommendation
      capacity_type  = "SPOT"         # Save money with spot instances

      # Amazon Linux 2023 with containerd - CRITICAL for Chaos Mesh
      ami_type = "AL2023_x86_64_STANDARD"

      labels = {
        Environment = "chaos-lab"
        Purpose     = "safely-breaking-things"
        NodeGroup   = "chaos-workers"
      }

      # Additional policies for chaos engineering tools
      iam_role_additional_policies = {
        additional = aws_iam_policy.chaos_additional.arn
      }
    }
  }

  # Enable IRSA for service accounts
  enable_irsa = true

  tags = local.tags
}

################################################################################
# Additional IAM Policy for Chaos Engineering
################################################################################

resource "aws_iam_policy" "chaos_additional" {
  name        = "${local.name}-chaos-additional"
  description = "Additional IAM policy for chaos engineering cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

################################################################################
# Security Group for Additional Access
################################################################################

resource "aws_security_group" "additional" {
  name_prefix = "${local.name}-additional"
  vpc_id      = module.vpc.vpc_id
  description = "Additional security group for chaos engineering cluster"

  ingress {
    description = "SSH access from private subnets"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-additional" })
}

