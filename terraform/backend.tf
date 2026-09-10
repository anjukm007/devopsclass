terraform {
  backend "s3" {
    bucket = "devopstest-terraform-state-490617"
    key    = "ecs/terraform.tfstate"
    region = "ap-south-1"
  }
}
