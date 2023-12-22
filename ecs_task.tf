provider "aws" {
  region = "us-west-2" # Replace with your desired AWS region
}

resource "aws_ecs_task_definition" "gfpgan_task" {
  family                   = "gfpgan-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"  # Adjusted to 2 vCPUs
  memory                   = "4096"  # Adjusted to 4GB RAM

  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "gfpgan"
    image = "${aws_ecr_repository.gfpgan_repo.repository_url}:latest"

    # Environment variables
    environment = [
      { name = "SQS_QUEUE_NAME", value = "PerfectPic-Queue" },
      { name = "DYNAMODB_TABLE_NAME", value = "PerfectPic-Table" },
      { name = "S3_BUCKET_NAME", value = "perfectpic-bucket" }
    ]

    # Container-level health check
    healthCheck = {
      command     = ["CMD-SHELL", "exit 0"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }

    # Logging configuration
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "PerfectPic-Log-Group"
        awslogs-region        = "us-west-2"
        awslogs-stream-prefix = "gfpgan"
      }
    }
  }])
}
