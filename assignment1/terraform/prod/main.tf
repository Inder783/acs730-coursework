terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  backend "s3" {
    bucket       = "acs730-tfstate-622080298024"
    key          = "assignment1/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

module "web" {
  source = "../modules/web"

  environment   = "prod"
  vpc_cidr      = "10.30.0.0/16"
  instance_type = "t3.micro"
  app_version   = "v2"
}
