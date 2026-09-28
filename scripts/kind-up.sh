#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="ai-ops-lab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/kind-cluster-config.yaml"
IMAGE_NAME="ai-ops-lab-api:v1.0.0"

echo "=========================================="
echo " Starting local Kubernetes cluster: ${CLUSTER_NAME}"
echo "=========================================="

# 1. Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "[!] Cluster '${CLUSTER_NAME}' already exists. Switching context..."
    kubectl config use-context "kind-${CLUSTER_NAME}"
else
    echo "[+] Creating kind cluster using config: ${CONFIG_FILE}"
    kind create cluster --config "${CONFIG_FILE}"
fi

# 2. Load locally built container image into kind node
echo "[+] Loading Docker image '${IMAGE_NAME}' into kind cluster..."
kind load docker-image "${IMAGE_NAME}" --name "${CLUSTER_NAME}"

# 3. Deploy official NGINX Ingress Controller for kind
echo "[+] Deploying NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "[+] Waiting for Ingress controller pods to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s || {
    echo "[!] Warning: Ingress controller took longer than 120s to ready. Check with: kubectl get pods -n ingress-nginx"
}

echo "=========================================="
echo " Cluster '${CLUSTER_NAME}' is ready!"
echo " Ingress HTTP mapped to: http://localhost:8080"
echo " Ingress HTTPS mapped to: https://localhost:8443"
echo "=========================================="
