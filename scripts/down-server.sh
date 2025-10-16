#!/bin/bash
set -e

# Homelab Teardown Script
# This script deletes all homelab resources from the local K3s cluster

REPO_DIR="/opt/homelab"
LOG_FILE="/var/log/homelab-down.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

kubectl() {
    k3s kubectl "$@"
}

teardown_applications() {
    log "Deleting application resources (production overlay)..."
    if [ -d "$REPO_DIR" ]; then
        cd "$REPO_DIR"
        kustomize build k8s/overlays/production | kubectl delete -f - || warn "Some resources may not exist"
    else
        warn "Repository directory not found: $REPO_DIR"
    fi
    success "Applications deleted"
}

teardown_infrastructure() {
    log "Deleting infrastructure components..."
    if [ -d "$REPO_DIR" ]; then
        cd "$REPO_DIR"
        # Delete cert-manager ClusterIssuers
        kubectl delete -f k8s/base/cert-manager/cluster-issuers.yaml || warn "ClusterIssuers may not exist"
        # Delete cert-manager Helm chart
        kubectl delete -f k8s/base/cert-manager/cert-manager.yaml || warn "cert-manager may not exist"
        # Delete Traefik
        kubectl delete -k k8s/base/traefik || warn "Traefik may not exist"
        # Delete namespaces (last)
        kubectl delete -k k8s/base/namespaces || warn "Namespaces may not exist"
    else
        warn "Repository directory not found: $REPO_DIR"
    fi
    success "Infrastructure deleted"
}

teardown_secrets() {
    log "Deleting secrets..."
    # Delete secrets in cert-manager and private namespaces
    kubectl delete secret cloudflare-api-token -n cert-manager --ignore-not-found=true || warn "cloudflare-api-token may not exist"
    kubectl delete secret drone-secrets -n private --ignore-not-found=true || warn "drone-secrets may not exist"
    kubectl delete secret example-secrets -n private --ignore-not-found=true || warn "example-secrets may not exist"
    # Delete certificates and challenges
    kubectl delete certificates -n private --all --ignore-not-found=true || warn "certificates may not exist"
    kubectl delete challenges -n private --all --ignore-not-found=true || warn "challenges may not exist"
    success "Secrets deleted"
}

main() {
    log "Starting homelab teardown..."
    log "================================"
    mkdir -p "$(dirname "$LOG_FILE")"
    teardown_applications
    teardown_infrastructure
    if [[ "$1" == "-all" ]]; then
        teardown_secrets
    fi
    success "Homelab teardown completed!"
    log "================================"
}

trap 'error "Teardown interrupted"' INT TERM

main "$@"
