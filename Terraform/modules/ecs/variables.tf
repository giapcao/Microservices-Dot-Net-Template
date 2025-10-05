variable "project_name" {
  description = "Prefix for all ECS-related resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region (used for log driver options)"
  type        = string
}

variable "vpc_id" {
  description = "VPC where service-discovery namespaces will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC, used for SG ingress rules"
  type        = string
}

variable "task_subnet_ids" {
  description = "Subnets where ECS tasks (awsvpc ENIs) will be placed"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB to allow inbound traffic from"
  type        = string
}

variable "assign_public_ip" {
  description = "Assign public IPs to task ENIs (typically true in public subnets)"
  type        = bool
  default     = true
}

variable "ecs_cluster_id" {
  description = "Cluster ID, passed from the EC2 module"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Cluster name, passed from the EC2 module (needed for auto-scaling resource_id)"
  type        = string
}

variable "desired_count" {
  description = "Default number of tasks to keep running when not overridden per service."
  type        = number
  default     = 1
}

variable "enable_service_discovery" {
  description = "Globally enable/disable Cloud Map namespace creation. Individual services and containers may override this."
  type        = bool
  default     = false
}

variable "service_discovery_domain" {
  description = "Fully qualified name for the private DNS namespace used by service discovery"
  type        = string
}

variable "enable_auto_scaling" {
  description = "Create target-tracking scaling policies for the service when enabled globally or per-service."
  type        = bool
  default     = false
}

variable "service_discovery_containers" {
  description = "Optional Cloud Map registration config per ECS service"
  type = map(list(object({
    name = string
    port = number
  })))
  default = {}
}

variable "autoscaling_settings" {
  description = "Optional autoscaling configuration per ECS service"
  type = map(object({
    max_capacity        = number
    min_capacity        = number
    cpu_target_value    = number
    memory_target_value = number
  }))
  default = {}
}

variable "service_definitions" {
  description = "Map of ECS services to create. Keys are used as suffixes for resource names and Cloud Map services."
  type = map(object({
    task_cpu                           = optional(number)
    task_memory                        = optional(number)
    desired_count                      = optional(number)
    assign_public_ip                   = optional(bool)
    enable_service_discovery           = optional(bool)
    enable_auto_scaling                = optional(bool)
    max_capacity                       = optional(number)
    min_capacity                       = optional(number)
    cpu_target_value                   = optional(number)
    memory_target_value                = optional(number)
    deployment_maximum_percent         = optional(number)
    deployment_minimum_healthy_percent = optional(number)
    containers = list(object({
      name                 = string
      image_repository_url = string
      image_tag            = string
      cpu                  = number
      memory               = number
      essential            = optional(bool, true)
      command              = optional(list(string))
      port_mappings = optional(list(object({
        container_port = number
        host_port      = optional(number)
        protocol       = optional(string)
      })), [])
      environment_variables = optional(list(object({
        name  = string
        value = string
      })), [])
      health_check = optional(object({
        command     = list(string)
        interval    = optional(number, 30)
        timeout     = optional(number, 5)
        retries     = optional(number, 3)
        startPeriod = optional(number, 60)
      }))
      enable_service_discovery = optional(bool)
      service_discovery_port   = optional(number)
      depends_on               = optional(list(string))
    }))
    placement_constraints = optional(list(object({
      type       = string
      expression = optional(string)
    })), [])
    target_groups = optional(list(object({
      target_group_arn = string
      container_name   = string
      container_port   = number
    })), [])
  }))
  default = {}
}
variable "service_names" {
  description = "List of ECS service identifiers to create"
  type        = list(string)
}

variable "log_retention_days" {
  description = "Retention period for /ecs/<project> log group in CloudWatch."
  type        = number
  default     = 30
}

variable "max_capacity" {
  description = "Upper limit for auto-scaling (number of tasks)."
  type        = number
  default     = 4
}

variable "min_capacity" {
  description = "Lower limit for auto-scaling (number of tasks)."
  type        = number
  default     = 1
}

variable "cpu_target_value" {
  description = "Target CPU utilisation percentage for auto-scaling."
  type        = number
  default     = 50
}

variable "memory_target_value" {
  description = "Target memory utilisation percentage for auto-scaling."
  type        = number
  default     = 70
}




