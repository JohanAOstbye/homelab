#!/bin/bash

# Tailscale Subnet Router Setup Script
# This script configures your home server as a Tailscale subnet router
# for ostbye.dev domain routing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌐 Tailscale Subnet Router Setup for ostbye.dev${NC}"
echo "This will configure selective routing where only *.ostbye.dev goes through Tailscale"
echo ""

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo -e "${RED}❌ Tailscale not found. Installing...${NC}"
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Detect home network range
HOME_NETWORK=$(ip route | grep -E "192\.168\.|10\.|172\." | grep -E "proto kernel.*src" | head -1 | awk '{print $1}' || echo "192.168.1.0/24")
echo -e "${YELLOW}📡 Detected home network: ${HOME_NETWORK}${NC}"

# Ask user to confirm or change
read -p "Is this your home network range? (y/n/custom): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Common ranges:"
    echo "  192.168.1.0/24 (most home routers)"
    echo "  192.168.0.0/24 (some routers)" 
    echo "  10.0.0.0/24 (some routers)"
    echo "  172.16.0.0/24 (some enterprise setups)"
    read -p "Enter your network range (e.g., 192.168.1.0/24): " HOME_NETWORK
fi

echo ""
echo -e "${YELLOW}⚙️  Setting up Tailscale with subnet routing...${NC}"

# Configure Tailscale with subnet routing and DNS
sudo tailscale up --advertise-routes="$HOME_NETWORK" --accept-routes --accept-dns

echo ""
echo -e "${GREEN}✅ Tailscale subnet router configured!${NC}"

# Get Tailscale IPs
TS_IP=$(tailscale ip -4 2>/dev/null || echo "Not available")
TS_HOSTNAME=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' 2>/dev/null | sed 's/\.$//' || echo "Not available")

echo ""
echo -e "${BLUE}📋 Configuration Summary:${NC}"
echo "  Home Network: $HOME_NETWORK"
echo "  Tailscale IP: $TS_IP" 
echo "  Tailscale Hostname: $TS_HOSTNAME"
echo ""

echo -e "${YELLOW}🔧 Next Steps:${NC}"
echo ""
echo -e "${BLUE}1. Approve subnet routing:${NC}"
echo "   → Go to: https://login.tailscale.com/admin/machines"
echo "   → Find this server → Edit route settings"
echo "   → Approve subnet route for $HOME_NETWORK"
echo ""

echo -e "${BLUE}2. Configure DNS override (choose one):${NC}"
echo ""
echo -e "${GREEN}   Option A: MagicDNS (Recommended)${NC}"
echo "   → Go to: https://login.tailscale.com/admin/dns"
echo "   → Enable MagicDNS"
echo "   → Add Split DNS:"
echo "     Domain: ostbye.dev"
echo "     Nameserver: $TS_IP"
echo ""

echo -e "${GREEN}   Option B: Manual client configuration${NC}"
echo "   → On each client device, add to /etc/hosts:"
echo "     $TS_IP git.ostbye.dev"
echo "     $TS_IP ci.ostbye.dev"
echo ""

echo -e "${BLUE}3. Update Kubernetes middleware (if needed):${NC}"
echo "   → Edit: k8s/base/tailscale-middleware.yaml"
echo "   → Ensure sourceRange includes: $HOME_NETWORK"
echo ""

echo -e "${BLUE}4. Test the setup:${NC}"
echo "   → From Tailscale device: curl -I https://git.ostbye.dev"
echo "   → Should work (200 OK)"
echo "   → From non-Tailscale device: should get 403 Forbidden"
echo ""

echo -e "${GREEN}🎉 Setup complete! Your homelab is now accessible via selective Tailscale routing.${NC}"
echo "   Only *.ostbye.dev domains will route through Tailscale"
echo "   All other traffic will go direct to internet for normal speed"