#!/usr/bin/env bash
set -e

# ==============================================================================
# AI Ops Lab: Automated MySQL Database Backup Script (Disaster Recovery)
# ==============================================================================
NAMESPACE="${NAMESPACE:-ai-ops}"
POD_NAME="${POD_NAME:-mysql-0}"
DB_NAME="${DB_NAME:-ai_ops_db}"
BACKUP_DIR="${BACKUP_DIR:-backups}"

mkdir -p "${BACKUP_DIR}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/backup_${DB_NAME}_${TIMESTAMP}.sql.gz"
LATEST_LINK="${BACKUP_DIR}/latest.sql.gz"

echo "=========================================================="
echo "AI Ops Lab: Starting Database Backup"
echo "Target Pod : ${POD_NAME} (Namespace: ${NAMESPACE})"
echo "Database   : ${DB_NAME}"
echo "Destination: ${BACKUP_FILE}"
echo "=========================================================="

START_TIME=$(date +%s)

# Execute mysqldump inside mysql-0 and stream compressed backup to host
kubectl exec -i "${POD_NAME}" -n "${NAMESPACE}" -c mysql -- \
  mysqldump -u root -prootpassword \
  --single-transaction \
  --quick \
  --databases "${DB_NAME}" 2>/dev/null | gzip > "${BACKUP_FILE}"

END_TIME=$(date +%s)
DURATION=$(( END_TIME - START_TIME ))

# Update latest symlink
ln -sf "backup_${DB_NAME}_${TIMESTAMP}.sql.gz" "${LATEST_LINK}"

FILE_SIZE=$(du -h "${BACKUP_FILE}" | awk '{print $1}')

# Check record count inside database
RECORD_COUNT=$(kubectl exec -i "${POD_NAME}" -n "${NAMESPACE}" -c mysql -- \
  mysql -u root -prootpassword -N -e "SELECT COUNT(*) FROM ${DB_NAME}.sentiment_predictions;" 2>/dev/null || echo "N/A")

echo "✔ Backup completed successfully in ${DURATION}s"
echo "  File Size : ${FILE_SIZE}"
echo "  Row Count : ${RECORD_COUNT} records saved"
echo "  Symlink   : ${LATEST_LINK}"
echo "=========================================================="
