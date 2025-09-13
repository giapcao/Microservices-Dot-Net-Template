# Guest Service Configuration
services = {
  guest = {
    # ALB Target Group
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

    # ECS Container
    ecs_container_name_suffix          = "microservice"
    ecs_container_image_repository_url = "897279497116.dkr.ecr.us-east-1.amazonaws.com/your-ecr-repository"
    ecs_container_image_tag            = "Guest.Microservice-latest"
    ecs_container_cpu                  = 150
    ecs_container_memory               = 150
    ecs_container_essential            = true
    ecs_container_port_mappings = [
      { 
        container_port = 5001
        host_port      = 0
        protocol       = "tcp"
      }
    ]

    # Environment Variables
    ecs_environment_variables = [
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
      { name = "DATABASE_HOST", value = "pg-1-database25811.g.aivencloud.com" },
      { name = "DATABASE_PORT", value = "16026" },
      { name = "DATABASE_NAME", value = "defaultdb" },
      { name = "DATABASE_USERNAME", value = "avnadmin" },
      { name = "DATABASE_PASSWORD", value = "AVNS_iGi4kJJObNRnGdM6BTb" },
      { name = "ASPNETCORE_URLS", value = "http://+:5001" },
      { name = "RABBITMQ_HOST", value = "localhost" },
      { name = "RABBITMQ_PORT", value = "5672" },
      { name = "RABBITMQ_USERNAME", value = "rabbitmq" },
      { name = "RABBITMQ_PASSWORD", value = "0Kg04Rq08!" },
      { name = "REDIS_HOST", value = "localhost" },
      { name = "REDIS_PASSWORD", value = "0Kg04Rs05!" },
      { name = "REDIS_PORT", value = "6379" },
      { name = "Jwt__SecretKey", value = "YourSuperSecretKeyThatIsAtLeast32CharactersLong!@#$%^&*()" },
      { name = "Jwt__Issuer", value = "UserMicroservice" },
      { name = "Jwt__Audience", value = "MicroservicesApp" },
      { name = "Jwt__ExpirationMinutes", value = "60" }
    ]

    # Health Check
    ecs_container_health_check = {
      command     = ["CMD-SHELL", "curl -f http://localhost:5001/api/guest/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 0
    }

    ecs_service_discovery_port = 5001
    depends_on                 = ["redis", "rabbitmq"]
  }
}
