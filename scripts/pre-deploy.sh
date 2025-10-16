#!/bin/bash

# Pre-deploy script to update timestamps and prepare manifests
# This script is called by the deployment script before applying manifests

set -e

TIMESTAMP=$(date +%s)

log() {
    echo "[INFO] $1"
}

# Update kustomization with current timestamp
update_timestamp() {
    log "Updating deployment timestamp: $TIMESTAMP"
    
    # Update the production overlay kustomization to include timestamp
    cat > k8s/overlays/production/timestamp-patch.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drone-server
  namespace: private
  annotations:
    redeployTimestamp: "$TIMESTAMP"
spec: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drone-runner-kube
  namespace: private
  annotations:
    redeployTimestamp: "$TIMESTAMP"
spec: {}
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gitea
  namespace: private
  annotations:
    redeployTimestamp: "$TIMESTAMP"
spec: {}
EOF

    log "Timestamp patch created"
}

# Create Gitea secrets that the HelmChart expects
create_gitea_secrets() {
    log "Creating Gitea secrets..."
    
    if [ -z "$GITEA_SECRET_KEY" ] || [ -z "$GITEA_ADMIN_PASSWORD" ]; then
        echo "ERROR: GITEA_SECRET_KEY and GITEA_ADMIN_PASSWORD must be set in /etc/homelab/config"
        exit 1
    fi
    
    # Create the gitea-secrets secret that the HelmChart expects
    # Note: The Gitea HelmChart expects 'username' and 'password' keys for admin
    # and 'secret-key' for the security configuration
    kubectl create secret generic gitea-secrets \
        --from-literal=username="gitea_admin" \
        --from-literal=password="$GITEA_ADMIN_PASSWORD" \
        --from-literal=secret-key="$GITEA_SECRET_KEY" \
        --namespace=private \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log "Gitea secrets created"
}

# Replace secret placeholders with actual values from environment
update_secrets() {
    log "Updating secrets in kustomization..."
    
    if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
        sed -i "s/CLOUDFLARE_TOKEN_PLACEHOLDER/$CLOUDFLARE_API_TOKEN/g" k8s/overlays/production/kustomization.yaml
    fi
    
    if [ -n "$DRONE_RPC_SECRET" ]; then
        sed -i "s/RPC_SECRET_PLACEHOLDER/$DRONE_RPC_SECRET/g" k8s/overlays/production/kustomization.yaml
    fi
    
    if [ -n "$DRONE_GITEA_CLIENT_ID" ]; then
        sed -i "s/GITEA_CLIENT_ID_PLACEHOLDER/$DRONE_GITEA_CLIENT_ID/g" k8s/overlays/production/kustomization.yaml
    fi
    
    if [ -n "$DRONE_GITEA_CLIENT_SECRET" ]; then
        sed -i "s/GITEA_CLIENT_SECRET_PLACEHOLDER/$DRONE_GITEA_CLIENT_SECRET/g" k8s/overlays/production/kustomization.yaml
    fi
    
    log "Secrets updated"
}

# Validate the updated manifests
validate_manifests() {
    log "Validating updated manifests..."
    
    if ! kustomize build k8s/overlays/production > /tmp/manifests.yaml; then
        echo "ERROR: Kustomize build failed"
        exit 1
    fi
    
    log "Manifest validation passed"
}

# Main execution
update_timestamp
create_gitea_secrets
update_secrets
validate_manifests

log "Pre-deployment preparation completed successfully"