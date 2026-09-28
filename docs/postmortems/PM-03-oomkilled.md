# Blameless Postmortem: PM-03 - OOMKilled (Exit Code 137) Under Inference Load

## 1. Incident Overview
- **Incident ID:** INC-20260928-03
- **Severity:** P1 (Critical Outage / Service Degradation)
- **Status:** Resolved
- **Date & Time:** 2026-09-28 15:30 - 15:45 WIB (Duration: 15 minutes)
- **Incident Commander:** Insinyur On-Call (System Engineer AI Ops)
- **Services Impacted:** `sentiment-api` in namespace `ai-ops`
- **Customer Impact:** 42 permintaan inferensi sentimen mengalami *connection reset* / HTTP 502 Bad Gateway akibat proses Python dimatikan secara mendadak oleh kernel Linux.

---

## 2. Executive Summary
Pada 28 September 2026 pukul 15:30 WIB, setelah penyesuaian resource quota klaster, batas memori (*memory limits*) pod `sentiment-api` diturunkan ke `24Mi`. Ketika request inferensi mulai masuk, proses Python yang membutuhkan alokasi memori runtime Scikit-learn melampaui batas cgroup cgroup memory. Kernel Linux membunuh kontainer dengan sinyal `SIGKILL (9)` menghasilkan `Exit Code 137 (OOMKilled)`. Kontainer mengalami crash berulang kali. Insinyur on-call mengidentifikasi terminasi cgroup OOM melalui `kubectl describe pod`, menaikkan batas limit memori ke nilai aman (`256Mi`), dan menstabilkan layanan dalam 15 menit.

---

## 3. Incident Timeline

| Waktu (WIB) | Fase | Kejadian & Tindakan |
|---|---|---|
| **15:30** | **Trigger** | Batas limit memori deployment diubah menjadi `24Mi` (terlalu kecil untuk runtime Python AI). |
| **15:31** | **Failure** | Klien mengirimkan request inferensi. Kontainer melampaui 24Mi RAM; Linux OOM Killer langsung mengirim `SIGKILL`. Pod exit dengan kode `137`. |
| **15:32** | **Detection** | Alert Prometheus `HighHttpErrorRate` terpicu. Grafana menampilkan lonjakan drastis pada error HTTP 502/504. |
| **15:34** | **Triage** | Insinyur on-call memeriksa status pod: `kubectl get pods -n ai-ops`. Terlihat pod mengalami restart berkali-kali (`RESTARTS: 5`). |
| **15:36** | **Diagnosis** | Menjalankan `kubectl describe pod <pod-name> -n ai-ops`. Di bawah `Last State: Terminated`, ditemukan: `Reason: OOMKilled`, `Exit Code: 137`. |
| **15:38** | **Mitigation** | Insinyur on-call menaikkan resource limit via hot-patch: `kubectl set resources deployment/sentiment-api -n ai-ops --limits=memory=256Mi --requests=memory=64Mi`. |
| **15:40** | **Verification** | Deployment rollout selesai. Insinyur mengirimkan 50 request inferensi konkuren; semua berhasil dengan status 200 OK tanpa pod restart. |
| **15:45** | **Resolution** | Metrik memory working set stabil di kisaran ~45-55Mi. Alert kembali hijau. Postmortem diinisiasi. |

---

## 4. Root Cause Analysis (5 Whys)

1. **Mengapa klien menerima error 502 Bad Gateway dan connection drop?**
   Kontainer `sentiment-api` tiba-tiba mati saat sedang memproses request HTTP klien.
2. **Mengapa kontainer tiba-tiba mati di tengah pemrosesan?**
   Kernel Linux mengirimkan sinyal pembunuhan paksa `SIGKILL` ke proses Python.
3. **Mengapa kernel mengirimkan `SIGKILL` (Exit Code 137)?**
   Proses melewati batas memori yang dialokasikan pada Linux cgroup (`memory.max_usage_in_bytes > memory.limit_in_bytes`).
4. **Mengapa batas cgroup terlampaui?**
   Limit memori pada manifest Kubernetes disetel ke `24Mi`, sedangkan *baseline memory footprint* FastAPI + Uvicorn + Scikit-learn model berukuran ~45Mi.
5. **Akar Masalah (Root Cause):**
   Konfigurasi resource limit Kubernetes ditentukan tanpa pengukuran *memory profiling* (profiling empiris) terlebih dahulu terhadap beban kerja model machine learning di lingkungan produksi.

---

## 5. Lessons Learned

### What Went Well
- Exit code 137 dan string `OOMKilled` dicatat secara akurat oleh kubelet dan ditampilkan jelas di `kubectl describe pod`, mempercepat proses diagnosis ke ranah resource limits.
- Kenaikan limits melalui `kubectl set resources` diterapkan secara *rolling update* tanpa mengorbankan konfigurasi lainnya.

### What Went Poorly
- Tidak ada alert Prometheus khusus yang mengawasi rasio penggunaan memori (`container_memory_working_set_bytes / kube_pod_container_resource_limits_memory_bytes > 0.85`), sehingga tim baru mengetahui masalah setelah kontainer mati dibunuh kernel.

### Where We Got Lucky
- Tidak terjadi kebocoran memori (*memory leak*) pada aplikasi; kenaikan murni karena batas limit yang terlalu sempit (*under-provisioning*).

---

## 6. Action Items & Pencegahan

| No | Tindakan Pencegahan | Prioritas | Tipe | Penanggung Jawab | Target |
|---|---|---|---|---|---|
| **1** | Tetapkan *golden rule* memory sizing: `limits = 2x - 3x baseline model memory consumption` (minimal 256Mi untuk Scikit-learn, 1Gi untuk BERT/PyTorch). | **P0** | Prevent | Tim AI Platform | Selesai |
| **2** | Tambahkan alert Prometheus `ContainerMemoryUsageNearLimit` (memicu peringatan saat memory > 85% limit). | **P1** | Detect | Tim Ops/SRE | Sprint 1 |
| **3** | Lakukan *benchmark profiling* otomatis menggunakan load test sebelum menaikkan versi manifest ke produksi. | **P2** | Mitigate | Tim DevOps | Sprint 2 |
