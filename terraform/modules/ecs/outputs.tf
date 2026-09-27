output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "blue_service_name" {
  value = aws_ecs_service.blue.name
}

output "green_service_name" {
  value = aws_ecs_service.green.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}
