output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.ecoligo_cluster.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.ecoligo_cluster.arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.ecoligo_cluster.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.ecoligo_cluster.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the cluster"
  value       = aws_security_group.eks_cluster_sg.id
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.ecoligo_nodes.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.ecoligo_vpc.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private_subnets[*].id
}
