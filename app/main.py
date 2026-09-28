import time
from fastapi import FastAPI, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse

from prometheus_client import CONTENT_TYPE_LATEST

from app.schemas import SentimentRequest, SentimentResponse, HealthResponse
from app.model_loader import get_model_loader
from app.metrics import (
    HTTP_REQUESTS_TOTAL,
    HTTP_REQUEST_DURATION_SECONDS,
    PREDICTIONS_TOTAL,
    MODEL_INFERENCE_DURATION_SECONDS,
    get_latest_metrics,
)

app = FastAPI(
    title="AI Ops Lab: Sentiment Analysis API",
    description="Operational microservice for Indonesian stock news sentiment analysis.",
    version="1.0.0",
)


@app.middleware("http")
async def track_metrics_middleware(request: Request, call_next):
    """
    HTTP middleware that measures request duration and counts requests
    to populate Prometheus RED metrics (Rate, Errors, Duration).
    """
    start_time = time.time()
    method = request.method
    path = request.url.path

    status_code = 500
    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    except Exception:
        status_code = 500
        raise
    finally:
        duration = time.time() - start_time
        # Record RED metrics
        HTTP_REQUESTS_TOTAL.labels(method=method, endpoint=path, status_code=str(status_code)).inc()
        HTTP_REQUEST_DURATION_SECONDS.labels(method=method, endpoint=path).observe(duration)


@app.get("/", summary="Root service status")
def root():
    return {
        "service": "AI Ops Lab: Sentiment Analysis API",
        "version": "1.0.0",
        "status": "operational",
        "docs": "/docs",
        "metrics": "/metrics",
        "health": "/health",
    }


@app.get("/health", response_model=HealthResponse, summary="Liveness and readiness health probe")
def health():
    """
    Health check endpoint used by Kubernetes liveness and readiness probes.
    Verifies that the inference model is loaded in memory.
    """
    try:
        loader = get_model_loader()
        is_loaded = loader.model is not None
        return HealthResponse(
            status="ok" if is_loaded else "degraded",
            model_loaded=is_loaded,
            model_type="baseline-sklearn"
        )
    except Exception as exc:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "unhealthy",
                "model_loaded": False,
                "error": str(exc)
            }
        )


@app.get("/metrics", summary="Prometheus scraping endpoint")
def metrics():
    """Prometheus exposition endpoint for metrics scraper."""
    return Response(content=get_latest_metrics(), media_type=CONTENT_TYPE_LATEST)


@app.post(
    "/predict",
    response_model=SentimentResponse,
    status_code=status.HTTP_200_OK,
    summary="Predict sentiment from news headline"
)
@app.post(
    "/sentiment",
    response_model=SentimentResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False,
    summary="Alias matching thesis sentiment_api.py endpoint"
)
def predict(payload: SentimentRequest):
    """
    Perform sentiment inference on input headline text.
    Contract matches the thesis application schema (label, confidence, score, probabilities).
    """
    input_text = payload.inputs or payload.text
    if not input_text or not input_text.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="inputs must not be empty"
        )

    loader = get_model_loader()

    # Track model inference execution latency specifically
    infer_start = time.time()
    try:
        prediction = loader.predict(input_text)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Inference execution failed: {str(exc)}"
        )
    finally:
        MODEL_INFERENCE_DURATION_SECONDS.observe(time.time() - infer_start)

    # Track prediction distribution by winning label
    PREDICTIONS_TOTAL.labels(sentiment=prediction["label"]).inc()

    return SentimentResponse(**prediction)
