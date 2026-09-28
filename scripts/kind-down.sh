#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="ai-ops-lab"

echo "=========================================="
echo " Deleting kind cluster: ${CLUSTER_NAME}"
echo "=========================================="

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    kind delete cluster --name "${CLUSTER_NAME}"
    echo "[+] Cluster '${CLUSTER_NAME}' deleted successfully."
else
    echo "[!] Cluster '${CLUSTER_NAME}' does not exist."
fi
