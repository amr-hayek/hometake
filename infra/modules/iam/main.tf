# IAM Role for EC2 instances
resource "aws_iam_role" "ec2" {
  name = "${var.project}-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom policy for ECR access
resource "aws_iam_policy" "ecr_access" {
  name        = "${var.project}-ecr-access"
  description = "Policy for ECR access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

# Custom policy for Secrets Manager access
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project}-secrets-access"
  description = "Policy for Secrets Manager access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:${var.secrets_manager_name}*"
        ]
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-instance-profile"
  role = aws_iam_role.ec2.name
  
  tags = var.tags
}

# Create Secrets Manager secret
resource "aws_secretsmanager_secret" "app" {
  name        = var.secrets_manager_name
  description = "Application environment variables"
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    APP_SECRET = "dev-secret-change-me"
    NODE_ENV   = "production"
  })
}
