# Runbook: RB-01 - CrashLoopBackOff on Sentiment API

## 1. Metadata
- **Incident Type:** Pod Lifecycle Failure (`CrashLoopBackOff`)
- **Service Affected:** `sentiment-api` (Deployment)
- **Namespace:** `ai-ops`
- **Severity Level:** **P1** (Critical if all replicas fail; **P2** if partial)
- **Target SLO:** Availability >= 99.5% (< 21.6m downtime/month)

---

## 2. Symptoms & Detection
1. **Prometheus Alert:** `ServiceDown` or `HighHttpErrorRate` triggers in `#alerts-aiops`.
2. **Kubectl Status:**
   ```bash
   kubectl get pods -n ai-ops -l app=sentiment-api
   ```
   Output displays `STATUS: CrashLoopBackOff` or `Error` with increasing restart counts (`RESTARTS > 3`).
3. **Ingress / HTTP Response:** Clients receive `HTTP 502 Bad Gateway` or `HTTP 503 Service Unavailable`.

---

## 3. Diagnostic Workflow

```
[Alert Fired / Pod Failing]
             |
             v
   kubectl get pods -n ai-ops
             |
             +---> Status: CrashLoopBackOff
             |
             v
   kubectl describe pod <pod-name> -n ai-ops
             |
             v
   Inspect "Last State: Terminated" & "Exit Code"
   - Exit Code 1 / 2: Application/Python runtime error (check logs)
   - Exit Code 137: OOMKilled (see RB-03)
             |
             v
   kubectl logs <pod-name> -n ai-ops --previous --tail=50
```

### Essential Diagnostic Commands:
```bash
# 1. Check pod status and restart count
kubectl get pods -n ai-ops -l app=sentiment-api

# 2. Inspect container events and termination state
kubectl describe pod <pod-name> -n ai-ops

# 3. Read previous logs before the container crashed
kubectl logs <pod-name> -n ai-ops -c api --previous --tail=50

# 4. Check deployment configuration changes (ConfigMap, Secret, Env)
kubectl get deployment sentiment-api -n ai-ops -o yaml | grep -A 10 env:
```

---

## 4. Common Root Causes & Immediate Triage

| Root Cause | Diagnostic Indicator in Logs | Mitigation Step |
|---|---|---|
| **Missing Model File / Invalid Path** | `FileNotFoundError: Model artifact not found at ...` | Verify ConfigMap `MODEL_PATH` or rollback deployment: `kubectl rollout undo deployment/sentiment-api -n ai-ops` |
| **Missing Environment Variable** | `KeyError: 'DATABASE_URL'` or startup assertion error | Check `k8s/sentiment-api-configmap.yaml` and `k8s/sentiment-api-secret.yaml` |
| **Syntax / Dependency Error** | `ModuleNotFoundError: No module named '...'` | Roll back to previous container image version in deployment |

---

## 5. Step-by-Step Mitigation & Rollback

### Step 5.1: Immediate Rollback to Last Stable Revision
If a new release caused the crash, execute an immediate rollback:
```bash
kubectl rollout undo deployment/sentiment-api -n ai-ops
kubectl rollout status deployment/sentiment-api -n ai-ops --timeout=60s
```

### Step 5.2: Hot-Fixing Bad Environment Variables
If the error is caused by a wrong environment variable (e.g. `MODEL_PATH`):
```bash
kubectl set env deployment/sentiment-api -n ai-ops MODEL_PATH="model/artifacts/baseline_tfidf_model.joblib"
```

### Step 5.3: Verification
Verify that new pods transition to `Running` and `1/1 Ready`:
```bash
kubectl get pods -n ai-ops -l app=sentiment-api
curl -f http://localhost:8080/health
```

---

## 6. Escalation & Post-Incident
- If unresolved after 15 minutes, page the Secondary On-Call / AI Platform Engineer.
- Initiate Blameless Postmortem (see [PM-01-crashloopbackoff.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/postmortems/PM-01-crashloopbackoff.md)).
