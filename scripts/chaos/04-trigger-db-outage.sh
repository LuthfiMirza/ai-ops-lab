#!/usr/bin/env bash
# ==============================================================================
# Chaos Experiment 04: Database Outage & Graceful Degradation Simulation
# Description: Scales MySQL StatefulSet to 0 replicas to simulate total DB outage.
# Verifies that FastAPI continues to serve predictions without HTTP 500
# (graceful degradation) while reporting db_errors_total metrics, then recovers.
# ==============================================================================

set -euo pipefail

NAMESPACE="ai-ops"
STATEFULSET="mysql"

MODE="${1:---trigger}"

echo "================================================================="
echo "💥 Chaos Experiment 04: Database Outage & Graceful Fallback"
echo "================================================================="

case "$MODE" in
    --trigger)
        echo "🚨 [1/4] Simulating MySQL outage (scaling replicas to 0)..."
        kubectl scale statefulset/${STATEFULSET} -n ${NAMESPACE} --replicas=0

        echo "⏳ [2/4] Waiting 5 seconds for mysql-0 pod termination..."
        sleep 5
        kubectl get pods -n ${NAMESPACE} -l app=mysql

        echo ""
        echo "🚀 [3/4] Sending inference request to verify API Graceful Fallback:"
        RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST http://localhost:8080/sentiment \
            -H "Content-Type: application/json" \
            -d '{"text":"IHSG menguat di tengah sentimen positif rilis laporan keuangan perbankan."}')
        
        HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
        BODY=$(echo "$RESPONSE" | grep -v "HTTP_STATUS")

        echo "HTTP Status Code: ${HTTP_CODE}"
        echo "Response Payload: ${BODY}"

        if [ "$HTTP_CODE" -eq 200 ]; then
            echo "✅ SUCCESS: API did NOT crash (graceful degradation active!)."
        else
            echo "❌ FAILURE: API returned unexpected status ${HTTP_CODE}."
        fi

        echo ""
        echo "📊 [4/4] Verifying Prometheus db_errors_total metric:"
        curl -s http://localhost:8080/metrics | grep "db_errors_total" || echo "Metric not yet scraped."

        echo ""
        echo "👉 To recover, run: bash $0 --recover"
        ;;

    --recover)
        echo "🛠️  [1/2] Restoring MySQL StatefulSet (scaling replicas to 1)..."
        kubectl scale statefulset/${STATEFULSET} -n ${NAMESPACE} --replicas=1

        echo "⏳ [2/2] Waiting for mysql-0 to be Ready..."
        kubectl wait --for=condition=ready pod/mysql-0 -n ${NAMESPACE} --timeout=90s

        echo "✅ MySQL pod restored and ready:"
        kubectl get pods -n ${NAMESPACE} -l app=mysql

        echo ""
        echo "🧪 Testing end-to-end sentiment prediction with restored DB:"
        curl -s -X POST http://localhost:8080/sentiment \
            -H "Content-Type: application/json" \
            -d '{"text":"Pemulihan database sukses dan koneksi kembali normal."}' | jq . || true
        ;;

    *)
        echo "Usage: $0 [--trigger | --recover]"
        exit 1
        ;;
esac
