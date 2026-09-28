# Runbook: RB-03 - OOMKilled (Exit Code 137)

## 1. Metadata
- **Incident Type:** Memory Exhaustion & Kernel cgroup kill (`OOMKilled` / Exit Code 137)
- **Service Affected:** `sentiment-api` (Container: `api`)
- **Namespace:** `ai-ops`
- **Severity Level:** **P1** (Frequent pod restarts lead to dropped client connections and high HTTP 502/504 errors)
- **Target SLO:** Pod restart frequency < 1 per week; Error budget burn rate < 1%.

---

## 2. Symptoms & Detection
1. **Prometheus Alert:** `HighHttpErrorRate` triggers due to connection drops mid-flight.
2. **Kubectl Status:**
   ```bash
   kubectl get pods -n ai-ops -l app=sentiment-api
   ```
   Pod exhibits sudden restarts (`RESTARTS > 0`), intermittent `CrashLoopBackOff`, or `OOMKilled`.
3. **Container State in Describe:**
   ```bash
   kubectl describe pod <pod-name> -n ai-ops
   ```
   Under `Last State: Terminated`:
   - `Reason: OOMKilled`
   - `Exit Code: 137` (128 + Signal 9 SIGKILL by Linux kernel)

---

## 3. Diagnostic Workflow

```
[Spike in 502/504 Errors or Restarts]
                  |
                  v
   kubectl describe pod <pod-name> -n ai-ops
                  |
                  +---> Reason: OOMKilled (Exit Code 137)
                  |
                  v
   Check Container Memory Limits & Current Usage
                  |
   kubectl top pod <pod-name> -n ai-ops (or Grafana memory panel)
                  |
                  v
   Differentiate:
   1. Memory Sizing Too Small for Model Artifact? (Fixed footprint)
   2. Memory Leak over time? (Sawtooth / monotonic upward curve)
   3. Large Batch Inference Payload? (Spike on single request)
```

### Essential Diagnostic Commands:
```bash
# 1. Check termination reason across all pods in namespace
kubectl get pods -n ai-ops -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount,LAST_REASON:.status.containerStatuses[*].lastState.terminated.reason,EXIT_CODE:.status.containerStatuses[*].lastState.terminated.exitCode

# 2. Inspect current resource limits
kubectl get deployment sentiment-api -n ai-ops -o jsonpath='{.spec.template.spec.containers[*].resources}'

# 3. Check memory usage in Grafana dashboard or via cgroup metrics
# PromQL: container_memory_working_set_bytes{namespace="ai-ops",pod=~"sentiment-api.*"}
```

---

## 4. Root Causes & Remediation

| Cause | Indicator | Action |
|---|---|---|
| **Under-provisioned Memory Limit** | Fails immediately during model load (`joblib.load`) or on first batch request | Increase memory limit to >= 256Mi in Deployment manifest |
| **Batch Inference Oversizing** | Memory spike correlates with request body size > 1MB | Implement request payload size limits in FastAPI middleware |
| **Python Process Memory Leak** | Memory grows linearly with request count without releasing | Profile object references, enforce garbage collection, or configure worker restarts (`gunicorn --max-requests`) |

---

## 5. Step-by-Step Mitigation

### Step 5.1: Increase Memory Limit Immediately (Hot-Patch)
Raise container memory limit and requests to provide breathing room:
```bash
kubectl set resources deployment/sentiment-api -n ai-ops \
    --limits=memory=384Mi \
    --requests=memory=128Mi

# Verify rollout status
kubectl rollout status deployment/sentiment-api -n ai-ops --timeout=60s
```

### Step 5.2: Verify Stability Under Load
Generate 50 inference requests and verify zero pod restarts:
```bash
bash scripts/generate-traffic.sh 50 0.1
kubectl get pods -n ai-ops -l app=sentiment-api
```

### Step 5.3: Permanent Fix in Git Repository
Update [k8s/deployment.yaml](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/k8s/deployment.yaml) with permanent limits and commit.

---

## 6. Post-Incident & Prevention
- Sizing rule: Set container memory limit at >= 2x the model baseline RSS footprint to accommodate peak garbage collection buffers.
- Postmortem reference: [PM-03-oomkilled.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/postmortems/PM-03-oomkilled.md).
