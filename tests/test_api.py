from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_check():
    """Verify /health returns 200 OK and model is marked as loaded."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["model_loaded"] is True
    assert data["model_type"] == "baseline-sklearn"


def test_metrics_endpoint():
    """Verify /metrics returns Prometheus text exposition with RED counters."""
    response = client.get("/metrics")
    assert response.status_code == 200
    content = response.text
    assert "http_requests_total" in content
    assert "http_request_duration_seconds" in content


def test_predict_positive_headline():
    """Verify /predict processes a positive stock headline and returns valid contract."""
    payload = {"inputs": "IHSG melonjak tajam ditopang aksi beli investor asing pada saham perbankan"}
    response = client.post("/predict", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["label"] in ["positive", "neutral", "negative"]
    assert 0.0 <= data["confidence"] <= 1.0
    assert -1.0 <= data["score"] <= 1.0
    assert "prob_positive" in data
    assert "prob_neutral" in data
    assert "prob_negative" in data


def test_predict_empty_input_validation():
    """Verify /predict rejects empty string payload with HTTP 422."""
    payload = {"inputs": "   "}
    response = client.post("/predict", json=payload)
    assert response.status_code == 422


def test_sentiment_alias_endpoint():
    """Verify /sentiment alias behaves identically to /predict for thesis compatibility."""
    payload = {"inputs": "Pergerakan harga saham TLKM cenderung mendatar di bursa"}
    response = client.post("/sentiment", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "label" in data
    assert "confidence" in data
    assert "score" in data
