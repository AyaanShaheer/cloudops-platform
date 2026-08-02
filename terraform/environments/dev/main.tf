terraform {
  required_version = ">= 1.5.0"
}

module "vpc" {
  source = "../../modules/vpc"

  name       = "cloudops-dev-vpc"
  cidr_block = "10.0.0.0/16"
  az_count   = 3

  public_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
  ]

  private_subnet_cidrs = [
    "10.0.11.0/24",
    "10.0.12.0/24",
    "10.0.13.0/24",
  ]

  single_nat_gateway = true

  tags = {
    Environment = "dev"
    Project     = "cloudops-platform"
  }
}