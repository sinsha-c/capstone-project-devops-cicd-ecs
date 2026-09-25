module "vpc" {
  source = "./modules/vpc"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  container_port = var.container_port
}

module "ecr" {
  source = "./modules/ecr"
  project_name = var.project_name
}

module "iam" {
  source = "./modules/iam"
  project_name = var.project_name
}

module "cloudwatch" {
  source = "./modules/cloudwatch"
  project_name = var.project_name
}

module "alb" {
  source = "./modules/alb"
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnet_ids
  alb_sg_id      = module.security.alb_sg_id
  container_port = var.container_port

  target_group_name = "${var.project_name}-tg"
  target_group_port = var.container_port
}

module "ecs" {
  source = "./modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  private_subnets       = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security.ecs_sg_id
  target_group_arn      = module.alb.target_group_arn
  execution_role_arn    = module.iam.ecs_execution_role_arn
  ecr_repository_url    = module.ecr.repository_url
  log_group_name        = module.cloudwatch.log_group_name
  container_port        = var.container_port
  desired_count         = var.desired_count
}
