# docker-python-golden-image

A production-ready, multi-stage Docker golden image for Python Flask applications.

## Project layout

```
.
├── Dockerfile          # Original multi-stage Dockerfile
├── Dockerfile-v2       # Hardened production Dockerfile (recommended)
├── requirements.txt    # Pinned Flask + Gunicorn dependencies
├── src/
│   └── app.py          # Minimal Flask app with / and /health endpoints
├── .dockerignore
└── .gitignore
```

## Quick start

Build the recommended image:

```bash
docker build -f Dockerfile-v2 -t flask-app:v2 .
```

Run locally:

```bash
docker run --rm -p 8080:8080 flask-app:v2
```

Verify:

```bash
curl http://localhost:8080/health   # {"status":"ok"}
curl http://localhost:8080/           # {"message":"Hello from Flask"}
```

## Dockerfile-v2 highlights

- **Multi-stage build** — compile dependencies in a builder stage, ship a minimal runtime
- **Digest-pinned base image** — reproducible builds on `python:3.11-slim`
- **Non-root user** — runs as UID `10001`
- **Virtual environment isolation** — dependencies installed in `/opt/venv`
- **Gunicorn** — production WSGI server (2 workers, 2 threads)
- **Health check** — built-in `HEALTHCHECK` against `/health`
- **BuildKit features** — pip cache mounts, bind-mounted `requirements.txt`, `COPY --link`

## Requirements

- Docker with BuildKit enabled (default in Docker Desktop and recent Docker Engine versions)
