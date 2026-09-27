variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "capstone-devops-cicd"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "container_port" {
  type    = number
  default = 80
}

variable "jenkins_source_ip" {
  description = "Public IP address of the Jenkins server allowed to access ALB test listener"
  type        = string
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alerts"
}
