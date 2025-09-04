## Removed CloudFront/Wasabi related variables

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# VPC Variables
variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "projectname"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.3.0/24"
}

# EC2 Variables
variable "instance_type" {
  description = "EC2 instance type (free tier eligible: t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "associate_public_ip" {
  description = "Whether to associate an Elastic IP with the EC2 instance"
  type        = bool
  default     = true
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# ECS Global Variables
variable "enable_auto_scaling" {
  description = "Enable auto scaling for the ECS service"
  type        = bool
  default     = false
}

variable "enable_service_discovery" {
  description = "Enable service discovery for ECS services"
  type        = bool
  default     = true
}

# Service Definitions Variable
variable "services" {
  description = "Configuration for each microservice"
  type = map(object({
    # ALB Target Group attributes
    alb_target_group_port     = number
    alb_target_group_protocol = string
    alb_target_group_type     = string
    alb_health_check = object({
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

    # ALB Listener Rule attributes
    alb_listener_rule_priority   = number
    alb_listener_rule_conditions = list(object({
      path_pattern = optional(object({
        values = list(string)
      }))
      # Add other condition types here if needed (e.g., host_header)
    }))

    # ECS Container attributes
    ecs_container_name_suffix          = string # e.g. "microservice" to form "project-key-suffix"
    ecs_container_image_repository_url = string
    ecs_container_image_tag            = string
    ecs_container_cpu                  = number
    ecs_container_memory               = number
    ecs_container_essential            = bool
    ecs_container_port_mappings = list(object({
      container_port = number
      host_port      = number
      protocol       = string
    }))
    ecs_environment_variables = list(object({
      name  = string
      value = string
    }))
    ecs_container_health_check = object({
      command     = list(string)
      interval    = number
      timeout     = number
      retries     = number
      startPeriod = number
    })
    ecs_service_discovery_port = number # Port for service discovery registration
  }))
  default = {
    "guest" = {
      alb_target_group_port     = 5001
      alb_target_group_protocol = "HTTP"
      alb_target_group_type     = "ip"
      alb_health_check = {
        enabled             = true
        path                = "/api/guest/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
      alb_listener_rule_priority = 10
      alb_listener_rule_conditions = [
        {
          path_pattern = {
            values = ["/api/guest/*"]
          }
        }
      ]
      ecs_container_name_suffix          = "microservice"
      ecs_container_image_repository_url = "897279497116.dkr.ecr.us-east-1.amazonaws.com/vkev-infrastructure-khanghv2406-ecr"
      ecs_container_image_tag            = "Guest.Microservice-latest"
      ecs_container_cpu                  = 200
      ecs_container_memory               = 200
      ecs_container_essential            = true
      ecs_container_port_mappings = [
        {
          container_port = 5001
          host_port      = 0
          protocol       = "tcp"
        }
      ]
      ecs_environment_variables = [
        { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
        { name = "DATABASE_HOST", value = "pg-1-database25811.g.aivencloud.com" },
        { name = "DATABASE_PORT", value = "16026" },
        { name = "DATABASE_NAME", value = "defaultdb" },
        { name = "DATABASE_USERNAME", value = "avnadmin" },
        { name = "DATABASE_PASSWORD", value = "AVNS_iGi4kJJObNRnGdM6BTb" },
        { name = "ASPNETCORE_URLS", value = "http://0.0.0.0:5001" },
        { name = "RABBITMQ_HOST", value = "rabbit-mq.projectname.local" },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_USERNAME", value = "rabbitmq" },
        { name = "RABBITMQ_PASSWORD", value = "0Kg04Rq08!" },
        { name = "REDIS_HOST", value = "redis.projectname.local" },
        { name = "REDIS_PASSWORD", value = "0Kg04Rs05!" },
        { name = "REDIS_PORT", value = "6379" },
        { name = "USER_MICROSERVICE_HOST", value = "user-microservice.projectname.local" },
        { name = "USER_MICROSERVICE_PORT", value = "5002" }
      ]
      ecs_container_health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5001/api/guest/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 0
      }
      ecs_service_discovery_port = 5001
    },
    "user" = {
      alb_target_group_port     = 5002
      alb_target_group_protocol = "HTTP"
      alb_target_group_type     = "ip"
      alb_health_check = {
        enabled             = true
        path                = "/api/user/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
      alb_listener_rule_priority = 11
      alb_listener_rule_conditions = [
        {
          path_pattern = {
            values = ["/api/user/*"]
          }
        }
      ]
      ecs_container_name_suffix          = "microservice"
      ecs_container_image_repository_url = "897279497116.dkr.ecr.us-east-1.amazonaws.com/vkev-infrastructure-khanghv2406-ecr"
      ecs_container_image_tag            = "User.Microservice-latest"
      ecs_container_cpu                  = 200
      ecs_container_memory               = 200
      ecs_container_essential            = true
      ecs_container_port_mappings = [
        {
          container_port = 5002
          host_port      = 0
          protocol       = "tcp"
        }
      ]
      ecs_environment_variables = [
        { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
        { name = "DATABASE_HOST", value = "pg-2-database25812.g.aivencloud.com" },
        { name = "DATABASE_PORT", value = "19217" },
        { name = "DATABASE_NAME", value = "defaultdb" },
        { name = "DATABASE_USERNAME", value = "avnadmin" },
        { name = "DATABASE_PASSWORD", value = "AVNS_vsIotPLRrxJUhcJlM0m" },
        { name = "ASPNETCORE_URLS", value = "http://0.0.0.0:5002" },
        { name = "RABBITMQ_HOST", value = "rabbit-mq.projectname.local" },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_USERNAME", value = "rabbitmq" },
        { name = "RABBITMQ_PASSWORD", value = "0Kg04Rq08!" },
        { name = "REDIS_HOST", value = "redis.projectname.local" },
        { name = "REDIS_PASSWORD", value = "0Kg04Rs05!" },
        { name = "REDIS_PORT", value = "6379" },
        { name = "GUEST_MICROSERVICE_HOST", value = "guest-microservice.projectname.local" },
        { name = "GUEST_MICROSERVICE_PORT", value = "5001" }
      ]
      ecs_container_health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5002/api/user/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 0
      }
      ecs_service_discovery_port = 5002
    },
    "apigateway" = {
      alb_target_group_port     = 8080
      alb_target_group_protocol = "HTTP"
      alb_target_group_type     = "ip"
      alb_health_check = {
        enabled             = true
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
      alb_listener_rule_priority = 12
      alb_listener_rule_conditions = []
      ecs_container_name_suffix          = "apigateway"
      ecs_container_image_repository_url = "897279497116.dkr.ecr.us-east-1.amazonaws.com/vkev-infrastructure-khanghv2406-ecr"
      ecs_container_image_tag            = "ApiGateway-latest"
      ecs_container_cpu                  = 200
      ecs_container_memory               = 200
      ecs_container_essential            = true
      ecs_container_port_mappings = [
        {
          container_port = 8080
          host_port      = 0
          protocol       = "tcp"
        }
      ]
      ecs_environment_variables = [
        { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
        { name = "ASPNETCORE_URLS", value = "http://0.0.0.0:8080" },
        { name = "USER_MICROSERVICE_HOST", value = "user-microservice.projectname.local" },
        { name = "USER_MICROSERVICE_PORT", value = "5002" },
        { name = "GUEST_MICROSERVICE_HOST", value = "guest-microservice.projectname.local" },
        { name = "GUEST_MICROSERVICE_PORT", value = "5001" },
        { name = "BASE_URL", value = "http://apigateway.projectname.local:8080" },
        { name = "RABBITMQ_HOST", value = "rabbit-mq.projectname.local" },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "REDIS_HOST", value = "redis.projectname.local" },
        { name = "REDIS_PORT", value = "6379" }
      ]
      ecs_container_health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 0
      }
      ecs_service_discovery_port = 8080
    },
    "redis" = {
      alb_target_group_port     = 6379
      alb_target_group_protocol = "TCP"
      alb_target_group_type     = "instance"
      alb_health_check = {
        enabled             = false
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
      alb_listener_rule_priority = 13
      alb_listener_rule_conditions = []
      ecs_container_name_suffix          = "redis"
      ecs_container_image_repository_url = "redis"
      ecs_container_image_tag            = "alpine"
      ecs_container_cpu                  = 200
      ecs_container_memory               = 200
      ecs_container_essential            = true
      ecs_container_port_mappings = [
        {
          container_port = 6379
          host_port      = 0
          protocol       = "tcp"
        }
      ]
      ecs_environment_variables = [
        { name = "REDIS_PASSWORD", value = "0Kg04Rs05!" }
      ]
      command = ["redis-server", "--requirepass", "0Kg04Rs05!"]
      ecs_container_health_check = null
      ecs_service_discovery_port = 6379
    },
    "rabbitmq" = {
      alb_target_group_port     = 5672
      alb_target_group_protocol = "TCP"
      alb_target_group_type     = "instance"
      alb_health_check = {
        enabled             = false
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
      alb_listener_rule_priority = 14
      alb_listener_rule_conditions = []
      ecs_container_name_suffix          = "rabbitmq"
      ecs_container_image_repository_url = "rabbitmq"
      ecs_container_image_tag            = "3-management"
      ecs_container_cpu                  = 200
      ecs_container_memory               = 200
      ecs_container_essential            = true
      ecs_container_port_mappings = [
        {
          container_port = 5672
          host_port      = 0
          protocol       = "tcp"
        },
        {
          container_port = 15672
          host_port      = 0
          protocol       = "tcp"
        }
      ]
      ecs_environment_variables = [
        { name = "RABBITMQ_DEFAULT_USER", value = "rabbitmq" },
        { name = "RABBITMQ_DEFAULT_PASS", value = "0Kg04Rq08!" }
      ]
      ecs_container_health_check = null
      ecs_service_discovery_port = 5672
    }
  }
}
