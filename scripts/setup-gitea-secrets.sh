#!/bin/bash
set -e

echo "🔐 Setting up Gitea secrets securely..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to generate secure passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 This script will create secure secrets for Gitea${NC}"
echo "It will generate random passwords and store them as Kubernetes secrets."
echo ""

# Generate secrets
GITEA_SECRET_KEY=$(openssl rand -base64 32)
GITEA_ADMIN_PASSWORD=$(generate_password)

echo -e "${GREEN}🔑 Generated secure credentials:${NC}"
echo "  Admin Username: admin"
echo "  Admin Password: $GITEA_ADMIN_PASSWORD"
echo "  Secret Key: [hidden - stored in cluster]"
echo ""
echo -e "${YELLOW}⚠️  SAVE THE ADMIN PASSWORD! You'll need it to login to Gitea.${NC}"
echo ""

# Create namespace if it doesn't exist
kubectl create namespace private --dry-run=client -o yaml | kubectl apply -f -

# Create the secret
kubectl create secret generic gitea-secrets -n private \
    --from-literal=secret-key="$GITEA_SECRET_KEY" \
    --from-literal=admin-password="$GITEA_ADMIN_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Gitea secrets created successfully!${NC}"
echo ""
echo "To use the secure configuration:"
echo "1. Replace gitea-production.yaml with gitea-production-secure.yaml"
echo "2. Deploy your infrastructure"
echo "3. Login to Gitea with:"
echo "   Username: admin"
echo "   Password: $GITEA_ADMIN_PASSWORD"
echo ""
echo "Your secrets are now stored securely in the cluster and not in Git!"