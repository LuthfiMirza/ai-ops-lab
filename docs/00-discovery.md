# Phase 0: Environment & Infrastructure Discovery

**Date:** 2026-09-28  
**Author:** AI Ops Lab Team  
**Status:** Completed  

---

## 1. Machine Hardware Specifications

Discovery commands executed: `uname -m`, `sw_vers`, `sysctl -n hw.ncpu`, `sysctl hw.memsize`.

| Attribute | Measured Value | Operational Implications |
|---|---|---|
| **Architecture** | `x86_64` (Intel 64-bit) | Container base images should target `linux/amd64` natively. No ARM emulation overhead. |
| **Operating System** | macOS (Darwin x86_64, Build 25G83) | Local development host environment. |
| **CPU Logical Cores** | `16` cores | Ample compute capacity to run Docker, Kubernetes nodes (`kind`), and background monitoring tools concurrently. |
| **System Memory (RAM)** | `34,359,738,368` bytes (~32 GB) | Excellent memory headroom. Allows comfortable allocation of 4–6 GB RAM to Docker Desktop. |

---

## 2. CLI Tooling Inventory

Discovery check: `which git docker kubectl kind python3 node make`.

| Tool | Installed Path | Version | Status | Action Required |
|---|---|---|:---:|---|
| **`git`** | `/usr/local/bin/git` | `git version 2.51.0` | ✅ Installed | Ready for version control. |
| **`docker` (CLI)** | `/usr/local/bin/docker` | `Docker version 29.0.1, build eedd969` | ✅ Installed | CLI available. Requires active Docker daemon. |
| **`kubectl`** | `/usr/local/bin/kubectl` | `v1.34.1` (Kustomize `v5.7.1`) | ✅ Installed | Ready for interacting with Kubernetes clusters. |
| **`kind`** | *Not found* | N/A | ❌ Missing | Safe installation via Homebrew: `brew install kind`. |
| **`python3`** | `/usr/bin/python3` | `Python 3.9.6` | ✅ Installed | Standard macOS Python. Recommended to use project-local virtualenv (`venv`). |
| **`node`** | `/usr/local/bin/node` | `v24.9.0` | ✅ Installed | Available if needed for tooling. |
| **`make`** | `/usr/bin/make` | `GNU Make 3.81` | ✅ Installed | Ready for automating operational workflows. |
| **`brew`** | `/usr/local/bin/brew` | `Homebrew 7.0.4` | ✅ Installed | Package manager ready for installing missing tools. |

---

## 3. Container Runtime (Docker Desktop) Audit

- **Application Location:** `/Applications/Docker.app` (Detected)
- **Daemon Status:** **Inactive / Stopped**  
  *Diagnostic:* Attempting connection to `/Users/mac/.docker/run/docker.sock` returned `Cannot connect to the Docker daemon`.
- **Recommended Resource Allocation:**
  Since the host machine has **32 GB RAM** and **16 CPU cores**, configure Docker Desktop preferences (under *Settings -> Resources*) with:
  - **CPUs:** 4 cores
  - **Memory:** 4 GB to 6 GB
  - **Swap:** 1 GB
  - **Virtual Disk Limit:** 32 GB to 64 GB
- **Action Plan:** Launch Docker Desktop (`open -a Docker`) before beginning Phase 1 and confirm with `docker ps`.

---

## 4. Model Status & Operational Strategy

An essential responsibility of a System Engineer (AI/ML) is decoupling the inference runtime from the specific model training framework.

1. **Inquiry for Thesis Model:**
   - Verify whether a standalone trained model artifact (e.g., PyTorch `.pt`, TensorFlow `.h5`, ONNX `.onnx`, or Joblib `.joblib` / `.pkl`) is available on the local filesystem.
   - If sentiment classification logic is currently embedded inside a Laravel application (e.g. lexical rule-based matching, PHP script, or external API call), it cannot be directly imported as a Python model file.
2. **Proposed Baseline Plan:**
   - If an exported model artifact is not directly accessible, implement a **lightweight baseline** using Python's `scikit-learn`:
     - Algorithm: TF-IDF Vectorizer + Logistic Regression.
     - Dataset: Compact Indonesian financial/stock news dataset marked explicitly as `DEMO DATA (bukan data asli)`.
     - Output Artifact: `model/artifacts/sentiment_model.joblib`.
   - **Reasoning:** Keeps memory footprint under 50 MB, starts sub-second in container environments, avoids heavy GPU/PyTorch dependencies, and perfectly exercises the operational pipeline (serving, monitoring, latency tracking, scaling).
