resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.0"

  vpc_id = module.vpc.vpc_id

  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = module.vpc.private_subnets

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags            = { Name = "s3-vpc-endpoint" }
    }
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
    }
    sts = {
      service             = "sts"
      private_dns_enabled = true
    }
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
    }
  }
  depends_on = [ 
    aws_security_group.vpc_endpoints,
   ]
}

