.PHONY: help fmt validate lint security test plan apply destroy clean all

# Variables
ENV ?= production
TERRAFORM_DIR = environments/$(ENV)
PLAN_FILE = tfplan

# Validate environment exists
VALIDATE_ENV := $(shell test -d $(TERRAFORM_DIR) && echo "ok" || echo "fail")

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;36m
NC := \033[0m

##@ General

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(YELLOW)<target>$(NC) $(BLUE)[ENV=environment]$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(GREEN)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Available Environments:$(NC)"
	@ls -d environments/*/ 2>/dev/null | sed 's|environments/||' | sed 's|/||' | sed 's/^/  - /'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make plan ENV=production"
	@echo "  make apply ENV=production"
	@echo "  make test"

check-env:
	@if [ "$(VALIDATE_ENV)" = "fail" ]; then \
		echo "$(RED)Error: Environment '$(ENV)' does not exist$(NC)"; \
		echo "$(YELLOW)Available environments:$(NC)"; \
		ls -d environments/*/ | sed 's|environments/||' | sed 's|/||' | sed 's/^/  - /'; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Using environment: $(ENV)$(NC)"

##@ Code Quality

fmt: ## Format all Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	terraform fmt -recursive
	@echo "$(GREEN)✓ Formatting complete$(NC)"

fmt-check: ## Check if Terraform files are formatted
	@echo "$(BLUE)Checking Terraform formatting...$(NC)"
	terraform fmt -check -recursive

validate: check-env ## Validate Terraform configuration
	@echo "$(BLUE)Validating $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && terraform init -backend=false
	cd $(TERRAFORM_DIR) && terraform validate
	@echo "$(GREEN)✓ Validation passed$(NC)"

tflint: check-env ## Run tflint linter
	@echo "$(BLUE)Running tflint for $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && tflint --init
	cd $(TERRAFORM_DIR) && tflint
	@echo "$(GREEN)✓ tflint passed$(NC)"

lint: fmt-check validate tflint ## Run all linting checks
	@echo "$(GREEN)✓ All linting checks passed$(NC)"

##@ Security Scanning

##@ Security Scanning

tfsec: check-env ## Run tfsec security scanner
	@echo "$(BLUE)Running tfsec for $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && tfsec --config-file ../../.tfsec.yml --force-all-dirs --minimum-severity MEDIUM .
	@echo "$(GREEN)✓ tfsec passed$(NC)"

trivy: check-env ## Run trivy security scanner
	@echo "$(BLUE)Running trivy for $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && trivy config --severity HIGH,CRITICAL --tf-exclude-downloaded-modules --ignorefile ../../.trivyignore .
	@echo "$(GREEN)✓ trivy passed$(NC)"

checkov: check-env ## Run checkov security scanner
	@echo "$(BLUE)Running checkov for $(ENV)...$(NC)"
	checkov -d $(TERRAFORM_DIR) --config-file .checkov.yaml --compact --quiet
	@echo "$(GREEN)✓ checkov passed$(NC)"

security: tfsec trivy checkov ## Run all security scans
	@echo "$(GREEN)✓ All security scans complete$(NC)"

##@ Testing

test: ## Run terraform test on all modules
	@echo "$(BLUE)Running terraform test on all modules...$(NC)"
	@failed=0; \
	for dir in modules/*/; do \
		echo "$(YELLOW)Testing $$dir...$(NC)"; \
		if [ -d "$$dir/tests" ]; then \
			cd $$dir && terraform init -backend=false && terraform test || failed=$$((failed + 1)); \
			cd ../..; \
		else \
			echo "$(YELLOW)  No tests found, validating only...$(NC)"; \
			cd $$dir && terraform init -backend=false && terraform validate || failed=$$((failed + 1)); \
			cd ../..; \
		fi; \
	done; \
	if [ $$failed -gt 0 ]; then \
		echo "$(RED)✗ $$failed module(s) failed$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ All modules passed$(NC)"; \
	fi

##@ Planning

plan: check-env ## Create Terraform execution plan
	@echo "$(BLUE)Creating plan for $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && terraform init
	cd $(TERRAFORM_DIR) && terraform plan -out=$(PLAN_FILE)
	@echo "$(GREEN)✓ Plan created$(NC)"

plan-target: check-env ## Plan specific target (usage: make plan-target TARGET=module.vpc)
	@echo "$(BLUE)Planning target $(TARGET) for $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && terraform init
	cd $(TERRAFORM_DIR) && terraform plan -target=$(TARGET) -out=$(PLAN_FILE)

##@ Deployment

apply: check-env ## Apply Terraform changes
	@echo "$(YELLOW)Applying changes to $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply $(PLAN_FILE)
	@echo "$(GREEN)✓ Apply complete$(NC)"

apply-target: check-env ## Apply specific target (usage: make apply-target TARGET=module.vpc)
	@echo "$(YELLOW)Applying target $(TARGET) for $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -target=$(TARGET)

destroy: check-env ## Destroy Terraform-managed infrastructure
	@echo "$(RED)⚠ WARNING: This will destroy infrastructure in $(ENV)!$(NC)"
	@read -p "Type '$(ENV)' to confirm: " confirm && [ "$$confirm" = "$(ENV)" ]
	cd $(TERRAFORM_DIR) && terraform destroy

destroy-target: check-env ## Destroy specific target (usage: make destroy-target TARGET=module.vpc)
	@echo "$(RED)Destroying target $(TARGET) in $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && terraform destroy -target=$(TARGET)

##@ Output

output: check-env ## Show all Terraform outputs
	@echo "$(BLUE)Terraform outputs for $(ENV):$(NC)"
	cd $(TERRAFORM_DIR) && terraform output

output-json: check-env ## Show outputs in JSON format
	cd $(TERRAFORM_DIR) && terraform output -json

##@ Cost Estimation

cost: plan ## Estimate infrastructure costs with openinfraquote
	@echo "$(BLUE)Estimating costs for $(ENV)...$(NC)"
	@if command -v oiq >/dev/null 2>&1; then \
		cd $(TERRAFORM_DIR) && oiq estimate --plan $(PLAN_FILE); \
	else \
		echo "$(RED)Error: openinfraquote (oiq) not installed$(NC)"; \
		echo "Install from: https://github.com/kaytu-io/infracost"; \
		exit 1; \
	fi

##@ Documentation

docs: ## Generate module documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@if command -v terraform-docs >/dev/null 2>&1; then \
		for dir in modules/*/; do \
			echo "$(YELLOW)Documenting $$dir...$(NC)"; \
			terraform-docs markdown table $$dir > $$dir/README.md; \
		done; \
		echo "$(GREEN)✓ Documentation generated$(NC)"; \
	else \
		echo "$(RED)Error: terraform-docs not installed$(NC)"; \
		echo "Install: brew install terraform-docs"; \
		exit 1; \
	fi

graph: check-env ## Generate dependency graph
	@echo "$(BLUE)Generating graph for $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && terraform graph | dot -Tpng > graph.png
	@echo "$(GREEN)✓ Graph saved to $(TERRAFORM_DIR)/graph.png$(NC)"

##@ Cleanup

clean: check-env ## Clean temporary files for environment
	@echo "$(BLUE)Cleaning $(ENV)...$(NC)"
	cd $(TERRAFORM_DIR) && rm -f $(PLAN_FILE) *.tfstate.backup
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

clean-all: ## Clean all environments
	@echo "$(BLUE)Cleaning all environments...$(NC)"
	find environments -name "$(PLAN_FILE)" -delete
	find environments -name "*.tfstate.backup" -delete
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✓ All environments cleaned$(NC)"

##@ Workflows

all: fmt lint security plan ## Run complete pre-deploy workflow
	@echo "$(GREEN)✓ All checks passed for $(ENV) - ready to deploy$(NC)"

ci: fmt-check lint security ## Run CI pipeline checks
	@echo "$(GREEN)✓ CI checks passed for $(ENV)$(NC)"

deploy: all apply ## Full deployment workflow
	@echo "$(GREEN)✓ Deployment complete for $(ENV)$(NC)"

##@ Environment Management

list-envs: ## List all available environments
	@echo "$(BLUE)Available environments:$(NC)"
	@ls -d environments/*/ | sed 's|environments/||' | sed 's|/||' | sed 's/^/  - /'

##@ Utilities

console: check-env ## Open Terraform console
	cd $(TERRAFORM_DIR) && terraform console

providers: check-env ## Show provider information
	cd $(TERRAFORM_DIR) && terraform providers

version: ## Show Terraform version
	@terraform version

check-tools: ## Check if required tools are installed
	@echo "$(BLUE)Checking required tools...$(NC)"
	@command -v terraform >/dev/null 2>&1 && echo "$(GREEN)✓ terraform$(NC)" || echo "$(RED)✗ terraform$(NC)"
	@command -v tflint >/dev/null 2>&1 && echo "$(GREEN)✓ tflint$(NC)" || echo "$(RED)✗ tflint$(NC)"
	@command -v tfsec >/dev/null 2>&1 && echo "$(GREEN)✓ tfsec$(NC)" || echo "$(RED)✗ tfsec$(NC)"
	@command -v trivy >/dev/null 2>&1 && echo "$(GREEN)✓ trivy$(NC)" || echo "$(RED)✗ trivy$(NC)"
	@command -v checkov >/dev/null 2>&1 && echo "$(GREEN)✓ checkov$(NC)" || echo "$(RED)✗ checkov$(NC)"
	@command -v terraform-docs >/dev/null 2>&1 && echo "$(GREEN)✓ terraform-docs (optional)$(NC)" || echo "$(YELLOW)○ terraform-docs (optional)$(NC)"
	@command -v oiq >/dev/null 2>&1 && echo "$(GREEN)✓ oiq (optional)$(NC)" || echo "$(YELLOW)○ oiq (optional)$(NC)"

##@ Development

dev-setup: ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install; \
		echo "$(GREEN)✓ Pre-commit hooks installed$(NC)"; \
	else \
		echo "$(YELLOW)Warning: pre-commit not found. Install with: pip install pre-commit$(NC)"; \
	fi
	@echo "$(GREEN)✓ Run 'make check-tools' to verify all tools are installed$(NC)"
