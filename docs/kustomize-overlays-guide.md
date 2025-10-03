# Kustomize Overlays Explained

This guide explains how Kustomize overlays work in your homelab setup and how to use them effectively.

## 🎯 The Problem Overlays Solve

**Without overlays, you'd have:**
- Duplicate YAML files for each environment
- Hard to maintain (change base config = update everywhere)
- Risk of inconsistencies between environments

**With overlays:**
- ✅ Single source of truth (base)
- ✅ Environment-specific customizations
- ✅ No duplication
- ✅ Easy to add new environments

## 📁 Directory Structure Explained

```
k8s/
├── base/                    # 🏗️ Foundation - works everywhere
│   ├── namespaces/
│   ├── cert-manager/
│   ├── gitea/
│   └── drone/
└── overlays/                # 🎨 Customizations per environment
    └── production/          # 🏭 Production-specific settings
        ├── kustomization.yaml
        ├── patches/
        └── secrets.yaml
```

## 🏗️ Base Layer Deep Dive

### What Goes in Base
**Core functionality that every environment needs:**

```yaml
# k8s/base/drone/server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drone-server
spec:
  containers:
    - name: drone-server
      image: drone/drone:latest  # Generic image
      env:
        - name: DRONE_SERVER_HOST
          value: "ci.ostbye.dev"   # Common config
      # No resource limits - added by overlays
      # No production-specific env vars
```

**Base kustomization.yaml:**
```yaml
# k8s/base/drone/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:          # What files to include
  - server.yaml
  - service.yaml
  - ingress.yaml
  - runner.yaml
```

## 🎨 Overlay Layer Deep Dive

### Production Overlay Structure

```
overlays/production/
├── kustomization.yaml       # Main overlay config
├── patches/                 # Customizations
│   ├── drone-production.yaml
│   └── gitea-production.yaml
├── secrets.yaml            # Environment secrets
└── timestamp-patch.yaml    # Generated dynamically
```

### Main Overlay Configuration

```yaml
# k8s/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: private          # Default namespace for resources

resources:                  # Include all base components
  - ../../base/namespaces
  - ../../base/cert-manager
  - ../../base/gitea
  - ../../base/drone
  - secrets.yaml           # Add environment-specific secrets

secretGenerator:           # Generate secrets with real values
  - name: cloudflare-api-token
    namespace: cert-manager
    literals:
      - token=CLOUDFLARE_TOKEN_PLACEHOLDER

patchesStrategicMerge:    # Apply environment-specific patches
  - patches/drone-production.yaml
  - patches/gitea-production.yaml

images:                   # Override image tags
  - name: drone/drone
    newTag: "2.23.0"      # Specific version for production
```

## 🔧 How Patches Work

Patches use **strategic merge** - they intelligently merge with base configurations:

### Example: Adding Resource Limits

**Base (no limits):**
```yaml
# k8s/base/drone/server.yaml
containers:
  - name: drone-server
    image: drone/drone:latest
    env:
      - name: DRONE_SERVER_HOST
        value: "ci.ostbye.dev"
```

**Production Patch:**
```yaml
# k8s/overlays/production/patches/drone-production.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drone-server        # Must match base deployment name
  namespace: private
spec:
  template:
    spec:
      containers:
        - name: drone-server # Must match base container name
          resources:         # ADDS resource limits
            requests:
              memory: "256Mi"
              cpu: "200m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
          env:              # ADDS new environment variables
            - name: DRONE_LOGS_DEBUG
              value: "false"
            - name: DRONE_DATABASE_DRIVER
              value: "sqlite3"
```

**Final Result (after kustomize build):**
```yaml
containers:
  - name: drone-server
    image: drone/drone:2.23.0    # From images override
    resources:                   # From patch
      requests: [memory: "256Mi", cpu: "200m"]
      limits: [memory: "1Gi", cpu: "1000m"]
    env:
      - name: DRONE_SERVER_HOST  # From base
        value: "ci.ostbye.dev"
      - name: DRONE_LOGS_DEBUG   # From patch
        value: "false"
      - name: DRONE_DATABASE_DRIVER # From patch
        value: "sqlite3"
```

## 🚀 Advanced Overlay Features

### 1. Secret Generation
```yaml
secretGenerator:
  - name: drone-secrets
    literals:
      - rpc-secret=generated-secret-value
      - gitea-client-id=oauth-app-id
```

### 2. ConfigMap Generation
```yaml
configMapGenerator:
  - name: app-config
    literals:
      - environment=production
      - log-level=warn
```

### 3. Image Tag Overrides
```yaml
images:
  - name: drone/drone
    newTag: "2.23.0"
  - name: drone/drone-runner-kube
    newTag: "1.0.0-rc.3"
```

### 4. Resource Transformers
```yaml
replicas:
  - name: drone-server
    count: 2              # Scale to 2 replicas in production

commonLabels:
  environment: production
  managed-by: kustomize
```

## 🌍 Adding More Environments

### Create Staging Environment
```bash
# Copy production overlay
cp -r k8s/overlays/production k8s/overlays/staging

# Customize for staging
cd k8s/overlays/staging
```

**Staging customizations:**
```yaml
# k8s/overlays/staging/kustomization.yaml
namePrefix: staging-      # All resources get "staging-" prefix

images:
  - name: drone/drone
    newTag: "latest"      # Use latest for testing

patchesStrategicMerge:
  - patches/drone-staging.yaml  # Different resource limits
```

**Staging patch:**
```yaml
# k8s/overlays/staging/patches/drone-staging.yaml
containers:
  - name: drone-server
    resources:
      requests: [memory: "128Mi", cpu: "100m"]  # Smaller resources
      limits: [memory: "512Mi", cpu: "500m"]
    env:
      - name: DRONE_LOGS_DEBUG
        value: "true"     # Debug enabled for staging
```

## 🔍 Testing and Validation

### Build Without Applying
```bash
# See production result
kustomize build k8s/overlays/production

# See staging result  
kustomize build k8s/overlays/staging

# Compare environments
diff <(kustomize build k8s/overlays/production) \
     <(kustomize build k8s/overlays/staging)
```

### Validate Before Deploy
```bash
# Validate YAML syntax
kustomize build k8s/overlays/production | kubectl apply --dry-run=client -f -

# Check what would change
kustomize build k8s/overlays/production | kubectl diff -f -
```

## 🎯 Best Practices

### 1. Keep Base Minimal
- Only include what ALL environments need
- No environment-specific configurations
- Use generic image tags (`latest` or no tag)

### 2. Use Descriptive Patch Names
```
patches/
├── drone-production.yaml     # Clear what it patches
├── gitea-high-availability.yaml
└── monitoring-production.yaml
```

### 3. Validate Changes
```bash
# Always test builds before committing
make validate

# Use dry-run for safety
kubectl apply --dry-run=server -k k8s/overlays/production
```

### 4. Document Overlay Differences
Keep a README in each overlay explaining its purpose:
```markdown
# Production Overlay

## Changes from Base:
- Resource limits: 1GB memory, 1 CPU
- Debug logging: disabled
- Specific image versions
- Production secrets
```

## 🚀 Real-World Benefits

1. **Easy rollbacks**: Change image tag in overlay, redeploy
2. **Environment parity**: Same base ensures consistency
3. **Safe testing**: Test patches in staging first
4. **Quick scaling**: Adjust replicas per environment
5. **Security**: Different secrets per environment

This overlay system makes your homelab incredibly maintainable and scalable! 🎉