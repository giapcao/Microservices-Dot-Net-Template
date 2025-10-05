services = {
  apigateway = {
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
    alb_listener_rule_priority   = 10
    alb_listener_rule_conditions = []

    ecs_container_name_suffix          = "apigateway"
    ecs_container_image_repository_url = "897279497116.dkr.ecr.us-east-1.amazonaws.com/ghepxe-ghepxe-infrastructure-ecr"
    ecs_container_image_tag            = "ApiGateway-latest"
    ecs_container_cpu                  = 256
    ecs_container_memory               = 512
    ecs_container_essential            = true
    ecs_container_port_mappings = [
      {
        container_port = 8080
        host_port      = 0
        protocol       = "tcp"
      }
    ]
    ecs_environment_variables = [
      { name = "ENABLE_SWAGGER_UI", value = "true" },
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
      { name = "ASPNETCORE_URLS", value = "http://+:8080" },
      { name = "USER_MICROSERVICE_HOST", value = "localhost" },
      { name = "USER_MICROSERVICE_PORT", value = "5002" },
      { name = "GUEST_MICROSERVICE_HOST", value = "guest.vkev.local" },
      { name = "GUEST_MICROSERVICE_PORT", value = "5001" },
      { name = "Jwt__SecretKey", value = "YourSuperSecretKeyThatIsAtLeast32CharactersLong!@#$%^&*()" },
      { name = "Jwt__Issuer", value = "UserMicroservice" },
      { name = "Jwt__Audience", value = "MicroservicesApp" },
      { name = "Jwt__ExpirationMinutes", value = "60" }
    ]
    ecs_container_health_check = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
    ecs_service_discovery_port = 8080
    depends_on                 = ["user-microservice"]
  }

  user = {
    alb_target_group_port     = 5002
    alb_target_group_protocol = "HTTP"
    alb_target_group_type     = "ip"
    alb_health_check = {
      enabled             = false
      path                = "/health"
      port                = "traffic-port"
      protocol            = "HTTP"
      matcher             = "200"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 3
    }
    alb_listener_rule_priority   = 11
    alb_listener_rule_conditions = []

    ecs_container_name_suffix          = "microservice"
    ecs_container_image_repository_url = "897279497116.dkr.ecr.us-east-1.amazonaws.com/ghepxe-ghepxe-infrastructure-ecr"
    ecs_container_image_tag            = "User.Microservice-latest"
    ecs_container_cpu                  = 256
    ecs_container_memory               = 512
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

  guest = {
    alb_target_group_port     = 5001
    alb_target_group_protocol = "HTTP"
    alb_target_group_type     = "ip"
    alb_health_check = {
      enabled             = false
      path                = "/health"
      port                = "traffic-port"
      protocol            = "HTTP"
      matcher             = "200"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 3
    }
    alb_listener_rule_priority   = 12
    alb_listener_rule_conditions = []

    ecs_container_name_suffix          = "microservice"
    ecs_container_image_repository_url = "897279497116.dkr.ecr.us-east-1.amazonaws.com/ghepxe-ghepxe-infrastructure-ecr"
    ecs_container_image_tag            = "Guest.Microservice-latest"
    ecs_container_cpu                  = 256
    ecs_container_memory               = 512
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
      { name = "DATABASE_NAME", value = "guestdb" },
      { name = "DATABASE_USERNAME", value = "avnadmin" },
      { name = "DATABASE_PASSWORD", value = "AVNS_iGi4kJJObNRnGdM6BTb" },
      { name = "ASPNETCORE_URLS", value = "http://+:5001" },
      { name = "RABBITMQ_HOST", value = "core.vkev.local" },
      { name = "RABBITMQ_PORT", value = "5672" },
      { name = "RABBITMQ_USERNAME", value = "rabbitmq" },
      { name = "RABBITMQ_PASSWORD", value = "0Kg04Rq08!" },
      { name = "REDIS_HOST", value = "core.vkev.local" },
      { name = "REDIS_PASSWORD", value = "0Kg04Rs05!" },
      { name = "REDIS_PORT", value = "6379" },
      { name = "Jwt__SecretKey", value = "YourSuperSecretKeyThatIsAtLeast32CharactersLong!@#$%^&*()" },
      { name = "Jwt__Issuer", value = "UserMicroservice" },
      { name = "Jwt__Audience", value = "MicroservicesApp" },
      { name = "Jwt__ExpirationMinutes", value = "60" }
    ]
    ecs_container_health_check = {
      command     = ["CMD-SHELL", "curl -f http://localhost:5001/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
    ecs_service_discovery_port = 5001
    depends_on                 = []
  }

  redis = {
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
    alb_listener_rule_priority   = 13
    alb_listener_rule_conditions = []

    ecs_container_name_suffix          = "redis"
    ecs_container_image_repository_url = "redis"
    ecs_container_image_tag            = "alpine"
    ecs_container_cpu                  = 128
    ecs_container_memory               = 256
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
    ecs_container_health_check = {
      command     = ["CMD-SHELL", "redis-cli -a 0Kg04Rs05! ping || exit 1"]
      interval    = 10
      timeout     = 5
      retries     = 5
      startPeriod = 30
    }
    ecs_service_discovery_port = 6379
    depends_on                 = []
  }

  rabbitmq = {
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
    alb_listener_rule_priority   = 14
    alb_listener_rule_conditions = []

    ecs_container_name_suffix          = "rabbitmq"
    ecs_container_image_repository_url = "rabbitmq"
    ecs_container_image_tag            = "3-management"
    ecs_container_cpu                  = 256
    ecs_container_memory               = 512
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
    ecs_container_health_check = {
      command     = ["CMD", "rabbitmqctl", "status"]
      interval    = 10
      timeout     = 5
      retries     = 5
      startPeriod = 30
    }
    ecs_service_discovery_port = 5672
    depends_on                 = []
  }
}
