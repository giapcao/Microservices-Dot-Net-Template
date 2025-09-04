resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${var.project_name}-ecs-logs" }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
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
    Version   = "2012-10-17"
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
    Version   = "2012-10-17"
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
  role       = aws_iam_role.ecs_task_role.name # Task role needs ECR pull if not using execution role for it (best practice is execution role)
  # For tasks to pull from ECR, AmazonECSTaskExecutionRolePolicy on ecs_execution_role is sufficient.
  # If containers need to interact with other AWS services (e.g. S3, DynamoDB), add permissions to ecs_task_role.
  # Adding AmazonEC2ContainerRegistryReadOnly to task role is redundant if execution role has it, but harmless.
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_security_group" "task_sg" {
  name_prefix = "${var.project_name}-ecs-task-sg-"
  description = "Security group for ECS tasks (awsvpc)"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound from ALB"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    security_groups = [var.alb_security_group_id]
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
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)

  task_role_arn      = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    for c in var.containers : merge(
      {
        name      = c.name
        image     = "${c.image_repository_url}:${c.image_tag}"
        cpu       = c.cpu
        memory    = c.memory
        essential = c.essential

        portMappings = [
          for pm in c.port_mappings : {
            containerPort = pm.container_port
            hostPort      = pm.container_port
            protocol      = pm.protocol
          }
        ]

        environment = [
          for env_var in c.environment_variables : {
            name  = env_var.name
            value = env_var.value
          }
        ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "ecs/${c.name}"
          }
        }
      },
      c.command != null ? {
        command = c.command
      } : {},
      c.health_check != null ? {
        healthCheck = {
          command     = c.health_check.command
          interval    = c.health_check.interval
          timeout     = c.health_check.timeout
          retries     = c.health_check.retries
          startPeriod = c.health_check.startPeriod
        }
      } : {}
    )
  ])

  tags = { Name = "${var.project_name}-task-definition" }
}

resource "aws_ecs_service" "app_service" {
  name            = "${var.project_name}-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"

  network_configuration {
    assign_public_ip = var.assign_public_ip
    subnets          = var.task_subnet_ids
    security_groups  = [aws_security_group.task_sg.id]
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.instance-id" # Spread tasks across instances
  }

  dynamic "service_registries" {
    # ECS only supports a single service_registries block per service. Pick the first eligible container (if any).
    for_each = var.enable_service_discovery && length(keys(aws_service_discovery_service.discovery_services)) > 0 ? {
      for cn in [keys(aws_service_discovery_service.discovery_services)[0]] : cn => cn
    } : {}
    content {
      registry_arn   = aws_service_discovery_service.discovery_services[service_registries.key].arn
      container_name = service_registries.key
      port           = lookup({ for c in var.containers : c.name => lookup(c, "service_discovery_port", null) }, service_registries.key, null)
    }
  }

  dynamic "load_balancer" {
    for_each = var.target_groups # Iterate through the list of target group configurations
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  lifecycle {
    ignore_changes = [desired_count] # Useful if desired_count managed by auto-scaling or CI/CD
  }

  tags = { Name = "${var.project_name}-ecs-service" }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_ecr_pull,
    aws_iam_role_policy_attachment.ecs_execution_managed,
    aws_service_discovery_service.discovery_services # Ensure discovery services are created first if used
  ]
}

resource "aws_service_discovery_private_dns_namespace" "dns_ns" {
  count       = var.enable_service_discovery ? 1 : 0
  name        = "${var.project_name}.local" # Consider making this configurable
  vpc         = var.vpc_id
  description = "Service discovery namespace for ${var.project_name}"
  tags        = { Name = "${var.project_name}-dns-namespace" }
}

resource "aws_service_discovery_service" "discovery_services" {
  for_each = {
    # Create a discovery service for each container that has it enabled
    for c in var.containers : c.name => c
    if var.enable_service_discovery && lookup(c, "enable_service_discovery", false) && lookup(c, "service_discovery_port", null) != null
  }

  name = each.value.name # Cloud Map service name will be the container name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.dns_ns[0].id
    routing_policy = "MULTIVALUE" # Appropriate for SRV records, resolves to multiple task IPs/ports
    dns_records {
      ttl  = 10
      type = "A" # Use A records so standard clients resolve service names
    }
  }

  description = "Service Discovery for container ${each.value.name} in service ${var.project_name}"
  tags        = { Name = "${var.project_name}-${each.value.name}-discovery" }
}

resource "aws_appautoscaling_target" "ecs_target" {
  count              = var.enable_auto_scaling ? 1 : 0
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.app_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  count              = var.enable_auto_scaling ? 1 : 0
  name               = "${var.project_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300 # Optional: Cooldown period in seconds
    scale_out_cooldown = 60  # Optional: Cooldown period in seconds
  }
}

resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  count              = var.enable_auto_scaling ? 1 : 0
  name               = "${var.project_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_value
    scale_in_cooldown  = 300 # Optional: Cooldown period in seconds
    scale_out_cooldown = 60  # Optional: Cooldown period in seconds
  }
}

# Allow all traffic within the same task security group (container-to-container across tasks)
resource "aws_security_group_rule" "task_sg_intra_self" {
  type              = "ingress"
  description       = "Allow all traffic within ECS task SG"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.task_sg.id
  self              = true
}
