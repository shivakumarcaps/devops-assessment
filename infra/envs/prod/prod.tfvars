region               = "ap-south-1"
name                 = "caps-prod"
vpc_cidr             = "10.20.0.0/16"
azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]

ecs_cpu           = 1024
ecs_memory        = 2048
ecs_desired_count = 2

db_instance_class        = "db.m5.large"
db_allocated_storage     = 100
db_backup_retention_days = 14
db_deletion_protection   = true
db_multi_az              = true
