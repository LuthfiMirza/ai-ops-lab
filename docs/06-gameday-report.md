# Laporan Game Day & Chaos Engineering: AI Ops Lab

Dokumen ini mendokumentasikan pelaksanaan **Game Day** pada klaster Kubernetes `kind` di proyek **AI Ops Lab**. Tujuan dari kegiatan ini adalah memverifikasi ketahanan arsitektur (*architectural resilience*), menguji efektivitas sistem pemantauan (Prometheus + Grafana), mengukur kecepatan mitigasi insinyur (*MTTD & MTTR*), serta memvalidasi kesiapan dokumen operasional (*Runbooks* dan *Postmortems*).

---

## 1. Ringkasan Eksekutif & Metrik Resiliensi

| Skenario | Jenis Kegagalan | Metode Injeksi | Perilaku Sistem | MTTD | MTTR | Hasil |
|---|---|---|---|---|---|---|
| **#1** | `CrashLoopBackOff` | Bad `MODEL_PATH` env var | Pod crash saat startup, Kubelet auto-restart | ~1m | ~2m | **PASS** (Triage via logs & rollback) |
| **#2** | `ImagePullBackOff` | Nonexistent image tag | Rollout hung, zero client downtime | ~1m | ~1.5m | **PASS** (`rollout undo` berhasil) |
| **#3** | `OOMKilled` (Exit 137) | Memory limits `24Mi` | Linux cgroup SIGKILL saat inferensi | ~1.5m | ~2m | **PASS** (Limits dinaikkan ke 256Mi) |
| **#4** | Database Outage | Scale MySQL to 0 | API tetap melayani inferensi (Graceful Fallback) | ~30s | ~1m | **PASS** (Zero HTTP 500, auto-reconnect) |
| **#5** | Traffic Surge Spike | 100 requests concurrent | P95 latency naik, alert terpicu | ~45s | ~1m | **PASS** (Horizontal scaling buffer) |

- **Average Mean Time to Detect (MTTD):** ~54 detik
- **Average Mean Time to Resolve (MTTR):** ~1.5 menit
- **Customer Downtime:** 0 detik pada insiden ImagePullBackOff dan Database Outage; minor blip (< 15 request) pada CrashLoop dan OOMKilled.

---

## 2. Rincian Skenario & Bukti Eksekusi

### Skenario 1: `CrashLoopBackOff` (Kegagalan Startup Aplikasi)
- **Hipotesis:** Jika path file model salah atau tidak ditemukan, pod akan gagal startup, tetapi pod lama harus tetap melayani traffic selama proses rolling update berlangsung.
- **Injeksi:**
  ```bash
  bash scripts/chaos/01-trigger-crashloop.sh --trigger
  ```
- **Hasil Pengamatan:** Pod baru gagal pada startup event `load_model()` dengan exception `FileNotFoundError`. Kubernetes menandai pod sebagai `CrashLoopBackOff`.
- **Mitigasi:** Menggunakan Runbook [RB-01-crashloopbackoff.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-01-crashloopbackoff.md), insinyur on-call memeriksa log kontainer via `kubectl logs --previous` dan memulihkan path yang valid:
  ```bash
  bash scripts/chaos/01-trigger-crashloop.sh --recover
  ```
- **Postmortem:** [PM-01-crashloopbackoff.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/postmortems/PM-01-crashloopbackoff.md).

---

### Skenario 2: `ImagePullBackOff` (Kegagalan Pengambilan Container Image)
- **Hipotesis:** Jika tag image yang di-deploy tidak valid, pod baru akan gagal ditarik (`ErrImagePull`), namun Kubernetes tidak boleh mematikan pod lama yang masih sehat (`maxUnavailable: 0`).
- **Injeksi:**
  ```bash
  bash scripts/chaos/02-trigger-imagepullbackoff.sh --trigger
  ```
- **Hasil Pengamatan:** Pod baru berada dalam status `ImagePullBackOff`. Klien yang mengakses `http://localhost:8080/predict` tetap dilayani 100% oleh pod lama yang berjalan normal (Zero downtime).
- **Mitigasi:** Mengikuti Runbook [RB-02-imagepullbackoff.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-02-imagepullbackoff.md):
  ```bash
  bash scripts/chaos/02-trigger-imagepullbackoff.sh --recover
  ```
- **Postmortem:** [PM-02-imagepullbackoff.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/postmortems/PM-02-imagepullbackoff.md).

---

### Skenario 3: `OOMKilled` (Exit Code 137 pada Beban Inferensi)
- **Hipotesis:** Jika memory limit disetel di bawah kebutuhan dasar Python + Scikit-learn (`24Mi`), pod akan dibunuh oleh kernel Linux (`cgroup OOM Killer`) saat request inferensi dieksekusi.
- **Injeksi:**
  ```bash
  bash scripts/chaos/03-trigger-oom.sh --trigger
  ```
- **Hasil Pengamatan:** Kubelet mencatat pod terminasi dengan alasan `OOMKilled` dan exit code `137`.
- **Mitigasi:** Mengikuti Runbook [RB-03-oomkilled.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-03-oomkilled.md), batas limit dinaikkan kembali ke `256Mi`:
  ```bash
  bash scripts/chaos/03-trigger-oom.sh --recover
  ```
- **Postmortem:** [PM-03-oomkilled.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/postmortems/PM-03-oomkilled.md).

---

### Skenario 4: Database Outage & Graceful Degradation
- **Hipotesis:** Jika database MySQL mati total, API inferensi sentimen tidak boleh melempar error `500 Internal Server Error` ke client. API harus tetap mengembalikan hasil inferensi, mencatat warning log, dan meningkatkan metrik error `db_errors_total`. Ketika database pulih, koneksi harus pulih secara otomatis (*auto-reconnect*).
- **Injeksi:**
  ```bash
  bash scripts/chaos/04-trigger-db-outage.sh --trigger
  ```
- **Hasil Pengamatan:**
  - Client menerima response `HTTP 200 OK` dengan payload prediksi yang lengkap.
  - Log kontainer mencatat warning: `[DB Warning] Failed to log prediction to MySQL`.
  - Metrik Prometheus `db_errors_total{operation="insert"}` bertambah.
- **Mitigasi:** Mengikuti Runbook [RB-04-database-outage.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-04-database-outage.md):
  ```bash
  bash scripts/chaos/04-trigger-db-outage.sh --recover
  ```
  MySQL StatefulSet kembali `1/1 Ready`, dan request inferensi berikutnya langsung tersimpan kembali ke database.

---

### Skenario 5: Lonjakan Traffic & Latency Spikes
- **Hipotesis:** Hantaman request konkuren tinggi akan meningkatkan throughput request, menaikkan p95 latency, dan memicu alert evaluasi Prometheus.
- **Injeksi:**
  ```bash
  bash scripts/chaos/05-trigger-traffic-spike.sh 150 15
  ```
- **Hasil Pengamatan:** 150 request diselesaikan dalam hitungan detik dengan 100% status `HTTP 200`. Metrik `http_requests_total` meningkat tajam dan terekam di Grafana RED Dashboard.
- **Mitigasi:** Mengikuti Runbook [RB-05-traffic-spike.md](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-05-traffic-spike.md) untuk melakukan scale-out pod.

---

## 3. Indeks Dokumen Operasional

### Standard Operating Procedures (Runbooks)
- [RB-01: CrashLoopBackOff on Sentiment API](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-01-crashloopbackoff.md)
- [RB-02: ImagePullBackOff / ErrImagePull Handling](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-02-imagepullbackoff.md)
- [RB-03: OOMKilled (Exit Code 137) Diagnostic & Sizing](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-03-oomkilled.md)
- [RB-04: Database Outage & Disaster Recovery](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-04-database-outage.md)
- [RB-05: Traffic Spike & Horizontal Scaling](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/runbooks/RB-05-traffic-spike.md)

### Blameless Postmortems
- [PM-01: CrashLoopBackOff Due to Invalid Model Path](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/postmortems/PM-01-crashloopbackoff.md)
- [PM-02: ImagePullBackOff Non-existent Tag Rollout](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/postmortems/PM-02-imagepullbackoff.md)
- [PM-03: OOMKilled Under Machine Learning Inference Load](file:///Applications/XAMPP/xamppfiles/htdocs/ai-ops-lab/docs/postmortems/PM-03-oomkilled.md)
