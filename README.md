# The-Redemption

- [The-Redemption](#the-redemption)
- [Terraform usage](#terraform-usage)
  * [Prerequisites](#prerequisites)
    + [AWS CLI installation](#aws-cli-installation)
    + [Terraform installation](#terraform-installation)
    + [S3 bucket to hold terraform state](#s3-bucket-to-hold-terraform-state)
- [Code process](#code-process)
  * [Networking](#networking)
    + [Deploy VPC](#deploy-vpc)
      - [Architecture](#architecture)
    + [Deploy VPC endpoint for private connection to AWS services](#deploy-vpc-endpoint-for-private-connection-to-aws-services)
  * [EKS cluster and Karpenter install](#eks-cluster-and-karpenter-install)
  * [Database and cache](#database-and-cache)
    + [Testing Aurora DB connection from pods](#testing-aurora-db-connection-from-pods)
  * [POD security with Pod Identity](#pod-security-with-pod-identity)
  * [SQS](#sqs)
  * [KEDA](#keda)
    + [ScaledObject definition](#scaledobject-definition)
  * [Pause pod](#pause-pod)
  * [Mock application](#mock-application)
  * [Load Testing in video](#load-testing-in-video)
- [List of improvement for prod ready Workload](#list-of-improvement-for-prod-ready-workload)
- [Sources:](#sources-)
  * [Technologies](#technologies)
  * [Architecture](#architecture-1)
  * [Terraform Modules](#terraform-modules)
  * [Security](#security)


# Terraform usage
```bash
cd Infra
terraform apply --target module.vpc --auto-approve
terraform apply --auto-approve

TF_OUTPUTS=$(terraform output -json)
export QUEUE_URL=$(echo $TF_OUTPUTS | jq -r '.sqs_queue_url.value')
export PGHOST=$(echo $TF_OUTPUTS | jq -r '.aurora_endpoint.value')
export SECRET_ID=$(echo $TF_OUTPUTS | jq -r '.aurora_secret_arn.value')
export KUBE_CONFIG=$(echo $TF_OUTPUTS | jq -r '.configure_kubectl.value')

$KUBE_CONFIG


envsubst < ../kubernetes/pod-sa.yaml| kubectl apply -f -
envsubst '${PGHOST} ${SECRET_ID}' < ../kubernetes/test-db.yaml | kubectl apply -f -

# KEDA installation
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
kubectl get pods -n keda

kubectl apply -f ../kubernetes/mock-test-cm.yaml
envsubst < ../kubernetes/mock-test-deploy.yaml | kubectl apply -f -
envsubst < ../kubernetes/keda-crds.yaml | kubectl apply -f -
envsubst < ../kubernetes/keda-scaled-object.yaml | kubectl apply -f -


# K6 installation
kubectl create configmap k6-test --from-file=../kubernetes/load-test.js -n deduction
kubectl run k6-load-test -n deduction -i --rm --image=grafana/k6 \
  --restart=Never \
  --overrides='{"spec": {"volumes": [{"name": "test-script", "configMap": {"name": "k6-test"}}], "containers": [{"name": "k6", "image": "grafana/k6", "command": ["k6", "run", "/scripts/load-test.js"], "volumeMounts": [{"name": "test-script", "mountPath": "/scripts"}]}]}}'


# check if Points have be substracted
envsubst '${PGHOST} ${SECRET_ID}' < ../kubernetes/check-db.yaml | kubectl apply -f -
kubectl logs aurora-admin-check -n deduction

envsubst < ../kubernetes/mock-test-deploy.yaml | kubectl delete -f -
envsubst < ../kubernetes/mock-test-cm.yaml | kubectl delete -f -
envsubst < ../kubernetes/keda-scaled-object.yaml | kubectl delete -f -
envsubst < ../kubernetes/keda-crds.yaml | kubectl delete -f -
envsubst '${PGHOST} ${SECRET_ID}' < ../kubernetes/test-db.yaml | kubectl delete -f -
envsubst < ../kubernetes/pod-sa.yaml| kubectl delete -f -

helm uninstall keda -n keda

terraform destroy
```

## Prerequisites

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
aws s3api put-bucket-encryption --bucket $BUCKET_NAME --region $REGION --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#Not usefull anymore use use_lock in bakend.tf instead
#aws dynamodb create-table --table-name terraform-state-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region $REGION
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
Improvement : add DB deletion protection
### Testing Aurora DB connection from pods

`kubectl run netshoot-debug --rm -it --image nicolaka/netshoot -- /bin/bash`

in the pod run those commands

```bash
export RDSHOST="redemption-db.cluster-cdo24w8gi7zq.eu-west-1.rds.amazonaws.com" 
export ELASTICACHE="master.redemption-cache.varra4.euw1.cache.amazonaws.com"
nc -zv $RDSHOST 5432 # test postregres connection
nc -zv $ELASTICACHE 6379 # test Redis connection
```

## POD security with Pod Identity
goal : allow pod to retrieve Aurora secret
use aws_eks_pod_identity_association resource in associattion with a k8s sa to inherit IAM permissions

kubectl apply -f kubernetes/pod-sa.yaml
kubectl apply -f kubernetes/test-db.yaml
kubectl exec -it aurora-admin-client -n deduction -- /bin/bash


## SQS 
SQS will help us queue messages as clients connect to the application to use their loyalty points so we can make a deduction of the points on the database.

It also protects us from app malfunction with the implementation of a retry process as well as a deadletter queue.

Number of SQS messages in the queue is our indicator to know if we need to scale the application using KEDA

## KEDA
KEDA will help us to scale the numbers of pod according to the number of messages in the queue allowing the Redemption app to scale on a given metric (number of messages in SQS) during load spikes

### ScaledObject definition

The KEDA ScaledObject will scale our redemption-worker (the pod treating SQS messages)
- number of replicas : 1-100
- check : every 5s
- allows us to scale 3 pods at a time (200% of the value) every 15s

## Pause pod
We define Pause Pods with low priorityClass (-1) to reserve cpu and memory artificially. Those pods will be evicted and replaced by the redemption-worker when needed since they have a higher priority class. Those pods will also warm up the next node needed to scale in seconds.

https://abozar-alizadeh.medium.com/the-kubernetes-overprovisioning-playbook-how-a-simple-pause-pod-can-eliminate-scaling-delays-in-0ec95688dbe3

## Mock application

In order to emulate the app processing the messages and writing in the database we mock application with 2 pods:
- redemption-api: emulates a client clicking on a button in the interface thats sends a message in SQS
- redemption-worker: emulates the backend that reads message and its content to allow loyalty point deduction from the user account in database

## Load Testing in video
you can find a load testing video here : https://www.youtube.com/watch?v=umzoblhi0hQ

The test could react faster to infrastructure change by modifying the kubernetes/load-test.js file and fine tuning the kubernetes/keda-scaled-object.yaml also the pods used as a mock for the API and the backend weren't already packaged as docker images nor the code was optimized for such test which make it slower than a test in a real environment but the proof of concept in addition to the load test shows the infrastructure answers the business need of handling 10x clients spikes on the platform. Thanks to SQS, KEDA, Karpenter and the pause pods working all together to handle the load.

# List of improvements for production ready workload
- Database : enable deletion protection + transaction table with transaction id for processed messages
- Create docker images instead of mock images which install the necessary packages at the startup of the pod
- SQS DLQ management : test with non working messages to check how DLQ works around it 
- Idempotency : randomly delete pods before they finish processing a message and check if transaction could be done and was processed only once
- Security : review all IAM roles for least privilege, install Secret managerCSI driver, create k8s network policies
- FinOps : fine tune the load testing, machine type and machine size, use spot instance
- Operational Toil: install a gitops solution like ArgoCD to automate new deployments and automate resource creation
- Observability : configure observability and alerting according to the defined SLIs and SLOs to stay informed of the system health
- Loadbalancing : implement a public loadbalancer to receive real traffic from internet (to not expose the infrastructure and the application to internet I decided to not deploy an ELB for the assignment)
- Implement mTLS : https://aws.amazon.com/fr/blogs/containers/enabling-mtls-with-alb-in-amazon-eks/


# Feedback on The-Redemption

Coming from a GCP background, it was refreshing to get back to AWS after a few years away from it. It was also a great challenge to implement an Event-Driven Architecture for the first time, especially on EKS.
I think the subject reflects your business needs well, and that's what motivated me to build and thoroughly test this infrastructure, which turned out to be a lot of fun. What I enjoyed most was load testing the setup and watching Karpenter and KEDA work together, scaling nodes as expected, even though the first attempt didn't go as planned.

Figuring out how to scale instantly during unexpected load spikes was particularly interesting, and it gave me the opportunity to get hands-on with Karpenter. That's actually why I chose to implement it myself rather than rely on the managed Karpenter available through EKS Auto Mode. Along the way, I also discovered new capabilities I hadn't planned on: for example, I started implementing IRSA before finding that Pod Identity was now the native AWS  approach.

I come out of this assignment with new hands-on skills and I'm proud to have gotten all the tools I used to work together to meet the business needs of autoscaling, availability, and resiliency.

Of course, this remains a POC, and several topics would still need to be addressed to bring this architecture to production. Some of my ideas for a second version are listed in the [List of improvement for prod ready Workload](#list-of-improvement-for-prod-ready-workload) section. I'd be glad to walk you through the implementation and hear your feedback.

If these are the kind of challenge your team faces day to day, I'd genuinely love the opportunity to work with you. Thank you for taking the time to review my work.

Sincerely,
Maxence CARLIN

# Sources:
## Technologies
https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/

https://keda.sh/docs/2.20/deploy/

github.com/aws-samples/karpenter-blueprints/blob/main/README.md

## Architecture
https://docs.aws.amazon.com/solutions/event-driven-application-autoscaling-with-keda-on-amazon-eks/

https://abozar-alizadeh.medium.com/the-kubernetes-overprovisioning-playbook-how-a-simple-pause-pod-can-eliminate-scaling-delays-in-0ec95688dbe3


## Terraform Modules
https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/modules/vpc-endpoints/main.tf

https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter

https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest

https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest


## Security
https://aws.amazon.com/fr/blogs/containers/enabling-mtls-with-alb-in-amazon-eks/

## Other
markdown table of content generator : https://ecotrust-canada.github.io/markdown-toc/