services = {
  user = {
    alb_target_group_port     = 5002
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
    ecs_container_cpu                  = 120
    ecs_container_memory               = 120
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
      { name = "DATABASE_NAME", value = "userdb" },
      { name = "DATABASE_USERNAME", value = "avnadmin" },
      { name = "DATABASE_PASSWORD", value = "AVNS_vsIotPLRrxJUhcJlM0m" },
      { name = "ASPNETCORE_URLS", value = "http://+:5002" },
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

    ecs_container_health_check = {
      command     = ["CMD-SHELL", "curl -f http://localhost:5002/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }

    ecs_service_discovery_port = 5002
    depends_on                 = ["rabbit-mq", "redis"]
  }
}

