
data "aws_caller_identity" "current" {}

######################
# Create ECR Repository
######################
resource "aws_ecr_repository" "tic_tac" {
  name                 = "tic-tac"
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }
}

######################
# IAM Role for ECS Task Execution
######################
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

######################
# ECS Cluster
######################
resource "aws_ecs_cluster" "my_cluster" {
  name = "my_cluster"
}

######################
# ECS Task Definition
######################
resource "aws_ecs_task_definition" "task_def" {
  family                   = "task_def"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "tic-tac-container"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/tic-tac:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

######################
# ECS Service
######################
resource "aws_ecs_service" "my_service" {
  name            = "my_service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.task_def.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = ["subnet-0348e5e04ade6f182", "subnet-039e353f4eabc3802", "subnet-0dea966d0a4d90ef2"] # Replace with actual subnet IDs
    security_groups = ["sg-0c184566d89eb39d4"]     
    assign_public_ip = true
  }

  depends_on = [
    aws_ecs_cluster.my_cluster,
    aws_iam_role_policy_attachment.ecs_task_execution_attach
  ]
}
