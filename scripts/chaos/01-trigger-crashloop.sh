#!/usr/bin/env bash
# ==============================================================================
# Chaos Experiment 01: CrashLoopBackOff Simulation & Recovery
# Description: Injects an invalid MODEL_PATH into the sentiment-api deployment,
# causing FastAPI to fail startup validation and enter CrashLoopBackOff.
# ==============================================================================

set -euo pipefail

NAMESPACE="ai-ops"
DEPLOYMENT="sentiment-api"
INVALID_PATH="/opt/app/invalid_nonexistent_model.joblib"
ORIGINAL_PATH="model/artifacts/baseline_tfidf_model.joblib"

MODE="${1:---trigger}"

echo "================================================================="
echo "💥 Chaos Experiment 01: CrashLoopBackOff Injection"
echo "================================================================="

case "$MODE" in
    --trigger)
        echo "🚨 [1/4] Injecting invalid MODEL_PATH into deployment/${DEPLOYMENT}..."
        kubectl set env deployment/${DEPLOYMENT} -n ${NAMESPACE} MODEL_PATH="${INVALID_PATH}"

        echo "⏳ [2/4] Waiting 8 seconds for new pods to fail startup..."
        sleep 8

        echo "📋 [3/4] Current Pod Status (look for CrashLoopBackOff or Error):"
        kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT}

        echo ""
        echo "🔍 [4/4] Diagnostic Proof (kubectl logs --previous or tail):"
        FAILED_POD=$(kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT} --no-headers | grep -E "CrashLoopBackOff|Error|0/1" | head -n 1 | awk '{print $1}' || true)
        if [ -n "$FAILED_POD" ]; then
            echo "Logs from failed pod [${FAILED_POD}]:"
            kubectl logs "${FAILED_POD}" -n ${NAMESPACE} -c ${DEPLOYMENT} --tail=10 || true
        else
            echo "Pod is still terminating/restarting. Run 'kubectl get pods -n ${NAMESPACE}' to observe."
        fi

        echo ""
        echo "👉 To recover, run: bash $0 --recover"
        ;;

    --recover)
        echo "🛠️  [1/2] Restoring valid deployment configuration (removing invalid MODEL_PATH)..."
        kubectl set env deployment/${DEPLOYMENT} -n ${NAMESPACE} MODEL_PATH-

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
