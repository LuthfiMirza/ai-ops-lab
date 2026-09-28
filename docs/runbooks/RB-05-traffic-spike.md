# Runbook: RB-05 - Traffic Spike & High Latency

## 1. Metadata
- **Incident Type:** Sudden Load Surge & Model Latency Degradation
- **Service Affected:** `sentiment-api`
- **Namespace:** `ai-ops`
- **Severity Level:** **P2** (Service responding slowly; p95 latency > 200ms)
- **Target SLO:** p95 Latency <= 150ms; HTTP Error Rate < 0.1%

---

## 2. Symptoms & Detection
1. **Prometheus Alert:** `HighInferenceLatency` (p95 > 200ms for 1m) or `HighHttpErrorRate` triggers.
2. **Grafana Dashboard:**
   - RED Metrics: HTTP Request Rate spikes from 2 req/s to 50+ req/s.
   - P95 / P99 Latency graph jumps into yellow/red thresholds.
3. **Client Perspective:** Upstream caller (e.g. Laravel queue worker) experiences timeout warnings.

---

## 3. Diagnostic Workflow

```
[HighInferenceLatency Alert Firing]
                |
                v
   Check Ingress & Pod Metrics in Grafana
                |
                +---> Is CPU throttling occurring?
                |     PromQL: container_cpu_cfs_throttled_seconds_total
                |
                +---> Are all API replicas at 100% CPU capacity?
                |
                v
   kubectl top pods -n ai-ops -l app=sentiment-api
                |
                v
   Immediate Triage:
   1. Scale API Replicas horizontally (HPA or manual)
   2. Verify DB Connection Pool capacity
   3. Check upstream client rate limits
```

### Essential Diagnostic Commands:
```bash
# 1. Check pod CPU and memory usage
kubectl top pods -n ai-ops -l app=sentiment-api

# 2. Check current replica count
kubectl get deployment sentiment-api -n ai-ops

# 3. Check Prometheus p95 inference latency metric
# PromQL: histogram_quantile(0.95, sum(rate(inference_duration_seconds_bucket[2m])) by (le))
```

---

## 4. Immediate Remediation

### Step 4.1: Fast Horizontal Scale-Out
Scale `sentiment-api` from 2 replicas to 4 or 6 replicas to distribute the inference load:
```bash
kubectl scale deployment sentiment-api -n ai-ops --replicas=4
kubectl rollout status deployment/sentiment-api -n ai-ops --timeout=45s
```

### Step 4.2: Verify Traffic Rebalancing
Confirm all new pods are receiving traffic:
```bash
kubectl get pods -n ai-ops -l app=sentiment-api -o wide
```

### Step 4.3: Scale-In (Post-Spike Normalization)
Once the traffic burst subsides and latency normalizes below 100ms:
```bash
kubectl scale deployment sentiment-api -n ai-ops --replicas=2
```

---

## 5. Long-Term Prevention & Automation
- Enable Horizontal Pod Autoscaler (HPA) targeting CPU utilization at 70%.
- Implement token-bucket rate limiting at Ingress controller level.
- Postmortem reference: [docs/06-gameday-report.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/06-gameday-report.md).
