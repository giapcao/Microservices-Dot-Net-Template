# RabbitMQ Service Configuration
services = {
  rabbitmq = {
    # ALB Target Group (not used for RabbitMQ)
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

    # ECS Container
    ecs_container_name_suffix          = "rabbitmq"
    ecs_container_image_repository_url = "rabbitmq"
    ecs_container_image_tag            = "3-management"
    ecs_container_cpu                  = 100
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

    # Environment Variables
    ecs_environment_variables = [
      { name = "RABBITMQ_DEFAULT_USER", value = "rabbitmq" },
      { name = "RABBITMQ_DEFAULT_PASS", value = "your-rabbitmq-password" }
    ]

    # Health Check
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
