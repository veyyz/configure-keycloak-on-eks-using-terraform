SHELL := /usr/bin/env bash

# Colors
RED := \033[0;31m
GRE := \033[0;32m
NC  := \033[0m

TERRAFORM_DIR := terraform
TFVARS := terraform.tfvars
CLUSTER_NAME := keycloak-demo
REGION := $(shell aws configure get region)

.PHONY: all local plan apply destroy clean update-kube-config deploy-keycloak

all: plan apply
	@echo "$(GRE) All tasks completed.$(NC)"

local:
	@echo "$(GRE) Checking Terraform installation...$(NC)"
	@if command -v terraform >/dev/null 2>&1; then \
		echo "$(GRE) Terraform version: $$(terraform version | head -n1)$(NC)"; \
	else \
		echo "$(RED) ERROR: Terraform not installed.$(NC)"; \
		exit 1; \
	fi

plan:
	@echo "$(GRE) Running terraform init/plan...$(NC)"
	@cd $(TERRAFORM_DIR); \
	terraform init -reconfigure; \
	terraform fmt; \
	terraform validate; \
	terraform plan -var-file=$(TFVARS)

apply:
	@echo "$(GRE) Applying terraform changes...$(NC)"
	@cd $(TERRAFORM_DIR); \
	terraform init -reconfigure; \
	terraform validate; \
	terraform apply --auto-approve -var-file=$(TFVARS)

update-kube-config:
	@echo "$(GRE) Updating kubeconfig for cluster $(CLUSTER_NAME)...$(NC)"
	@if [ -z "$(REGION)" ]; then echo "$(RED) AWS Region not set.$(NC)"; exit 1; fi
	@aws eks update-kubeconfig --name $(CLUSTER_NAME) --region $(REGION)

deploy-keycloak:
	@echo "$(GRE) Re-applying terraform to deploy Keycloak...$(NC)"
	@cd $(TERRAFORM_DIR); \
	terraform apply --auto-approve -var-file=$(TFVARS)

destroy:
	@echo "$(RED) WARNING: Destroying all terraform-managed resources.$(NC)"
	@if [ "$(CONFIRM)" != "YES" ]; then \
		echo "$(RED) Add CONFIRM=YES to proceed.$(NC)"; \
		exit 1; \
	fi
	@cd $(TERRAFORM_DIR); \
	terraform init -reconfigure; \
	terraform validate; \
	terraform destroy --auto-approve -var-file=$(TFVARS)

clean:
	@echo "$(RED) Cleaning local terraform artifacts...$(NC)"
	@rm -rf $(TERRAFORM_DIR)/.terraform* $(TERRAFORM_DIR)/terraform.tfstate* 