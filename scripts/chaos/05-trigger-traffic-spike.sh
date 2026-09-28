#!/usr/bin/env bash
# ==============================================================================
# Chaos Experiment 05: High Traffic Load & Latency Spike Simulation
# Description: Generates sudden concurrent spikes of sentiment inference requests
# to test throughput, response latency, and trigger Prometheus alerts.
# ==============================================================================

set -euo pipefail

TOTAL_REQUESTS="${1:-100}"
CONCURRENCY="${2:-10}"
API_URL="http://localhost:8080/sentiment"

echo "================================================================="
echo "💥 Chaos Experiment 05: Traffic Spike & Latency Stress Test"
echo "================================================================="
echo "🎯 Target URL   : ${API_URL}"
echo "📊 Total Requests: ${TOTAL_REQUESTS}"
echo "⚡ Concurrency   : ${CONCURRENCY} parallel workers"
echo ""

START_TIME=$(date +%s)

echo "🚀 [1/3] Generating traffic spike..."

# Using a lightweight parallel worker loop
seq 1 "$TOTAL_REQUESTS" | xargs -n 1 -P "$CONCURRENCY" -I {} curl -s -X POST "${API_URL}" \
    -H "Content-Type: application/json" \
    -d '{"text":"Lonjakan transaksi pasar modal memicu aktivitas perdagangan saham perbankan dan energi melonjak tajam."}' \
    -o /dev/null -w "%{http_code}\n" | sort | uniq -c

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "⏱️  [2/3] Completed ${TOTAL_REQUESTS} requests in ~${DURATION}s"

echo ""
echo "📈 [3/3] Prometheus Alert Evaluation:"
echo "Checking alert rules on Prometheus (:9090)..."
curl -s http://localhost:9090/api/v1/alerts | jq -r '.data.alerts[]? | "🚨 Alert: \(.labels.alertname) | State: \(.state) | Severity: \(.labels.severity)"' || echo "No active alerts or Prometheus query failed."

echo ""
echo "📊 Current HTTP Request Rate on Sentiment API:"
curl -s http://localhost:8080/metrics | grep "http_requests_total" | head -n 5 || true
