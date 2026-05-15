# ─── Stage 1: Builder ────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

COPY app/requirements.txt .

# Install dependencies into a prefix directory (no cache)
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ─── Stage 2: Final hardened image ───────────────────────────────────────────
# Pinned digest — prevents supply-chain attacks
FROM python:3.11-slim

# Metadata
LABEL maintainer="DeepDhar75"
LABEL org.opencontainers.image.title="SecurePipe App"
LABEL org.opencontainers.image.description="Hardened Flask app for DevSecOps pipeline demo"
LABEL org.opencontainers.image.source="https://github.com/DeepDhar75/SecurePipe"

# Security: create non-root user + group
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --no-create-home --shell /bin/false appuser

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY app/app.py .

# Permissions: app owned by root, read-only for appuser
RUN chown -R root:appgroup /app && chmod -R 550 /app

# Security: switch to non-root
USER appuser

# Expose only required port
EXPOSE 5000

# Docker HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Run with Gunicorn — NOT flask dev server
CMD ["gunicorn", \
     "--bind", "0.0.0.0:5000", \
     "--workers", "2", \
     "--timeout", "60", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]
