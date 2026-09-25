resource "aws_lb" "this" {
  name = "${var.project_name}-alb"
  load_balancer_type = "application"
  subnets = var.public_subnets
  security_groups = [var.alb_sg_id]
  tags = { Name = "${var.project_name}-alb", Environment = var.environment }
}
resource "aws_lb_target_group" "this" {
  name        = var.target_group_name
  port        = var.target_group_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port = 80
  protocol = "HTTP"
  default_action {
  type = "forward"

  forward {
    target_group {
      arn = aws_lb_target_group.this.arn
    }
  }
}
}
