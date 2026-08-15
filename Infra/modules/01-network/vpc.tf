module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs              = var.azs
  private_subnets  = var.private_subnet_cidrs
  public_subnets   = var.public_subnet_cidrs
  database_subnets = var.private_database_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true # only one NAT gateway for testing purposes

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}