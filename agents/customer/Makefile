# Makefile for Customer Agent Docker image

# Get repository owner and name from git remote
REPO_OWNER := $(shell git config --get remote.origin.url | sed -n 's/.*github.com[:/]\([^/]*\)\/.*/\1/p')
REPO_NAME := $(shell git config --get remote.origin.url | sed -n 's/.*\/\([^.]*\).*/\1/p')

# Image configuration
IMAGE_NAME := customer-agent
REGISTRY := ghcr.io
FULL_IMAGE := $(REGISTRY)/$(REPO_OWNER)/$(IMAGE_NAME)
VERSION ?= 0.1.2
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

.PHONY: dev
dev: check-env ## Run customer agent locally with uvicorn
	@echo "Starting customer agent server on port 8124..."
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
