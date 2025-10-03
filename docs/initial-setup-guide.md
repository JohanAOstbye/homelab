# Initial Setup Guide: Fresh Homelab Deployment

This guide helps you set up your homelab from scratch using the new GitOps-based structure.

## 🎯 What You'll Get

**Modern Homelab Stack:**
- **K3s** - Lightweight Kubernetes
- **GitHub Actions** - Automated GitOps deployment
- **Kustomize** - Configuration management
- **cert-manager** - Automated SSL certificates
- **Gitea** - Self-hosted Git service
- **Drone CI** - Continuous Integration
- **Tailscale** - Secure network access
- **Cloudflare** - DNS and SSL management

## 📋 Prerequisites

- [ ] Clean server (Ubuntu/Debian preferred)
- [ ] SSH access to the server
- [ ] Tailscale account and auth key
- [ ] Cloudflare account with API token
- [ ] GitHub repository with this code
- [ ] Domain configured in Cloudflare (ostbye.dev)

## 🧹 Step 1: Clean Existing Server

If you have an existing setup, let's completely clean it:

### Complete K3s Cleanup

```bash
# SSH into your server
ssh user@your-server-ip

# Stop and remove K3s completely
sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || echo "K3s not installed"

# Clean up any remaining files
sudo rm -rf /etc/rancher/
sudo rm -rf /var/lib/rancher/
sudo rm -rf /opt/setup/

# Remove any old Docker containers/images (if using Docker)
docker system prune -af 2>/dev/null || echo "Docker not found"

# Clean up leftover processes
sudo pkill -f k3s 2>/dev/null || true
sudo pkill -f containerd 2>/dev/null || true

# Remove Tailscale (we'll reinstall)
sudo tailscale down 2>/dev/null || true
sudo apt-get remove --purge tailscale -y 2>/dev/null || true
sudo rm -rf /var/lib/tailscale/

# Update system
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y
```

### Verify Clean State

```bash
# Should show no K3s processes
ps aux | grep k3s

# Should show no containers
docker ps -a 2>/dev/null || echo "Docker not running"

# Check disk space (should have freed up space)
df -h

echo "✅ Server is now clean and ready for fresh setup"
```

## 🚀 Step 2: Initial Server Setup

### Install Prerequisites

```bash
# SSH into your clean server
ssh user@your-server-ip

# Create setup directory
mkdir -p ~/homelab-setup
cd ~/homelab-setup

# Download the setup script
curl -O https://raw.githubusercontent.com/JohanAOstbye/homelab/main/scripts/setup-homelab.sh
chmod +x setup-homelab.sh

# Create environment file
cat > .env << 'EOF'
TS_AUTHKEY=your-tailscale-auth-key
CLOUDFLARE_API_TOKEN=your-cloudflare-api-token
CLOUDFLARE_EMAIL=johan.august@outlook.com
EMAIL=johan@ostbye.dev
EOF

# Run the initial setup
./setup-homelab.sh install
```

### What the Setup Does

1. **Installs K3s** with proper configuration
2. **Installs Helm** for chart management
3. **Installs Kustomize** for configuration management
4. **Connects to Tailscale** for secure access
5. **Sets up cert-manager** with Cloudflare integration
6. **Creates namespaces** for your services

## 🔧 Step 3: Configure GitHub Repository

### Set Up GitHub Secrets

Generate the required secrets:

```bash
# On your server, get the kubeconfig (base64 encoded)
sudo cat /etc/rancher/k3s/k3s.yaml | base64 -w 0
# Copy this output for KUBECONFIG secret

# Generate Drone RPC secret
openssl rand -hex 32
# Copy this for DRONE_RPC_SECRET
```

**Add these secrets to your GitHub repository** (Settings → Secrets and variables → Actions):

1. **KUBECONFIG** - The base64 kubeconfig from above
2. **CLOUDFLARE_API_TOKEN** - Your Cloudflare API token
3. **DRONE_RPC_SECRET** - The generated hex string
4. **DRONE_GITEA_CLIENT_ID** - (Will set up after Gitea is running)
5. **DRONE_GITEA_CLIENT_SECRET** - (Will set up after Gitea is running)

## 🚀 Step 4: Deploy Your Homelab

### Option A: Automated Deployment (Recommended)

```bash
# Clone your repository locally
git clone https://github.com/JohanAOstbye/homelab.git
cd homelab

# Validate the configuration
make validate

# Push to trigger deployment (if you made any local changes)
git add .
git commit -m "Initial homelab deployment"
git push origin main

# Monitor deployment at:
# https://github.com/JohanAOstbye/homelab/actions
```

### Option B: Manual Deployment

```bash
# On your local machine with kubectl configured
./scripts/local-deploy.sh deploy
```

## 🔗 Step 5: Configure DNS Records

Update your Cloudflare DNS records to point to your server:

```bash
# Get your server's public IP
curl ipinfo.io/ip

# Add these A records in Cloudflare:
# git.ostbye.dev → YOUR_SERVER_IP
# ci.ostbye.dev → YOUR_SERVER_IP
```

## ✅ Step 6: Verification

### From Your Server

```bash
# SSH into your server
ssh user@your-server-ip

# Check all services are running
kubectl get pods -A

# Check ingress status
kubectl get ingress -A

# Check certificates (should show Ready=True)
kubectl get certificates -A
```

### From Your Local Machine

```bash
# Test web access (wait 5-10 minutes for certificates)
curl -I https://git.ostbye.dev
curl -I https://ci.ostbye.dev

# Or open in browser:
# https://git.ostbye.dev
# https://ci.ostbye.dev
```

## 🎯 Step 7: Complete Gitea and Drone Setup

### Configure Gitea

1. **Access Gitea**: https://git.ostbye.dev
2. **Complete setup wizard**:
   - Database: SQLite (default)
   - Admin user: `admin`
   - Admin password: Choose a strong password
   - Admin email: `johan@ostbye.dev`

### Create Drone OAuth Application

1. **In Gitea** → Settings → Applications → OAuth2 Applications
2. **Create new application**:
   - Application Name: `Drone CI`
   - Redirect URI: `https://ci.ostbye.dev/login`
3. **Copy the Client ID and Client Secret**
4. **Add to GitHub Secrets**:
   - `DRONE_GITEA_CLIENT_ID`
   - `DRONE_GITEA_CLIENT_SECRET`

### Redeploy with Drone Secrets

```bash
# Trigger redeployment to pick up new secrets
git commit --allow-empty -m "Add Drone OAuth secrets"
git push origin main
```

## 🎉 Final Verification

After redeployment:

1. **Gitea**: https://git.ostbye.dev ✅
2. **Drone CI**: https://ci.ostbye.dev ✅
3. **SSL Certificates**: Both should show valid Let's Encrypt certificates
4. **Drone Integration**: Should be able to login to Drone with Gitea account

## 🚀 What's Next?

Your homelab is now running! You can:

1. **Create repositories** in Gitea
2. **Set up CI/CD pipelines** in Drone
3. **Add more services** to your homelab
4. **Monitor and maintain** through GitHub Actions

## 🐛 Troubleshooting

### Server Cleanup Issues

```bash
# If K3s won't uninstall cleanly
sudo systemctl stop k3s
sudo systemctl disable k3s
sudo rm -rf /etc/systemd/system/k3s.service
sudo systemctl daemon-reload

# Force remove containers
sudo crictl rm --force $(sudo crictl ps -aq) 2>/dev/null || true
sudo crictl rmi --prune 2>/dev/null || true
```

### Services Won't Start

```bash
# Check pod status
kubectl get pods -A

# Describe problematic pods
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs -f deployment/<deployment> -n <namespace>

# Common fixes:
kubectl delete pod <pod-name> -n <namespace>  # Force restart
```

### Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate requests
kubectl get certificaterequests -A

# Check cluster issuer
kubectl describe clusterissuer letsencrypt-prod

# Manual certificate request (if needed)
kubectl delete certificate <cert-name> -n <namespace>
# It will be recreated automatically
```

### GitHub Actions Failing

1. **Check KUBECONFIG secret**:
   ```bash
   # Verify it's valid base64
   echo "$KUBECONFIG_SECRET" | base64 -d | kubectl --kubeconfig=/dev/stdin get nodes
   ```

2. **Tailscale connectivity**: Ensure server is accessible via Tailscale IP

3. **Secret names**: Must match exactly (case-sensitive)

### Drone Can't Connect to Gitea

1. **Check OAuth credentials** in GitHub Secrets
2. **Verify internal connectivity**:
   ```bash
   kubectl exec -n private deployment/drone-server -- nslookup gitea-http
   ```
3. **Check Drone logs**:
   ```bash
   kubectl logs -f deployment/drone-server -n private
   ```

## 🔧 Useful Commands

### Quick Status Check
```bash
# From your server
kubectl get all -A
kubectl get certificates -A
kubectl get ingress -A
```

### Reset Everything (Nuclear Option)
```bash
# Complete reset if things go wrong
sudo /usr/local/bin/k3s-uninstall.sh
# Then restart from Step 2 of this guide
```

### Update Server IP (if it changes)
```bash
# Update kubeconfig with new IP
sudo sed -i 's/OLD_IP/NEW_IP/g' /etc/rancher/k3s/k3s.yaml
# Update KUBECONFIG secret in GitHub
```

## 📚 Expanding Your Homelab

Once your base setup is running, you can add:

1. **Monitoring**: Prometheus + Grafana
2. **Storage**: Longhorn or NFS
3. **Backup**: Velero or custom scripts
4. **Security**: Network policies, OPA Gatekeeper
5. **Apps**: Nextcloud, Jellyfin, Home Assistant
6. **Advanced GitOps**: ArgoCD

## 🔒 Security Features

Your new homelab includes:
- ✅ Automated SSL certificates
- ✅ No secrets in Git repositories  
- ✅ RBAC for service accounts
- ✅ Resource limits on all pods
- ✅ Health checks and monitoring
- ✅ Encrypted Tailscale network access
- ✅ Git-based audit trail for all changes

## � Congratulations!

You now have a production-grade homelab with:
- **GitOps deployment** via GitHub Actions
- **Automated SSL certificates** via Let's Encrypt
- **Self-hosted Git** with Gitea  
- **CI/CD pipeline** with Drone
- **Secure access** via Tailscale
- **Easy maintenance** via Makefile commands

Your homelab is ready to grow! 🚀