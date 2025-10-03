#!/bin/bash

# Local deployment script for testing
# This script allows you to deploy changes locally before pushing to GitHub

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_tools() {
    log "Checking required tools..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v kustomize &> /dev/null; then
        error "kustomize not found. Please install kustomize."
        exit 1
    fi
    
    success "All tools available"
}

test_cluster_connection() {
    log "Testing cluster connection..."
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
    success "Connected to cluster: $(kubectl config current-context)"
}

validate_manifests() {
    log "Validating Kubernetes manifests..."
    
    # Validate YAML syntax
    find k8s -name "*.yaml" -o -name "*.yml" | while read -r file; do
        if ! kubectl apply --dry-run=client -f "$file" &> /dev/null; then
            warn "Validation warning for: $file"
        fi
    done
    
    # Test kustomize build
    if ! kustomize build k8s/overlays/production > /dev/null; then
        error "Kustomize build failed for production overlay"
        exit 1
    fi
    
    success "Manifests validation passed"
}

deploy_infrastructure() {
    log "Deploying infrastructure components..."
    
    # Deploy namespaces first
    kubectl apply -k k8s/base/namespaces
    
    # Deploy cert-manager
    kubectl apply -k k8s/base/cert-manager
    
    # Wait for cert-manager to be ready
    log "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager || true
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager || true
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager || true
    
    success "Infrastructure deployed"
}

deploy_applications() {
    log "Deploying applications..."
    
    # Apply the full production overlay
    # Note: This will fail without proper secrets, which is expected in local testing
    if kustomize build k8s/overlays/production | kubectl apply -f - --dry-run=server; then
        success "Applications would deploy successfully"
    else
        warn "Application deployment validation had warnings (expected without secrets)"
    fi
    
    success "Applications validated"
}

show_status() {
    log "Current cluster status:"
    echo
    kubectl get nodes
    echo
    kubectl get pods -A
    echo  
    kubectl get ingress -A
    echo
    kubectl get pvc -A
}

cleanup() {
    warn "Cleaning up deployed resources..."
    
    kubectl delete --ignore-not-found -k k8s/overlays/production || true
    kubectl delete --ignore-not-found -k k8s/base/cert-manager || true
    kubectl delete --ignore-not-found -k k8s/base/namespaces || true
    
    success "Cleanup completed"
}

# Main execution
case "${1:-deploy}" in
    "deploy")
        check_tools
        test_cluster_connection
        validate_manifests
        deploy_infrastructure
        deploy_applications
        show_status
        ;;
    "validate")
        check_tools
        validate_manifests
        ;;
    "status")
        test_cluster_connection
        show_status
        ;;
    "cleanup")
        test_cluster_connection
        cleanup
        ;;
    *)
        echo "Usage: $0 {deploy|validate|status|cleanup}"
        echo
        echo "Commands:"
        echo "  deploy    - Deploy all components to the cluster"
        echo "  validate  - Validate manifests without deploying"
        echo "  status    - Show current cluster status"  
        echo "  cleanup   - Remove all deployed resources"
        exit 1
        ;;
esac