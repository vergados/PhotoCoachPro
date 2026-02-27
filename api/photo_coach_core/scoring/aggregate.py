"""
Photo Coach Pro — Scoring Aggregator
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

Purpose:
- Combine metric dictionaries (exposure, sharpness, color) into a single, explainable score.
- Keep this pure-Python (no heavy dependencies).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional


def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))


def _getf(d: Dict[str, Any], key: str, default: float = 0.0) -> float:
    v = d.get(key, default)
    try:
        return float(v)
    except Exception:
        return float(default)


@dataclass(frozen=True)
class ScoreWeights:
    exposure: float = 0.40
    sharpness: float = 0.35
    color: float = 0.25


def score_image(
    exposure: Dict[str, Any],
    sharpness: Dict[str, Any],
    color: Dict[str, Any],
    weights: Optional[ScoreWeights] = None,
) -> Dict[str, Any]:
    """
    Returns a transparent scoring breakdown in 0..100.

    Expected metric dict keys (we'll implement producers in other files):
      Exposure:
        - "score_0_100"
      Sharpness:
        - "score_0_100"
      Color:
        - "score_0_100"
    """

    w = weights or ScoreWeights()

    exp = _clamp(_getf(exposure, "score_0_100", 50.0), 0.0, 100.0)
    shp = _clamp(_getf(sharpness, "score_0_100", 50.0), 0.0, 100.0)
    col = _clamp(_getf(color, "score_0_100", 50.0), 0.0, 100.0)

    # Weighted sum (normalized)
    total_w = max(0.0001, (w.exposure + w.sharpness + w.color))
    overall = (exp * w.exposure + shp * w.sharpness + col * w.color) / total_w
    overall = _clamp(overall, 0.0, 100.0)

    # Simple letter grade (optional UI helper)
    if overall >= 93:
        grade = "A"
    elif overall >= 85:
        grade = "B"
    elif overall >= 75:
        grade = "C"
    elif overall >= 65:
        grade = "D"
    else:
        grade = "F"

    return {
        "overall_0_100": round(overall, 1),
        "grade": grade,
        "weights": {
            "exposure": w.exposure,
            "sharpness": w.sharpness,
            "color": w.color,
        },
        "subscores_0_100": {
            "exposure": round(exp, 1),
            "sharpness": round(shp, 1),
            "color": round(col, 1),
        },
        "explain": [
            "Overall score is a weighted blend of exposure, sharpness, and color.",
            "Each subscore is expected to be 0–100 from its own metric module.",
        ],
    }