aws_region = "ap-south-1"

project_name = "capstone-devops-cicd"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]

container_port = 80

jenkins_source_ip = "15.252.70.189/32"

desired_count = 1

alert_email = "mailtosinsha@gmail.com"
