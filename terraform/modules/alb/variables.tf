variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnets" { type = list(string) }
variable "alb_sg_id" { type = string }
variable "container_port" { type = number }
