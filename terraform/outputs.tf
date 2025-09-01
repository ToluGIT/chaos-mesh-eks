# Outputs for Chaos Engineering EKS Cluster

################################################################################
# Cluster Information
################################################################################

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = module.eks.cluster_status
}

output "cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = module.eks.cluster_version
}

################################################################################
# Connection Information
################################################################################

output "configure_kubectl" {
  description = "CLI command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}"
}

output "region" {
  description = "AWS region where the cluster is deployed"
  value       = local.region
}

################################################################################
# Node Group Information
################################################################################

output "node_groups" {
  description = "EKS managed node groups"
  value       = module.eks.eks_managed_node_groups
}

################################################################################
# Network Information
################################################################################

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

################################################################################
# OIDC Provider (for IRSA)
################################################################################

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

################################################################################
# Security
################################################################################

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

################################################################################
# Blog Post Helpers
################################################################################

output "next_steps" {
  description = "Next steps for chaos engineering setup"
  value = <<-EOT
    1. Configure kubectl: ${module.eks.cluster_name}
       aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}
    
    2. Verify cluster access:
       kubectl get nodes
    
    3. Check containerd socket path (important for Chaos Mesh):
       kubectl get nodes -o wide
    
    4. Ready for Chaos Mesh installation with containerd configuration!
  EOT
}