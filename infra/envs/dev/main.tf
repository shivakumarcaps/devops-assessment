terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "caps-tfstate-dev"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "caps-tf-lock-dev"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  # Plan-only: AWS account లేకుండా కూడా plan చూపించడానికి
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

module "network" {
  source               = "../../modules/network"
  name                 = var.name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "rds" {
  source                = "../../modules/rds"
  name                  = var.name
  private_subnet_ids    = module.network.private_subnet_ids
  rds_sg_id             = module.network.rds_sg_id
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  multi_az              = var.db_multi_az
}

module "ecs" {
  source             = "../../modules/ecs"
  name               = var.name
  region             = var.region
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  alb_sg_id          = module.network.alb_sg_id
  ecs_sg_id          = module.network.ecs_sg_id
  cpu                = var.ecs_cpu
  memory             = var.ecs_memory
  desired_count      = var.ecs_desired_count
  db_host            = module.rds.endpoint
}

output "alb_dns_name" { value = module.ecs.alb_dns_name }
