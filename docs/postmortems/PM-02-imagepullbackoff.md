# Blameless Postmortem: PM-02 - ImagePullBackOff / Non-existent Tag Rollout Failure

## 1. Incident Overview
- **Incident ID:** INC-20260928-02
- **Severity:** P2 (Major Deployment Failure)
- **Status:** Resolved
- **Date & Time:** 2026-09-28 15:00 - 15:08 WIB (Duration: 8 minutes)
- **Incident Commander:** Insinyur On-Call (System Engineer AI Ops)
- **Services Impacted:** Deployment rollout pipeline for `sentiment-api`
- **Customer Impact:** 0 client errors (zero customer downtime) karena Kubernetes mempertahankan pod versi sebelumnya yang masih sehat.

---

## 2. Executive Summary
Pada 28 September 2026 pukul 15:00 WIB, pipeline rilis otomatis mencoba memperbarui image container `sentiment-api` ke tag `sentiment-api:v999-chaos-nonexistent`. Kubelet gagal menarik (*pull*) image tersebut dari registry lokal/remote, menyebabkan pod baru berstatus `ErrImagePull` dan berlanjut ke `ImagePullBackOff`. Rollout deployment terhenti (*hung*). Insinyur on-call mendeteksi kegagalan rollout, memeriksa event Kubernetes via `kubectl describe pod`, dan mengeksekusi `kubectl rollout undo` untuk membatalkan rilis cacat tersebut dalam 8 menit.

---

## 3. Incident Timeline

| Waktu (WIB) | Fase | Kejadian & Tindakan |
|---|---|---|
| **15:00** | **Trigger** | Perintah rilis dijalankan dengan tag image fiktif `sentiment-api:v999-chaos-nonexistent`. |
| **15:01** | **Failure** | Kubelet mencoba me-pull image, gagal dengan pesan `rpc error: not found / pull access denied`. |
| **15:02** | **Detection** | Command `kubectl rollout status` melebihi ambang batas toleransi waktu (timeout). |
| **15:03** | **Triage** | Insinyur on-call memeriksa status pod: `kubectl get pods -n ai-ops`. Terlihat 2 pod baru berstatus `ImagePullBackOff`, sementara 2 pod lama tetap `1/1 Running`. |
| **15:04** | **Diagnosis** | Menjalankan `kubectl describe pod <pod-name> -n ai-ops`, mengonfirmasi event: `Failed to pull image "sentiment-api:v999-chaos-nonexistent": rpc error: code = NotFound`. |
| **15:06** | **Mitigation** | Menjalankan `kubectl rollout undo deployment/sentiment-api -n ai-ops`. Kubernetes langsung menghentikan proses pembuatan pod baru yang bermasalah. |
| **15:07** | **Cleanup** | Pod bermasalah terhapus otomatis oleh Kubernetes controller manager. |
| **15:08** | **Resolution** | Rollout deployment stabil pada revisi sebelumnya. Endpoint API tetap 100% melayani request. |

---

## 4. Root Cause Analysis (5 Whys)

1. **Mengapa pod baru tidak dapat berjalan?**
   Kubelet tidak dapat men-download image container yang didefinisikan pada manifest deployment.
2. **Mengapa image download gagal?**
   Image tag `sentiment-api:v999-chaos-nonexistent` tidak ada di registry lokal container engine `kind`.
3. **Mengapa tag yang tidak ada bisa masuk ke manifest deployment?**
   Skrip deployment/CI menghasilkan tag rilis yang tidak sesuai dengan hasil tag dari proses `docker build`.
4. **Mengapa deploy dilakukan sebelum image selesai di-push/diverifikasi?**
   Tidak ada langkah verifikasi keberadaan image (*pre-deployment smoke check*) antara tahap build dan tahap deploy di CI/CD.
5. **Akar Masalah (Root Cause):**
   Tidak adanya *gatekeeper* atau *manifest verification* di pipeline CI/CD untuk memastikan image tag benar-benar terdaftar di registry sebelum menerapkan manifest `kubectl apply`.

---

## 5. Lessons Learned

### What Went Well
- **Zero Customer Downtime:** Berkat mekanisme `maxUnavailable: 0` pada strategi `RollingUpdate`, Kubernetes menolak mematikan pod lama sebelum pod baru sehat. Klien tidak merasakan gangguan sama sekali.
- `kubectl rollout undo` bekerja seketika tanpa efek samping pada database atau traffic.

### What Went Poorly
- Proses rollout deployment menggantung (*hung*) tanpa time-out otomatis bawaan jika tidak diberikan parameter `--timeout` pada script deploy.

### Where We Got Lucky
- Beban memori dan kuota pod pada node `kind` tidak terganggu oleh keberadaan pod `ImagePullBackOff`.

---

## 6. Action Items & Pencegahan

| No | Tindakan Pencegahan | Prioritas | Tipe | Penanggung Jawab | Target |
|---|---|---|---|---|---|
| **1** | Tambahkan parameter `--timeout=60s` pada setiap perintah `kubectl rollout status` di skrip automation. | **P0** | Mitigate | Tim DevOps | Selesai |
| **2** | Terapkan penamaan image berbasis Git commit SHA (`sentiment-api:${{ github.sha }}`) alih-alih tag manual di CI/CD. | **P1** | Prevent | Tim DevOps | Selesai (Fase 3) |
| **3** | Tambahkan alert Prometheus untuk pod yang stuck di status waiting lebih dari 5 menit (`kube_pod_container_status_waiting_reason{reason=~"ImagePullBackOff|ErrImagePull"}`). | **P2** | Detect | Tim Ops/SRE | Sprint 2 |
