from typing import Optional
from pydantic import BaseModel, Field, model_validator


class SentimentRequest(BaseModel):
    """
    Request payload for sentiment analysis.
    Matches the schema expected by the Laravel application (PythonApiSentimentAnalyzer.php)
    with backward/forward compatibility for {"text": "..."}.
    """
    inputs: Optional[str] = Field(
        default=None,
        description="Text content of the news headline or article excerpt."
    )
    text: Optional[str] = Field(
        default=None,
        description="Alias for inputs field."
    )

    @model_validator(mode="after")
    def validate_content_not_empty(self) -> "SentimentRequest":
        raw_text = self.inputs if self.inputs is not None else self.text
        if raw_text is None or not raw_text.strip():
            raise ValueError("inputs must not be empty")
        # Normalize into self.inputs
        self.inputs = raw_text.strip()
        return self


class SentimentResponse(BaseModel):
    """
    Prediction response contract matching the thesis sentiment API schema.
    """
    label: str = Field(description="Winning sentiment class: positive | neutral | negative")
    confidence: float = Field(description="Confidence probability of the winning class (0.0 - 1.0)")
    score: float = Field(description="Directional polarity score (-1.0 to 1.0)")
    prob_positive: float = Field(description="Softmax probability for positive sentiment")
    prob_neutral: float = Field(description="Softmax probability for neutral sentiment")
    prob_negative: float = Field(description="Softmax probability for negative sentiment")


class HealthResponse(BaseModel):
    """Health check payload for container liveness and readiness probes."""
    status: str = Field(default="ok")
    model_loaded: bool = Field(default=True)
    model_type: str = Field(default="baseline-sklearn")
    database_connected: Optional[bool] = Field(default=None)
