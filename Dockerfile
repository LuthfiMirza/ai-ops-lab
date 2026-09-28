# ==========================================
# Stage 1: Builder (compile & install wheels)
# ==========================================
FROM python:3.9-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install dependencies into a user target directory
RUN pip install --no-cache-dir --user -r requirements.txt

# ==========================================
# Stage 2: Final Minimal Runtime (Non-root)
# ==========================================
FROM python:3.9-slim AS runner

WORKDIR /app

# Security: Create non-root system user with fixed UID 10001
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -m -s /bin/bash appuser

# Copy installed Python packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Copy application source code and model artifacts
COPY --chown=appuser:appgroup app /app/app
COPY --chown=appuser:appgroup model /app/model

# Switch to non-root user
USER appuser

EXPOSE 8000

# Container liveness healthcheck without external dependencies (no curl needed in slim)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Start FastAPI serving server via Uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
