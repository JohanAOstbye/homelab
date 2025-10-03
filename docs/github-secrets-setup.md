# GitHub Secrets Setup Guide

This guide helps you configure the required GitHub Secrets for your homelab GitOps deployment.

## Required Secrets

### 1. KUBECONFIG
Your K3s cluster configuration file, base64 encoded.

**⚠️ Security Note:** This gives GitHub Actions **full admin access** to your cluster. The connection is secured by:
- **Tailscale network** (only accessible via your private network)
- **GitHub's encrypted secrets** (encrypted at rest and in transit)
- **TLS encryption** (kubectl uses HTTPS)

**Get the value:**
```bash
# On your K3s server
sudo cat /etc/rancher/k3s/k3s.yaml | base64 -w 0
```

**Alternative if accessing via Tailscale:**
```bash
# From your local machine (replace with your server's Tailscale IP)
ssh user@100.x.x.x "sudo cat /etc/rancher/k3s/k3s.yaml" | \
sed 's/127.0.0.1/100.x.x.x/g' | \
base64 -w 0
```

**🔐 More Secure Alternative (Optional):**
Instead of using the admin kubeconfig, create a limited service account:
```bash
# Create dedicated service account for GitHub Actions
kubectl create serviceaccount github-deployer -n kube-system
kubectl create clusterrolebinding github-deployer \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:github-deployer

# Get the token (use this instead of full kubeconfig)
kubectl create token github-deployer -n kube-system --duration=8760h
```

### 2. CLOUDFLARE_API_TOKEN
API token with DNS edit permissions.

**Create at:** https://dash.cloudflare.com/profile/api-tokens
**Permissions needed:**
- Zone: Zone Settings: Read
- Zone: Zone: Read  
- Zone: DNS: Edit

### 3. DRONE_RPC_SECRET
Random secret for Drone CI communication.

**Generate:**
```bash
openssl rand -hex 32
```

### 4. DRONE_GITEA_CLIENT_ID & DRONE_GITEA_CLIENT_SECRET
OAuth application credentials from Gitea.

**Setup steps:**
1. Access Gitea: `https://git.ostbye.dev`
2. Go to Settings → Applications → OAuth2 Applications
3. Create new application:
   - **Application Name:** `Drone CI`
   - **Redirect URI:** `https://ci.ostbye.dev/login`
4. Copy Client ID and Client Secret

## Setting GitHub Secrets

1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each secret with the exact names above

## Verifying Setup

After setting secrets, push to main branch and check:
1. GitHub Actions workflow runs successfully
2. Services are accessible:
   - Gitea: https://git.ostbye.dev
   - Drone CI: https://ci.ostbye.dev

## Troubleshooting

### "context deadline exceeded" errors
This means GitHub Actions can't reach your K3s cluster:

**Network Issues:**
- **Tailscale connectivity** - GitHub runner must reach your Tailscale IP
- **K3s not running** - Check `sudo systemctl status k3s`
- **Wrong IP in kubeconfig** - Should be Tailscale IP (100.x.x.x), not 127.0.0.1

**Debug steps:**
```bash
# Test connection manually
kubectl --kubeconfig=<downloaded-file> get nodes

# Check if Tailscale IP is accessible
ping 100.x.x.x

# Verify kubeconfig server address
grep server: ~/.kube/config
# Should show: https://100.x.x.x:6443 (not 127.0.0.1)
```

**Fix common issues:**
```bash
# Update kubeconfig with correct Tailscale IP
sudo sed -i 's/127.0.0.1/YOUR_TAILSCALE_IP/g' /etc/rancher/k3s/k3s.yaml

# Restart K3s if needed
sudo systemctl restart k3s
```

### Certificate issues
- Verify Cloudflare API token permissions
- Check DNS records point to correct IP
- Monitor cert-manager logs: `kubectl logs -n cert-manager deployment/cert-manager`

### Drone CI not connecting to Gitea
- Verify OAuth credentials in GitHub Secrets
- Check if both services are running: `kubectl get pods -n private`
- Review Drone logs: `kubectl logs -n private deployment/drone-server`

## Security Best Practices

1. **Rotate secrets regularly**
2. **Use least-privilege API tokens**  
3. **Monitor access logs**
4. **Consider using external secret management** (Vault, etc.)
5. **Enable 2FA** on all accounts