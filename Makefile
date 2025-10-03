# Homelab Makefile
# Common operations for managing your Kubernetes homelab

.PHONY: help validate deploy status clean setup-secrets

# Colors for output
BLUE = \033[0;34m
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Homelab Management Commands$(NC)"
	@echo "================================"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

validate: ## Validate all Kubernetes manifests
	@echo "$(BLUE)Validating Kubernetes manifests...$(NC)"
	@find k8s -name "*.yaml" -o -name "*.yml" | xargs -I {} kubectl apply --dry-run=client -f {} > /dev/null
	@kustomize build k8s/overlays/production > /dev/null
	@echo "$(GREEN)✓ All manifests are valid$(NC)"

build: ## Build kustomize manifests without applying
	@echo "$(BLUE)Building production manifests...$(NC)"
	@kustomize build k8s/overlays/production

deploy: validate ## Deploy to local cluster (use with caution)
	@echo "$(YELLOW)⚠️  This will deploy to your current kubectl context$(NC)"
	@echo "Current context: $$(kubectl config current-context)"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		echo "$(BLUE)Deploying...$(NC)"; \
		./scripts/local-deploy.sh deploy; \
	else \
		echo ""; \
		echo "$(YELLOW)Deployment cancelled$(NC)"; \
	fi

status: ## Show cluster status
	@echo "$(BLUE)Cluster Status$(NC)"
	@echo "==============="
	@kubectl get nodes
	@echo ""
	@kubectl get pods -A
	@echo ""
	@kubectl get ingress -A

clean: ## Clean up deployed resources
	@echo "$(RED)⚠️  This will remove all homelab resources$(NC)"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		./scripts/local-deploy.sh cleanup; \
	else \
		echo ""; \
		echo "$(YELLOW)Cleanup cancelled$(NC)"; \
	fi

setup-secrets: ## Generate example secrets for GitHub Actions setup
	@echo "$(BLUE)Generating secret values for GitHub Actions...$(NC)"
	@echo ""
	@echo "$(GREEN)KUBECONFIG:$(NC)"
	@echo "Get this from your K3s server:"
	@echo "  sudo cat /etc/rancher/k3s/k3s.yaml | base64 -w 0"
	@echo ""
	@echo "$(GREEN)CLOUDFLARE_API_TOKEN:$(NC)"
	@echo "Create at: https://dash.cloudflare.com/profile/api-tokens"
	@echo ""
	@echo "$(GREEN)DRONE_RPC_SECRET:$(NC)"
	@openssl rand -hex 32
	@echo ""
	@echo "$(GREEN)DRONE_GITEA_CLIENT_ID & DRONE_GITEA_CLIENT_SECRET:$(NC)"
	@echo "Create OAuth app in Gitea at: https://git.ostbye.dev/user/settings/applications"

logs: ## Show logs for main services
	@echo "$(BLUE)Gitea logs:$(NC)"
	@kubectl logs -n private deployment/gitea --tail=20 || true
	@echo ""
	@echo "$(BLUE)Drone Server logs:$(NC)"
	@kubectl logs -n private deployment/drone-server --tail=20 || true
	@echo ""
	@echo "$(BLUE)Cert-Manager logs:$(NC)"
	@kubectl logs -n cert-manager deployment/cert-manager --tail=20 || true

restart: ## Restart all main deployments
	@echo "$(BLUE)Restarting deployments...$(NC)"
	@kubectl rollout restart deployment/gitea -n private || true
	@kubectl rollout restart deployment/drone-server -n private || true
	@kubectl rollout restart deployment/drone-runner-kube -n private || true

cert-status: ## Check certificate status
	@echo "$(BLUE)Certificate status:$(NC)"
	@kubectl get certificates -A
	@echo ""
	@kubectl get certificaterequests -A
	@echo ""
	@kubectl describe clusterissuer letsencrypt-prod

install-tools: ## Install required tools (kubectl, kustomize, helm)
	@echo "$(BLUE)Installing required tools...$(NC)"
	@./scripts/setup-homelab.sh install