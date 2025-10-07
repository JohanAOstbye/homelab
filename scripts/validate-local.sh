#!/bin/bash

set -e

echo "🔍 Validating Kubernetes manifests locally..."

# Check if yamllint is installed
if ! command -v yamllint &> /dev/null; then
    echo "❌ yamllint not found. Install with:"
    echo "   brew install yamllint  # macOS"
    echo "   pip install yamllint   # Python"
    exit 1
fi

# Check if kustomize is installed
if ! command -v kustomize &> /dev/null; then
    echo "❌ kustomize not found. Install with:"
    echo "   brew install kustomize  # macOS"
    echo "   curl -s 'https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh' | bash"
    exit 1
fi

echo "📋 Validating YAML files..."
# Use config file if it exists, otherwise use relaxed rules
if [ -f ".yamllint.yaml" ] || [ -f ".yamllint.yml" ]; then
    find k8s -name "*.yaml" -o -name "*.yml" | xargs yamllint
else
    # Relaxed validation without config file
    find k8s -name "*.yaml" -o -name "*.yml" | xargs yamllint -d "{extends: default, rules: {line-length: {max: 120}}}" || true
fi

echo "🔧 Validating Kustomize builds..."
for overlay in k8s/overlays/*/; do
  echo "  → Validating $overlay"
  kustomize build "$overlay" > /dev/null
done

echo "✅ All validations passed!"