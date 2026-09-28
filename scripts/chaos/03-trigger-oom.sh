#!/usr/bin/env bash
# ==============================================================================
# Chaos Experiment 03: OOMKilled (Exit Code 137) Simulation & Recovery
# Description: Lowers memory limits of sentiment-api to 24Mi (insufficient for
# Python + Scikit-learn runtime) and triggers prediction requests to cause
# Linux cgroup kernel kill (OOMKilled).
# ==============================================================================

set -euo pipefail

NAMESPACE="ai-ops"
DEPLOYMENT="sentiment-api"
TINY_MEMORY_LIMIT="24Mi"
HEALTHY_MEMORY_LIMIT="256Mi"
HEALTHY_MEMORY_REQUEST="64Mi"

MODE="${1:---trigger}"

echo "================================================================="
echo "💥 Chaos Experiment 03: OOMKilled (Exit Code 137) Injection"
echo "================================================================="

case "$MODE" in
    --trigger)
        echo "🚨 [1/4] Throttling memory limit to ${TINY_MEMORY_LIMIT}..."
        kubectl set resources deployment/${DEPLOYMENT} -n ${NAMESPACE} \
            --limits=memory="${TINY_MEMORY_LIMIT}" \
            --requests=memory="${TINY_MEMORY_LIMIT}"

        echo "⏳ [2/4] Waiting 8 seconds for new pods to be scheduled..."
        sleep 8

        echo "🚀 [3/4] Firing sentiment inference requests to trigger memory pressure..."
        for i in {1..5}; do
            curl -s -X POST http://localhost:8080/sentiment \
                -H "Content-Type: application/json" \
                -d '{"text":"Saham teknologi mengalami kenaikan volume transaksi luar biasa di bursa efek."}' > /dev/null 2>&1 || true
        done
        sleep 4

        echo "📋 [4/4] Current Pod Status (look for OOMKilled / CrashLoopBackOff / Restarts):"
        kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT}

        echo ""
        echo "🔍 Termination Reason & Exit Code (grep OOMKilled / 137):"
        kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT} -o jsonpath='{range .items[*]}{.metadata.name}{"\tLastState: "}{.status.containerStatuses[*].lastState.terminated.reason}{"\tExitCode: "}{.status.containerStatuses[*].lastState.terminated.exitCode}{"\n"}{end}' || true

        echo ""
        echo "👉 To recover, run: bash $0 --recover"
        ;;

    --recover)
        echo "🛠️  [1/2] Restoring healthy memory limits (${HEALTHY_MEMORY_LIMIT}) and requests (${HEALTHY_MEMORY_REQUEST})..."
        kubectl set resources deployment/${DEPLOYMENT} -n ${NAMESPACE} \
            --limits=memory="${HEALTHY_MEMORY_LIMIT}" \
            --requests=memory="${HEALTHY_MEMORY_REQUEST}"

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
