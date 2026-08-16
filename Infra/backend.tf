terraform {
  backend "s3" {
    bucket       = "tf-state-redemption"
    key          = "redemption/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}