# Homelab Makefile
# Common operations for managing your Kubernetes homelab

.PHONY: help validate debug-cluster fix-kubectl deploy deploy-force status clean setup-secrets check-config update check-updates git-status logs-deploy validate-yaml sync-server

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
	@echo "$(BLUE)Testing cluster connection first...$(NC)"
	@if kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then \
		echo "$(GREEN)✓ Cluster connection OK, using server-side validation$(NC)"; \
		find k8s -name "*.yaml" -o -name "*.yml" | xargs -I {} kubectl apply --dry-run=server -f {} > /dev/null; \
	else \
		echo "$(YELLOW)⚠️  Cluster connection failed, using client-side validation$(NC)"; \
		find k8s -name "*.yaml" -o -name "*.yml" | xargs -I {} kubectl apply --dry-run=client --validate=false -f {} > /dev/null; \
	fi
	@echo "$(BLUE)Validating kustomize builds...$(NC)"
	@kustomize build k8s/overlays/production > /dev/null
	@echo "$(GREEN)✓ All manifests are valid$(NC)"

debug-cluster: ## Debug cluster connection issues
	@echo "$(BLUE)Cluster Connection Diagnostics$(NC)"
	@echo "================================"
	@echo "$(YELLOW)Current kubectl context:$(NC)"
	@kubectl config current-context 2>/dev/null || echo "No context set"
	@echo ""
	@echo "$(YELLOW)Kubectl config:$(NC)"
	@kubectl config view --minify 2>/dev/null || echo "No config found"
	@echo ""
	@echo "$(YELLOW)K3s service status:$(NC)"
	@sudo systemctl is-active k3s 2>/dev/null || echo "K3s service not active"
	@echo ""
	@echo "$(YELLOW)K3s kubeconfig exists:$(NC)"
	@if [ -f /etc/rancher/k3s/k3s.yaml ]; then \
		echo "✓ K3s kubeconfig found"; \
	else \
		echo "✗ K3s kubeconfig not found"; \
	fi
	@echo ""
	@echo "$(YELLOW)Testing cluster connection:$(NC)"
	@kubectl cluster-info --request-timeout=5s 2>&1 || echo "Connection failed"

build: ## Build kustomize manifests without applying
	@echo "$(BLUE)Building production manifests...$(NC)"
	@kustomize build k8s/overlays/production

deploy: validate ## Deploy to local cluster
	@echo "$(YELLOW)⚠️  This will deploy to your current kubectl context$(NC)"
	@echo "Current context: $$(kubectl config current-context)"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		echo "$(BLUE)Deploying using server script...$(NC)"; \
		sudo ./scripts/deploy-server.sh; \
	else \
		echo ""; \
		echo "$(YELLOW)Deployment cancelled$(NC)"; \
	fi

deploy-force: ## Deploy without confirmation (for scripts)
	@echo "$(BLUE)Deploying to cluster...$(NC)"
	@sudo ./scripts/deploy-server.sh

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

setup-secrets: ## Set up secrets configuration for server deployment
	@echo "$(BLUE)Setting up server deployment secrets...$(NC)"
	@echo ""
	@if [ ! -f /etc/homelab/config ]; then \
		echo "$(YELLOW)Creating /etc/homelab/config from template...$(NC)"; \
		sudo mkdir -p /etc/homelab; \
		sudo cp scripts/config.example /etc/homelab/config; \
		sudo chmod 600 /etc/homelab/config; \
		echo "$(GREEN)✓ Config file created at /etc/homelab/config$(NC)"; \
		echo ""; \
		echo "$(YELLOW)Please edit /etc/homelab/config with your actual secrets:$(NC)"; \
		echo "  sudo nano /etc/homelab/config"; \
	else \
		echo "$(GREEN)✓ Config file already exists at /etc/homelab/config$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)Required secrets:$(NC)"
	@echo "$(YELLOW)CLOUDFLARE_API_TOKEN:$(NC) Create at https://dash.cloudflare.com/profile/api-tokens"
	@echo "$(YELLOW)DRONE_RPC_SECRET:$(NC) Use this: $$(openssl rand -hex 32)"
	@echo "$(YELLOW)DRONE_GITEA_CLIENT_*:$(NC) Create OAuth app in Gitea"

check-config: ## Check if secrets are properly configured
	@if [ -f /etc/homelab/config ]; then \
		echo "$(GREEN)✓ Config file exists$(NC)"; \
		echo "$(BLUE)Checking configuration...$(NC)"; \
		sudo grep -E "^export" /etc/homelab/config | sed 's/=.*/=***/' || true; \
	else \
		echo "$(RED)✗ Config file not found$(NC)"; \
		echo "Run: make setup-secrets"; \
	fi

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

update: ## Pull latest changes from git and deploy
	@echo "$(BLUE)Pulling latest changes...$(NC)"
	@git pull origin main
	@echo "$(BLUE)Deploying updates...$(NC)"
	@make deploy-force

check-updates: ## Check if local code is up to date with remote
	@echo "$(BLUE)Checking for updates...$(NC)"
	@git fetch origin
	@LOCAL=$$(git rev-parse HEAD); \
	REMOTE=$$(git rev-parse origin/main); \
	if [ "$$LOCAL" = "$$REMOTE" ]; then \
		echo "$(GREEN)✓ Your code is up to date$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  Updates available$(NC)"; \
		echo "Local:  $$LOCAL"; \
		echo "Remote: $$REMOTE"; \
		echo ""; \
		echo "$(BLUE)Recent commits:$(NC)"; \
		git log --oneline HEAD..origin/main; \
		echo ""; \
		echo "Run 'make update' to pull changes and deploy"; \
	fi

git-status: ## Show git status and any uncommitted changes
	@echo "$(BLUE)Git Repository Status$(NC)"
	@echo "====================="
	@git status --porcelain -b | head -20
	@echo ""
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "$(YELLOW)⚠️  You have uncommitted changes$(NC)"; \
		echo "Run 'git add . && git commit -m \"your message\"' to save them"; \
	else \
		echo "$(GREEN)✓ Working directory is clean$(NC)"; \
	fi

logs-deploy: ## Show deployment logs
	@echo "$(BLUE)Recent deployment logs:$(NC)"
	@sudo tail -n 50 /var/log/homelab-deploy.log 2>/dev/null || echo "No deployment logs found"

validate-yaml: ## Validate YAML syntax with yamllint
	@if command -v yamllint >/dev/null 2>&1; then \
		echo "$(BLUE)Running yamllint validation...$(NC)"; \
		find k8s -name "*.yaml" -o -name "*.yml" | xargs yamllint; \
	else \
		echo "$(YELLOW)yamllint not installed, skipping YAML validation$(NC)"; \
	fi

sync-server: ## Sync changes to server repository (if running on server)
	@if [ -d "/opt/homelab" ] && [ "$$(pwd)" != "/opt/homelab" ]; then \
		echo "$(BLUE)Syncing changes to server repository...$(NC)"; \
		sudo rsync -av --exclude='.git' ./ /opt/homelab/; \
		echo "$(GREEN)✓ Changes synced to /opt/homelab$(NC)"; \
		echo "You can now run: cd /opt/homelab && make deploy"; \
	elif [ "$$(pwd)" = "/opt/homelab" ]; then \
		echo "$(GREEN)✓ Already in server repository location$(NC)"; \
	else \
		echo "$(YELLOW)No /opt/homelab directory found - are you on the server?$(NC)"; \
	fi