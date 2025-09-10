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
- **AMI**: Amazon Linux 2023
- **Features**:
  - Docker and Docker Compose
  - CloudWatch Agent
  - SSM Agent for remote management
  - IAM role for AWS service access

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

## Security Architecture

### Network Security
- **Security Groups**: Restrictive inbound/outbound rules
- **VPC**: Isolated network environment
- **HTTPS Only**: All traffic encrypted in transit

### Access Control
- **IAM Roles**: Least privilege access
- **No SSH**: SSM Session Manager for access
- **Secrets**: AWS Secrets Manager integration

### Data Protection
- **Encryption**: TLS 1.2 for data in transit
- **Secrets**: Encrypted at rest in Secrets Manager
- **Logs**: Encrypted in CloudWatch

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

### Vertical Scaling
- **Instance Types**: Easy to change
- **Resource Monitoring**: CloudWatch metrics
- **Performance Tuning**: Based on metrics

## Cost Optimization

### Resource Optimization
- **t3.micro**: Free tier eligible
- **Public Subnets**: No NAT Gateway costs
- **Log Retention**: Configurable retention periods
- **Auto Scaling**: Scale down during low usage

### Monitoring Costs
- **CloudWatch**: Pay for what you use
- **ALB**: Pay per hour and per LCU
- **ECR**: Pay per GB stored

## Disaster Recovery

### High Availability
- **Multi-AZ**: Instances across availability zones
- **Health Checks**: Automatic replacement of unhealthy instances
- **Auto Scaling**: Maintains desired capacity

### Backup Strategy
- **Infrastructure**: Terraform state management
- **Application**: Container images in ECR
- **Configuration**: Version controlled in Git

## Future Enhancements

### Potential Improvements
1. **Database**: Add RDS or DynamoDB
2. **CDN**: CloudFront for static assets
3. **Blue/Green**: Implement canary deployments
4. **Microservices**: Split into multiple services
5. **Service Mesh**: Istio for service communication
6. **Observability**: Distributed tracing with X-Ray
