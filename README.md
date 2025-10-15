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
- **ArgoCD** - Advanced GitOps (alternative to GitHub Actions for cluster management)

## 📁 Directory Structure

```
├── .github/workflows/     # GitHub Actions workflows
├── k8s/
│   ├── base/             # Base Kubernetes manifests
│   │   ├── namespaces/
│   │   ├── cert-manager/
│   │   ├── gitea/
│   │   └── drone/
│   └── overlays/         # Environment-specific overlays
│       └── production/
├── scripts/              # Utility scripts
├── docs/                 # Documentation
└── src/                  # Environment variables (.env)
```

## 🚀 Quick Start

### Prerequisites

1. **K3s cluster** with Tailscale access
2. **Cloudflare API token** with DNS edit permissions
3. **GitHub repository** with this code
4. **GitHub Secrets** configured (see Setup section)

### Fresh Installation

For a complete fresh installation, follow the **[Initial Setup Guide](docs/initial-setup-guide.md)** which includes:

1. **Server cleanup** (removing any existing setup)
2. **Fresh K3s installation** with all prerequisites
3. **GitHub Secrets configuration**
4. **Automated deployment** via GitHub Actions
5. **DNS and SSL setup**
6. **Service configuration** (Gitea + Drone)

### GitHub Secrets Required

```bash
# Your K3s kubeconfig (base64 encoded)
KUBECONFIG

# Cloudflare API token
CLOUDFLARE_API_TOKEN

# Drone CI secrets
DRONE_RPC_SECRET
DRONE_GITEA_CLIENT_ID  
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

## 🤔 GitOps vs CI/CD - What's the Difference?

### Current Setup
- **GitHub Actions** = GitOps (deploys **infrastructure** changes to your Kubernetes cluster)
- **Drone CI** = CI/CD (builds, tests, and deploys **your application code**)

### Example Workflow
1. You push infrastructure changes (new services, config updates) → **GitHub Actions** deploys to K8s
2. You push application code to Gitea → **Drone CI** builds, tests, and deploys your app

### ArgoCD Alternative (Future)
- **ArgoCD** could replace **GitHub Actions** for GitOps (not Drone CI)
- ArgoCD provides advanced features like:
  - Real-time sync monitoring
  - Rollback capabilities
  - Multi-cluster management
  - Web UI for deployment status

**TL;DR: GitHub Actions and ArgoCD both do GitOps. Drone CI does application CI/CD. They serve different purposes.**

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

## � How GitHub Actions Accesses Your K3s Cluster

### The Connection Method
GitHub Actions connects to your K3s cluster using the **KUBECONFIG secret**, which contains:

1. **Cluster endpoint** - Your server's Tailscale IP (e.g., `100.x.x.x:6443`)
2. **Client certificate** - Authenticates GitHub Actions as a legitimate user
3. **Client key** - Private key for the certificate
4. **Cluster CA certificate** - Verifies your cluster's identity

### Security Flow
```bash
# 1. GitHub Actions runner gets the secret
KUBECONFIG_CONTENT: ${{ secrets.KUBECONFIG }}

# 2. Decodes and creates kubeconfig file
echo "$KUBECONFIG_CONTENT" | base64 -d > ~/.kube/config

# 3. kubectl uses this to connect via Tailscale network
kubectl cluster-info  # Connects to 100.x.x.x:6443
```

### Security Considerations

**✅ Secure Aspects:**
- **Tailscale network** - Only accessible via your private Tailscale network
- **Encrypted secrets** - GitHub encrypts secrets at rest and in transit
- **Limited scope** - Kubeconfig only has access to your cluster
- **Audit trail** - All deployments are logged in GitHub Actions

**⚠️ Security Trade-offs:**
- **Cloud dependency** - Relies on GitHub's security
- **Broad cluster access** - Kubeconfig typically has admin privileges
- **Secret exposure risk** - If GitHub account is compromised

### Alternative: More Secure Approaches

**Option 1: Limited Service Account (Recommended Improvement)**
```bash
# Create limited service account instead of using admin kubeconfig
kubectl create serviceaccount github-actions -n kube-system
kubectl create clusterrolebinding github-actions --clusterrole=cluster-admin --serviceaccount=kube-system:github-actions

# Use this token instead of full kubeconfig
kubectl create token github-actions -n kube-system --duration=8760h
```

**Option 2: ArgoCD Pull-based GitOps**
- ArgoCD runs **inside** your cluster
- **Polls** GitHub for changes (no inbound access needed)
- More secure but requires more setup

**Option 3: Self-hosted GitHub Runner**
- Run GitHub Actions runner **on your server**
- No network access needed from GitHub's cloud
- Requires runner maintenance

## �🔒 Current Security Features

- **Automated SSL certificates** via Let's Encrypt
- **RBAC** configured for service accounts
- **Network policies** (can be added)
- **Pod security standards** (can be enforced)
- **Secret management** via Kustomize + GitHub Secrets

## 🚦 Deployment Process

1. **Push to main** → Triggers GitHub Actions
2. **Validate** → YAML linting and Kustomize validation
3. **Deploy** → Apply changes to K3s cluster
4. **Verify** → Check deployment status

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
- [ ] Optional: Replace GitHub Actions with ArgoCD for advanced GitOps features

## 🤝 Contributing

This is a personal homelab setup, but feel free to:
1. Fork for your own homelab
2. Submit issues for bugs
3. Suggest improvements via PRs

---

**⚠️ Important**: This setup includes production secrets placeholders. Make sure to replace them with proper secret management before deploying!