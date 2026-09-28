from prometheus_client import Counter, Histogram, generate_latest

# RED Metrics (Rate, Errors, Duration)
HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total count of HTTP requests processed by the API.",
    ["method", "endpoint", "status_code"]
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "http_request_duration_seconds",
    "Histogram of HTTP request latency duration in seconds.",
    ["method", "endpoint"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

PREDICTIONS_TOTAL = Counter(
    "predictions_total",
    "Total count of sentiment predictions served, labeled by sentiment class.",
    ["sentiment"]
)

MODEL_INFERENCE_DURATION_SECONDS = Histogram(
    "model_inference_duration_seconds",
    "Duration of model inference forward execution in seconds.",
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5]
)

DB_ERRORS_TOTAL = Counter(
    "db_errors_total",
    "Total count of database insert or connection failures.",
    ["operation"]
)

PREDICTIONS_PERSISTED_TOTAL = Counter(
    "predictions_persisted_total",
    "Total count of sentiment prediction records successfully committed to MySQL."
)


def get_latest_metrics() -> bytes:
    """Serialize current Prometheus registry into Prometheus exposition format."""
    return generate_latest()
