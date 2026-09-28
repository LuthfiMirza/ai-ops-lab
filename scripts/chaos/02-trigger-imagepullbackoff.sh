#!/usr/bin/env bash
# ==============================================================================
# Chaos Experiment 02: ImagePullBackOff Simulation & Recovery
# Description: Patches deployment with a non-existent container image tag,
# causing kubelet image pull failure and ErrImagePull / ImagePullBackOff.
# ==============================================================================

set -euo pipefail

NAMESPACE="ai-ops"
DEPLOYMENT="sentiment-api"
NONEXISTENT_IMAGE="sentiment-api:v999-chaos-nonexistent"

MODE="${1:---trigger}"

echo "================================================================="
echo "💥 Chaos Experiment 02: ImagePullBackOff Injection"
echo "================================================================="

case "$MODE" in
    --trigger)
        echo "🚨 [1/4] Updating image to nonexistent tag [${NONEXISTENT_IMAGE}]..."
        kubectl set image deployment/${DEPLOYMENT} -n ${NAMESPACE} sentiment-api="${NONEXISTENT_IMAGE}"

        echo "⏳ [2/4] Waiting 8 seconds for kubelet to attempt image pull..."
        sleep 8

        echo "📋 [3/4] Current Pod Status (look for ImagePullBackOff or ErrImagePull):"
        kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT}

        echo ""
        echo "🔍 [4/4] Kubernetes Warning Events:"
        kubectl get events -n ${NAMESPACE} --field-selector reason=Failed --sort-by='.lastTimestamp' | tail -n 5 || true

        echo ""
        echo "👉 To recover, run: bash $0 --recover"
        ;;

    --recover)
        echo "🛠️  [1/2] Rolling back deployment to previous healthy revision..."
        kubectl rollout undo deployment/${DEPLOYMENT} -n ${NAMESPACE}

        echo "⏳ [2/2] Waiting for deployment rollout to complete..."
        kubectl rollout status deployment/${DEPLOYMENT} -n ${NAMESPACE} --timeout=60s

        echo "✅ Pods restored and healthy:"
        kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT}
        ;;

    *)
        echo "Usage: $0 [--trigger | --recover]"
        exit 1
        ;;
esac
