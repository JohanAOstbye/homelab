# AI Assistant API

A simple AI assistant API that demonstrates a typical application deployment in the homelab.

## 🏗️ Project Structure

```
assistant-app/
├── src/                    # Application code
│   ├── main.py            # FastAPI application
│   ├── models/            # Data models
│   └── requirements.txt   # Python dependencies
├── k8s/                   # Kubernetes manifests
│   ├── deployment.yaml    # App deployment
│   ├── service.yaml       # Service definition
│   └── ingress.yaml       # External access
├── Dockerfile             # Container definition
├── .drone.yml             # CI/CD pipeline
└── README.md             # This file
```

## 🚀 Deployment Workflow

1. **Developer pushes code** to Gitea repository
2. **Drone CI triggers** and runs the pipeline:
   - Builds Docker image
   - Runs tests
   - Pushes to registry
   - Deploys to Kubernetes
3. **Application is accessible** at `https://assistant.ostbye.dev`

## 🔧 Local Development

```bash
# Clone from your Gitea instance
git clone https://git.ostbye.dev/username/assistant-app.git
cd assistant-app

# Install dependencies
pip install -r src/requirements.txt

# Run locally
python src/main.py

# Test the API
curl http://localhost:8000/health
curl -X POST http://localhost:8000/ask -d '{"question": "Hello!"}'
```

## 🐳 Docker

```bash
# Build image
docker build -t assistant-app:latest .

# Run container
docker run -p 8000:8000 assistant-app:latest
```

## ☸️ Kubernetes Deployment

```bash
# Deploy to your homelab
kubectl apply -f k8s/

# Check status
kubectl get pods -l app=assistant
kubectl get ingress assistant-ingress
```

## 📊 Monitoring

- **Health Check**: `https://assistant.ostbye.dev/health`
- **Metrics**: `https://assistant.ostbye.dev/metrics`
- **Logs**: `kubectl logs -l app=assistant -f`

## 🔄 CI/CD Pipeline

The `.drone.yml` file defines the automated pipeline:

1. **Test** - Run unit tests
2. **Build** - Create Docker image
3. **Push** - Push to container registry
4. **Deploy** - Update Kubernetes deployment

## 🎯 API Endpoints

- `GET /health` - Health check
- `POST /ask` - Ask the assistant a question
- `GET /metrics` - Prometheus metrics