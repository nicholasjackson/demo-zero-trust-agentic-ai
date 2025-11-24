.PHONY: build push run clean

IMAGE_NAME ?= ghcr.io/nicholasjackson/chat-ui
VERSION ?= 0.0.2

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

clean:
	@echo "Cleaning up Docker images"
	docker rmi $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest || true
	@echo "Clean complete!"

help:
	@echo "Available targets:"
	@echo "  build  - Build Docker image"
	@echo "  push   - Build and push Docker image to registry"
	@echo "  run    - Run Docker image locally on port 8080"
	@echo "  clean  - Remove Docker images"
