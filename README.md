# DevOps Takehome - Scalable Web Application

This repository deploys a web application using:
- **AWS**: VPC, ALB (HTTPS via ACM), Auto Scaling Group with EC2, ECR, CloudWatch metrics & alarms, Secrets Manager, SSM for zero-SSH deploys
- **Docker Compose** on EC2 instances
- **GitHub Actions** for CI (build & push image to ECR) and CD (SSM RunCommand rollout)

## Architecture

```
Internet → Route53 → ALB (HTTPS) → EC2 Auto Scaling Group → Docker Compose → Node.js App
                                                      ↓
                                              CloudWatch Monitoring
                                                      ↓
                                              AWS Secrets Manager
```

## Features

✅ **Infrastructure as Code**: Complete Terraform setup with modular architecture  
✅ **Auto Scaling**: EC2 Auto Scaling Group with CPU-based scaling  
✅ **HTTPS**: SSL/TLS termination with ACM certificates  
✅ **Monitoring**: CloudWatch dashboards, metrics, and alerts  
✅ **CI/CD**: GitHub Actions pipeline with automated deployments  
✅ **Secrets Management**: AWS Secrets Manager integration  
✅ **Health Checks**: Application and infrastructure health monitoring  
✅ **Logging**: Centralized logging with CloudWatch Logs  
✅ **Security**: IAM roles, security groups, and least privilege access  

# Deployment Guide

This guide provides detailed instructions for deploying the DevOps Takehome application from scratch.

## Prerequisites Checklist

- [ ] AWS account with admin permissions
- [ ] Domain name hosted in Route53
- [ ] Terraform v1.6+ installed
- [ ] AWS CLI v2 installed and configured
- [ ] GitHub repository created

## Step 1: AWS Account Setup

1. **Create AWS Account** (if you don't have one)
   - Go to [AWS Console](https://aws.amazon.com/console/)
   - Create a new account or sign in. Generate access keys to be used through awc-cli

2. **Configure AWS CLI**
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, and region (us-east-1)
   ```

3. **Verify AWS Access**
   ```bash
   aws sts get-caller-identity
   ```

## Step 2: Domain Setup

1. **Route53 Hosted Zone**
   - Go to Route53 in AWS Console
   - Create a hosted zone for your domain

2. **Update Name Servers**
   - Copy the name servers from Route53
   - Update your domain registrar with these name servers
   - Wait for DNS propagation (can take up to 48 hours)

## Step 3: Repository Setup

1. **Clone Repository**
   ```bash
   git clone https://github.com/amr-hayek/hometake
   cd devops-takehome
   ```

2. **Configure Terraform Variables**
   ```bash
   cp infra/terraform.tfvars.example infra/terraform.tfvars
   ```

3. **Edit terraform.tfvars**
   ```hcl
   project = "takehome"
   region  = "us-east-1"
   
   # Your Route53 hosted zone domain
   domain_name = "yourdomain.com"
   subdomain   = "app"
   
   # Optional: Email for CloudWatch alerts
   email_alerts = "your-email@yourdomain.com"
   ```

## Step 4: GitHub Secrets

1. **Create IAM User for GitHub Actions**
   ```bash
   aws iam create-user --user-name github-actions
   aws iam attach-user-policy --user-name github-actions --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
   aws iam create-access-key --user-name github-actions
   ```

2. **Add GitHub Secrets**
   - Go to your GitHub repository
   - Settings → Secrets and variables → Actions
   - Add these secrets:
     - `AWS_ACCESS_KEY_ID`: From step above
     - `AWS_SECRET_ACCESS_KEY`: From step above

## Step 5: Infrastructure Deployment

1. **Initialize Terraform**
   ```bash
   make init
   ```

2. **Review Plan**
   ```bash
   make plan
   ```

3. **Deploy Infrastructure**
   ```bash
   make apply
   ```

   This will create:
   - VPC with public subnets
   - Application Load Balancer
   - Auto Scaling Group
   - ECR repository
   - CloudWatch monitoring
   - IAM roles and policies
   - Route53 DNS records

## Step 6: First Application Deployment

**Important**: Before deploying, you need to configure the ECR repository URL in your CI/CD pipeline:

1. **Get ECR Repository URL**
   ```bash
   make output
   ```
   Copy the `ecr_repo_url` value from the output.

2. **Update CI/CD Configuration**
   - **Option A**: Update `.github/workflows/ci-cd.yml` line 63 with your ECR URL
   - **Option B**: Set the `ECR_REPO_URL` variable in GitHub Actions repository settings

3. **Commit and Push**
   ```bash
   git add .
   git commit -m "Initial deployment"
   git push origin main
   ```

2. **Monitor GitHub Actions**
   - Go to Actions tab in GitHub
   - Watch the CI/CD pipeline execute
   - Check for any errors

3. **Verify Deployment**
   - Visit `https://app.<your-domain>.com`
   - You should see a JSON response

## Step 7: Post-Deployment Verification

1. **Check Infrastructure Status**
   ```bash
   make status
   ```

2. **View Application Logs**
   ```bash
   make logs
   ```

3. **Test Health Endpoint**
   ```bash
   curl https://app.<your-domain>/health
   ```

4. **Check CloudWatch Dashboard**
   - Go to CloudWatch in AWS Console
   - Find the "takehome-dashboard"
   - Verify metrics are being collected

## Step 8: Secrets Configuration

1. **Update Secrets Manager**
   - Go to AWS Console → Secrets Manager
   - Find the secret: `takehome/app`
   - Update with your environment variables

## Troubleshooting

### Common Issues

1. **Certificate Validation Failed**
   ```
   Error: Certificate validation failed
   ```
   - Ensure domain is hosted in Route53
   - Check hosted zone exists
   - Wait for DNS propagation

2. **No Running Instances**
   ```
   Error: No running instances found
   ```
   - Check ASG status in EC2 console
   - Verify launch template
   - Check CloudWatch logs

3. **Application Not Responding**
   - Check ALB target group health
   - Verify security group rules
   - Check application logs in CloudWatch

4. **GitHub Actions Failing**
   - Verify AWS credentials in GitHub secrets
   - Check IAM permissions
   - Review workflow logs

### Debug Commands

```bash
# Check running instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=takehome" "Name=instance-state-name,Values=running"

# Check ALB status
aws elbv2 describe-load-balancers --names takehome-alb

# Check ASG status
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names takehome-asg
```

## Cleanup

To destroy all resources:

```bash
make destroy
```

**Warning**: This will delete all resources and data.

## Cost Estimation

Approximate monthly costs (us-east-1):
- t3.micro instances: $8.50/month each
- ALB: $16.20/month
- CloudWatch: $5-10/month
- Route53: $0.50/month per hosted zone
- ECR: $0.10/GB/month

Total: ~$30-50/month for 2 instances

# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet                                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                    Route53                                      │
│              app.yourdomain.com                                │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│              Application Load Balancer                          │
│                    (HTTPS)                                      │
│              - SSL/TLS Termination                              │
│              - Health Checks                                    │
│              - Auto Scaling Integration                         │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│              Auto Scaling Group                                 │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   EC2-1     │  │   EC2-2     │  │   EC2-N     │            │
│  │             │  │             │  │             │            │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │            │
│  │ │ Docker  │ │  │ │ Docker  │ │  │ │ Docker  │ │            │
│  │ │ Compose │ │  │ │ Compose │ │  │ │ Compose │ │            │
│  │ │         │ │  │ │         │ │  │ │         │ │            │
│  │ │ Node.js │ │  │ │ Node.js │ │  │ │ Node.js │ │            │
│  │ │ App     │ │  │ │ App     │ │  │ │ App     │ │            │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                    VPC                                          │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                Public Subnets                           │   │
│  │                                                         │   │
│  │  ┌─────────────┐              ┌─────────────┐          │   │
│  │  │   AZ-1      │              │   AZ-2      │          │   │
│  │  │             │              │             │          │   │
│  │  │ - ALB       │              │ - ALB       │          │   │
│  │  │ - EC2       │              │ - EC2       │          │   │
│  │  └─────────────┘              └─────────────┘          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Route53 DNS
- **Purpose**: Domain name resolution
- **Configuration**: A record pointing to ALB
- **SSL**: ACM certificate validation via DNS

### 2. Application Load Balancer (ALB)
- **Purpose**: Traffic distribution and SSL termination
- **Features**:
  - HTTPS redirect (HTTP → HTTPS)
  - Health checks on `/health` endpoint
  - Target group management
  - Integration with Auto Scaling Group

### 3. Auto Scaling Group (ASG)
- **Purpose**: Automatic scaling based on demand
- **Configuration**:
  - Min: 1 instance
  - Max: 5 instances
  - Desired: 2 instances
  - Scaling: CPU-based (70% threshold)

### 4. EC2 Instances
- **Instance Type**: t3.micro (free tier eligible)
- **AMI**: Ubuntu
- **Features**:
  - Docker and Docker Compose
  - CloudWatch Agent
  - SSM Agent for remote management

### 5. Docker Compose
- **Purpose**: Container orchestration
- **Services**:
  - Node.js application
  - Health checks
  - Logging to CloudWatch

### 6. VPC Network
- **CIDR**: 10.0.0.0/16
- **Subnets**: 2 public subnets across AZs
- **Security**: Security groups with least privilege

## Data Flow

1. **User Request** → Route53 → ALB
2. **ALB** → Health check → Target Group
3. **Target Group** → EC2 Instance → Docker Container
4. **Application** → Response → ALB → User

## Monitoring & Observability

```
┌─────────────────────────────────────────────────────────────────┐
│                    CloudWatch                                   │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │  Dashboard  │  │   Metrics   │  │    Logs     │            │
│  │             │  │             │  │             │            │
│  │ - CPU Usage │  │ - ALB Reqs  │  │ - App Logs  │            │
│  │ - Response  │  │ - Response  │  │ - System    │            │
│  │   Time      │  │   Time      │  │   Logs      │            │
│  │ - HTTP Codes│  │ - Error     │  │             │            │
│  │             │  │   Rates     │  │             │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐                              │
│  │   Alarms    │  │   SNS       │                              │
│  │             │  │             │                              │
│  │ - High CPU  │  │ - Email     │                              │
│  │ - 5xx Errors│  │   Alerts    │                              │
│  │ - Response  │  │             │                              │
│  │   Time      │  │             │                              │
│  └─────────────┘  └─────────────┘                              │
└─────────────────────────────────────────────────────────────────┘
```

## CI/CD Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions                               │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │    Build    │  │    Push     │  │   Deploy    │            │
│  │             │  │             │  │             │            │
│  │ - Docker    │  │ - ECR       │  │ - SSM       │            │
│  │   Build     │  │   Push      │  │   Commands  │            │
│  │ - Tests     │  │ - Tag       │  │ - Health    │            │
│  │             │  │   Images    │  │   Checks    │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## Scalability Features

### Horizontal Scaling
- **Auto Scaling**: CPU-based scaling
- **Load Balancing**: Traffic distribution
- **Multi-AZ**: High availability

## Tradeoffs
- **Monitoring**: Initially, I was planning to use Zabbix to monitor the instances and provide realtime metrics.
While Zabbix offers more granular monitoring, CloudWatch provides sufficient observability for this small project.
- **Deployment Method**: Selected SSM over SSH for zero-touch deployments and it's natively supported.