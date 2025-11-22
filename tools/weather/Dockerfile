FROM python:3.12-slim

WORKDIR /app

# Install git (required for git-based dependencies)
RUN apt-get update && \
    apt-get install -y git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy dependency files
COPY pyproject.toml uv.lock* ./

# Install uv for faster dependency management
RUN pip install uv

# Install dependencies
RUN uv pip install --system --no-cache -r pyproject.toml

# Copy application code
COPY weather.py .

# Expose the default port
EXPOSE 8000

# Set environment variables with defaults
ENV HOST=0.0.0.0
ENV PORT=8000
ENV USE_HTTPS=false

# Run the weather service
CMD ["python", "weather.py"]
