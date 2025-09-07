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
  subnet_id             = module.vpc.private_subnet_id
  instance_type         = var.instance_type
  associate_public_ip   = var.associate_public_ip
  alb_security_group_id = module.alb.alb_sg_id

  depends_on = [module.alb]
}

# ECS Module
locals {
  container_definitions = [
    for service_name, s in var.services : {
      name                      = service_name
      image_repository_url      = s.ecs_container_image_repository_url
      image_tag                 = s.ecs_container_image_tag
      cpu                       = s.ecs_container_cpu
      memory                    = s.ecs_container_memory
      essential                 = s.ecs_container_essential
      port_mappings             = s.ecs_container_port_mappings
      environment_variables     = s.ecs_environment_variables
      command                   = lookup(s, "command", null)
      health_check              = try(s.ecs_container_health_check, null)
      enable_service_discovery  = var.enable_service_discovery
      service_discovery_port    = s.ecs_service_discovery_port
      depends_on                = try(s.depends_on, [])
    }
  ]
}

module "ecs" {
  source = "./modules/ecs"

  project_name     = var.project_name
  aws_region       = var.aws_region
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  task_subnet_ids  = [module.vpc.private_subnet_id]
  ecs_cluster_id   = module.ec2.ecs_cluster_arn
  ecs_cluster_name = module.ec2.ecs_cluster_name
  desired_count    = 1

  task_cpu    = 800
  task_memory = 800
  alb_security_group_id = module.alb.alb_sg_id
  assign_public_ip      = false

  containers = local.container_definitions

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
