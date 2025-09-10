# Deployment Guide

This guide provides detailed instructions for deploying the DevOps Takehome application from scratch.

## Prerequisites Checklist

- [ ] AWS account with admin permissions
- [ ] Domain name hosted in Route53
- [ ] Terraform v1.6+ installed
- [ ] AWS CLI v2 installed and configured
- [ ] GitHub repository created
- [ ] Docker installed (for local testing)

## Step 1: AWS Account Setup

1. **Create AWS Account** (if you don't have one)
   - Go to [AWS Console](https://aws.amazon.com/console/)
   - Create a new account or sign in

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
   - Note the hosted zone ID

2. **Update Name Servers**
   - Copy the name servers from Route53
   - Update your domain registrar with these name servers
   - Wait for DNS propagation (can take up to 48 hours)

## Step 3: Repository Setup

1. **Clone Repository**
   ```bash
   git clone <your-repo-url>
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
   email_alerts = "your-email@example.com"
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

1. **Commit and Push**
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
   - Visit `https://app.<your-domain>`
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
   - Update with your environment variables:
   ```json
   {
     "APP_SECRET": "Secret@411539",
     "NODE_ENV": "production",
     "DATABASE_URL": "your-database-url"
   }
   ```

2. **Redeploy Application**
   ```bash
   git push origin main
   ```

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
# Check Terraform state
cd infra && terraform show

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

**Warning**: This will delete all resources and data. Make sure to backup any important data first.

## Cost Estimation

Approximate monthly costs (us-east-1):
- t3.micro instances: $8.50/month each
- ALB: $16.20/month
- CloudWatch: $5-10/month
- Route53: $0.50/month per hosted zone
- ECR: $0.10/GB/month

Total: ~$30-50/month for 2 instances

## Security Best Practices

1. **Use IAM Roles**: Never hardcode credentials
2. **Least Privilege**: Grant minimum required permissions
3. **Enable MFA**: Use multi-factor authentication
4. **Regular Updates**: Keep AMIs and dependencies updated
5. **Monitor Access**: Use CloudTrail for audit logs

## Next Steps

1. **Add Tests**: Implement unit and integration tests
2. **Blue/Green Deployment**: Set up canary deployments
3. **Database**: Add RDS or DynamoDB
4. **CDN**: Add CloudFront for static assets
5. **Backup**: Implement automated backups
6. **Monitoring**: Add custom metrics and dashboards
