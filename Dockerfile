# ══════════════════════════════════════════════════════════════════════════════
# Worker Rename Bot — Dockerfile
# Base: Python 3.10 slim (matches runtime.txt: python-3.10.15)
# ══════════════════════════════════════════════════════════════════════════════

FROM python:3.10-slim-bookworm

# ── Labels ────────────────────────────────────────────────────────────────────
LABEL maintainer="Worker Rename Bot"
LABEL description="Telegram file rename worker with FFmpeg metadata injection"

# ── System dependencies ───────────────────────────────────────────────────────
# ffmpeg       — media remux + metadata injection (ffmpeg -metadata ...)
# ffprobe      — bundled with ffmpeg package
# curl         — used by health-check and imgbb upload fallback
# ca-certificates — required for MongoDB Atlas TLS + HTTPS connections
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── Working directory ─────────────────────────────────────────────────────────
WORKDIR /app

# ── Python dependencies ───────────────────────────────────────────────────────
# Copy requirements first so Docker layer cache is reused on code-only changes
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ── Application code ──────────────────────────────────────────────────────────
COPY . .

# ── Temp directory for downloads / processing ────────────────────────────────
# Worker writes files here during download → ffmpeg → upload pipeline
RUN mkdir -p /tmp/worker_downloads && chmod 777 /tmp/worker_downloads

# ── Health-check port ─────────────────────────────────────────────────────────
# Matches Config.PORT default (8015) — override with PORT env var
EXPOSE 8015

# ── Health check (Koyeb / Railway / Render) ───────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8015}/ || exit 1

# ── Environment variable defaults ─────────────────────────────────────────────
# These are safe non-secret defaults; override ALL of them in your deployment.
# Secrets (BOT_TOKEN, MONGO_URI, API_HASH) must be injected at runtime —
# never bake them into the image.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8015 \
    WORKER_CONCURRENCY=3 \
    HEARTBEAT_INTERVAL=30 \
    WORKER_OFFLINE_TIMEOUT=120 \
    SHUTDOWN_GRACE_SECONDS=60

# ── Entry point ───────────────────────────────────────────────────────────────
CMD ["python", "worker_bot.py"]
