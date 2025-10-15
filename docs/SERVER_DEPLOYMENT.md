# Local Server Deployment Setup

This approach eliminates the Tailscale GitHub Action complexity by deploying directly on your homelab server.

## Benefits of Server-Side Deployment

✅ **No OAuth complications** - No need for Tailscale GitHub Actions integration
✅ **Faster deployments** - No network latency to GitHub runners
✅ **Simpler setup** - Direct access to your K3s cluster
✅ **Better security** - No external access needed to your cluster
✅ **More reliable** - No dependency on external CI/CD services

## Setup Instructions

### 1. On Your Homelab Server

```bash
# Clone your repository to a standard location
sudo git clone https://github.com/JohanAOstbye/homelab.git /opt/homelab
cd /opt/homelab

# Make scripts executable
sudo chmod +x scripts/*.sh

# Set up secrets configuration
make setup-secrets
sudo nano /etc/homelab/config  # Fill in your actual secrets

# Test deployment
make deploy
```

### 2. Deploy Your Applications

**Option A: Using Makefile (recommended)**
```bash
# Deploy with confirmation
make deploy

# Or deploy without confirmation (for scripts)
make deploy-force
```

**Option B: Direct script**
```bash
sudo /opt/homelab/scripts/deploy-server.sh
```

### 3. Regular Deployment Workflow

```bash
# Pull latest changes and deploy
make update

# Check status
make status

# View deployment logs
make logs-deploy

# Validate before deploying
make validate
```

## Script Features

### deploy-server.sh
- ✅ Pulls latest code from GitHub
- ✅ Validates YAML and Kustomize builds
- ✅ Creates secrets using your pre-deploy script
- ✅ Deploys infrastructure (cert-manager, etc.)
- ✅ Deploys applications
- ✅ Checks deployment status
- ✅ Comprehensive logging

## Configuration

Edit `/etc/homelab/config`:

```bash
# Required secrets for your applications
export CLOUDFLARE_API_TOKEN="your-token"
export DRONE_RPC_SECRET="your-secret"
export DRONE_GITEA_CLIENT_ID="your-id"  
export DRONE_GITEA_CLIENT_SECRET="your-secret"
```

## Comparison: GitHub Actions vs Server Deployment

| Aspect | GitHub Actions | Server Deployment |
|--------|---------------|-------------------|
| Setup Complexity | High (OAuth, ACLs, secrets) | Low (just secrets file) |
| Security Surface | External access required | Internal only |
| Deployment Speed | Slower (network + startup) | Faster (local) |
| Reliability | Dependent on GitHub/Tailscale | Self-contained |
| Debugging | GitHub Actions logs | Local logs |
| Cost | GitHub Actions minutes | None |

## Troubleshooting

### Check deployment logs:
```bash
sudo tail -f /var/log/homelab-deploy.log
```

### Run deployment manually:
```bash
sudo /opt/homelab/scripts/deploy-server.sh
```

### Check K3s cluster status:
```bash
kubectl cluster-info
kubectl get pods -A
kubectl get nodes
```

## Security Notes

- Secrets are stored in `/etc/homelab/config` (root-only access)
- All operations run with proper K3s authentication
- No external network access required to your cluster
- Deployment runs locally with full cluster privileges

This approach is much simpler and more reliable for homelab deployments!