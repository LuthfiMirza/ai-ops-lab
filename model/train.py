"""
Baseline Model Trainer for Stock News Sentiment Analysis.

NOTE: This dataset consists of synthetic demo headlines for Indonesian stock
market news. It is strictly DEMO DATA (bukan data asli) intended for validating
the operational microservice serving pipeline, Kubernetes deployment, and RED
metrics monitoring.
"""

from pathlib import Path
import joblib
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline

# Explicitly labeled DEMO DATA (bukan data asli)
DEMO_DATA = [
    # Positive headlines
    ("IHSG melonjak tajam ditopang aksi beli bersih investor asing pada saham perbankan", "positive"),
    ("Laba bersih BBCA melonjak 15 persen year-on-year didorong pertumbuhan kredit", "positive"),
    ("Kinerja kuartalan BBRI solid dengan margin bunga bersih yang meningkat", "positive"),
    ("Emiten sektor energi membukukan rekor pendapatan berkat kenaikan harga komoditas", "positive"),
    ("Analis menaikkan target harga saham ASII seiring pulihnya penjualan otomotif", "positive"),
    ("Dividen interim jumbo siap dibagikan emiten batu bara kepada para pemegang saham", "positive"),
    ("Ekspansi pabrik baru perseroan berjalan sukses dan siap dongkrak kapasitas produksi", "positive"),
    ("Sentimen pasar menguat setelah rilis data inflasi yang lebih rendah dari perkiraan", "positive"),

    # Neutral headlines
    ("Bursa Efek Indonesia mengumumkan jadwal libur perdagangan bursa bulan depan", "neutral"),
    ("Emiten telekomunikasi akan menyelenggarakan RUPS tahunan pada akhir pekan ini", "neutral"),
    ("Pergerakan harga saham TLKM cenderung mendatar di tengah penantian laporan keuangan", "neutral"),
    ("Manajemen perseroan menyampaikan klarifikasi atas volatilitas transaksi saham", "neutral"),
    ("OJK merilis peraturan baru terkait tata kelola dan transparansi perusahaan tercatat", "neutral"),
    ("Volume perdagangan saham hari ini terpantau moderat menjelang pengumuman suku bunga", "neutral"),
    ("Saham perbankan diperdagangkan sideways sepanjang sesi pertama perdagangan", "neutral"),
    ("Emiten farmasi mencatat realisasi belanja modal sesuai dengan target tahunan", "neutral"),

    # Negative headlines
    ("IHSG anjlok tajam tertekan aksi jual masif saham konglomerasi dan perbankan", "negative"),
    ("Laba bersih perseroan merosot tajam akibat lonjakan beban operasional dan bunga", "negative"),
    ("Penjualan semen melemah seiring lesunya sektor properti dan perlambatan ekonomi", "negative"),
    ("Kinerja keuangan tertekan rugi kurs rupiah dan beban utang luar negeri yang tinggi", "negative"),
    ("Peringkat utang emiten diturunkan menjadi negatif akibat risiko likuiditas", "negative"),
    ("Investor asing mencatatkan net sell ratusan miliar rupiah pada penutupan pasar", "negative"),
    ("Sengketa hukum dan penundaan proyek menghambat kinerja operasional emiten", "negative"),
    ("Pendapatan kuartal kedua turun drastis imbas pelemahan daya beli masyarakat", "negative"),
]


def train_baseline_model(output_path: Path) -> Pipeline:
    """Train TF-IDF + Logistic Regression pipeline on demo data and save to disk."""
    texts = [item[0] for item in DEMO_DATA]
    labels = [item[1] for item in DEMO_DATA]

    # Pipeline: Feature Extraction + Classification
    # Target classes: positive, neutral, negative
    pipeline = Pipeline([
        ("tfidf", TfidfVectorizer(ngram_range=(1, 2), min_df=1, lowercase=True)),
        ("classifier", LogisticRegression(C=1.0, max_iter=200, random_state=42))
    ])

    pipeline.fit(texts, labels)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(pipeline, output_path)

    return pipeline


if __name__ == "__main__":
    artifact_path = Path(__file__).resolve().parent / "artifacts" / "sentiment_baseline.joblib"
    print(f"[+] Training baseline model on {len(DEMO_DATA)} demo headlines...")
    trained_pipeline = train_baseline_model(artifact_path)
    print(f"[+] Baseline model successfully saved to: {artifact_path}")
    print(f"[+] Pipeline classes: {trained_pipeline.classes_.tolist()}")
