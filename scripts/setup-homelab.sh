#!/bin/bash

# Homelab Setup Script - Improved Version
# This script sets up the improved K3s homelab with proper GitOps

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG_FILE="/etc/rancher/k3s/k3s.yaml"

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. This is not recommended but continuing..."
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        error "No internet connectivity. Please check your network."
        exit 1
    fi
    
    success "Prerequisites check passed"
}

install_k3s() {
    if command -v k3s &>/dev/null; then
        warn "k3s is already installed. Skipping installation."
        return
    fi
    
    log "Installing K3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik --write-kubeconfig-mode=644" sh -
    
    # Wait for k3s to be ready
    log "Waiting for K3s to be ready..."
    timeout=60
    while ! kubectl get nodes &>/dev/null; do
        sleep 2
        timeout=$((timeout - 2))
        if [ $timeout -le 0 ]; then
            error "K3s failed to start within 60 seconds"
            exit 1
        fi
    done
    
    success "K3s installed and running"
}

install_helm() {
    if command -v helm &>/dev/null; then
        warn "Helm is already installed. Skipping installation."
        return
    fi
    
    log "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    success "Helm installed"
}

install_kustomize() {
    if command -v kustomize &>/dev/null; then
        warn "Kustomize is already installed. Skipping installation."
        return
    fi
    
    log "Installing Kustomize..."
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/
    success "Kustomize installed"
}

install_tailscale() {
    if command -v tailscale &>/dev/null; then
        warn "Tailscale is already installed. Skipping installation."
        return
    fi
    
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    
    if [ -n "$TS_AUTHKEY" ]; then
        log "Connecting to Tailscale..."
        sudo tailscale up --authkey "$TS_AUTHKEY" --accept-dns=false
        success "Tailscale connected"
    else
        warn "TS_AUTHKEY not set. Please run 'sudo tailscale up' manually."
    fi
}

setup_environment() {
    log "Setting up environment..."
    
    # Create kubeconfig directory for current user
    mkdir -p ~/.kube
    sudo cp $KUBECONFIG_FILE ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    
    # Export KUBECONFIG
    export KUBECONFIG=~/.kube/config
    
    success "Environment configured"
}

create_namespaces() {
    log "Creating namespaces..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: private
---
apiVersion: v1
kind: Namespace
metadata:
  name: public
---
apiVersion: v1
kind: Namespace
metadata:
  name: offline
EOF
    success "Namespaces created"
}

setup_cert_manager() {
    log "Setting up cert-manager..."
    
    # Install cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    log "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
    
    # Create Cloudflare secret
    if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
        kubectl create secret generic cloudflare-api-token \
            --from-literal=token="$CLOUDFLARE_API_TOKEN" \
            -n cert-manager --dry-run=client -o yaml | kubectl apply -f -
        success "Cloudflare secret created"
    else
        warn "CLOUDFLARE_API_TOKEN not set. Please create the secret manually."
    fi
    
    success "cert-manager setup complete"
}

display_next_steps() {
    echo
    success "Homelab setup complete!"
    echo
    log "Next steps:"
    echo "1. Set up GitHub repository secrets:"
    echo "   - KUBECONFIG (base64 encoded): $(base64 -w 0 ~/.kube/config)"
    echo "   - CLOUDFLARE_API_TOKEN: $CLOUDFLARE_API_TOKEN"
    echo "   - DRONE_RPC_SECRET: (generate a random string)"
    echo "   - DRONE_GITEA_CLIENT_ID: (from Gitea OAuth app)"
    echo "   - DRONE_GITEA_CLIENT_SECRET: (from Gitea OAuth app)"
    echo
    echo "2. Update DNS records in Cloudflare:"
    echo "   - git.ostbye.dev → $(curl -s ipinfo.io/ip)"
    echo "   - ci.ostbye.dev → $(curl -s ipinfo.io/ip)"
    echo
    echo "3. Deploy your manifests using: make deploy"
    echo
    echo "4. Access your services:"
    echo "   - Gitea: https://git.ostbye.dev"
    echo "   - Drone CI: https://ci.ostbye.dev"
    echo
    echo "5. Optional: Install ArgoCD for advanced GitOps"
}

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Load homelab configuration if it exists
if [ -f /etc/homelab/config ]; then
    set -a
    source /etc/homelab/config
    set +a
fi

# Main execution
case "${1:-install}" in
    "install")
        check_prerequisites
        install_k3s
        install_helm
        install_kustomize
        install_tailscale
        setup_environment
        create_namespaces
        setup_cert_manager
        display_next_steps
        ;;
    "uninstall")
        warn "Uninstalling homelab..."
        kubectl delete namespace private public offline --ignore-not-found
        /usr/local/bin/k3s-uninstall.sh
        sudo tailscale down || true
        success "Homelab uninstalled"
        ;;
    *)
        echo "Usage: $0 {install|uninstall}"
        exit 1
        ;;
esac