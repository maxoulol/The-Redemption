terraform {
  backend "s3" {
    bucket       = "tf-state-redemption"
    key          = "redemption/terraform.tfstate" # Chemin dans le bucket
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}