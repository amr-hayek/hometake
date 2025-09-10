# DevOps Takehome - Scalable Web Application

This repository deploys a production-ready web application using:
- **AWS**: VPC, ALB (HTTPS via ACM), Auto Scaling Group with EC2, ECR, CloudWatch metrics & alarms, Secrets Manager, SSM for zero-SSH deploys
- **Docker Compose** on EC2 instances (no EKS)
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

## Prerequisites

- AWS account with Admin permissions
- Your domain hosted in Route53 (e.g., `example.com`)
- Terraform v1.6+ and AWS CLI v2 installed
- GitHub repository for this code
- Docker installed locally (for testing)

## Step-by-Step Deployment

### 1) Clone and Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd devops-takehome

# Copy and configure Terraform variables
cp infra/terraform.tfvars.example infra/terraform.tfvars
```

Edit `infra/terraform.tfvars` with your configuration:
```hcl
# Your Route53 hosted zone domain
domain_name = "yourdomain.com"
subdomain   = "app"

# Optional: Email for CloudWatch alerts
email_alerts = "your-email@example.com"
```

### 2) Configure GitHub Secrets

In your GitHub repository, go to Settings → Secrets and variables → Actions, and add:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

### 3) Deploy Infrastructure

```bash
# Initialize Terraform
make init

# Review the plan
make plan

# Deploy infrastructure
make apply
```

This will create:
- VPC with public subnets
- Application Load Balancer with HTTPS
- Auto Scaling Group with EC2 instances
- ECR repository for Docker images
- CloudWatch monitoring and alerts
- IAM roles and policies
- Route53 DNS records

### 4) First Deployment

Push to the `main` branch to trigger the CI/CD pipeline:

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

The pipeline will:
1. Build the Docker image
2. Push to ECR
3. Deploy to all EC2 instances via SSM
4. Run health checks

### 5) Verify Deployment

Visit your application at: `https://app.<your-domain>`

You should see a JSON response with application information.

## Monitoring & Observability

### CloudWatch Dashboard
Access the dashboard at: [CloudWatch Console](https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards)

Or use: `make status` to get the dashboard URL.

### Metrics Tracked
- **CPU Utilization**: EC2 instance CPU usage
- **Request Count**: ALB request metrics
- **Response Time**: ALB target response time
- **HTTP Status Codes**: 2xx, 4xx, 5xx response counts

### Alerts
- **5xx Errors**: Triggers when ALB returns 5xx errors
- **High CPU**: Triggers when CPU usage > 80%
- **High Response Time**: Triggers when response time > 2 seconds

### Logs
- **Application Logs**: `/takehome/app` log group
- **System Logs**: `/takehome/system` log group

View logs with: `make logs`

## Secrets Management

The application automatically fetches secrets from AWS Secrets Manager:

1. Go to AWS Console → Secrets Manager
2. Find the secret: `takehome/app`
3. Update the secret value with your environment variables:

```json
{
  "APP_SECRET": "your-secret-value",
  "NODE_ENV": "production",
  "DATABASE_URL": "your-db-url"
}
```

## Application Endpoints

- **Root**: `GET /` - Application information
- **Health**: `GET /health` - Health check endpoint
- **Metrics**: `GET /metrics` - Application metrics

## Scaling

The Auto Scaling Group automatically scales based on CPU utilization:
- **Scale Up**: When CPU > 70% for 5 minutes
- **Scale Down**: When CPU < 70% for 5 minutes
- **Min Instances**: 1
- **Max Instances**: 5 (configurable)

## Blue/Green Deployment

The infrastructure supports blue/green deployments:
- Currently configured with blue target group (port 3000)
- For canary deployments, add a green target group on port 3001
- Update ALB listener rules to shift traffic between target groups

## Cost Optimization

- **Public Subnets Only**: No NAT Gateway costs
- **t3.micro Instances**: Free tier eligible
- **CloudWatch Logs**: 14-day retention for app logs, 7-day for system logs
- **Auto Scaling**: Scales down during low usage

## Troubleshooting

### Check Infrastructure Status
```bash
make status
```

### View Application Logs
```bash
make logs
```

### Manual Deployment
```bash
# SSH to an instance (if needed)
aws ssm start-session --target <instance-id>

# Run deployment manually
/usr/local/bin/docker-compose-wrapper
```

### Common Issues

1. **Certificate Validation Failed**
   - Ensure your domain is hosted in Route53
   - Check that the hosted zone exists

2. **Instances Not Scaling**
   - Check CloudWatch metrics
   - Verify ASG health checks

3. **Application Not Responding**
   - Check ALB target group health
   - Verify security group rules
   - Check application logs

## Security Considerations

- **IAM Roles**: Least privilege access
- **Security Groups**: Restrictive inbound rules
- **HTTPS Only**: HTTP redirects to HTTPS
- **Secrets**: Stored in AWS Secrets Manager
- **No SSH Access**: Use SSM Session Manager if needed

## Cleanup

To destroy all resources:
```bash
make destroy
```

**Warning**: This will delete all resources and data. Make sure to backup any important data first.

## File Structure

```
├── README.md                    # This file
├── Makefile                     # Build and deployment commands
├── app/                         # Node.js application
│   ├── package.json
│   ├── server.js
│   ├── Dockerfile
│   └── .dockerignore
├── deploy/                      # Deployment templates
│   ├── docker-compose.yml.tftpl
│   └── cwagent-config.json.tftpl
├── .github/workflows/           # CI/CD pipeline
│   └── ci-cd.yml
└── infra/                       # Terraform infrastructure
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── modules/                 # Terraform modules
        ├── vpc/                 # VPC and networking
        ├── ecr/                 # Container registry
        ├── iam/                 # IAM roles and policies
        ├── acm/                 # SSL certificates
        ├── alb/                 # Load balancer
        ├── asg/                 # Auto Scaling Group
        └── monitoring/          # CloudWatch monitoring
```

## Technology Choices

### Why These Technologies?

1. **Docker + EC2 vs EKS**: Simpler setup, lower cost, easier to understand
2. **CloudWatch vs Zabbix**: Native AWS integration, no additional infrastructure
3. **ACM + Route53 vs Nginx Proxy Manager**: Automatic certificate management, no additional server
4. **AWS Secrets Manager**: Native AWS service, automatic rotation support
5. **GitHub Actions**: Free for public repos, easy integration

### Trade-offs

- **EKS**: More complex but better for microservices
- **Zabbix**: More features but requires additional infrastructure
- **Nginx Proxy Manager**: More control but additional maintenance
- **External Secrets**: More complex but supports multiple backends

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
