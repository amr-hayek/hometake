Below is a complete, self-contained repository you can clone and use. It provisions AWS infrastructure (VPC, ALB+HTTPS via ACM+Route53, ASG with EC2 running Docker Compose, ECR, IAM, CloudWatch metrics/alarms), and sets up CI/CD with GitHub Actions to build/push to ECR and deploy via SSM RunCommand.

> **Assumptions (for full automation):**
>
> * Your domain is hosted in **Route53**. We’ll issue an ACM cert and validate via Route53 automatically.
> * You’ll create **two GitHub secrets**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (or wire OIDC later), and set a few repo variables in the workflow.
> * You’ll create **one Secrets Manager secret** (name provided in `terraform.tfvars`), or let Terraform create a placeholder.
> * Region defaults to `us-east-1`. Adjust as needed.

---

# Repo Tree

```
repo/
  README.md
  Makefile
  app/
    package.json
    server.js
    Dockerfile
  deploy/
    docker-compose.yml.tftpl
    cwagent-config.json.tftpl
  .github/workflows/
    ci-cd.yml
  infra/
    versions.tf
    providers.tf
    main.tf
    variables.tf
    outputs.tf
    terraform.tfvars.example
    modules/
      vpc/
        main.tf
        variables.tf
        outputs.tf
      ecr/
        main.tf
        variables.tf
        outputs.tf
      iam/
        main.tf
        variables.tf
        outputs.tf
      acm/
        main.tf
        variables.tf
        outputs.tf
      alb/
        main.tf
        variables.tf
        outputs.tf
      asg/
        main.tf
        variables.tf
        outputs.tf
      monitoring/
        main.tf
        variables.tf
        outputs.tf
```

---

## README.md

````md
# EC2 + Docker Compose + ALB/HTTPS + ASG (Terraform) with CI/CD (GitHub Actions)

This repository deploys a production-ish, minimal web service using:
- **AWS**: VPC, ALB (HTTPS via **ACM**), **Auto Scaling Group** with EC2, **ECR**, **CloudWatch** metrics & alarms, **Secrets Manager**, **SSM** for zero-SSH deploys.
- **Docker Compose** on instances (no EKS).
- **GitHub Actions** for CI (build & push image to ECR) and CD (SSM RunCommand rollout).

## Quick Start
### 0) Prereqs
- AWS account with Admin permissions.
- Your domain hosted in Route53 (e.g., `example.com`).
- Terraform v1.6+ and AWS CLI v2 installed.
- GitHub repo for this code.

### 1) Clone & Configure
```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# edit infra/terraform.tfvars with your domain/zone and optional secret name
````

Set **GitHub Secrets** in your repo:

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
  (Alternatively set up OIDC later.)

Optional **GitHub Variables** (or edit workflow):

* `AWS_REGION` (default `us-east-1`)

### 2) Terraform Apply

```bash
cd infra
terraform init
terraform apply -auto-approve
```

Outputs will include:

* `app_url` – your HTTPS URL
* `alb_dns_name` – ALB DNS
* `ecr_repo_url` – for CI build/push

### 3) First Build & Deploy (CI/CD)

Push to `main` branch to trigger the workflow. It will:

* Build Docker image
* Push to ECR
* Use SSM to instruct all instances to pull & restart via docker compose

Visit `https://app.<your_domain>` and you should see the hello page.

### 4) Secrets

* If you provided `secrets_manager_name` in tfvars, Terraform grants the instance role read access. Update the secret value in AWS → Secrets Manager. The deploy process fetches it into `/opt/app/.env`.

## Blue/Green (optional, simple)

We ship with **blue** target group (port 3000). For canary/blue-green, you can define a second compose service on port 3001 and a second TG (green). Listener rules are ready to accept weighted forwarding – see `infra/modules/alb` and notes in the workflow.

## Costs & Notes

* Public subnets only (to avoid NAT costs). EC2 is reachable via ALB only; SSH is closed. Use SSM Session Manager if needed.
* CloudWatch provides most of what you need. Add Managed Grafana later if desired.

## Tear Down

```bash
cd infra
terraform destroy
```

```
```

---

## Makefile

```makefile
.PHONY: plan apply destroy fmt lint

init:
	cd infra && terraform init

plan:
	cd infra && terraform plan -out=tf.plan

apply:
	cd infra && terraform apply -auto-approve

destroy:
	cd infra && terraform destroy -auto-approve

fmt:
	terraform fmt -recursive
```

````

---

## app/package.json
```json
{
  "name": "hello-app",
  "version": "1.0.0",
  "main": "server.js",
  "license": "MIT",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
````

## app/server.js

```js
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send(`Hello from Docker on EC2! Secret: ${process.env.APP_SECRET ? 'set' : 'not set'}\n`);
});

app.get('/health', (req, res) => res.status(200).send('OK'));

app.listen(port, () => console.log(`App listening on port ${port}`));
```

## app/Dockerfile

```dockerfile
FROM node:20-alpine
WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm i --omit=dev
COPY . .
ENV PORT=3000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["npm", "start"]
```

---

## deploy/docker-compose.yml.tftpl

```yaml
services:
  web:
    image: ${ecr_repo_url}:${image_tag}
    ports:
      - "3000:3000"
    env_file:
      - .env
    logging:
      driver: awslogs
      options:
        awslogs-region: ${region}
        awslogs-group: /takehome/app
        awslogs-stream: web
```

## deploy/cwagent-config.json.tftpl

```json
{
  "agent": { "metrics_collection_interval": 30, "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/agent.log" },
  "metrics": {
    "append_dimensions": { "AutoScalingGroupName": "${asg_name}", "InstanceId": "${instance_id}" },
    "metrics_collected": {
      "cpu": { "resources": ["*"], "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_system", "cpu_usage_user"], "totalcpu": true },
      "mem": { "measurement": ["mem_used_percent"] },
      "disk": { "resources": ["*"], "measurement": ["used_percent"], "ignore_file_system_types": ["sysfs", "devtmpfs", "overlay"] },
      "netstat": { "measurement": ["tcp_established", "tcp_time_wait"] }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          { "file_path": "/var/log/cloud-init-output.log", "log_group_name": "/takehome/system", "log_stream_name": "cloud-init" }
        ]
      }
    }
  }
}
```

---

## .github/workflows/ci-cd.yml

```yaml
name: CI-CD
on:
  push:
    branches: ["main"]

env:
  AWS_REGION: us-east-1
  IMAGE_TAG: ${{ github.sha }}

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Get Terraform outputs
        id: tf
        run: |
          cd infra
          echo "ecr_repo_url=$(terraform output -raw ecr_repo_url)" >> $GITHUB_OUTPUT
          echo "asg_tag_key=$(terraform output -raw asg_tag_key)" >> $GITHUB_OUTPUT
          echo "asg_tag_value=$(terraform output -raw asg_tag_value)" >> $GITHUB_OUTPUT

      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build & Push
        env:
          ECR: ${{ steps.tf.outputs.ecr_repo_url }}
        run: |
          docker build -t $ECR:${{ env.IMAGE_TAG }} -t $ECR:latest ./app
          docker push $ECR:${{ env.IMAGE_TAG }}
          docker push $ECR:latest

      - name: Rolling Deploy via SSM RunCommand
        env:
          ECR: ${{ steps.tf.outputs.ecr_repo_url }}
          ASG_TAG_KEY: ${{ steps.tf.outputs.asg_tag_key }}
          ASG_TAG_VALUE: ${{ steps.tf.outputs.asg_tag_value }}
        run: |
          # Find instance IDs by tag
          IDS=$(aws ec2 describe-instances \
            --filters "Name=tag:${ASG_TAG_KEY},Values=${ASG_TAG_VALUE}" "Name=instance-state-name,Values=running" \
            --query 'Reservations[].Instances[].InstanceId' --output text)

          if [ -z "$IDS" ]; then echo "No running instances found"; exit 1; fi

          COMMAND='#!/bin/bash\nset -euo pipefail\nexport AWS_DEFAULT_REGION=${{ env.AWS_REGION }}\nECR=${ECR}\nIMAGE_TAG=${{ env.IMAGE_TAG }}\naws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin ${ECR%/*}\ncd /opt/app\nsed -i "s|image_tag\": \".*\"|image_tag\": \"'"$IMAGE_TAG"'\"|" /opt/app/compose.vars.json || true\n/usr/local/bin/docker-compose-wrapper'

          aws ssm send-command \
            --document-name "AWS-RunShellScript" \
            --parameters commands=["$COMMAND"] \
            --instance-ids $IDS \
            --comment "Deploy ${ECR}:${{ env.IMAGE_TAG }}" \
            --output text
```

> The remote wrapper `/usr/local/bin/docker-compose-wrapper` is created by cloud-init and will: regenerate `docker-compose.yml` from template vars, `docker compose pull`, `docker compose up -d`, and restart the CloudWatch Agent if needed.

---

# Terraform

## infra/versions.tf

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
  }
}
```

## infra/providers.tf

```hcl
provider "aws" {
  region = var.region
}
```

## infra/variables.tf

```hcl
variable "project" { default = "takehome" }
variable "region"  { default = "us-east-1" }

variable "domain_name" { description = "Root domain in Route53" }
variable "subdomain"   { description = "Subdomain for app", default = "app" }

variable "instance_type" { default = "t3.micro" }
variable "desired_capacity" { default = 1 }
variable "min_size" { default = 1 }
variable "max_size" { default = 3 }

variable "secrets_manager_name" { description = "Name of AWS Secrets Manager secret for app env", default = "takehome/app" }
```

## infra/outputs.tf

```hcl
output "alb_dns_name" { value = module.alb.alb_dns_name }
output "app_url"      { value = "https://${var.subdomain}.${var.domain_name}" }
output "ecr_repo_url" { value = module.ecr.repo_url }
output "asg_tag_key"  { value = "Project" }
output "asg_tag_value"{ value = var.project }
```

## infra/terraform.tfvars.example

```hcl
project = "takehome"
region  = "us-east-1"

# Your Route53 hosted zone root domain
domain_name = "example.com"
subdomain   = "app"

# Optional: provide an existing secret name, or keep default
secrets_manager_name = "takehome/app"
```

## infra/main.tf

```hcl
locals {
  tags = {
    Project = var.project
  }
}

module "vpc" {
  source = "./modules/vpc"
  project = var.project
  tags    = local.tags
}

module "ecr" {
  source  = "./modules/ecr"
  project = var.project
  tags    = local.tags
}

module "iam" {
  source               = "./modules/iam"
  project              = var.project
  ecr_repo_arn         = module.ecr.repo_arn
  secrets_manager_name = var.secrets_manager_name
  tags                 = local.tags
}

module "acm" {
  source      = "./modules/acm"
  domain_name = var.domain_name
  subdomain   = var.subdomain
  tags        = local.tags
}

module "alb" {
  source         = "./modules/alb"
  project        = var.project
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  cert_arn       = module.acm.cert_arn
  tags           = local.tags
}

module "asg" {
  source              = "./modules/asg"
  project             = var.project
  vpc_id              = module.vpc.vpc_id
  public_subnets      = module.vpc.public_subnets
  instance_type       = var.instance_type
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  ec2_role_name       = module.iam.ec2_role_name
  ec2_instance_profile= module.iam.ec2_instance_profile
  target_group_arn    = module.alb.tg_blue_arn
  region              = var.region
  ecr_repo_url        = module.ecr.repo_url
  secrets_manager_name= var.secrets_manager_name
  alb_sg_id           = module.alb.alb_sg_id
  tags                = local.tags
}

module "monitoring" {
  source   = "./modules/monitoring"
  project  = var.project
  alb_arn  = module.alb.alb_arn
  tg_arn   = module.alb.tg_blue_arn
  asg_name = module.asg.asg_name
  tags     = local.tags
}

# Route53 record for app subdomain → ALB
resource "aws_route53_record" "app" {
  zone_id = module.acm.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"
  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
```

---

### modules/vpc

#### infra/modules/vpc/variables.tf

```hcl
variable "project" {}
variable "tags" { type = map(string) }
```

#### infra/modules/vpc/main.tf

```hcl
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.tags, { Name = "${var.project}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = var.tags
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = merge(var.tags, { Name = "${var.project}-public-${count.index}" })
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = var.tags
}

resource "aws_route" "default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "a" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

#### infra/modules/vpc/outputs.tf

```hcl
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnets" { value = aws_subnet.public[*].id }
```

---

### modules/ecr

#### infra/modules/ecr/variables.tf

```hcl
variable "project" {}
variable "tags" { type = map(string) }
```

#### infra/modules/ecr/main.tf

```hcl
resource "aws_ecr_repository" "repo" {
  name = "${var.project}-web"
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}
```

#### infra/modules/ecr/outputs.tf

```hcl
output "repo_url" { value = aws_ecr_repository.repo.repository_url }
output "repo_arn" { value = aws_ecr_repository.repo.arn }
```

---

### modules/iam

#### infra/modules/iam/variables.tf

```hcl
variable "project" {}
variable "tags" { type = map(string) }
variable "ecr_repo_arn" {}
variable "secrets_manager_name" {}
```

#### infra/modules/iam/main.tf

```hcl
resource "aws_iam_role" "ec2" {
  name = "${var.project}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cwagent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy" "ecr_read" {
  name   = "${var.project}-ecr-read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read_attach" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ecr_read.arn
}

resource "aws_iam_policy" "secrets_read" {
  name   = "${var.project}-secrets-read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["secretsmanager:GetSecretValue"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_read_attach" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.secrets_read.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-instance-profile"
  role = aws_iam_role.ec2.name
}
```

#### infra/modules/iam/outputs.tf

```hcl
output "ec2_role_name" { value = aws_iam_role.ec2.name }
output "ec2_instance_profile" { value = aws_iam_instance_profile.ec2.name }
```

---

### modules/acm

#### infra/modules/acm/variables.tf

```hcl
variable "domain_name" {}
variable "subdomain" {}
variable "tags" { type = map(string) }
```

#### infra/modules/acm/main.tf

```hcl
data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "cert" {
  domain_name               = "${var.subdomain}.${var.domain_name}"
  validation_method         = "DNS"
  lifecycle { create_before_destroy = true }
  tags = var.tags
}

resource "aws_route53_record" "validation" {
  for_each = { for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    type   = dvo.resource_record_type
    record = dvo.resource_record_value
  } }
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
```

#### infra/modules/acm/outputs.tf

```hcl
output "cert_arn" { value = aws_acm_certificate_validation.cert.certificate_arn }
output "zone_id"  { value = data.aws_route53_zone.zone.zone_id }
```

---

### modules/alb

#### infra/modules/alb/variables.tf

```hcl
variable "project" {}
variable "vpc_id" {}
variable "public_subnets" { type = list(string) }
variable "cert_arn" {}
variable "tags" { type = map(string) }
```

#### infra/modules/alb/main.tf

```hcl
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB SG"
  vpc_id      = var.vpc_id
  ingress { from_port = 80,  to_port = 80,  protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0,   to_port = 0,   protocol = "-1",  cidr_blocks = ["0.0.0.0/0"] }
  tags = var.tags
}

resource "aws_lb" "this" {
  name               = "${var.project}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnets
  tags               = var.tags
}

resource "aws_lb_target_group" "blue" {
  name     = "${var.project}-tg-blue"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path = "/health"
    port = "3000"
  }
  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action { type = "redirect" redirect { port = "443" protocol = "HTTPS" status_code = "HTTP_301" } }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}
```

#### infra/modules/alb/outputs.tf

```hcl
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "alb_zone_id"  { value = aws_lb.this.zone_id }
output "alb_sg_id"    { value = aws_security_group.alb.id }
output "alb_arn"      { value = aws_lb.this.arn }
output "tg_blue_arn"  { value = aws_lb_target_group.blue.arn }
```

---

### modules/asg

#### infra/modules/asg/variables.tf

```hcl
variable "project" {}
variable "vpc_id" {}
variable "public_subnets" { type = list(string) }
variable "instance_type" {}
variable "desired_capacity" {}
variable "min_size" {}
variable "max_size" {}
variable "ec2_role_name" {}
variable "ec2_instance_profile" {}
variable "target_group_arn" {}
variable "region" {}
variable "ecr_repo_url" {}
variable "secrets_manager_name" {}
variable "alb_sg_id" {}
variable "tags" { type = map(string) }
```

#### infra/modules/asg/main.tf

```hcl
# EC2 SG: allow app ports from ALB SG only
resource "aws_security_group" "ec2" {
  name   = "${var.project}-ec2-sg"
  vpc_id = var.vpc_id
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  tags = var.tags
}

resource "aws_security_group_rule" "from_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2.id
  source_security_group_id = var.alb_sg_id
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]
  filter { name = "name" values = ["al2023-ami-*-x86_64"] }
}

# Render templates (compose + cwagent config)
data "template_file" "compose" {
  template = file("${path.root}/../deploy/docker-compose.yml.tftpl")
  vars = {
    ecr_repo_url = var.ecr_repo_url
    image_tag    = "latest"
    region       = var.region
  }
}

data "template_file" "cwagent" {
  template = file("${path.root}/../deploy/cwagent-config.json.tftpl")
  vars = {
    asg_name    = aws_autoscaling_group.this.name
    instance_id = "${"$$"}{instance_id}"
  }
}

# Cloud-init user data
locals {
  userdata = <<-EOF
  #!/bin/bash
  set -euo pipefail

  yum update -y || true
  # Install docker
  amazon-linux-extras enable docker || true
  yum install -y docker jq amazon-cloudwatch-agent
  systemctl enable docker && systemctl start docker

  # Install docker compose v2 plugin
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -L https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

  # Directories
  mkdir -p /opt/app
  cd /opt/app

  # Write compose template vars (used by wrapper)
  cat > /opt/app/compose.vars.json <<VARS
  {"ecr_repo_url":"${var.ecr_repo_url}","image_tag":"latest","region":"${var.region}"}
VARS

  # docker-compose wrapper regenerates compose from vars then pulls/ups
  cat >/usr/local/bin/docker-compose-wrapper <<'WRAP'
  #!/bin/bash
  set -euo pipefail
  cd /opt/app
  ECR=$(jq -r .ecr_repo_url compose.vars.json)
  TAG=$(jq -r .image_tag compose.vars.json)
  REGION=$(jq -r .region compose.vars.json)
  cat > /opt/app/docker-compose.yml <<YML
  ${replace(data.template_file.compose.rendered, "\n", "\\n")}
YML
  # login + secrets + deploy
  aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin ${var.ecr_repo_url%/*}
  # secrets -> .env
  aws secretsmanager get-secret-value --secret-id "${var.secrets_manager_name}" --query SecretString --output text > /opt/app/.env || echo "APP_SECRET=dev" > /opt/app/.env
  docker compose pull
  docker compose up -d
  systemctl restart amazon-cloudwatch-agent || true
  WRAP
  chmod +x /usr/local/bin/docker-compose-wrapper

  # CloudWatch Agent config
  cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CW
  ${replace(data.template_file.cwagent.rendered, "\n", "\\n")}
CW
  systemctl enable amazon-cloudwatch-agent
  systemctl start amazon-cloudwatch-agent || true

  # First deploy
  /usr/local/bin/docker-compose-wrapper || true

  EOF
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.project}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type
  iam_instance_profile { name = var.ec2_instance_profile }
  user_data = base64encode(local.userdata)
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.project}-ec2" })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = var.tags
  }
  tags = var.tags
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.project}-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.public_subnets
  health_check_type         = "ELB"
  health_check_grace_period = 120
  launch_template { id = aws_launch_template.this.id, version = "$Latest" }
  target_group_arns = [var.target_group_arn]
  tag { key = "Project", value = var.project, propagate_at_launch = true }
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification { predefined_metric_type = "ASGAverageCPUUtilization" }
    target_value = 60
  }
}
```

#### infra/modules/asg/outputs.tf

```hcl
output "asg_name" { value = aws_autoscaling_group.this.name }
output "ec2_sg_id" { value = aws_security_group.ec2.id }
```

---

### modules/monitoring

#### infra/modules/monitoring/variables.tf

```hcl
variable "project" {}
variable "alb_arn" {}
variable "tg_arn" {}
variable "asg_name" {}
variable "tags" { type = map(string) }
```

#### infra/modules/monitoring/main.tf

```hcl
resource "aws_cloudwatch_log_group" "app" {
  name              = "/takehome/app"
  retention_in_days = 14
  tags = var.tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      { "type": "metric", "x":0, "y":0, "width":12, "height":6,
        "properties": { "metrics": [["AWS/EC2","CPUUtilization","AutoScalingGroupName", var.asg_name]], "stat":"Average", "region":"us-east-1", "title":"ASG CPU" } },
      { "type": "metric", "x":12,"y":0, "width":12, "height":6,
        "properties": { "metrics": [["AWS/ApplicationELB","RequestCount","LoadBalancer", var.alb_arn]], "stat":"Sum", "region":"us-east-1", "title":"ALB Requests" } }
    ]
  })
}

# Alarms
resource "aws_sns_topic" "alerts" { name = "${var.project}-alerts" }

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { TargetGroup = var.tg_arn }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

#### infra/modules/monitoring/outputs.tf

```hcl
output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }
```

---

# Notes

* On first boot, user-data installs Docker, CloudWatch Agent, docker compose plugin, writes a small wrapper, generates `docker-compose.yml` from the Terraform template, fetches the secret to `.env`, and starts the container. The CI pipeline later updates `compose.vars.json` with the new image tag, then calls the wrapper via SSM on all instances.
* You can extend to add a **green** Target Group on port `3001` and a second SG rule; then in CI, add ALB weight shifting.
* Replace instance type if you need more RAM/CPU.

```
```
