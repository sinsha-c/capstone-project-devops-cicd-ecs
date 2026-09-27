variable "project_name" {
  type = string
}

variable "blue_target_group_arn" {
  type = string
}

variable "green_target_group_arn" {
  type = string
}

variable "alb_arn" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alarm notifications"
}
