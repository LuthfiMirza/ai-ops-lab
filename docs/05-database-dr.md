# AI Ops Lab: Database Persistence & Disaster Recovery (RTO/RPO)

This document details the database architecture, schema indexing, application connection pooling, and disaster recovery (DR) procedures for the **AI Ops Lab** sentiment analysis service.

---

## 1. Architectural Design: StatefulSet vs. Deployment

In Kubernetes, stateless applications (like our FastAPI sentiment service) are deployed using **Deployments**, where pods are ephemeral and interchangeable. Databases, however, manage state and require strict guarantees:

| Characteristic | Deployment (Stateless) | StatefulSet (Stateful Database) |
|---|---|---|
| **Pod Identity** | Random hashes (`sentiment-api-778796bc-5mdzk`) | Stable, ordinal index (`mysql-0`, `mysql-1`) |
| **Network Identity** | Ephemeral IP behind ClusterIP service | Predictable DNS (`mysql-0.mysql-service...`) |
| **Storage Attachment** | Shared or ephemeral storage | Dedicated PersistentVolumeClaim per pod ordinal |
| **Termination Order** | Parallel termination | Graceful reverse ordinal termination (avoids write corruption) |

In [`k8s/mysql-statefulset.yaml`](../k8s/mysql-statefulset.yaml), we use `volumeClaimTemplates` to request a 1Gi volume from the cluster's default `standard` (`rancher.io/local-path`) StorageClass.

---

## 2. Database Schema & Query Optimization

The database schema is initialized declaratively via [`k8s/mysql-init-configmap.yaml`](../k8s/mysql-init-configmap.yaml):

```sql
CREATE DATABASE IF NOT EXISTS ai_ops_db;
USE ai_ops_db;

CREATE TABLE IF NOT EXISTS sentiment_predictions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    input_text TEXT NOT NULL,
    sentiment VARCHAR(32) NOT NULL,
    confidence DECIMAL(5, 4) NOT NULL,
    score DECIMAL(5, 4) NOT NULL,
    latency_ms DECIMAL(8, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_created_at (created_at),
    INDEX idx_sentiment (sentiment)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Indexing Strategy
- **`idx_created_at`:** Essential for filtering recent inferences, calculating daily trend aggregations, and running data retention purge jobs (`DELETE ... WHERE created_at < NOW() - INTERVAL 90 DAY`) without full-table scans.
- **`idx_sentiment`:** Speeds up grouping queries used by analytical reporting and Prometheus custom exporters (`GROUP BY sentiment`).

---

## 3. Application Integration & Architectural Resilience

### A. Connection Pooling (`DBUtils.PooledDB`)
Connecting to MySQL over TCP for every HTTP request incurs handshake and authentication overhead (~10-20ms). In [`app/db.py`](../app/db.py), we maintain a thread-safe connection pool with up to 10 persistent connections.

### B. Asynchronous Background Persistence
To protect client SLA/SLO, inference results are written to MySQL asynchronously via FastAPI's `BackgroundTasks`. The client receives the JSON prediction response immediately without waiting for disk I/O.

### C. Graceful Fallback
If the database goes offline or credentials become invalid:
- The API **does not return HTTP 500**. Model predictions continue serving smoothly.
- The failure is logged as a warning.
- Prometheus counter `db_errors_total{operation="insert"}` is incremented to trigger monitoring alerts.

---

## 4. Disaster Recovery (DR) Experiment: Measured RTO & RPO

### Definitions
- **RTO (Recovery Time Objective):** The maximum acceptable duration of downtime required to restore the service and database after a disaster.
- **RPO (Recovery Point Objective):** The maximum acceptable age of files/data that can be lost (the time elapsed between the last backup and the incident).

### Experiment Execution & Measured Results

1. **Populate Data:**
   Generated 15 transactions via [`scripts/generate-traffic.sh`](../scripts/generate-traffic.sh), committing 14 records to `sentiment_predictions`.
2. **Execute Snapshot Backup:**
   Ran [`scripts/backup.sh`](../scripts/backup.sh):
   - Output: `backups/backup_ai_ops_db_20260928_190210.sql.gz`
   - Archive size: `4.0 KB`
   - Duration: `< 1 second`
3. **Simulate Catastrophic Disaster:**
   Simulated total table drop (`DROP TABLE sentiment_predictions`).
4. **Execute Disaster Recovery Restore:**
   Ran [`scripts/restore.sh latest`](../scripts/restore.sh):
   - **Measured RTO:** **`0.247 seconds (247 ms)`**
   - **Data Recovered:** **`14 of 14 rows (100% data integrity verified)`**
5. **StatefulSet Pod Deletion Test:**
   Executed `kubectl delete pod mysql-0 -n ai-ops`. The StatefulSet recreated the pod in `~18s` and automatically reattached the same PVC volume (`mysql-data-mysql-0`), verifying zero data loss across pod restarts.

---

## 5. Operations Cheatsheet

```bash
# Check database records and distribution
make db-status

# Trigger an immediate compressed snapshot backup
make backup

# Restore from latest backup
make restore

# Restore from a specific backup file
make restore FILE=backups/backup_ai_ops_db_20260928_190210.sql.gz
```
