moved {
  from = module.alb.aws_lb_target_group.this
  to   = module.alb.aws_lb_target_group.blue
}

moved {
  from = module.ecs.aws_ecs_service.this
  to   = module.ecs.aws_ecs_service.blue
}
