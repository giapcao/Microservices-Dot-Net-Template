# API Gateway Service Configuration
services = {
  apigateway = {
    # ALB Target Group
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
    alb_listener_rule_priority   = 12
    alb_listener_rule_conditions = []

    # ECS Container
    ecs_container_name_suffix          = "apigateway"
    ecs_container_image_repository_url = "your-aws-account-id.dkr.ecr.us-east-1.amazonaws.com/your-ecr-repository"
    ecs_container_image_tag            = "ApiGateway-latest"
    ecs_container_cpu                  = 120
    ecs_container_memory               = 120
    ecs_container_essential            = true
    ecs_container_port_mappings = [
      { 
        container_port = 8080
        host_port      = 0
        protocol       = "tcp"
      }
    ]

    # Environment Variables
    ecs_environment_variables = [
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
      { name = "ASPNETCORE_URLS", value = "http://+:8080" },
      { name = "USER_MICROSERVICE_HOST", value = "localhost" },
      { name = "USER_MICROSERVICE_PORT", value = "5002" },
      { name = "GUEST_MICROSERVICE_HOST", value = "localhost" },
      { name = "GUEST_MICROSERVICE_PORT", value = "5001" }
    ]

    # Health Check
    ecs_container_health_check = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 0
    }

    ecs_service_discovery_port = 8080
    depends_on                 = []
  }
}
