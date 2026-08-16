resource "aws_security_group" "aurora" {
  name        = "eks-to-aurora-sg"
  vpc_id      = module.vpc.vpc_id
  description = "Allow EKS to Aurora connection"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
}

resource "aws_security_group" "redis" {
  name        = "redis-sg"
  vpc_id      = module.vpc.vpc_id
  description = "Allow EKS to elasticache connection"

  
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
}

module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 10.0"

  name           = "redemption-db"
  engine         = "aurora-postgresql"
  engine_version = "17.5"
  
  vpc_id                 = module.vpc.vpc_id
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  cluster_instance_class = "db.t3.medium"
    instances = {
      one = {}
    }

    autoscaling_enabled      = true
    autoscaling_min_capacity = 1
    autoscaling_max_capacity = 5

  storage_encrypted   = true
  apply_immediately   = true

  enabled_cloudwatch_logs_exports = ["postgresql"]
  master_username             = "mcaadmin"
  
  manage_master_user_password = true 
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet-group"
  subnet_ids = module.vpc.database_subnets
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "redemption-cache"
  description                = "Redis for redemption idempotency"
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