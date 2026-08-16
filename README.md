# The-Redemption

## Prerequisite

### AWS CLI installation
[AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

```bash
sudo apt update
sudo apt upgrade -y
curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash

aws configure
```

### Terraform installation

[Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint

gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt-get install terraform
```

### S3 bucket to hold terraform state

```bash
BUCKET_NAME="tf-state-redemption"
REGION="eu-west-1"

aws s3api create-bucket --bucket $BUCKET_NAME --region $REGION --create-bucket-configuration LocationConstraint=$REGION 
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled 
aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 
aws dynamodb create-table --table-name terraform-state-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region $REGION
#TODO CHECK BUCKET LOCK with dynamo --> deprecated
```
# Code process
## Networking
### Deploy VPC
https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest

#### Architecture 

- 1 VPC, 3 AZ, 3 subnet
- public subnet for NAT
- Private subnet for resources
- Private subnet for Database
- One Nat gateway for test purposes
- EKS cluster with karpenter submodule installed to manage node provisionning
- Aurora DB with autoscaling read replicas + elasticache to handle the load spikes 
- 

### Deploy VPC endpoint for private connection to AWS services
https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/examples/complete/main.tf

## EKS cluster and Karpenter install

https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/20.37.2?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls

https://github.com/aws-samples/karpenter-blueprints/blob/main/cluster/terraform/main.tf


Alias to check karpenter logs:

`alias kl="kubectl -n karpenter logs -l app.kubernetes.io/name=karpenter --all-containers=true -f --tail=20"` 

## Database and cache
Aurora DB: [Aurora module link](https://registry.terraform.io/modules/terraform-aws-modules/rds-aurora/aws/9.16.1?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls)

Redis Cache: [Redis/elasticache resource link](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group)

Added security group to allow EKS to Aurora and elasticache connection
improvement : add DB deletion protection
### Testing Aurora DB connection from pods


`kubectl run netshoot-debug --rm -it --image nicolaka/netshoot -- /bin/bash`

in the pod run those commands

```bash
export RDSHOST="redemption-db.cluster-cdo24w8gi7zq.eu-west-1.rds.amazonaws.com" 
export ELASTICACHE="master.redemption-cache.varra4.euw1.cache.amazonaws.com"
nc -zv $RDSHOST 5432 # test postregres connection
nc -zv $ELASTICACHE 6379 # test Redis connection
```

## POD security with IRSA test
goal : allow pod to retrieve Aurora secret

kubectl apply -f kubernetes/pod-sa.yaml
kubectl apply -f kubernetes/test-db.yaml
kubectl exec -it aurora-admin-client -n deduction -- /bin/bash


in the pod
```bash
apk add --no-cache aws-cli postgresql17 bash && bash
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id $SECRET_ID --query SecretString --output text)
export PGUSER=$(echo $SECRET_JSON | jq -r .username)
export PGPASSWORD=$(echo $SECRET_JSON | jq -r .password)
psql
```

when in the postgres console:
```bash
CREATE TABLE loyalty_accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    points_balance INT NOT NULL CHECK (points_balance >= 0),
    tier VARCHAR(20) DEFAULT 'BRONZE',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO loyalty_accounts (first_name, last_name, email, points_balance, tier) VALUES
('Jean', 'Dupont', 'jean.dupont@example.com', 1500, 'BRONZE'),
('Marie', 'Curie', 'm.curie@example.com', 8200, 'GOLD'),
('Ada', 'Lovelace', 'ada.l@example.com', 450, 'BRONZE'),
('Alan', 'Turing', 'alan.turing@example.com', 12000, 'PLATINUM'),
('Grace', 'Hopper', 'grace.h@example.com', 3200, 'SILVER'),
('Nikola', 'Tesla', 'nikola.t@example.com', 0, 'BRONZE'),
('Margaret', 'Hamilton', 'margaret.h@example.com', 5600, 'GOLD'),
('Tim', 'Berners-Lee', 'tim.bl@example.com', 800, 'BRONZE'),
('Hedy', 'Lamarr', 'hedy.l@example.com', 4100, 'SILVER'),
('Linus', 'Torvalds', 'linus.t@example.com', 9500, 'PLATINUM');

SELECT * FROM loyalty_accounts;
```
# List of improvement for prod ready Workload
- Database : enable deletion protection

# Terraform usage
```bash
terraform apply --target module.vpc --auto-approve
terraform apply --auto-approve
```

# Sources:
https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/
https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/modules/vpc-endpoints/main.tf