# VPC Module
module "vpc" {
  source                = "./modules/vpc"
  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  public_subnet_count   = 2
  private_subnet_cidr   = var.private_subnet_cidr
}

# ALB Module
module "alb" {
  source              = "./modules/alb"
  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids

  target_groups_definition = [
    { # API Gateway Target Group
      name_suffix = "apigateway"
      port        = var.services["apigateway"].alb_target_group_port
      protocol    = var.services["apigateway"].alb_target_group_protocol
      target_type = var.services["apigateway"].alb_target_group_type
      health_check = {
        enabled             = true
        path                = "/api/health"
        port                = var.services["apigateway"].alb_health_check.port
        protocol            = var.services["apigateway"].alb_health_check.protocol
        matcher             = var.services["apigateway"].alb_health_check.matcher
        interval            = var.services["apigateway"].alb_health_check.interval
        timeout             = var.services["apigateway"].alb_health_check.timeout
        healthy_threshold   = var.services["apigateway"].alb_health_check.healthy_threshold
        unhealthy_threshold = var.services["apigateway"].alb_health_check.unhealthy_threshold
      }
    }
  ]

  default_listener_action = {
    type = "forward"
    target_group_suffix = "apigateway"
  }

  listener_rules_definition = []
}

# EC2 Module
module "ec2" {
  source                = "./modules/ec2"
  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = var.vpc_cidr
  subnet_id             = module.vpc.public_subnet_ids[0]
  instance_type         = var.instance_type
  associate_public_ip   = var.associate_public_ip
  alb_security_group_id = module.alb.alb_sg_id

  depends_on = [module.alb]
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name     = var.project_name
  aws_region       = var.aws_region
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  task_subnet_ids  = module.vpc.public_subnet_ids
  ecs_cluster_id   = module.ec2.ecs_cluster_arn
  ecs_cluster_name = module.ec2.ecs_cluster_name
  desired_count    = 1

  task_cpu    = 800
  task_memory = 800
  alb_security_group_id = module.alb.alb_sg_id
  assign_public_ip      = false

  containers = [
    { # Guest Container Definition
      name                 = "guest-microservice"
      image_repository_url = var.services["guest"].ecs_container_image_repository_url
      image_tag            = var.services["guest"].ecs_container_image_tag
      cpu                  = var.services["guest"].ecs_container_cpu
      memory               = var.services["guest"].ecs_container_memory
      essential            = var.services["guest"].ecs_container_essential
      port_mappings        = var.services["guest"].ecs_container_port_mappings
      environment_variables= var.services["guest"].ecs_environment_variables
      health_check = {
        command     = var.services["guest"].ecs_container_health_check.command
        interval    = var.services["guest"].ecs_container_health_check.interval
        timeout     = var.services["guest"].ecs_container_health_check.timeout
        retries     = var.services["guest"].ecs_container_health_check.retries
        startPeriod = var.services["guest"].ecs_container_health_check.startPeriod
      }
      enable_service_discovery = var.enable_service_discovery # Uses the global variable
      service_discovery_port   = var.services["guest"].ecs_service_discovery_port
    },
    { # User Container Definition
      name                 = "user-microservice"
      image_repository_url = var.services["user"].ecs_container_image_repository_url
      image_tag            = var.services["user"].ecs_container_image_tag
      cpu                  = var.services["user"].ecs_container_cpu
      memory               = var.services["user"].ecs_container_memory
      essential            = var.services["user"].ecs_container_essential
      port_mappings        = var.services["user"].ecs_container_port_mappings
      environment_variables= var.services["user"].ecs_environment_variables
      health_check = {
        command     = var.services["user"].ecs_container_health_check.command
        interval    = var.services["user"].ecs_container_health_check.interval
        timeout     = var.services["user"].ecs_container_health_check.timeout
        retries     = var.services["user"].ecs_container_health_check.retries
        startPeriod = var.services["user"].ecs_container_health_check.startPeriod
      }
      enable_service_discovery = var.enable_service_discovery # Uses the global variable
      service_discovery_port   = var.services["user"].ecs_service_discovery_port
    },
    { # API Gateway
      name                 = "apigateway"
      image_repository_url = var.services["apigateway"].ecs_container_image_repository_url
      image_tag            = var.services["apigateway"].ecs_container_image_tag
      cpu                  = var.services["apigateway"].ecs_container_cpu
      memory               = var.services["apigateway"].ecs_container_memory
      essential            = var.services["apigateway"].ecs_container_essential
      port_mappings        = var.services["apigateway"].ecs_container_port_mappings
      environment_variables= var.services["apigateway"].ecs_environment_variables
      health_check = {
        command     = var.services["apigateway"].ecs_container_health_check.command
        interval    = var.services["apigateway"].ecs_container_health_check.interval
        timeout     = var.services["apigateway"].ecs_container_health_check.timeout
        retries     = var.services["apigateway"].ecs_container_health_check.retries
        startPeriod = var.services["apigateway"].ecs_container_health_check.startPeriod
      }
      enable_service_discovery = var.enable_service_discovery
      service_discovery_port   = var.services["apigateway"].ecs_service_discovery_port
    },
    { # Redis
      name                 = "redis"
      image_repository_url = var.services["redis"].ecs_container_image_repository_url
      image_tag            = var.services["redis"].ecs_container_image_tag
      cpu                  = var.services["redis"].ecs_container_cpu
      memory               = var.services["redis"].ecs_container_memory
      essential            = var.services["redis"].ecs_container_essential
      port_mappings        = var.services["redis"].ecs_container_port_mappings
      environment_variables= var.services["redis"].ecs_environment_variables
      command              = lookup(var.services["redis"], "command", null)
      health_check         = null
      enable_service_discovery = var.enable_service_discovery
      service_discovery_port   = var.services["redis"].ecs_service_discovery_port
    },
    { # RabbitMQ
      name                 = "rabbit-mq"
      image_repository_url = var.services["rabbitmq"].ecs_container_image_repository_url
      image_tag            = var.services["rabbitmq"].ecs_container_image_tag
      cpu                  = var.services["rabbitmq"].ecs_container_cpu
      memory               = var.services["rabbitmq"].ecs_container_memory
      essential            = var.services["rabbitmq"].ecs_container_essential
      port_mappings        = var.services["rabbitmq"].ecs_container_port_mappings
      environment_variables= var.services["rabbitmq"].ecs_environment_variables
      health_check         = null
      enable_service_discovery = var.enable_service_discovery
      service_discovery_port   = var.services["rabbitmq"].ecs_service_discovery_port
    }
  ]

  target_groups = [
    { # API Gateway to Target Group Mapping
      target_group_arn = module.alb.target_group_arns_map["apigateway"]
      container_name   = "apigateway"
      container_port   = var.services["apigateway"].ecs_container_port_mappings[0].container_port
    }
  ]

  enable_auto_scaling      = var.enable_auto_scaling
  enable_service_discovery = var.enable_service_discovery

  depends_on = [module.ec2]
}

## CloudFront and Lambda@Edge modules removed
