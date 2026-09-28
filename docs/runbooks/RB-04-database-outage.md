# Runbook: RB-04 - Database Outage & Recovery

## 1. Metadata
- **Incident Type:** Database Backend Outage (`MySQL` StatefulSet down / unreachable)
- **Service Affected:** `mysql-0` (StatefulSet) / `sentiment-api` persistence layer
- **Namespace:** `ai-ops`
- **Severity Level:** **P2** (Predictions continue via graceful fallback; persistence is degraded)
- **Target RTO:** < 15 minutes; **Target RPO:** <= 1 hour (backup frequency)

---

## 2. Symptoms & Detection
1. **API Logs:**
   ```bash
   kubectl logs -l app=sentiment-api -n ai-ops --tail=30
   ```
   Outputs warning: `[DB Warning] Failed to log prediction to MySQL: ...`
2. **Prometheus Metric:** `db_errors_total{operation="insert"}` is incrementing continuously.
3. **Database Pod Status:**
   ```bash
   kubectl get pods -n ai-ops -l app=mysql
   ```
   `mysql-0` shows `Terminating`, `Pending`, `Error`, or 0 replicas.
4. **Client Impact:** HTTP requests to `/predict` and `/sentiment` still return `200 OK` with valid sentiment inference results (graceful degradation working as designed).

---

## 3. Diagnostic Workflow

```
[db_errors_total metric spiking]
               |
               v
   kubectl get pods -n ai-ops -l app=mysql
               |
   +-----------+-----------+
   |                       |
   v                       v
Pod missing / 0 replicas  Pod Pending / CrashLoopBackOff
   |                       |
   |                       +---> Check PVC: kubectl get pvc -n ai-ops
   |                       +---> Check MySQL error logs
   v
Scale up / restart StatefulSet
```

### Essential Diagnostic Commands:
```bash
# 1. Check MySQL pod status and events
kubectl get statefulset mysql -n ai-ops
kubectl describe pod mysql-0 -n ai-ops

# 2. Check PersistentVolumeClaim binding
kubectl get pvc -n ai-ops -l app=mysql

# 3. Read MySQL error log
kubectl logs mysql-0 -n ai-ops --tail=50

# 4. Verify network connectivity from API pod to MySQL Service
kubectl exec -it deployment/sentiment-api -n ai-ops -c api -- python3 -c "import socket; s = socket.socket(); s.connect(('mysql.ai-ops.svc.cluster.local', 3306)); print('TCP connection OK')"
```

---

## 4. Remediation Steps

### Scenario A: StatefulSet was scaled down or crashed
If replicas were set to 0 or pod was evicted:
```bash
kubectl scale statefulset mysql -n ai-ops --replicas=1
kubectl wait --for=condition=ready pod/mysql-0 -n ai-ops --timeout=90s
```

### Scenario B: Database Corrupted or Accidentally Dropped (Disaster Recovery)
If database files or tables were dropped or corrupted, restore from the latest verified backup:
```bash
# 1. Identify latest backup
ls -lh backups/mysql_backup_*.sql.gz

# 2. Execute automated disaster recovery restore script
bash scripts/restore.sh
```

---

## 5. Verification & Health Check
Verify end-to-end functionality once MySQL is restored:
```bash
# 1. Check pod status
kubectl get pods -n ai-ops

# 2. Fire test prediction
curl -s -X POST http://localhost:8080/sentiment \
    -H "Content-Type: application/json" \
    -d '{"text":"Verifikasi pemulihan database pasca insiden selesai."}'

# 3. Verify record was successfully written into MySQL
kubectl exec -i mysql-0 -n ai-ops -- mysql -u aiops_user -paiops_password ai_ops_db -e "SELECT id, LEFT(input_text, 35) as input_text, sentiment, confidence, created_at FROM sentiment_predictions ORDER BY id DESC LIMIT 1;"
```
