.PHONY: help venv train test run docker-build docker-run docker-stop clean

IMAGE_NAME ?= ai-ops-lab-api
IMAGE_TAG ?= v1.0.0
PORT ?= 8000
VENV_PYTHON = .venv/bin/python
VENV_PYTEST = .venv/bin/pytest

help:
	@echo "AI Ops Lab: Developer Automation Commands"
	@echo "-----------------------------------------"
	@echo "make train        : Train baseline sentiment model on demo dataset"
	@echo "make test         : Run automated test suite with pytest"
	@echo "make run          : Run API locally with uvicorn (.venv)"
	@echo "make docker-build : Build multi-stage non-root container image"
	@echo "make docker-run   : Run containerized API on port $(PORT)"
	@echo "make docker-stop  : Stop and remove running container"
	@echo "make clean        : Clean cached files and artifacts"

train:
	$(VENV_PYTHON) model/train.py

test:
	$(VENV_PYTEST) tests/ -v

run:
	$(VENV_PYTHON) -m uvicorn app.main:app --host 0.0.0.0 --port $(PORT) --reload

docker-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run:
	docker run -d --name $(IMAGE_NAME) -p $(PORT):$(PORT) $(IMAGE_NAME):$(IMAGE_TAG)

docker-stop:
	docker stop $(IMAGE_NAME) || true
	docker rm $(IMAGE_NAME) || true

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
