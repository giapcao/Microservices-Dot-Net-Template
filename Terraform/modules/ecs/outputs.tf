output "ecs_service_names" {
  description = "Map of ECS service logical names to AWS ECS service names"
  value       = { for name, svc in aws_ecs_service.this : name => svc.name }
}

output "ecs_service_arns" {
  description = "Map of ECS service logical names to ECS service ARNs"
  value       = { for name, svc in aws_ecs_service.this : name => svc.id }
}

output "task_definition_arns" {
  description = "Map of ECS service logical names to task definition ARNs"
  value       = { for name, td in aws_ecs_task_definition.this : name => td.arn }
}

output "task_definition_families" {
  description = "Map of ECS service logical names to task definition families"
  value       = { for name, td in aws_ecs_task_definition.this : name => td.family }
}

output "task_definition_revisions" {
  description = "Map of ECS service logical names to task definition revisions"
  value       = { for name, td in aws_ecs_task_definition.this : name => td.revision }
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_logs.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the IAM role assumed by the tasks"
  value       = aws_iam_role.ecs_task_role.arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the IAM role used for ECS task execution"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "service_discovery_namespace_id" {
  description = "ID of the Cloud Map private DNS namespace (if created)"
  value       = length(aws_service_discovery_private_dns_namespace.dns_ns) > 0 ? aws_service_discovery_private_dns_namespace.dns_ns[0].id : null
}

output "service_discovery_service_arns" {
  description = "Map of ECS service logical names to their Cloud Map service ARNs"
  value       = { for name, svc in aws_service_discovery_service.discovery_services : name => svc.arn }
}
