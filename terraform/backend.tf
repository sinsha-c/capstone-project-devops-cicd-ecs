terraform {
  backend "s3" {
    bucket = "sinsha-capstone-devops-tfstate"
    key    = "capstone/terraform.tfstate"
    region = "ap-south-1"
  }
}
