.PHONY: help venv train test run docker-build docker-run docker-stop clean

IMAGE_NAME ?= ai-ops-lab-api
IMAGE_TAG ?= v1.0.0
PORT ?= 8000
VENV_PYTHON = .venv/bin/python
VENV_PYTEST = .venv/bin/pytest
VENV_FLAKE8 = .venv/bin/flake8

help:
	@echo "AI Ops Lab: Developer Automation Commands"
	@echo "-----------------------------------------"
	@echo "make train        : Train baseline sentiment model on demo dataset"
	@echo "make test         : Run automated test suite with pytest"
	@echo "make lint         : Run flake8 static code analysis and linting"
	@echo "make run          : Run API locally with uvicorn (.venv)"
	@echo "make docker-build : Build multi-stage non-root container image"
	@echo "make docker-run   : Run containerized API on port $(PORT)"
	@echo "make docker-stop  : Stop and remove running container"
	@echo "make clean        : Clean cached files and artifacts"

train:
	$(VENV_PYTHON) model/train.py

lint:
	$(VENV_FLAKE8) . --count --select=E9,F63,F7,F82 --show-source --statistics
	$(VENV_FLAKE8) app tests model --max-line-length=120 --statistics

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

cluster-up:
	bash scripts/kind-up.sh

cluster-down:
	bash scripts/kind-down.sh

k8s-deploy:
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/secret.example.yaml
	kubectl apply -f k8s/service.yaml
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/ingress.yaml

k8s-status:
	kubectl get all,ingress -n ai-ops

monitoring-deploy:
	kubectl apply -f monitoring/namespace.yaml
	kubectl apply -f monitoring/prometheus-rbac.yaml
	kubectl apply -f monitoring/prometheus-configmap.yaml
	kubectl apply -f monitoring/prometheus-deployment.yaml
	kubectl apply -f monitoring/prometheus-service.yaml
	kubectl apply -f monitoring/grafana-configmap.yaml
	kubectl apply -f monitoring/grafana-dashboards-configmap.yaml
	kubectl apply -f monitoring/grafana-deployment.yaml
	kubectl apply -f monitoring/grafana-service.yaml

monitoring-status:
	kubectl get all -n monitoring

monitoring-port-forward:
	@echo "Forwarding Grafana to http://localhost:3000 (Ctrl+C to stop)..."
	kubectl port-forward -n monitoring svc/grafana-service 3000:3000

traffic:
	bash scripts/generate-traffic.sh 30

mysql-deploy:
	kubectl apply -f k8s/mysql-secret.yaml
	kubectl apply -f k8s/mysql-init-configmap.yaml
	kubectl apply -f k8s/mysql-service.yaml
	kubectl apply -f k8s/mysql-statefulset.yaml

backup:
	bash scripts/backup.sh

restore:
	bash scripts/restore.sh $(or $(FILE),latest)

db-status:
	@kubectl exec mysql-0 -n ai-ops -- mysql -u aiops_user -paiops_password ai_ops_db -e "SELECT COUNT(*) as total_records FROM sentiment_predictions; SELECT sentiment, COUNT(*) as count FROM sentiment_predictions GROUP BY sentiment;"

