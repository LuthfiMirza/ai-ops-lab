#!/usr/bin/env bash
set -e

# ==============================================================================
# AI Ops Lab: Traffic Generator for RED Metrics & Load Simulation
# ==============================================================================
API_URL="${API_URL:-http://localhost:8080}"
NUM_REQUESTS="${1:-30}"

echo "=========================================================="
echo "AI Ops Lab: Generating ${NUM_REQUESTS} simulated requests to ${API_URL}"
echo "=========================================================="

HEADLINES_POSITIVE=(
  "IHSG menguat tajam ditopang aksi beli investor asing pada saham bankir"
  "Laba bersih BBCA melonjak 15 persen year-on-year berkat pertumbuhan kredit"
  "Kinerja kuartalan emiten energi melesat lampaui ekspektasi konsensus analis"
  "Dividen interim tunai siap dibagikan manajemen perseroan bulan depan"
  "Analis merekomendasikan beli saham ASII dengan target valuasi optimis"
)

HEADLINES_NEGATIVE=(
  "IHSG anjlok dalam tertekan sentimen pelemahan nilai tukar rupiah"
  "Laba bersih emiten teknologi merosot 40 persen akibat lonjakan beban operasional"
  "Kenaikan suku bunga acuan bank sentral memicu pelemahan sektor properti"
  "Investor asing mencatatkan net sell masif pada perdagangan saham hari ini"
  "Emiten terancam gagal bayar kewajiban obligasi jatuh tempo kuartal ini"
)

HEADLINES_NEUTRAL=(
  "Rapat Umum Pemegang Saham Luar Biasa perseroan dijadwalkan besok pagi"
  "Bursa Efek Indonesia membuka kembali perdagangan saham emiten terkait"
  "Manajemen mengumumkan perubahan jajaran direksi dan dewan komisaris"
  "Perseroan menyampaikan laporan keuangan interim triwulan ketiga"
)

count_pos=0
count_neg=0
count_neu=0
count_err=0

for i in $(seq 1 "${NUM_REQUESTS}"); do
  # 70% valid headlines, 30% edge cases / invalid requests
  mode=$(( RANDOM % 10 ))

  if [ "${mode}" -lt 4 ]; then
    # Positive headline
    idx=$(( RANDOM % ${#HEADLINES_POSITIVE[@]} ))
    headline="${HEADLINES_POSITIVE[$idx]}"
    resp=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/predict" \
      -H "Content-Type: application/json" \
      -d "{\"inputs\": \"${headline}\"}")
    http_code=$(echo "${resp}" | tail -n 1)
    echo "[REQ #${i}] [HTTP ${http_code}] [POSITIVE] ${headline:0:55}..."
    count_pos=$(( count_pos + 1 ))

  elif [ "${mode}" -lt 7 ]; then
    # Negative headline
    idx=$(( RANDOM % ${#HEADLINES_NEGATIVE[@]} ))
    headline="${HEADLINES_NEGATIVE[$idx]}"
    resp=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/predict" \
      -H "Content-Type: application/json" \
      -d "{\"inputs\": \"${headline}\"}")
    http_code=$(echo "${resp}" | tail -n 1)
    echo "[REQ #${i}] [HTTP ${http_code}] [NEGATIVE] ${headline:0:55}..."
    count_neg=$(( count_neg + 1 ))

  elif [ "${mode}" -lt 9 ]; then
    # Neutral headline
    idx=$(( RANDOM % ${#HEADLINES_NEUTRAL[@]} ))
    headline="${HEADLINES_NEUTRAL[$idx]}"
    resp=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/predict" \
      -H "Content-Type: application/json" \
      -d "{\"inputs\": \"${headline}\"}")
    http_code=$(echo "${resp}" | tail -n 1)
    echo "[REQ #${i}] [HTTP ${http_code}] [NEUTRAL ] ${headline:0:55}..."
    count_neu=$(( count_neu + 1 ))

  else
    # Edge case: Empty input string to test 422 Unprocessable Entity
    resp=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/predict" \
      -H "Content-Type: application/json" \
      -d '{"inputs": ""}')
    http_code=$(echo "${resp}" | tail -n 1)
    echo "[REQ #${i}] [HTTP ${http_code}] [VALIDATION ERR] Empty input payload"
    count_err=$(( count_err + 1 ))
  fi

  # Micro-sleep between 50ms and 150ms for realistic traffic flow
  sleep 0.1
done

echo "=========================================================="
echo "Traffic summary:"
echo "  Positive: ${count_pos}"
echo "  Negative: ${count_neg}"
echo "  Neutral : ${count_neu}"
echo "  Errors  : ${count_err}"
echo "  Total   : ${NUM_REQUESTS}"
echo "=========================================================="
