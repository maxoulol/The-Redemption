resource "aws_security_group" "aurora" {
  name        = "eks-to-aurora-sg"
  vpc_id      = module.vpc.default_vpc_id
  description = "Allow EKS to Aurora connection"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }
}

resource "aws_security_group" "redis" {
  name        = "redis-sg"
  vpc_id      = module.vpc.default_vpc_id
description = "Allow EKS to Aurora connection"

  
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }
}

module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.0"

  name           = "points-database-prod"
  engine         = "aurora-postgresql"
  engine_version = "15.3"
  
  vpc_id                 = module.vpc.default_vpc_id
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  serverlessv2_scaling_configuration = {
    min_capacity = 0.5 
    max_capacity = 2 #16.0 
  }

  instances = {
    writer = {}
    reader = {}
  }

  storage_encrypted           = true
  master_username             = "mcaadmin"
  
  manage_master_user_password = true 
}

# 3. CACHE D'IDEMPOTENCE (ElastiCache Redis)
resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet-group"
  subnet_ids = module.vpc.database_subnets
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "points-cache"
  description                = "Redis for points idempotency"
  node_type                  = "cache.t4g.micro"
  port                       = 6379
  
  automatic_failover_enabled = true
  multi_az_enabled           = true
  num_cache_clusters         = 2
  
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
}