"""Multi-Cloud DevOps Demo - FastAPI App with Prometheus metrics."""

import os
import time
import random
import logging
from datetime import datetime

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from prometheus_client import CONTENT_TYPE_LATEST as PROMETHEUS_CONTENT_TYPE

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
)
logger = logging.getLogger("multi-cloud-app")

app = FastAPI(title="Multi-Cloud DevOps Demo", version="1.0.0")

REQUEST_COUNT = Counter("http_requests_total", "Total HTTP requests", ["method", "endpoint", "status"])
REQUEST_DURATION = Histogram("http_request_duration_seconds", "Request duration", ["method", "endpoint"])
ERROR_COUNT = Counter("http_errors_total", "Total HTTP errors", ["method", "endpoint", "error_type"])
UP_GAUGE = Gauge("app_up", "App health (1=healthy)")
PROCESSED_ITEMS = Counter("items_processed_total", "Items processed", ["item_type"])


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    method, endpoint = request.method, request.url.path
    start = time.time()
    try:
        response = await call_next(request)
        status = response.status_code
    except Exception:
        status = 500
        raise
    finally:
        duration = time.time() - start
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=status).inc()
        REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(duration)
        if status >= 400:
            ERROR_COUNT.labels(
                method=method, endpoint=endpoint,
                error_type="4xx" if status < 500 else "5xx"
            ).inc()
    return response


@app.get("/health")
async def health():
    UP_GAUGE.set(1)
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "version": "1.0.0",
    }


@app.get("/ready")
async def readiness():
    return {
        "status": "ready",
        "checks": {"database": "ok", "cache": "ok", "queue": "ok"},
    }


@app.get("/metrics")
async def metrics():
    return JSONResponse(
        content=generate_latest().decode("utf-8"),
        media_type=PROMETHEUS_CONTENT_TYPE,
    )


@app.get("/api/v1/info")
async def app_info():
    return {
        "name": "multi-cloud-devops-demo",
        "version": "1.0.0",
        "cloud": os.getenv("CLOUD_PROVIDER", "unknown"),
        "environment": os.getenv("APP_ENV", "development"),
    }


@app.post("/api/v1/process")
async def process_item(item_type: str = "default"):
    time.sleep(random.uniform(0.01, 0.2))
    if random.random() < 0.02:
        logger.error(f"Failed to process {item_type}")
        raise HTTPException(status_code=500, detail="Processing failed")
    PROCESSED_ITEMS.labels(item_type=item_type).inc()
    return {"status": "processed", "item_type": item_type}


@app.get("/api/v1/error-sim")
async def simulate_error(code: int = 500):
    raise HTTPException(status_code=code, detail=f"Simulated {code} error")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        log_level=os.getenv("LOG_LEVEL", "info").lower(),
    )