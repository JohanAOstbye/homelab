#!/bin/bash
set -e

# Homelab Deploy Script
# This script pulls the latest changes and deploys to the local K3s cluster

REPO_DIR="/opt/homelab"
BRANCH="main"
LOG_FILE="/var/log/homelab-deploy.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if we're running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
    fi
    
    # Use K3s built-in kubectl (no separate kubectl needed)
    if ! command -v k3s &> /dev/null; then
        error "K3s is not installed or not in PATH"
    fi
    
    # Create kubectl alias for k3s kubectl
    log "Using K3s built-in kubectl..."
    alias kubectl="k3s kubectl"
    
    # Check if kustomize is available
    if ! command -v kustomize &> /dev/null; then
        warn "kustomize not found, installing..."
        install_kustomize
    fi
    
    # Check if git is available
    if ! command -v git &> /dev/null; then
        error "git is not installed"
    fi
    
    # Check K3s cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to K3s cluster. Is K3s running?"
    fi
    
    success "Prerequisites check passed"
}

install_kustomize() {
    log "Installing kustomize..."
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/
    success "Kustomize installed"
}

setup_repo() {
    log "Setting up repository..."
    
    if [[ ! -d "$REPO_DIR" ]]; then
        log "Cloning repository..."
        git clone https://github.com/JohanAOstbye/homelab.git "$REPO_DIR"
        cd "$REPO_DIR"
    else
        log "Repository exists, updating..."
        cd "$REPO_DIR"
        git fetch origin
        git reset --hard "origin/$BRANCH"
    fi
    
    success "Repository setup complete"
}

validate_manifests() {
    log "Validating Kubernetes manifests..."
    
    cd "$REPO_DIR"
    
    # Validate YAML files with yamllint if available
    if command -v yamllint &> /dev/null; then
        log "Running yamllint validation..."
        find k8s -name "*.yaml" -o -name "*.yml" | xargs yamllint || warn "YAML validation warnings found"
    fi
    
    # Validate kustomize builds
    log "Validating kustomize builds..."
    for overlay in k8s/overlays/*/; do
        log "Validating $overlay"
        if ! kustomize build "$overlay" > /dev/null; then
            error "Kustomize build failed for $overlay"
        fi
    done
    
    success "Manifest validation complete"
}

create_secrets() {
    log "Creating/updating secrets..."
    
    cd "$REPO_DIR"
    
    # Check if pre-deploy script exists
    if [[ -f "scripts/pre-deploy.sh" ]]; then
        log "Running pre-deploy script..."
        chmod +x scripts/pre-deploy.sh
        
        # Source environment variables if config file exists
        if [[ -f "/etc/homelab/config" ]]; then
            source /etc/homelab/config
        fi
        
        scripts/pre-deploy.sh
    else
        warn "No pre-deploy script found, skipping secret creation"
    fi
    
    success "Secrets created/updated"
}

deploy_infrastructure() {
    log "Deploying infrastructure components..."
    
    cd "$REPO_DIR"
    
    # Deploy namespaces first
    log "Deploying namespaces..."
    kubectl apply -k k8s/base/namespaces
    
    # Deploy cert-manager
    log "Deploying cert-manager..."
    kubectl apply -k k8s/base/cert-manager
    
    # Wait for cert-manager to be ready
    log "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager || warn "cert-manager deployment timeout"
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager || warn "cert-manager-webhook deployment timeout"
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager || warn "cert-manager-cainjector deployment timeout"
    
    success "Infrastructure deployment complete"
}

deploy_applications() {
    log "Deploying applications..."
    
    cd "$REPO_DIR"
    
    # Deploy applications using kustomize
    log "Applying production overlay..."
    kustomize build k8s/overlays/production | kubectl apply -f -
    
    success "Applications deployed"
}

check_deployment_status() {
    log "Checking deployment status..."
    
    log "Pod status:"
    kubectl get pods -A | tee -a "$LOG_FILE"
    
    log "Ingress status:"
    kubectl get ingress -A | tee -a "$LOG_FILE"
    
    log "Service status:"
    kubectl get services -A | tee -a "$LOG_FILE"
    
    success "Deployment status check complete"
}

cleanup() {
    log "Performing cleanup..."
    
    # Remove any temporary files if needed
    # Clean up old logs (keep last 10)
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
    
    success "Cleanup complete"
}

main() {
    log "Starting homelab deployment..."
    log "================================"
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Run deployment steps
    check_prerequisites
    setup_repo
    validate_manifests
    create_secrets
    deploy_infrastructure
    deploy_applications
    check_deployment_status
    cleanup
    
    success "Homelab deployment completed successfully!"
    log "================================"
}

# Handle script interruption
trap 'error "Deployment interrupted"' INT TERM

# Run main function
main "$@"