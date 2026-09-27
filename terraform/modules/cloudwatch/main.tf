resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-app"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs"
  }
}


locals {
  ecs_cluster_name       = "${var.project_name}-cluster"
  ecs_blue_service_name  = "${var.project_name}-service"
  ecs_green_service_name = "${var.project_name}-green-service"

  alb_arn_suffix = join(
    "/",
    slice(split("/", var.alb_arn), 1, 4)
  )

  blue_target_group_arn_suffix = join(
    "/",
    slice(split("/", var.blue_target_group_arn), 1, 3)
  )

  green_target_group_arn_suffix = join(
    "/",
    slice(split("/", var.green_target_group_arn), 1, 3)
  )
}

# ---------------------------------------------------------
# ECS Blue/Green High CPU
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "ecs_blue_high_cpu" {
  alarm_name          = "${var.project_name}-ecs-blue-high-cpu"
  alarm_description   = "Blue ECS service CPU utilization is above 70%"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1
  period             = 300
  threshold          = 70

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  statistic   = "Average"

  dimensions = {
    ClusterName = local.ecs_cluster_name
    ServiceName = local.ecs_blue_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "ecs_green_high_cpu" {
  alarm_name          = "${var.project_name}-ecs-green-high-cpu"
  alarm_description   = "Green ECS service CPU utilization is above 70%"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1
  period             = 300
  threshold          = 70

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  statistic   = "Average"

  dimensions = {
    ClusterName = local.ecs_cluster_name
    ServiceName = local.ecs_green_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

# ---------------------------------------------------------
# ECS BLue/Green High Memory
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "ecs_blue_high_memory" {
  alarm_name          = "${var.project_name}-ecs-blue-high-memory"
  alarm_description   = "Blue ECS service memory utilization is above 80%"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1
  period             = 300
  threshold          = 80

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"
  statistic   = "Average"

  dimensions = {
    ClusterName = local.ecs_cluster_name
    ServiceName = local.ecs_blue_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "ecs_green_high_memory" {
  alarm_name          = "${var.project_name}-ecs-green-high-memory"
  alarm_description   = "Green ECS service memory utilization is above 80%"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1
  period             = 300
  threshold          = 80

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"
  statistic   = "Average"

  dimensions = {
    ClusterName = local.ecs_cluster_name
    ServiceName = local.ecs_green_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

# ---------------------------------------------------------
# ALB Blue/Green Target 5XX
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "alb_blue_target_5xx" {
  alarm_name          = "${var.project_name}-alb-blue-target-5xx"
  alarm_description   = "Blue ALB target is returning HTTP 5XX errors"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1
  period             = 300
  threshold          = 0

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"
  statistic   = "Sum"

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
    TargetGroup  = local.blue_target_group_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "alb_green_target_5xx" {
  alarm_name          = "${var.project_name}-alb-green-target-5xx"
  alarm_description   = "Green ALB target is returning HTTP 5XX errors"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1
  period             = 300
  threshold          = 0

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"
  statistic   = "Sum"

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
    TargetGroup  = local.green_target_group_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

# ---------------------------------------------------------
# ALB Healthy Target Count
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "alb_blue_unhealthy_target" {
  alarm_name          = "${var.project_name}-alb-blue-unhealthy-target"
  alarm_description   = "Blue ALB target group has fewer than one healthy target"
  comparison_operator = "LessThanThreshold"

  evaluation_periods = 1
  period             = 60
  threshold          = 1

  namespace   = "AWS/ApplicationELB"
  metric_name = "HealthyHostCount"
  statistic   = "Minimum"

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
    TargetGroup  = local.blue_target_group_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "alb_green_unhealthy_target" {
  alarm_name          = "${var.project_name}-alb-green-unhealthy-target"
  alarm_description   = "Green ALB target group has fewer than one healthy target"
  comparison_operator = "LessThanThreshold"

  evaluation_periods = 1
  period             = 60
  threshold          = 1

  namespace   = "AWS/ApplicationELB"
  metric_name = "HealthyHostCount"
  statistic   = "Minimum"

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
    TargetGroup  = local.green_target_group_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

# ---------------------------------------------------------
# Add SNS topic
# ---------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name = "${var.project_name}-alerts"
  }
}

# ---------------------------------------------------------
# Add your email subscription
# ---------------------------------------------------------

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
