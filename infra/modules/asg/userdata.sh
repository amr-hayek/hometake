#!/bin/bash
set -euo pipefail

# Update system
yum update -y

# Install Docker
amazon-linux-extras install -y docker
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install SSM Agent (should be pre-installed on AL2023, but ensure it's running)
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# Install jq for JSON processing
yum install -y jq

# Create application directory
mkdir -p /opt/app
cd /opt/app

# Write compose template variables
cat > /opt/app/compose.vars.json <<EOF
{
  "ecr_repo_url": "${ecr_repo_url}",
  "image_tag": "latest",
  "region": "${region}"
}
EOF

# Write docker-compose wrapper script
cat > /usr/local/bin/docker-compose-wrapper <<'EOF'
#!/bin/bash
set -euo pipefail

cd /opt/app

# Get variables from compose.vars.json
ECR=$(jq -r .ecr_repo_url compose.vars.json)
TAG=$(jq -r .image_tag compose.vars.json)
REGION=$(jq -r .region compose.vars.json)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Generate docker-compose.yml from template
cat > /opt/app/docker-compose.yml <<YML
version: '3.8'

services:
  web:
    image: $${ECR}:$${TAG}
    container_name: hello-app
    ports:
      - "3000:3000"
    env_file:
      - .env
    environment:
      - NODE_ENV=production
      - PORT=3000
    restart: unless-stopped
    logging:
      driver: awslogs
      options:
        awslogs-region: $${REGION}
        awslogs-group: /takehome/app
        awslogs-stream: web-$${INSTANCE_ID}
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
YML

# Login to ECR
aws ecr get-login-password --region "$${REGION}" | docker login --username AWS --password-stdin "$${ECR%/*}"

# Get secrets and create .env file
aws secretsmanager get-secret-value --secret-id "${secrets_manager_name}" --query SecretString --output text > /opt/app/.env || echo "APP_SECRET=dev-secret" > /opt/app/.env

# Deploy application
docker-compose pull
docker-compose up -d

# Restart CloudWatch Agent
systemctl restart amazon-cloudwatch-agent || true

echo "Deployment completed successfully"
EOF

chmod +x /usr/local/bin/docker-compose-wrapper

# Write CloudWatch Agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
${cwagent_template}
EOF

# Start CloudWatch Agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Wait for SSM agent to register (this can take a few minutes)
echo "Waiting for SSM agent to register..."
for i in {1..30}; do
  if systemctl is-active --quiet amazon-ssm-agent; then
    echo "SSM agent is running"
    break
  fi
  echo "Waiting for SSM agent... attempt $i/30"
  sleep 10
done

# Initial deployment
/usr/local/bin/docker-compose-wrapper

echo "User data script completed successfully"
