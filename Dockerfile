# syntax=docker/dockerfile:1
# check=error=true

# ────────────────────────────────────────────────────────────────────────
# STAGE 1: Dependency Compiler (Builder)
# ────────────────────────────────────────────────────────────────────────
# Using a pinned, trusted minimal base image digest for deterministic builds
FROM python:3.11-slim@sha256:d55f0535e0dfa2e6843bf1e028b17c1bf2092cc63261a868f0cb18fffae12080 AS builder

# Enforce global shell pipe safety so errors anywhere in a pipeline fail the build step
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install native package compilers safely with cache-busting and ommitting recommends
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential=12.9 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Isolate dependencies in a virtual environment to prevent system package contamination
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Secure build-time caching and bind mounts:
# 1. Binds requirements.txt directly from build context without baking it into the image layers
# 2. Leverages a cache mount for pip so subsequent builds skip downloading cached wheels
RUN --mount=type=bind,source=requirements.txt,target=requirements.txt \
    --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt


# ────────────────────────────────────────────────────────────────────────
# STAGE 2: Secure Production Runtime
# ────────────────────────────────────────────────────────────────────────
# Rely on the same base image digest to maintain runtime library consistency
FROM python:3.11-slim@sha256:d55f0535e0dfa2e6843bf1e028b17c1bf2092cc63261a868f0cb18fffae12080 AS runtime

WORKDIR /app

# 1. Define matching, static numeric UID/GIDs to prevent host config conflicts
# 2. Work around the Go archive/tar sparse files bug by passing the --no-log-init flag
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup --no-log-init -m -s /sbin/nologin appuser

# Pull only the isolated dependencies and build artifacts from Stage 1
# Explicitly apply non-root chown permissions to the copied directories
COPY --from=builder --chown=appuser:appgroup /opt/venv /opt/venv
COPY --from=builder --chown=appuser:appgroup /build /app

# Copy your local application source files with safe permissions
COPY --chown=appuser:appgroup src/ /app/src/

# Prepend the virtual environment binaries to PATH to ensure dependencies load cleanly
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

# Switch active process context to the non-privileged runtime user
USER appuser

# Document standard container network ports
EXPOSE 8080

# Use JSON-array exec form to run python as PID 1, cleanly intercepting SIGTERM stop signals
ENTRYPOINT ["python", "src/app.py"]

