output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "ecr_repository_name" {
  value = module.ecr.repository_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_blue_service_name" {
  value = module.ecs.blue_service_name
}

output "ecs_green_service_name" {
  value = module.ecs.green_service_name
}

output "task_definition_arn" {
  value = module.ecs.task_definition_arn
}

output "alb_listener_arn" {
  value = module.alb.listener_arn
}

output "test_listener_arn" {
  value = module.alb.test_listener_arn
}

output "blue_target_group_arn" {
  value = module.alb.blue_target_group_arn
}

output "green_target_group_arn" {
  value = module.alb.green_target_group_arn
}

output "alb_arn" {
  value = module.alb.alb_arn
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "application_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "cloudwatch_log_group" {
  value = module.cloudwatch.log_group_name
}
