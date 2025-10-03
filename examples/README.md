# Assistant App

## Git Repository Structure

This directory shows how a typical application repository would be structured when stored in your Gitea instance.

### Repository Contents

```
assistant-app/                 # Root of the Git repository
├── src/                      # Application source code
│   ├── main.py              # FastAPI application
│   └── requirements.txt     # Python dependencies
├── k8s/                     # Kubernetes deployment manifests
│   ├── deployment.yaml      # Application deployment
│   ├── service.yaml         # Service definition
│   └── ingress.yaml         # External access configuration
├── tests/                   # Unit tests
│   └── test_main.py         # Test suite
├── Dockerfile               # Container image definition
├── .drone.yml               # Drone CI pipeline configuration
├── requirements-dev.txt     # Development dependencies
└── README.md                # Project documentation
```

## � Available Examples

### 1. **Assistant App** (`assistant-app/`)
- **Custom application** deployment example
- **FastAPI** with Docker build process
- **Complete CI/CD** pipeline (test → build → deploy)
- **Custom container** creation and deployment

### 2. **Home Assistant** (`home-assistant/`)
- **Existing Docker Hub image** deployment
- **Configuration management** via ConfigMaps
- **Persistent storage** for smart home data
- **Host network access** for device discovery
- **Config-only updates** (no rebuilding containers)

## �🔄 Development Workflow

### 1. Developer Creates Repository in Gitea

**For Custom Applications (like Assistant App):**
```bash
# Create new repository in Gitea web interface
git clone https://git.ostbye.dev/username/assistant-app.git
cd assistant-app

# Copy example files
cp -r /path/to/homelab/examples/assistant-app/* .

# Initial commit
git add .
git commit -m "Initial assistant app structure"
git push origin main
```

**For Configuration-Based Applications (like Home Assistant):**
```bash
# Create new repository in Gitea web interface  
git clone https://git.ostbye.dev/username/home-assistant.git
cd home-assistant

# Copy example files
cp -r /path/to/homelab/examples/home-assistant/* .

# Customize configuration
vim config/configuration.yaml

# Initial commit
git add .
git commit -m "Initial Home Assistant setup"
git push origin main
```

### 2. Drone CI Automatically Triggers

When you push to the `main` branch, Drone CI will:

1. **Test Phase**: Install dependencies and run tests
2. **Build Phase**: Create Docker image tagged with commit hash
3. **Deploy Phase**: Update Kubernetes deployment with new image
4. **Notify Phase**: Send success notification

### 3. Application is Live

After successful deployment:
- **URL**: https://assistant.ostbye.dev
- **Health Check**: https://assistant.ostbye.dev/health
- **API Docs**: https://assistant.ostbye.dev/docs

## 🛠️ Local Development Setup

```bash
# Clone your repository
git clone https://git.ostbye.dev/username/assistant-app.git
cd assistant-app

# Set up Python environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r src/requirements.txt
pip install -r requirements-dev.txt

# Run locally
cd src
python main.py

# Test the API
curl http://localhost:8000/health
curl -X POST http://localhost:8000/ask -H "Content-Type: application/json" -d '{"question": "Hello!"}'

# Run tests
pytest tests/
```

## 🐳 Docker Development

```bash
# Build image locally
docker build -t assistant-app:dev .

# Run container
docker run -p 8000:8000 assistant-app:dev

# Test container
curl http://localhost:8000/health
```

## ☸️ Manual Kubernetes Deployment

For testing without CI/CD:

```bash
# Apply to your homelab cluster
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n public -l app=assistant
kubectl get ingress assistant-ingress -n public

# View logs
kubectl logs -n public -l app=assistant -f

# Clean up
kubectl delete -f k8s/
```

## 🔧 Customizing for Your Use Case

### Modify the Application

1. **Edit `src/main.py`** - Add your application logic
2. **Update `src/requirements.txt`** - Add necessary dependencies
3. **Modify `k8s/deployment.yaml`** - Adjust resource limits, replicas, etc.
4. **Update `k8s/ingress.yaml`** - Change the domain name

### Environment-Specific Configuration

Create different branches or use environment variables:

```yaml
# In deployment.yaml
env:
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: app-secrets
      key: database-url
- name: API_KEY
  valueFrom:
    secretKeyRef:
      name: app-secrets
      key: api-key
```

### Scaling the Application

```yaml
# In deployment.yaml
spec:
  replicas: 3  # Scale to 3 instances
```

## 🚀 Advanced CI/CD Features

### Multi-Environment Deployment

Modify `.drone.yml` to deploy to different environments:

```yaml
# Deploy to staging on feature branches
- name: deploy-staging
  image: bitnami/kubectl:latest
  commands:
  - kubectl apply -f k8s/ -n staging
  when:
    branch:
    - feature/*

# Deploy to production only on main
- name: deploy-production
  image: bitnami/kubectl:latest
  commands:
  - kubectl apply -f k8s/ -n public
  when:
    branch:
    - main
```

### Database Migrations

Add database migration steps:

```yaml
- name: migrate
  image: python:3.11-slim
  commands:
  - pip install alembic
  - alembic upgrade head
  when:
    branch:
    - main
```

### Security Scanning

Add security scanning to the pipeline:

```yaml
- name: security-scan
  image: aquasec/trivy:latest
  commands:
  - trivy image assistant-app:latest
```

## 📊 Monitoring and Logging

### Application Logs

```bash
# View application logs
kubectl logs -n public -l app=assistant -f

# View logs from specific pod
kubectl logs -n public assistant-deployment-xxx -f
```

### Metrics

The application exposes a `/metrics` endpoint that can be scraped by Prometheus (when added to your homelab).

### Health Checks

Kubernetes uses the `/health` endpoint for:
- **Liveness Probe**: Restart container if unhealthy
- **Readiness Probe**: Remove from service if not ready

## 🔒 Security Best Practices

1. **Non-root container**: Application runs as user 1000
2. **Resource limits**: CPU/memory limits prevent resource exhaustion
3. **Security context**: Drops all capabilities, prevents privilege escalation
4. **Health checks**: Ensures only healthy containers receive traffic
5. **TLS termination**: Ingress handles HTTPS certificates

## 📈 Next Steps

1. **Add real AI functionality** (OpenAI API, local LLM, etc.)
2. **Implement database persistence** (PostgreSQL, Redis)
3. **Add authentication** (JWT, OAuth)
4. **Implement caching** (Redis, memory cache)
5. **Add monitoring** (Prometheus metrics, Grafana dashboards)
6. **Implement rate limiting** and other API protections

This example shows the complete lifecycle from code to deployment in your homelab! 🎉