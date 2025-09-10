#!/bin/bash
set -euo pipefail

# Script to fix SSM agent on existing instances
echo "SSM Agent Fix Script"
echo "==================="

# Find running instances
echo "Finding instances..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=takehome" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text \
  --region us-east-1)

if [ -z "$INSTANCE_IDS" ]; then
  echo "No running instances found"
  exit 1
fi

echo "Found instances: $INSTANCE_IDS"

# Try to restart SSM agent on each instance
for instance_id in $INSTANCE_IDS; do
  echo "Attempting to restart SSM agent on $instance_id..."
  
  # Try to send a command to restart SSM agent
  if aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["sudo systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service","sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service","sleep 30","sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service"]' \
    --instance-ids $instance_id \
    --comment "Restart SSM agent" \
    --region us-east-1 \
    --output table; then
    echo "SSM restart command sent to $instance_id"
  else
    echo "Failed to send SSM command to $instance_id"
  fi
done

echo ""
echo "Waiting 2 minutes for SSM agents to restart..."
sleep 120

echo ""
echo "Checking SSM agent status..."
aws ssm describe-instance-information --region us-east-1 --query 'InstanceInformationList[*].{InstanceId:InstanceId,PingStatus:PingStatus,LastPingDateTime:LastPingDateTime}' --output table
