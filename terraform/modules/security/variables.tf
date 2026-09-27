variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "container_port" {
  type = number
}

variable "jenkins_source_ip" {
  description = "Jenkins source IP allowed to access ALB test listener"
  type        = string
}
