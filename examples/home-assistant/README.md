# Home Assistant Deployment

A complete Home Assistant deployment example using the official Docker Hub image for your homelab.

## 🏠 What This Deploys

- **Home Assistant Core** from Docker Hub (`homeassistant/home-assistant`)
- **Persistent configuration** storage
- **HTTPS access** via `https://home.ostbye.dev`
- **Host network access** for device discovery
- **Automated updates** via Drone CI

## 🏗️ Project Structure

```
home-assistant/
├── k8s/                     # Kubernetes manifests
│   ├── namespace.yaml       # Dedicated namespace
│   ├── pvc.yaml            # Persistent storage
│   ├── deployment.yaml      # Home Assistant deployment
│   ├── service.yaml         # Network service
│   └── ingress.yaml         # External HTTPS access
├── config/                  # Home Assistant configuration
│   ├── configuration.yaml   # Main config file
│   ├── automations.yaml     # Automation rules
│   └── scripts.yaml         # Custom scripts
├── .drone.yml              # CI/CD pipeline
├── docker-compose.yml       # Local development
└── README.md               # This file
```

## 🚀 Deployment Workflow

1. **Push configuration changes** to Gitea repository
2. **Drone CI triggers** and:
   - Validates configuration files
   - Updates ConfigMap with new config
   - Restarts Home Assistant if needed
3. **Home Assistant reloads** with new configuration
4. **Access via**: `https://home.ostbye.dev`

## 🔧 Local Development & Testing

```bash
# Clone from your Gitea instance
git clone https://git.ostbye.dev/username/home-assistant.git
cd home-assistant

# Test locally with Docker Compose
docker-compose up -d

# Access locally
open http://localhost:8123

# View logs
docker-compose logs -f homeassistant

# Stop local instance
docker-compose down
```

## ☸️ Kubernetes Features

### Persistent Storage
- **Configuration persistence** - Survives pod restarts
- **Database storage** - Home Assistant history preserved
- **Custom components** - Add-ons and integrations persist

### Network Access
- **Host network mode** - Access to local network devices
- **mDNS discovery** - Find smart home devices automatically
- **Port forwarding** - Direct access to device ports when needed

### Security
- **HTTPS only** - Automated Let's Encrypt certificates
- **Network policies** - Isolated network access (optional)
- **Resource limits** - Prevents resource exhaustion

## 🏠 Smart Home Integration

This deployment supports:
- **Zigbee/Z-Wave** devices (with USB dongles)
- **WiFi devices** discovery via mDNS
- **MQTT brokers** (can be deployed separately)
- **Voice assistants** (Google, Alexa integration)
- **Mobile app** access via HTTPS

## 📊 Configuration Management

### Automated Updates
Configuration changes are automatically deployed:

```bash
# Edit configuration
vim config/configuration.yaml

# Commit and push
git add config/
git commit -m "Add new automation"
git push origin main

# Drone CI automatically updates Home Assistant
```

### Backup Strategy
- **Git-based config backup** - All configuration in version control
- **Database backups** - Automated snapshots (can be added)
- **Restore process** - Deploy from Git history

## 🔄 CI/CD Pipeline Features

- **Configuration validation** - Check YAML syntax
- **Home Assistant config check** - Validate HA configuration
- **Rolling updates** - Zero-downtime deployments
- **Rollback capability** - Revert to previous version if needed

## 📱 Access & Monitoring

- **Web Interface**: `https://home.ostbye.dev`
- **Mobile Apps**: iOS/Android Home Assistant apps
- **Health Check**: Kubernetes probes monitor availability
- **Logs**: `kubectl logs -f deployment/homeassistant -n homeassistant`

Ready to deploy your smart home hub! 🏡✨