resource "aws_security_group" "alb" {
  name = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id = var.vpc_id
  ingress { description = "HTTP" from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "${var.project_name}-alb-sg", Environment = var.environment }
}
resource "aws_security_group" "ecs" {
  name = "${var.project_name}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id = var.vpc_id
  ingress { description = "Application traffic from ALB" from_port = var.container_port to_port = var.container_port protocol = "tcp" security_groups = [aws_security_group.alb.id] }
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "${var.project_name}-ecs-sg", Environment = var.environment }
}
