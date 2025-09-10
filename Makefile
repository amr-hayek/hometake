.PHONY: init plan apply destroy fmt lint help

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	cd infra && terraform init

plan: ## Plan Terraform changes
	cd infra && terraform plan -out=tf.plan

apply: ## Apply Terraform changes
	cd infra && terraform apply -auto-approve

destroy: ## Destroy all infrastructure
	cd infra && terraform destroy -auto-approve

fmt: ## Format Terraform files
	terraform fmt -recursive

lint: ## Lint Terraform files
	cd infra && terraform validate

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
