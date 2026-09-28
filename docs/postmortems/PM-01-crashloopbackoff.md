# Blameless Postmortem: PM-01 - CrashLoopBackOff Due to Invalid Model Path

## 1. Incident Overview
- **Incident ID:** INC-20260928-01
- **Severity:** P1 (Critical)
- **Status:** Resolved
- **Date & Time:** 2026-09-28 14:10 - 14:22 WIB (Duration: 12 minutes)
- **Incident Commander:** Insinyur On-Call (System Engineer AI Ops)
- **Services Impacted:** `sentiment-api` in namespace `ai-ops`
- **Customer Impact:** 18 inference requests received HTTP 502/503 during pod restart cycling.

---

## 2. Executive Summary
Pada 28 September 2026 pukul 14:10 WIB, dilakukan pembaruan environment variable pada deployment `sentiment-api`. Akibat kesalahan ketik (*typo*) pada parameter `MODEL_PATH`, pod baru yang di-deploy gagal melewati validasi startup (*lifespan event*) saat mencoba me-load model machine learning dari disk. Pod masuk ke dalam status `CrashLoopBackOff`. Tim on-call mendeteksi lonjakan error melalui alert Prometheus, melakukan inspeksi log kontainer sebelumnya (`kubectl logs --previous`), dan memulihkan konfigurasi stabil dalam waktu 12 menit.

---

## 3. Incident Timeline

| Waktu (WIB) | Fase | Kejadian & Tindakan |
|---|---|---|
| **14:10** | **Trigger** | Deployment diperbarui dengan environment variable `MODEL_PATH="/opt/app/invalid_model.joblib"`. |
| **14:11** | **Failure** | Kubelet memulai kontainer baru; FastAPI melempar `FileNotFoundError` dan kontainer langsung keluar (*Exit code 1*). |
| **14:12** | **Detection** | Alert Prometheus `HighHttpErrorRate` terpicu. PagerDuty/Slack notifikasi diterima oleh insinyur on-call. |
| **14:14** | **Triage** | Insinyur on-call menjalankan `kubectl get pods -n ai-ops` dan menemukan status `CrashLoopBackOff` dengan 4 kali restart. |
| **14:16** | **Diagnosis** | Menjalankan `kubectl logs <pod-name> -c api --previous`, menemukan stack trace: `FileNotFoundError: Model artifact not found at /opt/app/invalid_model.joblib`. |
| **14:19** | **Mitigation** | Menjalankan `kubectl rollout undo deployment/sentiment-api -n ai-ops` untuk mengembalikan deployment ke revisi sebelumnya yang valid. |
| **14:21** | **Recovery** | Deployment selesai rollout (`rollout status complete`). Pod kembali `1/1 Running`. |
| **14:22** | **Resolution** | Endpoint `/health` dan `/sentiment` merespons `200 OK`. Alert Prometheus kembali ke status `Normal`. Insiden dinyatakan selesai. |

---

## 4. Root Cause Analysis (5 Whys)

1. **Mengapa pod masuk ke status `CrashLoopBackOff`?**
   Kontainer FastAPI langsung berhenti (*exit code 1*) sesaat setelah dijalankan.
2. **Mengapa kontainer langsung berhenti saat startup?**
   Fungsi `load_model()` pada *lifespan handler* melempar unhandled exception `FileNotFoundError`.
3. **Mengapa file model tidak ditemukan di filesystem kontainer?**
   Environment variable `MODEL_PATH` menunjuk ke path yang salah (`/opt/app/invalid_model.joblib`).
4. **Mengapa path yang salah bisa diset pada deployment?**
   Pembaruan konfigurasi dilakukan tanpa tahap *pre-flight validation* atau schema checking pada ConfigMap/Deployment.
5. **Akar Masalah (Root Cause):**
   Tidak adanya *schema validation* dan *automated configuration linting* pada pipeline CI/CD yang memastikan integritas path file sebelum di-deploy ke cluster produksi.

---

## 5. Lessons Learned

### What Went Well
- Konfigurasi `RollingUpdate` mencegah pod lama di-terminate sebelum pod baru siap, sehingga dampak downtime minimal (hanya request yang diarahkan ke pod baru yang gagal).
- Fitur `kubectl logs --previous` memudahkan identifikasi akar masalah tanpa perlu membuka shell interaktif ke kontainer.
- Rollback menggunakan `kubectl rollout undo` berjalan cepat (< 2 menit).

### What Went Poorly
- Waktu deteksi (2 menit) bergantung pada pemicuan alert metrik HTTP daripada alert pod state langsung (`kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}`).

### Where We Got Lucky
- Beban traffic saat kejadian sedang normal (bukan jam puncak bursa efek), sehingga jumlah request terdampak sangat kecil (18 request).

---

## 6. Action Items & Pencegahan

| No | Tindakan Pencegahan | Prioritas | Tipe | Penanggung Jawab | Target |
|---|---|---|---|---|---|
| **1** | Tambahkan startup probe & konfirmasi keberadaan file model di *entrypoint* shell script Dockerfile. | **P0** | Prevent | Tim AI Platform | Sprint 1 |
| **2** | Tambahkan alert Prometheus khusus `PodCrashLooping` menggunakan metrik Kube-State-Metrics. | **P1** | Detect | Tim Ops/SRE | Sprint 1 |
| **3** | Validasi integritas manifest Kubernetes (kubeval/kube-linter) di pipeline CI GitHub Actions. | **P1** | Prevent | Tim DevOps | Selesai (Fase 3) |
