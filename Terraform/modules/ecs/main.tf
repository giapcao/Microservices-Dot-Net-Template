locals {
  service_definitions_nonsensitive = try(nonsensitive(var.service_definitions), var.service_definitions)

  service_name_map = { for name in var.service_names : name => name }

  # Use shared resources if provided, otherwise reference module-created resources
  log_group_name     = var.shared_log_group_name != null ? var.shared_log_group_name : "/ecs/${var.project_name}"
  task_role_arn      = var.shared_task_role_arn != null ? var.shared_task_role_arn : (length(aws_iam_role.ecs_task_role) > 0 ? aws_iam_role.ecs_task_role[0].arn : null)
  execution_role_arn = var.shared_execution_role_arn != null ? var.shared_execution_role_arn : (length(aws_iam_role.ecs_execution_role) > 0 ? aws_iam_role.ecs_execution_role[0].arn : null)
  task_sg_id         = var.shared_task_sg_id != null ? var.shared_task_sg_id : (length(aws_security_group.task_sg) > 0 ? aws_security_group.task_sg[0].id : null)

  autoscaling_settings = {
    for service_name, cfg in var.autoscaling_settings :
    service_name => {
      max_capacity        = cfg.max_capacity
      min_capacity        = cfg.min_capacity
      cpu_target_value    = cfg.cpu_target_value
      memory_target_value = cfg.memory_target_value
    }
    if var.enable_auto_scaling && contains(var.service_names, service_name)
  }

  normalized_services = {
    for service_name, service in local.service_definitions_nonsensitive :
    service_name => {
      task_cpu                           = lookup(service, "task_cpu", sum([for c in service.containers : c.cpu]))
      task_memory                        = lookup(service, "task_memory", sum([for c in service.containers : c.memory]))
      desired_count                      = lookup(service, "desired_count", var.desired_count)
      assign_public_ip                   = coalesce(lookup(service, "assign_public_ip", null), var.assign_public_ip)
      enable_auto_scaling                = coalesce(lookup(service, "enable_auto_scaling", null), var.enable_auto_scaling)
      max_capacity                       = lookup(service, "max_capacity", var.max_capacity)
      min_capacity                       = lookup(service, "min_capacity", var.min_capacity)
      cpu_target_value                   = lookup(service, "cpu_target_value", var.cpu_target_value)
      memory_target_value                = lookup(service, "memory_target_value", var.memory_target_value)
      deployment_maximum_percent         = lookup(service, "deployment_maximum_percent", 200)
      deployment_minimum_healthy_percent = lookup(service, "deployment_minimum_healthy_percent", 50)
      placement_constraints              = lookup(service, "placement_constraints", [])
      target_groups                      = lookup(service, "target_groups", [])
      containers = [
        for container in service.containers : merge(
          container,
          {
            environment_variables = lookup(container, "environment_variables", [])
            depends_on = [
              for dep in lookup(container, "depends_on", []) : dep
              if dep != container.name && contains([for c in service.containers : c.name], dep)
            ]
            essential = lookup(container, "essential", true)
            port_mappings = [
              for pm in lookup(container, "port_mappings", []) : merge(
                {
                  container_port = pm.container_port
                  host_port      = lookup(pm, "host_port", pm.container_port)
                  protocol       = lookup(pm, "protocol", "tcp")
                },
                lookup(pm, "name", null) != null ? { name = pm.name } : {},
                lookup(pm, "app_protocol", null) != null ? { app_protocol = pm.app_protocol } : {}
              )
            ]
          }
        )
      ]
    }
  }


}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  count             = var.shared_log_group_name == null ? 1 : 0
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${var.project_name}-ecs-logs" }
}

resource "aws_iam_role" "ecs_task_role" {
  count = var.shared_task_role_arn == null ? 1 : 0
  name  = "${var.project_name}-ecs-task-role"

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
  count = var.shared_execution_role_arn == null ? 1 : 0
  name  = "${var.project_name}-ecs-execution-role"

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
  count = var.shared_task_role_arn == null ? 1 : 0
  name  = "${var.project_name}-ecs-task-policy"
  role  = aws_iam_role.ecs_task_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:${var.aws_region}:*:log-group:${local.log_group_name}:*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  count      = var.shared_execution_role_arn == null ? 1 : 0
  role       = aws_iam_role.ecs_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_ecr_pull" {
  count      = var.shared_task_role_arn == null ? 1 : 0
  role       = aws_iam_role.ecs_task_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_security_group" "task_sg" {
  count       = var.shared_task_sg_id == null ? 1 : 0
  name_prefix = "${var.project_name}-ecs-task-sg-"
  description = "Security group for ECS tasks (awsvpc)"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow inbound from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
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

  tags = { Name = "${var.project_name}-ecs-task-sg" }
}

resource "aws_ecs_task_definition" "this" {
  for_each = local.service_name_map

  family                   = "${var.project_name}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = tostring(local.normalized_services[each.key].task_cpu)
  memory                   = tostring(local.normalized_services[each.key].task_memory)

  task_role_arn      = local.task_role_arn
  execution_role_arn = local.execution_role_arn

  container_definitions = jsonencode([
    for c in local.normalized_services[each.key].containers : merge(
      {
        name      = c.name
        image     = "${c.image_repository_url}:${c.image_tag}"
        cpu       = c.cpu
        memory    = c.memory
        essential = c.essential

        portMappings = [
          for pm in c.port_mappings : merge(
            {
              containerPort = pm.container_port
              hostPort      = coalesce(try(pm.host_port == 0 ? null : pm.host_port, null), pm.container_port)
              protocol      = try(pm.protocol, "tcp")
            },
            try(pm.name, null) != null ? { name = pm.name } : {},
            try(pm.app_protocol, null) != null ? { appProtocol = pm.app_protocol } : {}
          )
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
            awslogs-group         = local.log_group_name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "ecs/${c.name}"
          }
        }
      },
      lookup(c, "command", null) != null ? {
        command = c.command
      } : {},
      lookup(c, "health_check", null) != null ? {
        healthCheck = {
          command     = c.health_check.command
          interval    = c.health_check.interval
          timeout     = c.health_check.timeout
          retries     = c.health_check.retries
          startPeriod = c.health_check.startPeriod
        }
      } : {},
      length(c.depends_on) > 0 ? {
        dependsOn = [
          for dep in c.depends_on : {
            containerName = dep
            condition     = "HEALTHY"
          }
        ]
      } : {}
    )
  ])

  tags = { Name = "${var.project_name}-${each.key}-task" }
}

resource "aws_service_discovery_private_dns_namespace" "dns_ns" {
  count       = var.enable_service_connect && var.service_connect_namespace == null ? 1 : 0
  name        = var.service_discovery_domain
  vpc         = var.vpc_id
  description = "Service discovery namespace for ${var.project_name}"
  tags        = { Name = "${var.project_name}-dns-namespace" }
}

resource "aws_ecs_service" "this" {
  for_each = local.service_name_map

  name            = "${var.project_name}-${each.key}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.this[each.key].arn
  desired_count   = local.normalized_services[each.key].desired_count
  launch_type     = "EC2"

  network_configuration {
    assign_public_ip = local.normalized_services[each.key].assign_public_ip
    subnets          = var.task_subnet_ids
    security_groups  = [local.task_sg_id]
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.instance-id"
  }
  dynamic "placement_constraints" {
    for_each = local.normalized_services[each.key].placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = lookup(placement_constraints.value, "expression", null)
    }
  }

  dynamic "service_connect_configuration" {
    for_each = var.enable_service_connect ? [1] : []
    content {
      enabled = true
      namespace = (
        var.service_connect_namespace != null ? var.service_connect_namespace :
        (length(aws_service_discovery_private_dns_namespace.dns_ns) > 0 ? aws_service_discovery_private_dns_namespace.dns_ns[0].arn : null)
      )

      dynamic "service" {
        for_each = lookup(var.service_connect_services, each.key, [])
        content {
          port_name             = service.value.port_name
          discovery_name        = service.value.discovery_name
          ingress_port_override = try(service.value.ingress_port_override, null)

          dynamic "client_alias" {
            for_each = try(service.value.client_aliases, [])
            content {
              dns_name = client_alias.value.dns_name
              port     = client_alias.value.port
            }
          }
        }
      }
    }
  }
  dynamic "load_balancer" {
    for_each = local.normalized_services[each.key].target_groups
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  deployment_maximum_percent         = local.normalized_services[each.key].deployment_maximum_percent
  deployment_minimum_healthy_percent = local.normalized_services[each.key].deployment_minimum_healthy_percent

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(
    { Name = "${var.project_name}-${each.key}-ecs-service" },
    {
      for dep in lookup(var.service_dependencies, each.key, []) :
      "tf_dep_${dep}" => "${var.project_name}-${dep}"
      if dep != each.key
    }
  )

  depends_on = concat(
    var.shared_execution_role_arn == null ? [
      aws_iam_role_policy_attachment.ecs_task_ecr_pull[0],
      aws_iam_role_policy_attachment.ecs_execution_managed[0]
    ] : [],
    var.enable_service_connect && var.service_connect_namespace == null ? [
      aws_service_discovery_private_dns_namespace.dns_ns[0]
    ] : []
  )

}
resource "aws_appautoscaling_target" "ecs_target" {
  for_each = local.autoscaling_settings

  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.this[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  for_each = local.autoscaling_settings

  name               = "${var.project_name}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = each.value.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  for_each = local.autoscaling_settings

  name               = "${var.project_name}-${each.key}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = each.value.memory_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_security_group_rule" "task_sg_intra_self" {
  count             = var.shared_task_sg_id == null ? 1 : 0
  type              = "ingress"
  description       = "Allow all traffic within ECS task SG"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.task_sg[0].id
  self              = true
}
