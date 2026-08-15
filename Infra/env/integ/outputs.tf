output "vpc_name" {
  value = module.network.vpc_name
}

output "vpc_id" {
  value       = module.network.vpc_id
}

output "database_subnets" {
  value       = module.network.private_subnets
}

output "private_subnets" {
  value       = module.network.private_subnets
}

output "public_subnets" {
  value       = module.network.private_subnets
}
