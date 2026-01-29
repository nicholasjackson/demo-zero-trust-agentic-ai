# Makefile for Weather Agent Docker image

# Get repository owner and name from git remote
REPO_OWNER := $(shell git config --get remote.origin.url | sed -n 's/.*github.com[:/]\([^/]*\)\/.*/\1/p')
REPO_NAME := $(shell git config --get remote.origin.url | sed -n 's/.*\/\([^.]*\).*/\1/p')

# Image configuration
IMAGE_NAME := weather-agent
REGISTRY := ghcr.io
FULL_IMAGE := $(REGISTRY)/$(REPO_OWNER)/$(IMAGE_NAME)
VERSION ?= 0.0.6
TAG := $(FULL_IMAGE):$(VERSION)

# Docker build arguments
PLATFORM ?= linux/amd64,linux/arm64

.PHONY: help
help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

.PHONY: build
build: ## Build Docker image for local platform
	@echo "Building $(TAG) for local platform..."
	docker build -t $(TAG) .
	@echo "Build complete: $(TAG)"

.PHONY: build-multi
build-multi: ## Build multi-platform Docker image
	@echo "Building $(TAG) for platforms: $(PLATFORM)..."
	docker buildx build --platform $(PLATFORM) -t $(TAG) .
	@echo "Build complete: $(TAG)"

.PHONY: push
push: ## Build and push Docker image to GitHub Packages
	@echo "Building and pushing $(TAG)..."
	@echo "Registry: $(REGISTRY)"
	@echo "Repository: $(REPO_OWNER)/$(REPO_NAME)"
	docker buildx build --platform $(PLATFORM) --push -t $(TAG) .
	@echo "Push complete: $(TAG)"

.PHONY: login
login: ## Login to GitHub Container Registry
	@echo "Logging in to $(REGISTRY)..."
	@echo "Make sure GITHUB_TOKEN environment variable is set"
	@echo $(GITHUB_TOKEN) | docker login $(REGISTRY) -u $(REPO_OWNER) --password-stdin

.PHONY: tag-version
tag-version: ## Tag image with git commit SHA
	$(eval GIT_SHA := $(shell git rev-parse --short HEAD))
	@echo "Tagging $(TAG) as $(FULL_IMAGE):$(GIT_SHA)..."
	docker tag $(TAG) $(FULL_IMAGE):$(GIT_SHA)
	@echo "Tagged as: $(FULL_IMAGE):$(GIT_SHA)"

.PHONY: push-version
push-version: build tag-version ## Build, tag with git SHA, and push both latest and SHA tags
	@echo "Pushing $(TAG) and SHA-tagged version..."
	docker push $(TAG)
	$(eval GIT_SHA := $(shell git rev-parse --short HEAD))
	docker push $(FULL_IMAGE):$(GIT_SHA)
	@echo "Pushed: $(TAG)"
	@echo "Pushed: $(FULL_IMAGE):$(GIT_SHA)"

.PHONY: dev
dev: check-env ## Run weather agent locally with uvicorn
	@echo "Starting weather agent server on port 8123..."
	cd src && uv run python server.py

.PHONY: check-env
check-env: ## Check required environment variables are set
	@if [ -z "$(OLLAMA_HOST)" ]; then \
		echo "Error: OLLAMA_HOST environment variable is not set"; \
		exit 1; \
	fi
	@if [ -z "$(VAULT_ROLE_ID)" ]; then \
		echo "Error: VAULT_ROLE_ID environment variable is not set"; \
		exit 1; \
	fi
	@if [ -z "$(VAULT_SECRET_ID)" ]; then \
		echo "Error: VAULT_SECRET_ID environment variable is not set"; \
		exit 1; \
	fi
	@echo "All required environment variables are set"

.PHONY: up
up: ## Run LangGraph agent locally in Docker with langgraph up
	@echo "Starting LangGraph agent server in Docker..."
	langgraph up

.PHONY: test
test: build run-test ## Build and run a test container

.PHONY: run-test
run-test: ## Run the container for testing (detached)
	@echo "Starting test container..."
	docker run -d --name weather-agent-test \
		-p 8123:8123 \
		-e LANGGRAPH_AUTH_TYPE=noop \
		-e LANGSMITH_TRACING=false \
		-e LANGSMITH_API_KEY=dummy-key-for-dev \
		-e WEATHER_MCP_URI=${WEATHER_MCP_URI:-http://localhost:8000/mcp} \
		$(TAG)
	@echo "Container started. Waiting for service to be ready..."
	@sleep 3
	@echo "Test container running at http://localhost:8123"
	@echo "Run 'make stop-test' to stop and remove the container"

.PHONY: stop-test
stop-test: ## Stop and remove test container
	@echo "Stopping test container..."
	docker stop weather-agent-test || true
	docker rm weather-agent-test || true

.PHONY: clean
clean: stop-test ## Clean up local images and containers
	@echo "Removing local images..."
	docker rmi $(TAG) || true
	$(eval GIT_SHA := $(shell git rev-parse --short HEAD))
	docker rmi $(FULL_IMAGE):$(GIT_SHA) || true


.PHONY: info
info: ## Display image and repository information
	@echo "Repository Owner: $(REPO_OWNER)"
	@echo "Repository Name:  $(REPO_NAME)"
	@echo "Image Name:       $(IMAGE_NAME)"
	@echo "Registry:         $(REGISTRY)"
	@echo "Full Image:       $(FULL_IMAGE)"
	@echo "Version:          $(VERSION)"
	@echo "Tag:              $(TAG)"
	@echo "Platform:         $(PLATFORM)"
	$(eval GIT_SHA := $(shell git rev-parse --short HEAD))
	@echo "Git SHA:          $(GIT_SHA)"
