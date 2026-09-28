#!/usr/bin/env bash
set -e

# ==============================================================================
# AI Ops Lab: Database Disaster Recovery Restore Script (RTO Measurement)
# ==============================================================================
NAMESPACE="${NAMESPACE:-ai-ops}"
POD_NAME="${POD_NAME:-mysql-0}"
DB_NAME="${DB_NAME:-ai_ops_db}"
BACKUP_DIR="${BACKUP_DIR:-backups}"

INPUT_FILE="${1:-latest}"

if [ "${INPUT_FILE}" = "latest" ]; then
  TARGET_BACKUP="${BACKUP_DIR}/latest.sql.gz"
else
  TARGET_BACKUP="${INPUT_FILE}"
fi

if [ ! -f "${TARGET_BACKUP}" ]; then
  echo "❌ Error: Backup file not found: ${TARGET_BACKUP}"
  exit 1
fi

echo "=========================================================="
echo "AI Ops Lab: Starting Database Disaster Recovery Restore"
echo "Target Pod : ${POD_NAME} (Namespace: ${NAMESPACE})"
echo "Database   : ${DB_NAME}"
echo "Source File: ${TARGET_BACKUP}"
echo "=========================================================="

START_TIME_MS=$(python3 -c 'import time; print(int(time.time() * 1000))')

# Stream decompress and execute into mysql
gzip -dc "${TARGET_BACKUP}" | kubectl exec -i "${POD_NAME}" -n "${NAMESPACE}" -c mysql -- \
  mysql -u root -prootpassword "${DB_NAME}" 2>/dev/null

END_TIME_MS=$(python3 -c 'import time; print(int(time.time() * 1000))')
DURATION_MS=$(( END_TIME_MS - START_TIME_MS ))
DURATION_SEC=$(awk "BEGIN {print ${DURATION_MS} / 1000.0}")

# Verify recovered row count
RECOVERED_ROWS=$(kubectl exec -i "${POD_NAME}" -n "${NAMESPACE}" -c mysql -- \
  mysql -u root -prootpassword -N -e "SELECT COUNT(*) FROM ${DB_NAME}.sentiment_predictions;" 2>/dev/null || echo "N/A")

echo "✔ Disaster Recovery Restore Completed!"
echo "  Measured RTO (Recovery Time Objective): ${DURATION_SEC}s (${DURATION_MS}ms)"
echo "  Recovered Records: ${RECOVERED_ROWS} rows in sentiment_predictions"
echo "=========================================================="
