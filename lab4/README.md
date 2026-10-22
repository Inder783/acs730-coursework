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

## CI Caching Experiment

### Objective

Compare GitHub Actions performance with caching disabled, during the first cache-enabled run, and after the caches have been populated.

### Results

| Measurement | Baseline (No Cache) | Cache Miss | Cache Hit |
|---|---|---|---|
| Python dependency installation | 3 seconds | 2 seconds | 1 second |
| Docker image build step | 8 seconds | 16 seconds | 6 seconds |
| Pip cache | Disabled | Miss | Hit |
| Docker layer cache | Disabled | Cold build | Hit |

### Pip Caching

Python dependency caching was enabled using `actions/setup-python@v5` with `cache: pip`.

During the first cache-enabled run, GitHub Actions reported that the pip cache was not found. On the subsequent rerun, it reported a cache hit and successfully restored the cached packages.

Dependency installation improved from 3 seconds without caching to 1 second with a cache hit.

### Docker Layer Caching

Docker caching was configured using `docker/setup-buildx-action@v3` and `docker/build-push-action@v6` with GitHub Actions cache storage.

The first cache-enabled build took 16 seconds. The build executed the Dockerfile instructions and exported the resulting layers to GitHub Actions Cache.

On the subsequent rerun, Docker reported CACHED for the WORKDIR, dependency installation, application copy, and user creation layers.

The cached build completed in 6 seconds compared with the original 8-second baseline.

### Is Caching Worthwhile?

For this small application, caching provides a modest performance benefit. Python installation improved by 2 seconds, while the Docker build improved by 2 seconds compared with the uncached baseline.

However, creating the Docker cache initially increased build time to 16 seconds. This demonstrates that caching introduces overhead and may not always improve performance on the first run.

Caching becomes more valuable when dependencies are larger, builds are more expensive, and the same layers can be reused across multiple CI runs.

### Experiment Conclusion

The experiment confirmed that both pip and Docker layer caching work correctly. Cache hits improved the measured step durations, but the benefits must be compared against cache setup, transfer, and maintenance overhead.
