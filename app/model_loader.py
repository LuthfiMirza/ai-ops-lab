import os
from pathlib import Path
from typing import Any, Dict, Optional
import joblib


class SentimentModelLoader:
    """
    Modular loader for sentiment analysis inference.
    Decoupled from FastAPI routes to enable swapping models (baseline vs IndoBERT)
    without touching the serving layer.
    """

    def __init__(self, model_path: Optional[str] = None):
        if model_path is None:
            # Default to project-relative baseline artifact path
            base_dir = Path(__file__).resolve().parent.parent
            env_path = os.getenv("MODEL_PATH")
            if env_path:
                self.model_path = Path(env_path)
            else:
                self.model_path = base_dir / "model" / "artifacts" / "sentiment_baseline.joblib"
        else:
            self.model_path = Path(model_path)

        self.model: Any = None
        self.classes: list = ["positive", "neutral", "negative"]
        self.load_model()

    def load_model(self) -> None:
        """Load joblib pipeline artifact into memory."""
        if not self.model_path.exists():
            raise FileNotFoundError(
                f"Model artifact not found at '{self.model_path}'. "
                "Ensure 'python model/train.py' has been executed."
            )
        self.model = joblib.load(self.model_path)
        if hasattr(self.model, "classes_"):
            self.classes = list(self.model.classes_)

    def predict(self, text: str) -> Dict[str, Any]:
        """
        Execute inference and format output strictly adhering to thesis API contract:
        - label: winning class ("positive" | "neutral" | "negative")
        - confidence: probability of the winning class
        - score: +confidence (positive), -confidence (negative), 0.0 (neutral)
        - prob_positive, prob_neutral, prob_negative
        """
        if self.model is None:
            raise RuntimeError("Model is not initialized.")

        # Get class probabilities
        probabilities = self.model.predict_proba([text])[0]
        prob_dict = {cls_name: float(prob) for cls_name, prob in zip(self.classes, probabilities)}

        prob_pos = prob_dict.get("positive", 0.0)
        prob_neu = prob_dict.get("neutral", 0.0)
        prob_neg = prob_dict.get("negative", 0.0)

        # Determine winning class
        winning_label = max(prob_dict, key=prob_dict.get)
        confidence = round(prob_dict[winning_label], 4)

        if winning_label == "positive":
            score = confidence
        elif winning_label == "negative":
            score = -confidence
        else:
            score = 0.0

        return {
            "label": winning_label,
            "confidence": confidence,
            "score": round(score, 4),
            "prob_positive": round(prob_pos, 4),
            "prob_neutral": round(prob_neu, 4),
            "prob_negative": round(prob_neg, 4)
        }


# Global singleton instance for the application
model_loader = None


def get_model_loader() -> SentimentModelLoader:
    global model_loader
    if model_loader is None:
        model_loader = SentimentModelLoader()
    return model_loader
