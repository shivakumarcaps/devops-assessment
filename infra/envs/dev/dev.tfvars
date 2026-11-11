region               = "ap-south-1"
name                 = "caps-dev"
vpc_cidr             = "10.10.0.0/16"
azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]

ecs_cpu           = 256
ecs_memory        = 512
ecs_desired_count = 1

db_instance_class        = "db.t3.micro"
db_allocated_storage     = 20
db_backup_retention_days = 3
db_deletion_protection   = false
db_multi_az              = false
