## Removed CloudFront outputs



# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = module.vpc.private_subnet_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# EC2 Outputs
output "ec2_instance_ids" {
  description = "Map of ECS container instance IDs keyed by group name"
  value       = module.ec2.instance_ids
}

output "ec2_public_ips" {
  description = "Map of public IP addresses for ECS container instances"
  value       = module.ec2.instance_public_ips
}

output "ec2_private_ips" {
  description = "Map of private IP addresses for ECS container instances"
  value       = module.ec2.instance_private_ips
}

output "ec2_public_dns" {
  description = "Map of public DNS names for ECS container instances"
  value       = module.ec2.instance_public_dns
}

output "ec2_elastic_ips" {
  description = "Map of Elastic IPs attached to ECS container instances"
  value       = module.ec2.elastic_ips
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ec2.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ec2.ecs_cluster_arn
}

output "ec2_private_key_pem" {
  description = "Private key for EC2 instance."
  value       = module.ec2.ec2_private_key_pem
  sensitive   = true
}

## Optional ECS outputs commented out (kept minimal)
