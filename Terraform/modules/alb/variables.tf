variable "project_name" {
  description = "Base name applied to ALB-related resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the ALB and target groups are created."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs used by the ALB."
  type        = list(string)
}

variable "target_groups_definition" {
  description = "List of target group configurations that should be created for the ALB."
  type = list(object({
    name_suffix = string
    port        = number
    protocol    = string
    target_type = string
    health_check = object({
      enabled             = bool
      path                = string
      port                = string
      protocol            = string
      matcher             = string
      interval            = number
      timeout             = number
      healthy_threshold   = number
      unhealthy_threshold = number
    })
  }))
  default = []
}

variable "default_listener_action" {
  description = "Definition of the default listener action for the ALB HTTP listener."
  type = object({
    type                = string
    target_group_suffix = optional(string)
    fixed_response = optional(object({
      content_type = string
      status_code  = string
      message_body = optional(string)
    }))
  })
}

variable "listener_rules_definition" {
  description = "List of listener rule configurations applied to the ALB HTTP listener."
  type = list(object({
    priority             = number
    target_group_suffix  = string
    conditions           = list(map(any))
  }))
  default = []
}
