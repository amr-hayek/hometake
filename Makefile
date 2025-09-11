.PHONY: init plan apply destroy help

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@echo ' help            Show this help message'
	@echo ' init            Initialize Terraform'
	@echo ' plan            Plan Terraform changes'
	@echo ' apply           Apply Terraform changes'
	@echo ' destroy         Destroy all infrastructure'
	@echo ' output          Show Terraform outputs'
	@echo ' logs            Show application logs'
	@echo ' status          Show deployment status'

init: ## Initialize Terraform
	cd infra && terraform init

plan: ## Plan Terraform changes
	cd infra && terraform plan -out=tf.plan

apply: ## Apply Terraform changes
	cd infra && terraform apply -auto-approve

destroy: ## Destroy all infrastructure
	cd infra && terraform destroy -auto-approve


output: ## Show Terraform outputs
	cd infra && terraform output

logs: ## Show application logs
	aws logs tail /takehome/app --follow

status: ## Show deployment status
	@echo "=== Infrastructure Status ==="
	cd infra && terraform output
	@echo ""
	@echo "=== Running Instances ==="
	aws ec2 describe-instances --filters "Name=tag:Project,Values=takehome" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' --output table
