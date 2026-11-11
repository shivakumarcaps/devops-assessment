variable "name" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "rds_sg_id" { type = string }
variable "instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "backup_retention_days" { type = number }
variable "deletion_protection" { type = bool }
variable "multi_az" { type = bool }
