provider "aws" {
  region = var.aws_region
}

# --------------------------------------------------
# Default VPC
# --------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

# --------------------------------------------------
# Default subnets
# --------------------------------------------------

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --------------------------------------------------
# ECS Cluster
# --------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "devopstest-cluster"
}

# --------------------------------------------------
# Security Group
# --------------------------------------------------

resource "aws_security_group" "ecs" {
  name        = "devopstest-ecs-sg"
  description = "Security group for ECS Fargate"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --------------------------------------------------
# ECS Task Execution Role
# --------------------------------------------------

resource "aws_iam_role" "ecs_task_execution" {
  name = "devopstest-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role = aws_iam_role.ecs_task_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --------------------------------------------------
# ECS Task Definition
# --------------------------------------------------

resource "aws_ecs_task_definition" "app" {
  family = "devopstest"

  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "web"
      image = var.image_uri

      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = "/ecs/devopstest"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# --------------------------------------------------
# CloudWatch Log Group
# --------------------------------------------------

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/devopstest"
  retention_in_days = 7
}

# --------------------------------------------------
# ECS Service
# --------------------------------------------------

resource "aws_ecs_service" "app" {
  name = "devopstest-service"

  cluster = aws_ecs_cluster.main.id

  task_definition = aws_ecs_task_definition.app.arn

  desired_count = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets = data.aws_subnets.default.ids

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution
  ]
}
