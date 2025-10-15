# Makefile Quick Reference

Your homelab now uses a simple Makefile for all operations. Here are the most common commands:

## 🚀 Essential Commands

```bash
# First-time setup
make setup-secrets          # Create config file
sudo nano /etc/homelab/config    # Edit your secrets

# Deploy
make deploy                  # Deploy with confirmation
make deploy-force           # Deploy without asking

# Update workflow
make update                 # Pull git changes and deploy

# Status & monitoring
make status                 # Show cluster status
make logs-deploy           # Show deployment logs
make check-config          # Verify secrets are set
```

## 🔧 Development & Validation

```bash
make validate              # Validate Kubernetes manifests
make validate-yaml         # Validate YAML syntax
make build                 # Build kustomize manifests (dry-run)
```

## 📊 Monitoring & Debugging

```bash
make logs                  # Show application logs
make cert-status          # Check SSL certificate status
make restart              # Restart all deployments
```

## 🧹 Maintenance

```bash
make clean                # Remove all homelab resources
make install-tools        # Install kubectl, kustomize, etc.
```

## 💡 Pro Tips

- **Instead of** `sudo /opt/homelab/scripts/deploy-server.sh`
- **Use** `make deploy` or `make deploy-force`

- **Instead of** remembering complex kubectl commands
- **Use** `make status` for overview

- **For regular updates:**
  ```bash
  make update  # This pulls git changes AND deploys them
  ```

- **Check everything is working:**
  ```bash
  make validate && make deploy
  ```

The Makefile is much more convenient and provides better user experience than running scripts directly!