# Redis Service Configuration
services = {
  redis = {
    # ALB Target Group (not used for Redis)
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

    # ECS Container
    ecs_container_name_suffix          = "redis"
    ecs_container_image_repository_url = "redis"
    ecs_container_image_tag            = "alpine"
    ecs_container_cpu                  = 100
    ecs_container_memory               = 128
    ecs_container_essential            = true
    ecs_container_port_mappings = [
      {
        container_port = 6379
        host_port      = 0
        protocol       = "tcp"
      }
    ]

    # Environment Variables
    ecs_environment_variables = [
      { name = "REDIS_PASSWORD", value = "your-redis-password" }
    ]

    # Health Check
    ecs_container_health_check = {
      command     = ["CMD-SHELL", "redis-cli -a your-redis-password ping || exit 1"]
      interval    = 10
      timeout     = 5
      retries     = 5
      startPeriod = 30
    }

    ecs_service_discovery_port = 6379
    depends_on                 = []
    command                    = ["redis-server", "--requirepass", "your-redis-password"]
  }
}
