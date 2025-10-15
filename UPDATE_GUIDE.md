# Keeping Your Homelab Code Up to Date

Here are all the ways to manage updates for your homelab infrastructure:

## 🔄 Quick Update Workflow

### On Your Development Machine (Mac)
```bash
# Check what changes you have locally
make git-status

# See if there are updates from GitHub
make check-updates

# Commit any local changes first
git add .
git commit -m "Update configuration"
git push origin main
```

### On Your Homelab Server
```bash
cd /opt/homelab

# Check for and apply updates in one command
make update

# Or check first, then decide
make check-updates
# If updates available:
make update
```

## 📋 Detailed Commands

### Check Status
```bash
make git-status        # Show local changes and git status
make check-updates     # Check if remote has new commits
make status           # Check cluster deployment status
```

### Apply Updates
```bash
make update           # Pull git changes AND deploy them
make deploy           # Just deploy (without pulling)
make deploy-force     # Deploy without confirmation
```

### Development Workflow
```bash
# 1. Make changes on your Mac
# 2. Test locally
make validate

# 3. Commit and push
git add .
git commit -m "Add new service"
git push origin main

# 4. Deploy on server
# SSH to your server, then:
cd /opt/homelab
make update
```

## 🚀 Different Update Scenarios

### Scenario 1: Regular Updates
You pushed changes from your Mac and want to deploy them:

```bash
# On server
cd /opt/homelab
make update  # Pulls changes and deploys automatically
```

### Scenario 2: Check Before Updating
You want to see what changes are available first:

```bash
# On server
cd /opt/homelab
make check-updates  # Shows what commits are available
make update         # Apply them if you want
```

### Scenario 3: Emergency Deploy
Something broke and you need to redeploy quickly:

```bash
# On server
cd /opt/homelab
make deploy-force  # Deploys current code without git pull
```

### Scenario 4: Working Directly on Server
You made changes directly on the server:

```bash
# On server
cd /opt/homelab
make git-status     # See what you changed
git add .
git commit -m "Emergency fix"
git push origin main
make deploy-force   # Deploy the fix
```

## 🔧 Advanced Git Operations

### Reset to Latest Remote (Danger!)
If your local server code is messed up:

```bash
cd /opt/homelab
git fetch origin
git reset --hard origin/main  # ⚠️ Loses local changes!
make deploy-force
```

### Check Repository Location
```bash
# If you're not sure where you are:
pwd  # Should show /opt/homelab on server

# Or check if you're in sync:
make sync-server  # Syncs if you're in wrong location
```

## 📊 Monitoring Your Updates

### View Deployment History
```bash
make logs-deploy      # See recent deployment logs
git log --oneline -10 # See recent commits
```

### Verify Everything Works
```bash
make status          # Check cluster status
make validate        # Validate configuration
kubectl get pods -A  # See all running pods
```

## 💡 Pro Tips

1. **Always commit before updating:**
   ```bash
   make git-status && git add . && git commit -m "Save changes" && make update
   ```

2. **Safe update pattern:**
   ```bash
   make check-updates && make validate && make update
   ```

3. **Quick deploy after pushing from Mac:**
   ```bash
   # On server
   make update
   ```

4. **Check everything is working:**
   ```bash
   make update && make status
   ```

## 🚨 Troubleshooting

### "Repository is dirty" errors:
```bash
make git-status  # See what's uncommitted
git add .
git commit -m "Save local changes"
make update
```

### Deploy failed:
```bash
make logs-deploy  # Check what went wrong
make validate     # Check configuration
make status       # Check cluster state
```

### Can't pull updates:
```bash
git status
git stash         # Save local changes temporarily
make update
git stash pop     # Restore local changes if needed
```

The key is: **always use `make update` on your server** - it handles git pull + deployment in one safe command!