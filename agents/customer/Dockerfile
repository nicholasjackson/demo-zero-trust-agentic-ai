FROM python:3.12-slim

WORKDIR /app

# Install git and uv (required for dependencies)
RUN apt-get update && \
    apt-get install -y git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install uv for faster dependency management
RUN pip install uv

# Copy dependency files
COPY pyproject.toml uv.lock* ./

# Install dependencies
RUN uv pip install --system --no-cache -r pyproject.toml

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
CMD ["python", "src/server.py"]
