# Docker Best Practices

**Author:** Cloud Native Community
**Last Updated:** 2025-11-25
**Status:** Community Guidelines

---

## Overview

This guide covers best practices for building, securing, and deploying Docker containers. These guidelines help ensure your containers are secure, efficient, and production-ready.

## Image Building

### Use Official Base Images

Start with official, minimal base images from trusted sources:

```dockerfile
# Prefer official images
FROM python:3.11-slim

# Or minimal distroless images for production
FROM gcr.io/distroless/python3-debian11
```

### Multi-Stage Builds

Use multi-stage builds to reduce final image size:

```dockerfile
# Build stage
FROM python:3.11 AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Runtime stage
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["python", "app.py"]
```

### Layer Optimization

Optimize layer caching by ordering commands from least to most frequently changed:

```dockerfile
# Install system dependencies (rarely changes)
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files (changes occasionally)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code (changes frequently)
COPY . .
```

## Security Best Practices

### Run as Non-Root User

Always run containers as non-root users:

```dockerfile
FROM python:3.11-slim

# Create a non-root user
RUN useradd -m -u 1000 appuser

# Set ownership
WORKDIR /app
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

CMD ["python", "app.py"]
```

### Minimize Attack Surface

- Remove unnecessary packages and tools
- Use `.dockerignore` to exclude sensitive files
- Don't include development dependencies in production images

```dockerfile
# .dockerignore example
.git
.env
*.pyc
__pycache__
tests/
.vscode/
README.md
```

### Scan for Vulnerabilities

Regularly scan images for security vulnerabilities:

```bash
# Using Docker Scout
docker scout cves my-image:latest

# Using Trivy
trivy image my-image:latest
```

## Image Size Optimization

### Use Slim or Alpine Variants

Choose smaller base images when possible:

```dockerfile
# Standard image (~900MB)
FROM python:3.11

# Slim variant (~150MB)
FROM python:3.11-slim

# Alpine variant (~50MB, but may have compatibility issues)
FROM python:3.11-alpine
```

### Clean Up in Same Layer

Combine install and cleanup in the same RUN command:

```dockerfile
RUN apt-get update && apt-get install -y \
    build-essential \
    && pip install --no-cache-dir -r requirements.txt \
    && apt-get purge -y build-essential \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
```

### Use .dockerignore

Exclude unnecessary files from build context:

```
**/.git
**/__pycache__
**/*.pyc
**/node_modules
**/venv
.env*
```

## Configuration Management

### Environment Variables

Use environment variables for configuration:

```dockerfile
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

EXPOSE ${PORT}
```

### Build Arguments

Use build arguments for build-time configuration:

```dockerfile
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim

ARG APP_VERSION
LABEL version="${APP_VERSION}"
```

Build with arguments:

```bash
docker build --build-arg APP_VERSION=1.0.0 -t my-app:1.0.0 .
```

## Health Checks

Define health checks in your Dockerfile:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

Or use a Python-based health check:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"
```

## Metadata and Labels

Use labels for image metadata:

```dockerfile
LABEL maintainer="team@example.com" \
      version="1.0.0" \
      description="My application" \
      org.opencontainers.image.source="https://github.com/myorg/myapp"
```

## Docker Compose Best Practices

### Version Control

Always specify versions for services:

```yaml
version: '3.8'

services:
  app:
    image: my-app:1.0.0
    build:
      context: .
      dockerfile: Dockerfile
```

### Resource Limits

Define resource limits:

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

### Health Checks

```yaml
services:
  app:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s
```

## Production Deployment

### Don't Use Latest Tag

Always use specific version tags:

```bash
# Bad
docker pull my-app:latest

# Good
docker pull my-app:1.0.0
```

### Use Read-Only Filesystems

When possible, use read-only root filesystems:

```dockerfile
# In Kubernetes
securityContext:
  readOnlyRootFilesystem: true

# With docker run
docker run --read-only my-app:1.0.0
```

### Limit Capabilities

Drop unnecessary Linux capabilities:

```bash
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE my-app:1.0.0
```

## Logging

### Log to STDOUT/STDERR

Applications should log to stdout/stderr for container log collection:

```python
import logging
import sys

logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
```

## Common Pitfalls

### Avoid These Anti-Patterns

- ❌ Running as root user
- ❌ Using `latest` tag in production
- ❌ Including secrets in images
- ❌ Running multiple processes in one container
- ❌ Storing data in containers (use volumes)
- ❌ Installing unnecessary packages

### Do These Instead

- ✅ Run as non-root user
- ✅ Use specific version tags
- ✅ Use secrets management (Vault, Kubernetes secrets)
- ✅ One process per container
- ✅ Use volumes for persistent data
- ✅ Minimize image size and dependencies

## References

- [Docker Official Documentation](https://docs.docker.com/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Distroless Container Images](https://github.com/GoogleContainerTools/distroless)

---

**Note:** These are community guidelines. Always validate against your organization's security policies and compliance requirements.

**License:** CC BY-SA 4.0
