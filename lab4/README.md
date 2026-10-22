# ACS730 Lab 4 — Docker and GitHub Actions CI/CD

## Docker Image Optimization

### Image Comparison

| Measurement | Naive | Optimized |
|---|---|---|
| Base image | python:latest (Python 3.15.1) | python:3.12-slim-bookworm |
| Image size | 1.15 GB | 130 MB |
| Initial build | 26.850 seconds | 4.567 seconds |
| Rebuild after code change | 4.186 seconds | 0.504 seconds |
| Container user | root | appuser |

The optimized image is approximately 88.7% smaller.

### Base Image

The naive Dockerfile uses python:latest, which pulled a large Python image.
The optimized Dockerfile uses python:3.12-slim-bookworm, reducing image size
and providing a more predictable environment.

### Docker Layer Caching

The naive Dockerfile copies application files before installing dependencies.
A code change therefore invalidates the dependency installation layer.

The optimized Dockerfile copies requirements.txt and installs dependencies
before copying app.py.

During the optimized rebuild, Docker displayed CACHED for the pip install
step. The rebuild took 0.504 seconds compared with 4.186 seconds for naive.

### Dockerignore

The .dockerignore file excludes Git metadata, Python cache files, screenshots,
documentation, and other files not needed inside the container.

This reduces the build context and avoids unnecessary cache invalidation.

### Security

The naive container runs as root.

The optimized container uses a dedicated non-root user called appuser.
I verified this using docker exec lab4 whoami.

### Health Check

The optimized application responded successfully to:

curl -s http://localhost:8000/healthz

Response:

{"status":"ok","version":"dev"}

### Evidence

- evidence/image-sizes.png — Docker image size comparison screenshot.
