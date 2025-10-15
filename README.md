# Homelab Kubernetes GitOps Setup

This repository contains the Kubernetes configuration for Johan's homelab, designed for server-side GitOps deployment.

## 🏗️ Architecture

### Core Infrastructure
- **K3s** - Lightweight Kubernetes distribution
- **Tailscale** - Secure network access
- **Cloudflare** - DNS management and certificates
- **cert-manager** - Automated SSL certificate management
- **Kustomize** - Configuration management

### GitOps & CI/CD
- **Server-side deployment** - Local GitOps deployment script (see `docs/SERVER_DEPLOYMENT.md`)
- **Gitea** - Self-hosted Git service (for your projects)
- **Drone CI** - Continuous Integration (builds/tests your projects)

### Optional Future Additions
- **ArgoCD** - Advanced GitOps with web UI and monitoring

## 📁 Directory Structure

```
├── k8s/
│   ├── base/             # Base Kubernetes manifests
│   │   ├── namespaces/
│   │   ├── cert-manager/
│   │   ├── gitea/
│   │   └── drone/
│   └── overlays/         # Environment-specific overlays
│       └── production/
├── scripts/              # Deployment and utility scripts
├── docs/                 # Documentation
├── Makefile              # Main management interface
└── src/                  # Environment variables (.env)
```

## 🚀 Quick Start

### Prerequisites

1. **K3s cluster** with Tailscale access
2. **Cloudflare API token** with DNS edit permissions
3. **GitHub repository** with this code
4. **GitHub Secrets** configured (see Setup section)

### Fresh Installation

For a complete fresh installation, follow the **[Server Deployment Guide](docs/SERVER_DEPLOYMENT.md)** which includes:

1. **Server cleanup** (removing any existing setup)
2. **Fresh K3s installation** with all prerequisites  
3. **Server configuration** and secrets setup
4. **Server-side deployment** via deployment script
5. **DNS and SSL setup**
6. **Service configuration** (Gitea + Drone)

### Server Configuration Required

Configure secrets on your server at `/etc/homelab/config`:

```bash
# Cloudflare API token for DNS challenges
export CLOUDFLARE_API_TOKEN="your-token-here"

# Drone CI secrets
export DRONE_RPC_SECRET="your-rpc-secret"
export DRONE_GITEA_CLIENT_ID="your-client-id"
export DRONE_GITEA_CLIENT_SECRET="your-client-secret"  
DRONE_GITEA_CLIENT_SECRET
```

**See [GitHub Secrets Setup Guide](docs/github-secrets-setup.md) for detailed instructions.**

### Local Development

```bash
# Test Kustomize builds
kustomize build k8s/overlays/production

# Apply manually (if needed)
kubectl apply -k k8s/overlays/production
```

## 🔧 Configuration

### Updating Secrets

1. **For development**: Edit `k8s/overlays/production/secrets.yaml`
2. **For production**: Use GitHub Secrets or external secret management

### Adding New Services

1. Create base manifests in `k8s/base/[service-name]/`
2. Add Kustomization file
3. Include in overlay `k8s/overlays/production/kustomization.yaml`
4. Create patches if needed

### DNS Configuration

Update your Cloudflare DNS to point to your server:
- `git.ostbye.dev` → Your server IP
- `ci.ostbye.dev` → Your server IP

## 🤔 Server-side Deployment vs CI/CD - What's the Difference?

### Current Setup
- **Server Deployment Script** = Infrastructure deployment (deploys **infrastructure** changes to your Kubernetes cluster)
- **Drone CI** = Application CI/CD (builds, tests, and deploys **your application code**)

### Example Workflow
1. You update infrastructure (new services, config updates) → Run `make deploy` on server to deploy to K8s
2. You push application code to Gitea → **Drone CI** builds, tests, and deploys your app

### ArgoCD Alternative (Future)
- **ArgoCD** could replace **server deployment** for advanced GitOps features:
  - Real-time sync monitoring
  - Rollback capabilities
  - Multi-cluster management
  - Web UI for deployment status

**TL;DR: Server deployment handles infrastructure. Drone CI does application CI/CD. They serve different purposes.**

## 📂 Understanding Kustomize Overlays

Kustomize uses a **base + overlay** pattern that makes managing different environments super clean:

### Base Configuration (`k8s/base/`)
Contains the **core** Kubernetes manifests - the common configuration shared across all environments:

```
k8s/base/
├── namespaces/          # Basic namespace definitions
├── cert-manager/        # SSL certificate management
├── gitea/              # Git service (basic config)
└── drone/              # CI service (basic config)
```

Each base contains:
- **Core resources** (Deployments, Services, etc.)
- **Default configurations** (no environment-specific settings)
- **kustomization.yaml** (lists what files to include)

### Overlay Configuration (`k8s/overlays/production/`)
**Extends** and **customizes** the base for specific environments:

```yaml
# k8s/overlays/production/kustomization.yaml
resources:
  - ../../base/namespaces    # Include base namespaces
  - ../../base/cert-manager  # Include base cert-manager
  - ../../base/gitea        # Include base gitea
  - ../../base/drone        # Include base drone

secretGenerator:           # Generate secrets with real values
  - name: cloudflare-api-token
    literals: [token=REAL_TOKEN]

patchesStrategicMerge:    # Customize base configs
  - patches/drone-production.yaml
  - patches/gitea-production.yaml

images:                   # Override image tags
  - name: drone/drone
    newTag: "2.23.0"
```

### How Patches Work
Patches **modify** the base configuration without changing the original files:

```yaml
# patches/drone-production.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drone-server      # Matches base deployment
spec:
  template:
    spec:
      containers:
        - name: drone-server
          resources:      # ADD production resource limits
            requests:
              memory: "256Mi"
              cpu: "200m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
          env:           # ADD production environment variables
            - name: DRONE_LOGS_DEBUG
              value: "false"
```

### Why This Approach Rocks

**✅ Reusable Base:**
- Base configs work for any environment
- No duplication of common settings
- Easy to maintain core functionality

**✅ Environment-Specific:**
- Production: High resource limits, debug off
- Staging: Lower resources, debug on
- Development: Minimal resources, verbose logging

**✅ Easy to Extend:**
```bash
# Add a staging environment
cp -r k8s/overlays/production k8s/overlays/staging
# Modify staging/kustomization.yaml for staging-specific settings
```

### Real-World Example

**Base Drone Config:**
```yaml
# k8s/base/drone/server.yaml (simplified)
containers:
  - name: drone-server
    image: drone/drone:latest
    env:
      - name: DRONE_SERVER_HOST
        value: "ci.ostbye.dev"
```

**Production Overlay Adds:**
```yaml
# k8s/overlays/production/patches/drone-production.yaml
containers:
  - name: drone-server
    resources:              # ADDED: Resource limits
      requests: [memory: "256Mi"]
    env:
      - name: DRONE_LOGS_DEBUG  # ADDED: Production logging
        value: "false"
```

**Final Result:** Kustomize merges base + overlay = production-ready deployment!

### Build and See the Result
```bash
# See what gets deployed to production
kustomize build k8s/overlays/production

# See just the base (no environment-specific changes)
kustomize build k8s/base/drone
```

📚 **For a complete deep-dive into overlays, see the [Kustomize Overlays Guide](docs/kustomize-overlays-guide.md)**

## 🚀 Server-Side Deployment Process

### How It Works
The deployment script runs directly on your K3s server, providing a secure and simple approach:

1. **Clone/Update** - Downloads latest code from GitHub
2. **Validate** - Checks YAML syntax and Kustomize builds
3. **Apply** - Uses local kubectl to deploy to K3s cluster
4. **Verify** - Confirms deployment status

### Security Benefits
- **No external access** - No need for GitHub to access your cluster
- **Local authentication** - Uses K3s's built-in kubeconfig
- **Full control** - You control when deployments happen
- **Audit trail** - All deployments logged locally

### Deployment Commands
```bash
# Deploy with confirmation
make deploy

# Deploy without confirmation (for automation)
make deploy-force

# Check deployment status
make status

# View deployment logs
make logs-deploy
```

## 🔒 Current Security Features

- **Automated SSL certificates** via Let's Encrypt
- **RBAC** configured for service accounts
- **Network policies** (can be added)
- **Pod security standards** (can be enforced)
- **Secret management** via server configuration files

## 🚦 Deployment Workflow

1. **Update code** → Make changes to manifests or configuration
2. **Push to GitHub** → Code is available for server to pull
3. **Deploy on server** → Run `make deploy` to apply changes
4. **Verify** → Check deployment status with `make status`

## 🛠️ Troubleshooting

### Check deployment status
```bash
kubectl get pods -A
kubectl get ingress -A
kubectl describe pod [pod-name] -n [namespace]
```

### View logs
```bash
kubectl logs -f deployment/drone-server -n private
kubectl logs -f deployment/gitea -n private
```

### Certificate issues
```bash
kubectl get certificaterequests -A
kubectl describe clusterissuer letsencrypt-prod
```

## 🎯 Example Application

See [`examples/assistant-app/`](examples/) for a complete example showing:

- **FastAPI application** with proper structure
- **Dockerfile** with security best practices
- **Kubernetes manifests** (deployment, service, ingress)
- **Drone CI pipeline** for automated testing and deployment
- **Full development workflow** from code to production

This example demonstrates how applications in your Gitea repositories get automatically built and deployed to your homelab cluster.

## 📚 Next Steps

- [ ] Implement monitoring (Prometheus + Grafana)
- [ ] Add backup solutions
- [ ] Implement network policies
- [ ] Add more applications (Nextcloud, etc.)
- [ ] Optional: Add ArgoCD for advanced GitOps features

## 🤝 Contributing

This is a personal homelab setup, but feel free to:
1. Fork for your own homelab
2. Submit issues for bugs
3. Suggest improvements via PRs

---

**⚠️ Important**: This setup includes production secrets placeholders. Make sure to replace them with proper secret management before deploying!