# Runbook: RB-02 - ImagePullBackOff / ErrImagePull

## 1. Metadata
- **Incident Type:** Container Registry & Pull Failure (`ImagePullBackOff` / `ErrImagePull`)
- **Service Affected:** `sentiment-api` (Deployment)
- **Namespace:** `ai-ops`
- **Severity Level:** **P2** (Existing running pods still serve traffic due to RollingUpdate maxUnavailable limits; deployment rollout is blocked)
- **Target SLO:** Rollout success within 5 minutes.

---

## 2. Symptoms & Detection
1. **Deployment Rollout Hangs:**
   ```bash
   kubectl rollout status deployment/sentiment-api -n ai-ops
   # Output: Waiting for deployment "sentiment-api" rollout to finish...
   ```
2. **Kubectl Pod Status:**
   ```bash
   kubectl get pods -n ai-ops -l app=sentiment-api
   ```
   Output shows `STATUS: ImagePullBackOff` or `ErrImagePull` on new replacement pods.
3. **Existing Pods:** The old pods remain `1/1 Running` because Kubernetes will not terminate healthy replicas before new ones achieve readiness.

---

## 3. Diagnostic Workflow

```
[Deployment Blocked / ErrImagePull]
                 |
                 v
   kubectl describe pod <failing-pod> -n ai-ops
                 |
                 v
   Look at the "Events" section at the bottom:
   - "Failed to pull image ...: rpc error: not found" -> Bad tag / typo
   - "401 Unauthorized" / "403 Forbidden" -> Missing imagePullSecrets
   - "i/o timeout" / "connection refused" -> Registry network outage
```

### Essential Diagnostic Commands:
```bash
# 1. Identify failing pods
kubectl get pods -n ai-ops -l app=sentiment-api

# 2. Check the exact event reason
kubectl describe pod <failing-pod> -n ai-ops | grep -A 10 Events:

# 3. Check the configured image string in deployment
kubectl get deployment sentiment-api -n ai-ops -o jsonpath='{.spec.template.spec.containers[*].image}'
```

---

## 4. Common Root Causes & Immediate Triage

| Root Cause | Event Message | Remediation |
|---|---|---|
| **Typo in Image Tag / Name** | `repository does not exist or may require 'docker login'` | Verify CI build artifact tag. Revert deployment image or undo rollout. |
| **Missing Image in Local kind Node** | `pull access denied, repository does not exist` | For local kind clusters: `kind load docker-image sentiment-api:latest --name ai-ops-lab` |
| **Missing / Expired Registry Secret** | `no basic auth credentials` | Create/update `imagePullSecret` using `kubectl create secret docker-registry` |

---

## 5. Step-by-Step Mitigation & Rollback

### Step 5.1: Cancel Stuck Rollout (Rollback)
Revert immediately to the last working deployment revision:
```bash
kubectl rollout undo deployment/sentiment-api -n ai-ops
kubectl rollout status deployment/sentiment-api -n ai-ops --timeout=60s
```

### Step 5.2: If Image Exists Locally (kind cluster)
If the image was built locally on host Docker but not loaded into the kind node:
```bash
kind load docker-image sentiment-api:latest --name ai-ops-lab
kubectl rollout restart deployment/sentiment-api -n ai-ops
```

### Step 5.3: Verification
Verify that stuck pods are deleted and all running pods report `1/1 Ready`:
```bash
kubectl get pods -n ai-ops -l app=sentiment-api
```

---

## 6. Post-Incident & Prevention
- Add image existence check in CI/CD pipeline before deploying manifests.
- Enforce semantic release tags (avoid bare unversioned tags in production).
- Postmortem reference: [PM-02-imagepullbackoff.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/postmortems/PM-02-imagepullbackoff.md).
