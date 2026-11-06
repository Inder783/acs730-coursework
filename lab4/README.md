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

## Reusable GitHub Actions Components

### Composite Action

A composite action combines multiple steps into a reusable unit within a job.

For Lab 4, I created `.github/actions/python-deps/action.yml`. It accepts a Python version as input, configures Python with pip caching, and installs the application dependencies.

The main CI workflow uses this action for Python 3.11 and 3.12 before running pytest.

### Reusable Workflow

A reusable workflow allows one GitHub Actions workflow to call another workflow containing one or more jobs.

For Lab 4, I created `.github/workflows/docker-build.yml`. It builds the Docker image, uses GitHub Actions layer caching, optionally publishes the image to GHCR, and uploads the image as an artifact.

The main workflow calls this reusable workflow after the Python tests pass.

### Key Difference

A composite action reuses steps inside an existing job, while a reusable workflow reuses entire jobs or workflows.

Composite actions are useful for repeated setup tasks. Reusable workflows are useful for standardizing larger CI/CD processes across projects.

### Verification

GitHub Actions Run #11, commit `38ebdd8`, completed successfully after both reusable components were integrated.

## Build and Run

Build the optimized Docker image from the repository root:

    docker build -t acs730-lab4:optimized -f lab4/Dockerfile lab4

Run the container:

    docker run --rm -d --name lab4-app -p 8000:8000 acs730-lab4:optimized

Test the health endpoint:

    curl http://localhost:8000/healthz

Expected response:

    {"status":"ok","version":"dev"}

Stop the container:

    docker stop lab4-app


## Why GHCR Uses SHA Tags

The GitHub Actions workflow publishes Docker images to GitHub
Container Registry (GHCR) using a tag based on the Git commit SHA.

Each SHA tag identifies the source-code revision used to build the
image. This makes it easier to trace deployments, investigate
problems, and identify which code version was deployed.

The latest tag can be overwritten whenever a new image is published.
Therefore, latest does not reliably identify a specific version.

SHA-based tagging is better for traceability and controlled rollbacks.
For stronger deployment guarantees, an image digest can be used to
identify the exact image content.


## GitHub Actions vs AWS-Native CI/CD

GitHub Actions runs automated tests, Docker builds, and publishing
jobs using GitHub-hosted runners. It integrates directly with
GitHub repositories and pull requests.

An equivalent AWS-native solution would use:

- AWS CodePipeline to coordinate the CI/CD stages.
- AWS CodeBuild to execute tests and build Docker images.
- Amazon ECR to store container images instead of GHCR.

### Runners and Credentials

GitHub Actions uses GitHub-hosted runners for the CI jobs.
Our workflow uses GITHUB_TOKEN to authenticate with GHCR and
publish container images.

AWS CodeBuild uses AWS-managed build environments.
It requires IAM service roles with appropriate permissions
to access AWS resources such as ECR and build artifacts.

### AWS Academy Limitations

In an AWS Academy environment, IAM permissions are restricted.
Students may be unable to create or modify the IAM roles
required to configure CodePipeline, CodeBuild, and ECR.

This can prevent a complete AWS-native CI/CD implementation
even when the AWS services are available.

### Recommendation

For this lab, I recommend GitHub Actions because the code
is already hosted on GitHub, hosted runners are available,
and required status checks integrate with pull requests.

AWS-native CI/CD would be more suitable for an organization
that needs deeper integration with AWS services and has
permission to manage the required IAM roles.


## Experiments

### Experiment 1 — Inverting Docker Layer Order

**Prediction:** If I move COPY app.py above the dependency
installation instructions, changing the application code will
invalidate the Docker cache and force pip to reinstall dependencies.
The rebuild should take longer than the optimized version.

**Execution:** I created a temporary Dockerfile with COPY app.py
before COPY requirements.txt and RUN pip install. I built the
image, added a temporary comment to app.py, and rebuilt it.
I also built the original optimized Dockerfile for comparison.

**Results:**

| Measurement | Inverted Dockerfile | Optimized Dockerfile |
|---|---|---|
| Rebuild time | 5.189 seconds | 0.619 seconds |
| Pip installation | Executed (4.3 seconds) | CACHED |

**Explanation:** The inverted Dockerfile reinstalled Flask and
Gunicorn because changing app.py invalidated an earlier Docker
layer. In the optimized Dockerfile, dependency installation
remained cached because requirements.txt had not changed.
The optimized rebuild was approximately 8.4 times faster.

**Undo:** I restored the original app.py and removed the
temporary Dockerfile. The original Dockerfile was not modified.


### Experiment 2 — Removing .dockerignore

**Prediction:** Removing .dockerignore might increase the amount
of data transferred during a Docker build because files such as
screenshots, tests, and the virtual environment would no longer
be excluded. However, I expected the final optimized image size
to remain unchanged because the Dockerfile copies only the
application and requirements files.

**Execution:** I created two temporary copies of the lab4
directory outside the Git repository. One retained .dockerignore,
while the other had it removed. I built both images and inspected
their sizes and the contents of /app.

**Results:**

| Measurement | With .dockerignore | Without .dockerignore |
|---|---|---|
| Reported context transfer | 511 bytes | 511 bytes |
| Image size | 130,049,846 bytes | 130,049,846 bytes |
| Build time | 0.281 seconds | 0.297 seconds |
| Files in /app | app.py, requirements.txt | app.py, requirements.txt |

**Explanation:** Both builds reported the same context transfer
size and produced identical images. This happened because the
optimized Dockerfile explicitly copies only app.py and
requirements.txt, while Docker BuildKit can optimize context
transfer to the files required by the build. Removing
.dockerignore did not increase the final image size in this
experiment, but .dockerignore remains useful for excluding
**Naive vs. optimized Dockerfile:** A naive Dockerfile that uses `COPY . .` can include unnecessary files in the image when `.dockerignore` is removed, increasing its size. Our optimized Dockerfile copies only `app.py` and `requirements.txt`, so removing `.dockerignore` did not increase the final image size. This comparison explains why selective `COPY` instructions and `.dockerignore` are both useful.
unnecessary or sensitive files from build contexts.

**Undo:** The experiment used temporary directories outside the
repository, so the original lab4/.dockerignore was never changed.

