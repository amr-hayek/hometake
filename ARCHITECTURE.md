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