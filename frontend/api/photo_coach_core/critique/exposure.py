"""
Photo Coach Pro — Exposure Metrics
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

Goal:
- Compute simple, explainable exposure metrics and a 0–100 score.
- Uses Pillow if available (preferred).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict


def exposure_metrics(image_path: Path) -> Dict[str, Any]:
    """
    Returns:
      - brightness_mean_0_255
      - brightness_p05_0_255
      - brightness_p95_0_255
      - clipped_shadows_pct (near 0)
      - clipped_highlights_pct (near 255)
      - score_0_100
      - notes (list)
    """
    try:
        from PIL import Image  # type: ignore
    except Exception as e:
        return {"available": False, "error": f"Pillow not installed: {e}"}

    p = Path(image_path)
    if not p.exists():
        return {"available": False, "error": "File not found"}

    img = Image.open(str(p)).convert("L")  # grayscale luminance
    hist = img.histogram()  # 256 bins
    total = sum(hist) or 1

    # CDF for percentiles
    cdf = []
    running = 0
    for count in hist:
        running += count
        cdf.append(running)

    def percentile_value(frac: float) -> int:
        target = int(frac * total)
        for i, v in enumerate(cdf):
            if v >= target:
                return i
        return 255

    p05 = percentile_value(0.05)
    p95 = percentile_value(0.95)

    # Mean brightness
    mean = sum(i * hist[i] for i in range(256)) / float(total)

    # Clipping: extremes
    clipped_shadows = sum(hist[0:3]) / float(total) * 100.0     # 0–2
    clipped_highlights = sum(hist[253:256]) / float(total) * 100.0  # 253–255

    notes = []

    # Score heuristic:
    # - ideal mean around ~110–145 for typical photos (not universal, but reasonable baseline)
    # - penalize heavy clipping
    # - reward healthy dynamic range (p95 - p05)
    ideal_lo, ideal_hi = 110.0, 145.0
    if mean < ideal_lo:
        notes.append("Image looks underexposed (overall too dark).")
    elif mean > ideal_hi:
        notes.append("Image looks overexposed (overall too bright).")
    else:
        notes.append("Overall brightness looks reasonable.")

    dynamic_range = float(p95 - p05)
    if dynamic_range < 60:
        notes.append("Low dynamic range (may look flat or muddy).")
    elif dynamic_range > 170:
        notes.append("Very high dynamic range (could be harsh or high-contrast).")
    else:
        notes.append("Dynamic range looks healthy.")

    if clipped_highlights > 2.0:
        notes.append("Noticeable highlight clipping (blown whites).")
    if clipped_shadows > 2.0:
        notes.append("Noticeable shadow clipping (crushed blacks).")

    # Scoring
    score = 100.0

    # Mean penalty
    if mean < ideal_lo:
        score -= min(35.0, (ideal_lo - mean) * 0.5)
    if mean > ideal_hi:
        score -= min(35.0, (mean - ideal_hi) * 0.5)

    # Clipping penalty
    score -= min(30.0, clipped_highlights * 4.0)
    score -= min(30.0, clipped_shadows * 4.0)

    # Dynamic range bonus/penalty
    if dynamic_range < 60:
        score -= (60 - dynamic_range) * 0.25  # up to -15
    elif 80 <= dynamic_range <= 160:
        score += 3.0  # small bonus

    score = max(0.0, min(100.0, score))

    return {
        "available": True,
        "brightness_mean_0_255": round(mean, 2),
        "brightness_p05_0_255": int(p05),
        "brightness_p95_0_255": int(p95),
        "dynamic_range_0_255": round(dynamic_range, 2),
        "clipped_shadows_pct": round(clipped_shadows, 3),
        "clipped_highlights_pct": round(clipped_highlights, 3),
        "score_0_100": round(score, 1),
        "notes": notes,
    }