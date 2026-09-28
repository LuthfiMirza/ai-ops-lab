# AI Ops Lab

> **Disclaimer:** This repository is a personal engineering lab built to practice and demonstrate **System Engineering (AI/ML)** and platform operations principles (deployment, monitoring, incident handling, and automation) rather than commercial production experience.

An end-to-end operational platform for serving, monitoring, and maintaining an Indonesian stock news sentiment analysis model on Kubernetes.

---

## 🎯 Project Goals

1. **Containerized AI Serving:** Package a sentiment analysis service with FastAPI, exposing prediction, health check, and Prometheus metrics endpoints.
2. **Declarative Kubernetes Deployment:** Deploy the service onto local Kubernetes (`kind`) using declarative manifests (Deployment, Service, ConfigMap, Secret, Ingress, and HPA).
3. **Automated CI Pipeline:** Validate code formatting, run automated tests, and build container images via GitHub Actions.
4. **Observability (RED Metrics):** Monitor Request Rate, Errors, and Duration (RED) using Prometheus and Grafana with actionable alerting rules.
5. **Data Persistence & Disaster Recovery:** Store inference logs in MySQL (StatefulSet + PersistentVolumeClaim) with automated backup and restore validation (RTO/RPO measurement).
6. **Game Day & Chaos Scenarios:** Simulate real-world failures (CrashLoopBackOff, ImagePullBackOff, OOMKilled, database outage, traffic spikes) with runbooks and blameless postmortems.

---

## 🏗️ Architecture

```
Client / Ingress Controller
            │
            ▼
Kubernetes Service (ClusterIP)
            │
            ▼
FastAPI Sentiment API (Deployment / Pods)
      │                     │
      ▼                     ▼
MySQL Database        Prometheus Scraping (/metrics)
(StatefulSet + PVC)         │
                            ▼
                    Grafana Dashboard + Alertmanager
```

---

## 📂 Repository Structure

```
ai-ops-lab/
├── app/                  # FastAPI service code: API routes, model loader, schemas, metrics, db
├── model/                # Model training scripts, baseline pipelines, and artifacts
├── tests/                # Automated unit and integration tests (pytest)
├── k8s/                  # Kubernetes manifests (Deployment, Service, ConfigMap, Ingress, etc.)
├── monitoring/           # Prometheus configs, Grafana dashboards, and alert rules
├── docs/                 # Discovery report, architecture docs, runbooks, and postmortems
│   ├── runbooks/         # Standard operating procedures for incidents
│   ├── postmortems/      # Blameless postmortem reports
│   └── gamedays/         # Chaos experiment scenarios and execution logs
├── scripts/              # Helper automation scripts (cluster setup, load testing, backup/restore)
├── .github/workflows/    # CI/CD pipeline definitions
├── PLAN.md               # Master project roadmap and Definition of Done
├── Dockerfile            # Multi-stage production container image
├── Makefile              # Developer tasks and automation shortcuts
└── README.md             # Project documentation
```

---

## 📋 Roadmap & Phase Status

| Phase | Description | Status | Deliverables |
|---|---|:---:|---|
| **0** | **Discovery:** Environment discovery, hardware specs, tooling audit, and project scaffolding | ✅ Completed | `docs/00-discovery.md` |
| **1** | **API & Containerization:** FastAPI endpoints (`/predict`, `/health`, `/metrics`), model loading, multi-stage Docker build | ⏳ Pending | Docker image, `curl /predict` |
| **2** | **Kubernetes on kind:** Declarative manifests, resource limits, health probes, ingress routing | ⏳ Pending | Running pods, verified ingress |
| **3** | **Continuous Integration:** GitHub Actions pipeline for linting, testing, and container build | ⏳ Pending | Green CI pipeline |
| **4** | **Observability:** Prometheus metrics scraping, Grafana RED dashboard, alerting rules | ⏳ Pending | Live Grafana dashboard |
| **5** | **Database & DR:** MySQL StatefulSet, schema indexing, backup/restore scripts, RTO/RPO tracking | ⏳ Pending | Tested backup & restore |
| **6** | **Game Days:** Simulated production incidents, runbooks, and blameless postmortems | ⏳ Pending | 3+ incident postmortems |
| **7** | **Bonus Extensions:** Streaming ingestion, drift detection, or infrastructure automation | ⏳ Backlog | Selected operational bonus |

---

## 🛠️ Prerequisites & Setup

Detailed host discovery results and prerequisites are documented in [docs/00-discovery.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/00-discovery.md).

- **Host OS:** macOS (x86_64, Intel Core i9, 32 GB RAM)
- **Container Runtime:** Docker Desktop 29.0+
- **Kubernetes CLI:** `kubectl` v1.34+
- **Local Cluster Engine:** `kind` (Kubernetes in Docker)
- **Programming Language:** Python 3.9+
