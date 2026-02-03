FROM python:3.12-slim

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy dependency files
COPY pyproject.toml uv.lock* ./

# Sync dependencies
RUN uv sync --frozen --no-dev

# Copy application code
COPY src/ ./src/
COPY langgraph.json ./

# Expose the API server port
EXPOSE 8124

# Set environment variables with defaults
ENV HOST=0.0.0.0
ENV PORT=8124
ENV PYTHONUNBUFFERED=1

# Run our FastAPI server
CMD ["uv", "run", "python", "src/server.py"]
