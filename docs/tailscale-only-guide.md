# Tailscale Subnet Router Guide

This setup uses your home server as a **Tailscale subnet router** to provide secure access to `*.ostbye.dev` domains while keeping other traffic direct to internet.

## 🔒 Security Model

**Selective Tailscale routing:**
- `*.ostbye.dev` domains → Only accessible via Tailscale (routed through home network)
- Other domains → Direct internet access (normal speed)

**Split DNS ensures:**
- With Tailscale: `git.ostbye.dev` resolves to Tailscale IP → secure access
- Without Tailscale: `git.ostbye.dev` resolves to public IP → blocked by middleware

## 🌐 DNS Configuration

### **1. Cloudflare DNS (Public fallback)**
Set your public DNS records for users without Tailscale:

```bash
# Get your public IP
curl ipinfo.io/ip

# Set these A records in Cloudflare:
A    git.ostbye.dev    → YOUR_PUBLIC_IP
A    ci.ostbye.dev     → YOUR_PUBLIC_IP
```

### **2. Tailscale Subnet Router Setup**
Configure your home server as a subnet router:

```bash
# On your home server
sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes --accept-dns

# Approve subnet routing in Tailscale Admin Console:
# https://login.tailscale.com/admin/machines
# Find your server → Edit route settings → Approve subnet routes
```

### **3. Tailscale DNS Override**
Configure Tailscale to override DNS for ostbye.dev:

**Option A: MagicDNS (Recommended)**
1. Go to: https://login.tailscale.com/admin/dns
2. Enable **MagicDNS**
3. Add **Split DNS**:
   ```
   Domain: ostbye.dev
   Nameserver: 100.x.x.x (your server's Tailscale IP)
   ```

**Option B: Global nameserver**
1. In Tailscale DNS settings
2. Add your server's Tailscale IP as a nameserver
3. Clients will query your server for *.ostbye.dev

## 🛡️ How It Works

### **Subnet Router Traffic Flow**
```
Tailscale Client → Tailscale Mesh → Home Server (subnet router) → Local Network → Kubernetes
Your device        100.x.x.x      192.168.1.100 (server)       192.168.1.100   Services
```

**Traffic appears to come from home network (192.168.1.x)**, so middleware allows access.

### **Traefik Middleware Filtering**
```yaml
# Only home network IPs are allowed:
sourceRange:
  - "192.168.1.0/24"      # Your home network (all Tailscale traffic routes here)  
  - "127.0.0.1/32"        # Localhost for health checks
```

### **DNS Resolution Magic**
- **With Tailscale**: `git.ostbye.dev` → Tailscale IP → Subnet router → Allowed
- **Without Tailscale**: `git.ostbye.dev` → Public IP → Direct connection → Blocked

### **⚠️ IMPORTANT: Update Your Home Network**

**Find your home network range:**
```bash
# On your server
ip route | grep "192.168"
# or
hostname -I

# Update middleware if your network is different (e.g., 10.0.0.0/24)
```

## 🧪 Testing Access

### **Verify Subnet Routing Works:**
```bash
# From Tailscale client device
tailscale status
# Should show: "192.168.1.0/24 via 100.x.x.x"

# Test you can reach home network
ping 192.168.1.1        # Your router
ping 192.168.1.100      # Your server (adjust IP)
```

### **Test DNS Resolution:**
```bash
# With Tailscale connected
nslookup git.ostbye.dev
# Should resolve to Tailscale IP (100.x.x.x) or home network IP

# Without Tailscale  
nslookup git.ostbye.dev
# Should resolve to public IP
```

### **Test Service Access:**
```bash
# From Tailscale device (should work)
curl -I https://git.ostbye.dev
curl -I https://ci.ostbye.dev
# Should return 200 OK

# From public internet (should be blocked)
curl -I https://git.ostbye.dev  
curl -I https://ci.ostbye.dev
# Should return 403 Forbidden
```

## 🔧 Configuration Files

### **Middleware**: `k8s/base/tailscale-middleware.yaml`
```yaml
spec:
  ipWhiteList:
    sourceRange:
      - "192.168.1.0/24"  # Home network (adjust to your network)
      - "127.0.0.1/32"    # Localhost
```

### **Applied to services:**
- **Gitea**: `k8s/base/gitea/ingress.yaml`
- **Drone**: `k8s/base/drone/ingress.yaml`

Both reference the shared middleware:
```yaml
traefik.ingress.kubernetes.io/router.middlewares: private-tailscale-only@kubernetescrd
```

### **Tailscale Server Setup:**
```bash
# Enable subnet routing and DNS
sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes --accept-dns
```

## 🚀 Benefits

- ✅ **Complete privacy** - No public access to any part of your services
- ✅ **Stable DNS** - Public IP means no changing Tailscale IP issues
- ✅ **Simple setup** - No separate admin domains needed
- ✅ **Automatic SSL** - Let's Encrypt works via DNS challenge
- ✅ **Emergency access** - Can disable middleware if needed

## 🐛 Troubleshooting

### **Can't Access Services**

1. **Check Tailscale subnet routing:**
   ```bash
   tailscale status --peers
   # Should show your server advertising 192.168.1.0/24
   
   tailscale status  
   # Should show "192.168.1.0/24 via 100.x.x.x"
   ```

2. **Test network connectivity:**
   ```bash
   # Can you reach home network through Tailscale?
   ping 192.168.1.1        # Router
   ping 192.168.1.100      # Server
   ```

3. **Check DNS resolution:**
   ```bash
   nslookup git.ostbye.dev
   # With Tailscale: should resolve to Tailscale/home IP
   # Without Tailscale: should resolve to public IP
   ```

4. **Check middleware configuration:**
   ```bash
   kubectl get middleware tailscale-only -n private -o yaml
   # Verify 192.168.1.0/24 matches your actual home network
   ```

5. **Check Traefik logs:**
   ```bash
   kubectl logs -f deployment/traefik -n kube-system | grep -E "192\.168|forbidden|reject"
   ```

### **Emergency Public Access**
If you need to temporarily allow public access:

```bash
# Remove middleware from Gitea
kubectl patch ingress gitea-ingress -n private --type='json' \
  -p='[{"op": "remove", "path": "/metadata/annotations/traefik.ingress.kubernetes.io~1router.middlewares"}]'

# Access your service publicly to fix issues
# Then re-enable security:
kubectl patch ingress gitea-ingress -n private --type='json' \
  -p='[{"op": "add", "path": "/metadata/annotations/traefik.ingress.kubernetes.io~1router.middlewares", "value": "private-tailscale-only@kubernetescrd"}]'
```

### **Different Home Network Range**
If your home network uses a different range:

```yaml
# Update tailscale-middleware.yaml for your network
sourceRange:
  - "10.0.0.0/24"       # If you use 10.x.x.x network
  - "172.16.0.0/24"     # If you use 172.x.x.x network  
  - "127.0.0.1/32"      # Always keep localhost
```

### **Subnet Routing Not Working**
```bash
# Re-enable subnet routing on server
sudo tailscale down
sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes --accept-dns

# Approve in Tailscale admin console
# https://login.tailscale.com/admin/machines
```

## 🎯 Perfect for

- **Selective privacy** - Only homelab services use Tailscale, other traffic stays fast
- **Home-centric setup** - All Tailscale traffic routes through your home network
- **Simple management** - One network range to manage (192.168.1.0/24)
- **Stable routing** - No dependence on changing Tailscale IP assignments
- **DNS flexibility** - Clients automatically get correct IPs based on Tailscale connection

## ⚡ Quick Setup Steps

1. **Enable subnet routing on server:**
   ```bash
   sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes --accept-dns
   ```

2. **Approve subnet in Tailscale admin**

3. **Configure DNS override for *.ostbye.dev** (MagicDNS recommended)

4. **Deploy middleware** (already configured for 192.168.1.0/24)

This setup gives you **selective secure access**: homelab services via Tailscale, everything else direct for speed! �