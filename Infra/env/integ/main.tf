module "network" {
  source = "../../modules/01-network"

  environment          = "integ"
  vpc_cidr             = "10.20.0.0/16"
  azs                  = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  public_subnet_cidrs  = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]
  private_database_subnet_cidrs = ["10.20.201.0/24", "10.20.202.0/24", "10.20.203.0/24"]
}