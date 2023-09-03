provider "aws" {
  region = "eu-central-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "minecraft-on-demand-terraform"
  cidr = "10.0.0.0/16"
  azs = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

  map_public_ip_on_launch = true
  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support = true

}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"

  cluster_name = "minecraft-on-demand-terraform"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/minecraft-on-demand-terraform"
      }
    }
  }

  fargate_capacity_providers = {
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 1
      }
    }
  }

  default_capacity_provider_use_fargate = true

  services = {
    nginx = {
      cpu    = 1024
      memory = 4096
      assign_public_ip = true
      readonly_root_filesystem = false
      enable_autoscaling = false

      capacity_provider_strategy = {
        FARGATE_SPOT = {
          capacity_provider = "FARGATE_SPOT"
          weight            = 1
        }
      }

      # Container definition(s)
      container_definitions = {
        nginx = {
          cpu       = 1024
          memory    = 4096
          essential = true
          image     = "nginx:latest"
          port_mappings = [
            {
              name          = "nginx"
              containerPort = 80
              protocol      = "tcp"
            }
          ]
          memory_reservation = 50
          readonly_root_filesystem = false
        }
      }

      subnet_ids = module.vpc.public_subnets
      security_group_rules = {
        ingress_all = {
          type        = "ingress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }

  tags = {
    Project     = "minecraft-on-demand-terraform"
  }
}

output "services" {
  value = module.ecs.services
}
