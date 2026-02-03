.PHONY: build push run dev clean

IMAGE_NAME ?= ghcr.io/nicholasjackson/chat-ui
VERSION ?= 0.1.2

build:
	@echo "Building Docker image: $(IMAGE_NAME):$(VERSION)"
	docker build --load -t $(IMAGE_NAME):$(VERSION) .
	docker tag $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest
	@echo "Build complete!"

push: build
	@echo "Pushing Docker image: $(IMAGE_NAME):$(VERSION)"
	docker push $(IMAGE_NAME):$(VERSION)
	docker push $(IMAGE_NAME):latest
	@echo "Push complete!"

run:
	@echo "Running Docker image locally on port 8080"
	docker run -p 8080:80 $(IMAGE_NAME):$(VERSION)

dev:
	@echo "Starting chat-ui in dev mode..."
	npm run dev

clean:
	@echo "Cleaning up Docker images"
	docker rmi $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest || true
	@echo "Clean complete!"

help:
	@echo "Available targets:"
	@echo "  build  - Build Docker image"
	@echo "  push   - Build and push Docker image to registry"
	@echo "  run    - Run Docker image locally on port 8080"
	@echo "  dev    - Run in dev mode with hot reload (npm run dev)"
	@echo "  clean  - Remove Docker images"
