# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.repository_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.repository_name}-cluster"
    }
  )
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.repository_name}"
  retention_in_days = 7

  tags = merge(
    var.common_tags,
    {
      Name = "${var.repository_name}-logs"
    }
  )
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.repository_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.repository_name}-ecs-task-execution-role"
    }
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for Secrets Manager access
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${var.repository_name}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn
        ]
      }
    ]
  })
}

# ECS Task Role (for application permissions)
resource "aws_iam_role" "ecs_task" {
  name = "${var.repository_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.repository_name}-ecs-task-role"
    }
  )
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = var.repository_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = var.repository_name
      image = "${aws_ecr_repository.potato_app.repository_url}:latest"

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        },
        {
          name  = "SERVER_PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "DATABASE_URL"
          value = "jdbc:postgresql://${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"
        },
        {
          name  = "DATABASE_USERNAME"
          value = var.db_username
        },
        {
          name  = "LOG_LEVEL"
          value = "INFO"
        },
        {
          name  = "APP_LOG_LEVEL"
          value = "INFO"
        }
      ]

      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_password.arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${var.container_port}/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    var.common_tags,
    {
      Name = "${var.repository_name}-task-definition"
    }
  )
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.repository_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.repository_name
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = var.health_check_grace_period

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution
  ]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.repository_name}-service"
    }
  )
}
