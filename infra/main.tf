terraform {
  backend "s3" {
    bucket         = "wiktorkowalski-terraform-state"
    key            = "minecraft-ondemand-terraform/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "wiktorkowalski-terraform-state"
    encrypt        = false
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.37.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# Route 53
data "aws_route53_zone" "domain" {
  name = "wiktorkowalski.pl"
}

# Network
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "default" {
  vpc_id = aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.default.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.default.id
  route_table_id = aws_route_table.public.id
}
#

# ECS
resource "aws_ecs_cluster" "default" {
  name = "my-ecs-cluster"
}

resource "aws_efs_file_system" "efs" {
  creation_token = "minecraft-ondemand-terraform"
  encrypted = true
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

resource "aws_efs_mount_target" "mount_target" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.default.id
  security_groups = [aws_security_group.default.id]
}

resource "aws_efs_access_point" "access_point" {
  file_system_id = aws_efs_file_system.efs.id
  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/minecraft"
    creation_info {
      owner_uid = 1000
      owner_gid = 1000
      permissions = "0755"
    }
  } 
}

resource "aws_ecs_task_definition" "default" {
  family                   = "minecraft-ondemand-terraform"
  execution_role_arn       = aws_iam_role.default.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"
  memory                   = "8192"
  task_role_arn            = aws_iam_role.default.arn

  volume {
    name      = "minecraft-data"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs.id
      # root_directory = "/minecraft"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.access_point.id
        iam = "ENABLED"
      }
    }
  }

  container_definitions = <<DEFINITION
  [
    {
      "name": "minecraft-ondemand-terraform",
      "image": "ghcr.io/itzg/minecraft-server",
      "portMappings": [
        {
          "containerPort": 25565,
          "hostPort": 25565,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
            "name": "EULA",
            "value": "TRUE"
        },
        {
            "name": "VERSION",
            "value": "1.20.4"
        },
        {
            "name": "MEMORY",
            "value": "8G"
        },
        {
            "name": "TYPE",
            "value": "FABRIC"
        },
        {
            "name": "MODRINTH_PROJECTS",
            "value": "lithium"
        },
        {
            "name": "MODE",
            "value": "survival"
        },
        {
            "name": "OPS",
            "value": "Vicio123"
        },
        {
            "name": "WHITE_LIST",
            "value": "TRUE"
        },
        {
            "name": "MOTD",
            "value": "\\u00a74\\u00a7lJazda\\u00a7r \\u00a76\\u00a7nz\\u00a72\\u00a7o Creeperami\\u00a7r\\n\\u00a7kAUUUUUUUUUUUUUUUU"
        },
        {
            "name": "PVP",
            "value": "TRUE"
        },
        {
            "name": "DIFFICULTY",
            "value": "normal"
        },
        {
            "name": "ENABLE_RCON",
            "value": "TRUE"
        },
        {
            "name": "RCON_PASSWORD",
            "value": "yourpassword"
        },
        {
            "name": "ENABLE_QUERY",
            "value": "TRUE"
        },
        {
            "name": "SPAWN_ANIMALS",
            "value": "TRUE"
        },
        {
            "name": "SPAWN_NPCS",
            "value": "TRUE"
        },
        {
            "name": "SPAWN_MONSTERS",
            "value": "TRUE"
        },
        {
            "name": "GENERATE_STRUCTURES",
            "value": "TRUE"
        },
        {
            "name": "VIEW_DISTANCE",
            "value": "12"
        },
        {
            "name": "SIMULATION_DISTANCE",
            "value": "12"
        },
        {
            "name": "ONLINE_MODE",
            "value": "TRUE"
        }
      ],
      "mountPoints": [
        {
          "sourceVolume": "minecraft-data",
          "containerPath": "/data"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/ecs/minecraft-ondemand-terraform",
          "awslogs-region": "eu-west-1",
          "awslogs-stream-prefix": "minecraft-ondemand-terraform"
        }
      }
    },
    {
      "name": "housekeeper",
      "image": "ghcr.io/wiktorkowalski/housekeeper-minecraft-ondemand-terraform",
      "cpu": 128,
      "memory": 128,
      "essential": false,
      "environment": [
        {
          "name": "RCON_PASSWORD",
          "value": "yourpassword"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/ecs/housekeeper-minecraft-ondemand-terraform",
          "awslogs-region": "eu-west-1",
          "awslogs-stream-prefix": "housekeeper-minecraft-ondemand-terraform"
        }
      }
    }
  ]
  DEFINITION
}

resource "aws_cloudwatch_log_group" "minecraft_log_group" {
  name              = "/aws/ecs/minecraft-ondemand-terraform"
  retention_in_days = 30 # Optional: Adjust the retention period as needed
}

resource "aws_cloudwatch_log_group" "minecraft_log_group_housekeeper" {
  name              = "/aws/ecs/housekeeper-minecraft-ondemand-terraform"
  retention_in_days = 30 # Optional: Adjust the retention period as needed
}

resource "aws_ecs_service" "default" {
  name            = "minecraft-ondemand-terraform"
  cluster         = aws_ecs_cluster.default.id
  task_definition = aws_ecs_task_definition.default.arn
  # desired_count   = 1
  # launch_type = "FARGATE"

  deployment_maximum_percent = 100
  deployment_minimum_healthy_percent = 0

  network_configuration {
    subnets          = [aws_subnet.default.id]
    security_groups  = [aws_security_group.default.id]
    assign_public_ip = true
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
}

resource "aws_iam_role" "default" {
  name = "my-ecs-task-role"

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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.default.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_policy" {
  name        = "ecs_full_access_policy"
  description = "A policy that provides full access to ECS"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "ecs:*",
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.ecs_policy.arn
}

resource "aws_iam_policy" "route53_policy" {
  name        = "route53_full_access_policy"
  description = "A policy that provides full access to Route 53"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "route53:*",
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "route53_policy_attachment" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.route53_policy.arn
}

resource "aws_iam_policy" "ec2_policy" {
  name        = "ec2_full_access_policy"
  description = "A policy that provides full access to EC2"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "ec2:*",
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ec2_policy_attachment" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

