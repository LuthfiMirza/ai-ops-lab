# AI Ops Lab: Observability & Monitoring Architecture

This document describes the observability stack implemented for the **AI Ops Lab** sentiment analysis service.

---

## 1. Overview & Architecture

To operate an AI/ML microservice effectively in production, infrastructure metrics (CPU, RAM) alone are insufficient. We implement the **RED Method** (Rate, Errors, Duration) combined with domain-specific machine learning telemetry.

```
Client / Traffic Generator (scripts/generate-traffic.sh)
            │
            ▼
    Ingress Controller (:8080)
            │
            ▼
Kubernetes Service (sentiment-api-service.ai-ops.svc.cluster.local:8000)
            │
            ▼
FastAPI Sentiment Pods
    ├── GET /predict (serving sentiment inference)
    └── GET /metrics (Prometheus exposition endpoint)
            ▲
            │  Scrape Interval: 5s
            │
Prometheus (prom/prometheus:v2.51.0 in namespace `monitoring`)
    ├── Scrapes metrics endpoint
    ├── Evaluates alert rules every 5s
    └── Serves TSDB API on port 9090
            ▲
            │  Datasource Proxy (:9090)
            │
Grafana (grafana/grafana:10.4.0 in namespace `monitoring`)
    ├── Automated Datasource Provisioning
    ├── Automated Dashboard Provisioning
    └── Accessible at http://localhost:3000
```

---

## 2. Resource-Efficient Architecture (MacBook Optimization)

Per our project roadmap ([`PLAN.md`](../PLAN.md)), memory conservation on development hosts is a critical operational constraint. Rather than deploying heavy Helm stacks (e.g., `kube-prometheus-stack` which consumes 3-4 GB of RAM), we utilize **declarative, lightweight native manifests**:

| Component | Image | CPU Request / Limit | Memory Request / Limit |
|---|---|---|---|
| **Prometheus** | `prom/prometheus:v2.51.0` | `100m` / `500m` | `128Mi` / `384Mi` |
| **Grafana** | `grafana/grafana:10.4.0` | `100m` / `500m` | `128Mi` / `256Mi` |

**Total Monitoring RAM Footprint:** `< 500 MB` (smoothly coexisting with kind, Docker, and developer tools).

---

## 3. The RED Method for AI/ML Microservices

### A. Rate (Throughput)
Measures the incoming request volume to detect traffic spikes or unexpected drops.
- **PromQL:**
  ```promql
  sum(rate(http_requests_total[1m])) by (endpoint, status_code)
  ```

### B. Errors (Failure Frequency)
Calculates the proportion of failed HTTP requests (5xx server errors).
- **PromQL:**
  ```promql
  (sum(rate(http_requests_total{status_code=~"5.."}[1m])) / (sum(rate(http_requests_total[1m])) > 0) or vector(0)) * 100
  ```

### C. Duration (Latency Distribution)
Quantiles (p95 and p50) of end-to-end HTTP request processing time.
- **PromQL (p95):**
  ```promql
  histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))
  ```

---

## 4. Specialized AI/ML Telemetry

### Model Inference Latency vs. HTTP Latency
In standard web apps, request latency is primarily database or network I/O. In AI services, the CPU/GPU matrix multiplication of model inference dominates. We measure this separately:
- **Metric:** `model_inference_duration_seconds`
- **PromQL (p95):**
  ```promql
  histogram_quantile(0.95, sum(rate(model_inference_duration_seconds_bucket[1m])) by (le))
  ```

### Sentiment Prediction Distribution
Tracks business output and class balance. A sudden spike in neutral or negative predictions might indicate data drift or upstream scraping errors.
- **Metric:** `predictions_total{sentiment="positive|negative|neutral"}`
- **PromQL:**
  ```promql
  sum(increase(predictions_total[5m])) by (sentiment)
  ```

---

## 5. Alert Rules Configuration

Configured declaratively in [`monitoring/prometheus-configmap.yaml`](../monitoring/prometheus-configmap.yaml):

1. **`ServiceDown` (Severity: Critical)**
   - **Condition:** `up{job="ai-ops-api"} == 0` for `30s`
   - **Action:** Triggers when the sentiment API pods cannot be scraped.
2. **`HighHttpErrorRate` (Severity: Warning)**
   - **Condition:** 5xx errors > 5% over 1 minute.
   - **Action:** Triggers when server errors spike.
3. **`HighInferenceLatency` (Severity: Warning)**
   - **Condition:** p95 model inference latency > 500ms over 1 minute.
   - **Action:** Detects resource starvation or CPU throttling during model forward passes.

---

## 6. Accessing Grafana Dashboard

Grafana is pre-configured with anonymous read-only access and automated dashboard provisioning.

1. Start port-forwarding to local port 3000:
   ```bash
   make monitoring-port-forward
   ```
2. Open your browser:
   [http://localhost:3000/d/ai-ops-sentiment-red/ai-ops-lab3a-sentiment-service-red-metrics](http://localhost:3000/d/ai-ops-sentiment-red/ai-ops-lab3a-sentiment-service-red-metrics)
3. Generate simulated traffic:
   ```bash
   make traffic
   ```
4. Observe the live charts updating every 5 seconds.
