variable "name" { type = string }
variable "region" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }
variable "ecs_sg_id" { type = string }
variable "cpu" { type = number }
variable "memory" { type = number }
variable "desired_count" { type = number }
variable "db_host" { type = string }
variable "container_image" {
  type    = string
  default = "nginx:stable"
}
