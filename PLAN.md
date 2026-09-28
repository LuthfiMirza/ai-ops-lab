# AI Ops Lab: PLAN

Proyek portofolio untuk latihan peran **System Engineer (AI/ML)**: mengoperasikan layanan model AI seperti di production (deploy, monitor, insiden, dokumentasi), bukan sekadar membuat model.

> Catatan jujur: ini lab pribadi, bukan pengalaman production. Sebut apa adanya saat interview: "lab yang saya bangun untuk belajar operasional aplikasi AI/ML".

## Tujuan

Membangun layanan analisis sentimen berita saham yang:

1. berjalan di container,
2. dideploy ke Kubernetes lokal (kind) lewat pipeline,
3. dimonitor (metric + dashboard + alert),
4. punya database dengan backup/restore,
5. diuji lewat **game day** (insiden buatan) dengan runbook dan postmortem.

## Definition of Done (versi minimal)

- [x] API `/predict`, `/health`, `/metrics` jalan di Docker
- [x] Deploy ke kind (Deployment, Service, ConfigMap, Secret, Ingress)
- [x] GitHub Actions: lint, test, build image
- [x] Prometheus + Grafana menampilkan request rate, latency, error rate
- [ ] MySQL menyimpan hasil prediksi; backup dan restore teruji (RTO/RPO dicatat)
- [ ] Minimal 3 game day dengan runbook dan postmortem
- [ ] README + diagram arsitektur

Kalau semua tercentang, proyek sudah cukup kuat. Semua di bawah ini bonus.

## Arsitektur target

```
client -> Ingress -> Service -> Deployment (FastAPI sentiment API) -> MySQL (StatefulSet + PVC)
                                      |
                                      +-> /metrics -> Prometheus -> Grafana (+ alert rules)
GitHub Actions: lint -> test -> build image -> (deploy ke kind)
```

## Struktur repo

```
ai-ops-lab/
  app/            # FastAPI: main.py, model_loader.py, schemas.py, metrics.py, db.py
  model/          # train.py (baseline) + artifacts/ (di-gitignore bila besar)
  tests/
  k8s/            # namespace, deployment, service, configmap, secret.example, ingress, mysql, hpa
  monitoring/     # prometheus.yml/manifests, alert rules, grafana dashboard json
  docs/           # architecture.md, runbooks/, postmortems/, gamedays/
  scripts/        # kind-up.sh, backup.sh, restore.sh, loadtest.sh
  .github/workflows/ci.yml
  Dockerfile
  Makefile
  README.md
```

## Fase

| Fase | Isi | Status | Output yang bisa didemokan |
|---|---|---|---|
| 0 | Discovery: cek spek mesin, kondisi model skripsi, tool terpasang | Selesai | `docs/00-discovery.md` |
| 1 | API + model + Docker | Selesai | `docker run` lalu `curl /predict` |
| 2 | kind + manifest Kubernetes | Selesai | `kubectl get pods` sehat, akses via Ingress |
| 3 | CI GitHub Actions | Selesai | pipeline hijau |
| 4 | Monitoring Prometheus + Grafana + alert | Selesai | dashboard hidup |
| 5 | MySQL + persistensi + backup/restore | Belum | data tetap ada setelah pod dihapus |
| 6 | Game day + runbook + postmortem | Belum | 3 dokumen insiden |
| 7 (bonus) | Kafka, GraphQL, Ansible, drift metric | Belum | pilih sesuai waktu |

## Jadwal saran (estimasi, sesuaikan dengan kuliah, GUCC, dan skripsi)

- **Hari ini (sebelum interview 29 Sep 13:30 WIB):** Fase 0, 1, dan 2 saja. Cukup sampai API jalan di kind. Jangan kejar sisanya.
- **Minggu 1:** selesaikan Fase 2, mulai Fase 3.
- **Minggu 2:** Fase 4 dan 5.
- **Minggu 3:** Fase 6, lalu Fase 7 yang dipilih.
- **Minggu 4:** rapikan README, diagram, dan siapkan cerita untuk interview.

## Skenario game day (Fase 6)

1. Pod crash karena config salah (`CrashLoopBackOff`).
2. Image tidak ditemukan (`ImagePullBackOff`).
3. Pod kena OOMKilled karena memory limit terlalu kecil.
4. MySQL mati lalu restore dari backup (catat RTO dan RPO).
5. Lonjakan traffic (load test), amati latency dan HPA.

Tiap skenario wajib punya: gejala, deteksi (alert/metric), penanganan, akar masalah, pencegahan.

## Materi belajar per fase (ringkas)

- **Fase 1-2:** image vs container, pod, deployment, service, ingress, configmap/secret, `kubectl get/describe/logs/exec`.
- **Fase 3:** alur build-test-deploy, caching, secret di CI.
- **Fase 4:** metric vs log vs alert, RED metrics (rate, errors, duration), PromQL dasar.
- **Fase 5:** PVC/StatefulSet, indexing, `EXPLAIN`, RTO vs RPO.
- **Fase 6:** incident vs problem management, RCA, blameless postmortem.

## Risiko

- RAM MacBook terbatas: jalankan komponen bertahap, jangan semua sekaligus. Pakai Prometheus + Grafana ringan, bukan stack besar.
- Model skripsi mungkin belum bisa diekspor: pakai baseline sederhana dulu (lihat Fase 0 di prompt).
- Scope creep: bonus (Fase 7) hanya dikerjakan setelah Definition of Done tercapai.
