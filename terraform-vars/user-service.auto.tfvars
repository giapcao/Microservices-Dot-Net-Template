# User Service Configuration  
services = {
  user = {
    # ALB Target Group
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

    # ECS Container
    ecs_container_name_suffix          = "microservice"
    ecs_container_image_repository_url = "your-aws-id-account.dkr.ecr.us-east-1.amazonaws.com/vkev-infrastructure-khanghv2406-ecr"
    ecs_container_image_tag            = "User.Microservice-latest"
    ecs_container_cpu                  = 100
    ecs_container_memory               = 128
    ecs_container_essential            = true
    ecs_container_port_mappings = [
      {
        container_port = 5002
        host_port      = 0
        protocol       = "tcp"
      }
    ]

    # Environment Variables
    ecs_environment_variables = [
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
      { name = "DATABASE_HOST", value = "your-database-host.com" },
      { name = "DATABASE_PORT", value = "19217" },
      { name = "DATABASE_NAME", value = "defaultdb" },
      { name = "DATABASE_USERNAME", value = "your-db-username" },
      { name = "DATABASE_PASSWORD", value = "your-db-password" },
      { name = "ASPNETCORE_URLS", value = "http://0.0.0.0:5002" },
      { name = "RABBITMQ_HOST", value = "localhost" },
      { name = "RABBITMQ_PORT", value = "5672" },
      { name = "RABBITMQ_USERNAME", value = "rabbitmq" },
      { name = "RABBITMQ_PASSWORD", value = "your-rabbitmq-password" },
      { name = "REDIS_HOST", value = "localhost" },
      { name = "REDIS_PASSWORD", value = "your-redis-password" },
      { name = "REDIS_PORT", value = "6379" },
      { name = "GUEST_MICROSERVICE_HOST", value = "localhost" },
      { name = "GUEST_MICROSERVICE_PORT", value = "5001" }
    ]

    # Health Check
    ecs_container_health_check = {
      command     = ["CMD-SHELL", "curl -f http://localhost:5002/api/user/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 0
    }

    ecs_service_discovery_port = 5002
    depends_on                 = ["redis", "rabbitmq"]
  }
}
