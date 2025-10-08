locals {
  rabbitmq_host      = "rabbitmq"
  redis_host         = "redis"
  guest_service_host = "guest-service"
  user_service_host  = "user-service"
}

# VPC Module
module "vpc" {
  source              = "./modules/vpc"
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  public_subnet_count = 2
  private_subnet_cidr = var.private_subnet_cidr
}

# ALB Module
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  target_groups_definition = [
    {
      # API Gateway Target Group
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
    type                = "forward"
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
  container_instance_groups = {
    core = {
      instance_attributes = { service_group = "core" }
      tags                = { ServiceGroup = "core" }
    }
    guest = {
      instance_attributes = { service_group = "guest" }
      tags                = { ServiceGroup = "guest" }
    }
  }

  depends_on = [module.alb]
}

# Shared ECS Resources (created once, used by all services)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 30
  tags              = { Name = "${var.project_name}-ecs-logs" }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-ecs-task-role" }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-ecs-execution-role" }
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.project_name}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.ecs_logs.arn}:*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_ecr_pull" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_security_group" "ecs_task_sg" {
  name_prefix = "${var.project_name}-ecs-task-sg-"
  description = "Security group for ECS tasks (awsvpc)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow inbound from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [module.alb.alb_sg_id]
  }

  ingress {
    description = "Allow intra-VPC task-to-task"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-task-sg" }
}

resource "aws_security_group_rule" "task_sg_intra_self" {
  type              = "ingress"
  description       = "Allow all traffic within ECS task SG"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ecs_task_sg.id
  self              = true
}

resource "aws_service_discovery_private_dns_namespace" "ecs_namespace" {
  count       = var.enable_service_connect ? 1 : 0
  name        = "${var.project_name}.${var.service_discovery_domain_suffix}"
  vpc         = module.vpc.vpc_id
  description = "Service discovery namespace for ${var.project_name}"
  tags        = { Name = "${var.project_name}-dns-namespace" }
}

# ECS Module - Core Services
module "ecs_core" {
  source = "./modules/ecs"

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = [module.vpc.private_subnet_id]
  ecs_cluster_id           = module.ec2.ecs_cluster_arn
  ecs_cluster_name         = module.ec2.ecs_cluster_name
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = false
  desired_count            = 1
  service_names            = ["core"]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"
  service_dependencies     = {}
  enable_auto_scaling      = var.enable_auto_scaling
  enable_service_connect   = var.enable_service_connect
  
  # Pass shared resources
  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    core = [
      {
        port_name      = var.services["apigateway"].ecs_service_connect_port_name
        discovery_name = var.services["apigateway"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["apigateway"].ecs_service_connect_dns_name
            port     = var.services["apigateway"].ecs_container_port_mappings[0].container_port
          }
        ]
      },
      {
        port_name      = var.services["user"].ecs_service_connect_port_name
        discovery_name = var.services["user"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["user"].ecs_service_connect_dns_name
            port     = var.services["user"].ecs_container_port_mappings[0].container_port
          }
        ]
      },
      {
        port_name      = var.services["rabbitmq"].ecs_service_connect_port_name
        discovery_name = var.services["rabbitmq"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["rabbitmq"].ecs_service_connect_dns_name
            port     = var.services["rabbitmq"].ecs_container_port_mappings[0].container_port
          }
        ]
      },
      {
        port_name      = var.services["redis"].ecs_service_connect_port_name
        discovery_name = var.services["redis"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["redis"].ecs_service_connect_dns_name
            port     = var.services["redis"].ecs_container_port_mappings[0].container_port
          }
        ]
      }
      # Note: Guest service auto-discovered via Service Connect namespace
      # No need to explicitly define client-only config
    ]
  }

  service_definitions = {
    core = {
      task_cpu         = 900
      task_memory      = 900
      desired_count    = 1
      assign_public_ip = false
      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == core"
        }
      ]

      containers = [
        {
          # User Container Definition
          name                 = "user-microservice"
          image_repository_url = var.services["user"].ecs_container_image_repository_url
          image_tag            = var.services["user"].ecs_container_image_tag
          cpu                  = var.services["user"].ecs_container_cpu
          memory               = var.services["user"].ecs_container_memory
          essential            = var.services["user"].ecs_container_essential
          port_mappings        = var.services["user"].ecs_container_port_mappings
          environment_variables = [
            for env_var in var.services["user"].ecs_environment_variables :
            env_var
          ]
          health_check = {
            command     = var.services["user"].ecs_container_health_check.command
            interval    = var.services["user"].ecs_container_health_check.interval
            timeout     = var.services["user"].ecs_container_health_check.timeout
            retries     = var.services["user"].ecs_container_health_check.retries
            startPeriod = var.services["user"].ecs_container_health_check.startPeriod
          }
          depends_on = var.services["user"].depends_on
        },
        {
          # API Gateway
          name                 = "api-gateway"
          image_repository_url = var.services["apigateway"].ecs_container_image_repository_url
          image_tag            = var.services["apigateway"].ecs_container_image_tag
          cpu                  = var.services["apigateway"].ecs_container_cpu
          memory               = var.services["apigateway"].ecs_container_memory
          essential            = var.services["apigateway"].ecs_container_essential
          port_mappings        = var.services["apigateway"].ecs_container_port_mappings
          environment_variables = [
            for env_var in var.services["apigateway"].ecs_environment_variables :
            env_var
          ]
          health_check = {
            command     = var.services["apigateway"].ecs_container_health_check.command
            interval    = var.services["apigateway"].ecs_container_health_check.interval
            timeout     = var.services["apigateway"].ecs_container_health_check.timeout
            retries     = var.services["apigateway"].ecs_container_health_check.retries
            startPeriod = var.services["apigateway"].ecs_container_health_check.startPeriod
          }
          depends_on = var.services["apigateway"].depends_on
        },
        {
          # Redis
          name                  = "redis"
          image_repository_url  = var.services["redis"].ecs_container_image_repository_url
          image_tag             = var.services["redis"].ecs_container_image_tag
          cpu                   = var.services["redis"].ecs_container_cpu
          memory                = var.services["redis"].ecs_container_memory
          essential             = var.services["redis"].ecs_container_essential
          port_mappings         = var.services["redis"].ecs_container_port_mappings
          environment_variables = var.services["redis"].ecs_environment_variables
          command               = lookup(var.services["redis"], "command", null)
          health_check = {
            command     = var.services["redis"].ecs_container_health_check.command
            interval    = var.services["redis"].ecs_container_health_check.interval
            timeout     = var.services["redis"].ecs_container_health_check.timeout
            retries     = var.services["redis"].ecs_container_health_check.retries
            startPeriod = var.services["redis"].ecs_container_health_check.startPeriod
          }
          depends_on = var.services["redis"].depends_on
        },
        {
          # RabbitMQ
          name                  = "rabbitmq"
          image_repository_url  = var.services["rabbitmq"].ecs_container_image_repository_url
          image_tag             = var.services["rabbitmq"].ecs_container_image_tag
          cpu                   = var.services["rabbitmq"].ecs_container_cpu
          memory                = var.services["rabbitmq"].ecs_container_memory
          essential             = var.services["rabbitmq"].ecs_container_essential
          port_mappings         = var.services["rabbitmq"].ecs_container_port_mappings
          environment_variables = var.services["rabbitmq"].ecs_environment_variables
          health_check = {
            command     = var.services["rabbitmq"].ecs_container_health_check.command
            interval    = var.services["rabbitmq"].ecs_container_health_check.interval
            timeout     = var.services["rabbitmq"].ecs_container_health_check.timeout
            retries     = var.services["rabbitmq"].ecs_container_health_check.retries
            startPeriod = var.services["rabbitmq"].ecs_container_health_check.startPeriod
          }
          depends_on = var.services["rabbitmq"].depends_on
        }
      ]

      target_groups = [
        {
          # API Gateway to Target Group Mapping
          target_group_arn = module.alb.target_group_arns_map["apigateway"]
          container_name   = "api-gateway"
          container_port   = var.services["apigateway"].ecs_container_port_mappings[0].container_port
        }
      ]
    }
  }

  depends_on = [module.ec2]
}

# ECS Module - Guest Services  
# Deploys in parallel with core - Service Connect handles auto-discovery
module "ecs_guest" {
  source = "./modules/ecs"

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = [module.vpc.private_subnet_id]
  ecs_cluster_id           = module.ec2.ecs_cluster_arn
  ecs_cluster_name         = module.ec2.ecs_cluster_name
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = false
  desired_count            = 1
  service_names            = ["guest"]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"
  service_dependencies     = {}
  enable_auto_scaling      = var.enable_auto_scaling
  enable_service_connect   = var.enable_service_connect
  
  # Pass shared resources (same as core)
  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  # Use existing namespace created above
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    guest = [
      {
        # Publish guest-service to namespace
        port_name      = var.services["guest"].ecs_service_connect_port_name
        discovery_name = var.services["guest"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["guest"].ecs_service_connect_dns_name
            port     = var.services["guest"].ecs_container_port_mappings[0].container_port
          }
        ]
      }
      # Note: RabbitMQ and Redis auto-discovered via Service Connect namespace
      # No need to explicitly define client-only config
    ]
  }

  service_definitions = {
    guest = {
      task_cpu            = 900
      task_memory         = 900
      desired_count       = 1
      assign_public_ip    = false
      enable_auto_scaling = false
      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == guest"
        }
      ]

      containers = [
        {
          name                 = "guest-microservice"
          image_repository_url = var.services["guest"].ecs_container_image_repository_url
          image_tag            = var.services["guest"].ecs_container_image_tag
          cpu                  = var.services["guest"].ecs_container_cpu
          memory               = var.services["guest"].ecs_container_memory
          essential            = var.services["guest"].ecs_container_essential
          port_mappings        = var.services["guest"].ecs_container_port_mappings
          environment_variables = [
            for env_var in var.services["guest"].ecs_environment_variables :
            env_var
          ]
          health_check = {
            command     = var.services["guest"].ecs_container_health_check.command
            interval    = var.services["guest"].ecs_container_health_check.interval
            timeout     = var.services["guest"].ecs_container_health_check.timeout
            retries     = var.services["guest"].ecs_container_health_check.retries
            startPeriod = var.services["guest"].ecs_container_health_check.startPeriod
          }
          depends_on = []
        }
      ]

      target_groups = []
    }
  }

  depends_on = [module.ec2]
}

## CloudFront and Lambda@Edge modules removed
