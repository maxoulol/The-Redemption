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

#### architecture 
1 VPC, 3 AZ, 3 subnet

public subnet for NAT
Private subnet for resources
Private subnet for Database
One Nat gateway for test purposes
### Deploy VPC endpoint for private connection to AWS services
https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/examples/complete/main.tf

## EKS cluster and Karpenter install

https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/20.37.2?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls

https://github.com/aws-samples/karpenter-blueprints/blob/main/cluster/terraform/main.tf
`alias kl="kubectl -n karpenter logs -l app.kubernetes.io/name=karpenter --all-containers=true -f --tail=20"` Alias to check karpenter logs



# Sources:
https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/
https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/modules/vpc-endpoints/main.tf