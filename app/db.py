import logging
import os
from typing import Optional
import pymysql
from dbutils.pooled_db import PooledDB
from app.metrics import DB_ERRORS_TOTAL, PREDICTIONS_PERSISTED_TOTAL

logger = logging.getLogger(__name__)

# Connection pool singleton
_POOL: Optional[PooledDB] = None


def get_db_pool() -> Optional[PooledDB]:
    """Initialize or return existing thread-safe MySQL connection pool."""
    global _POOL
    db_host = os.environ.get("DB_HOST")
    if not db_host:
        return None

    if _POOL is None:
        try:
            db_port = int(os.environ.get("DB_PORT", "3306"))
            db_name = os.environ.get("DB_NAME", "ai_ops_db")
            db_user = os.environ.get("DB_USER", "aiops_user")
            db_pass = os.environ.get("DB_PASSWORD", "aiops_password")

            _POOL = PooledDB(
                creator=pymysql,
                maxconnections=10,
                mincached=1,
                maxcached=5,
                maxshared=3,
                blocking=True,
                host=db_host,
                port=db_port,
                user=db_user,
                password=db_pass,
                database=db_name,
                charset="utf8mb4",
                cursorclass=pymysql.cursors.DictCursor,
                autocommit=True,
            )
            logger.info("MySQL connection pool established to %s:%d/%s", db_host, db_port, db_name)
        except Exception as exc:
            logger.warning("Failed to establish MySQL connection pool: %s", exc)
            DB_ERRORS_TOTAL.labels(operation="connect").inc()
            return None

    return _POOL


def save_prediction_log(
    input_text: str,
    sentiment: str,
    confidence: float,
    score: float,
    latency_ms: float,
) -> bool:
    """
    Persist prediction result into MySQL table `sentiment_predictions`.
    Implements graceful fallback: if database is offline or unconfigured,
    records a metric and log warning without failing API response.
    """
    pool = get_db_pool()
    if pool is None:
        return False

    try:
        conn = pool.connection()
        try:
            with conn.cursor() as cursor:
                sql = """
                    INSERT INTO sentiment_predictions
                    (input_text, sentiment, confidence, score, latency_ms)
                    VALUES (%s, %s, %s, %s, %s)
                """
                cursor.execute(sql, (input_text, sentiment, confidence, score, latency_ms))
            PREDICTIONS_PERSISTED_TOTAL.inc()
            return True
        finally:
            conn.close()
    except Exception as exc:
        logger.warning("Database write failed for prediction: %s", exc)
        DB_ERRORS_TOTAL.labels(operation="insert").inc()
        return False


def check_db_health() -> bool:
    """Ping database connection to verify readiness."""
    pool = get_db_pool()
    if pool is None:
        return False
    try:
        conn = pool.connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1")
            return True
        finally:
            conn.close()
    except Exception:
        return False
