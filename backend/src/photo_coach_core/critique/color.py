"""
Photo Coach Pro — Color Metrics
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

Goal:
- Provide simple, explainable color metrics and a 0–100 score.
- Uses Pillow only.
- Focus: saturation balance + white balance tint + color cast hints.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Tuple


def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))


def color_metrics(image_path: Path) -> Dict[str, Any]:
    """
    Returns:
      - mean_rgb
      - saturation_mean_0_1
      - saturation_p95_0_1
      - warmth_r_minus_b
      - green_magenta_g_minus_avg_rb
      - score_0_100
      - notes (list)
    """
    try:
        from PIL import Image, ImageStat  # type: ignore
    except Exception as e:
        return {"available": False, "error": f"Pillow not installed: {e}"}

    p = Path(image_path)
    if not p.exists():
        return {"available": False, "error": "File not found"}

    img = Image.open(str(p)).convert("RGB")

    # Normalize size for stable metrics
    max_dim = 1400
    if max(img.size) > max_dim:
        scale = max_dim / float(max(img.size))
        img = img.resize((max(1, int(img.size[0] * scale)), max(1, int(img.size[1] * scale))))

    stat = ImageStat.Stat(img)
    mean_r, mean_g, mean_b = (float(stat.mean[0]), float(stat.mean[1]), float(stat.mean[2]))
    mean_rgb = [round(mean_r, 2), round(mean_g, 2), round(mean_b, 2)]

    # Color cast indicators (simple and explainable)
    warmth = mean_r - mean_b  # positive = warm, negative = cool
    g_minus_rb = mean_g - ((mean_r + mean_b) / 2.0)  # positive = greenish, negative = magenta-ish

    # Saturation: convert to HSV and compute stats
    hsv = img.convert("HSV")
    hsv_stat = ImageStat.Stat(hsv)
    # HSV channels: H,S,V in 0..255
    s_mean_0_1 = float(hsv_stat.mean[1]) / 255.0

    # For a p95-ish saturation measure, use histogram percentile on S channel
    s_band = hsv.split()[1]  # S only
    s_hist = s_band.histogram()  # 256 bins
    total = sum(s_hist) or 1
    cdf = []
    run = 0
    for c in s_hist:
        run += c
        cdf.append(run)

    def percentile_s(frac: float) -> float:
        target = int(frac * total)
        for i, v in enumerate(cdf):
            if v >= target:
                return i / 255.0
        return 1.0

    s_p95_0_1 = percentile_s(0.95)

    notes = []

    # Interpret saturation
    if s_mean_0_1 < 0.12:
        notes.append("Colors look very muted (low saturation).")
    elif s_mean_0_1 < 0.22:
        notes.append("Colors look slightly muted (cinematic/soft palette).")
    elif s_mean_0_1 <= 0.45:
        notes.append("Saturation looks natural/healthy.")
    elif s_mean_0_1 <= 0.60:
        notes.append("Saturation is strong; watch for oversaturation.")
    else:
        notes.append("Very strong saturation; risk of clipped/unnatural color.")

    # Interpret color cast
    if warmth > 18:
        notes.append("Warm color cast detected (reds/yellows dominate).")
    elif warmth < -18:
        notes.append("Cool color cast detected (blues dominate).")
    else:
        notes.append("White balance looks fairly neutral.")

    if g_minus_rb > 10:
        notes.append("Slight green cast detected (often from fluorescents/shade).")
    elif g_minus_rb < -10:
        notes.append("Slight magenta cast detected (often from mixed lighting).")

    # Scoring heuristic (0–100)
    # Target: saturation mean roughly 0.22–0.50 feels “natural” for most photos.
    score = 100.0

    # Saturation penalty if too low/high
    if s_mean_0_1 < 0.22:
        score -= (0.22 - s_mean_0_1) * 220.0  # up to about -48
    if s_mean_0_1 > 0.55:
        score -= (s_mean_0_1 - 0.55) * 180.0  # up to about -81

    # Cast penalties (small, because style can be intentional)
    score -= min(18.0, abs(warmth) * 0.35)
    score -= min(12.0, abs(g_minus_rb) * 0.40)

    # Bonus if highlights contain some richly saturated regions without being insane
    if 0.35 <= s_p95_0_1 <= 0.85:
        score += 3.0

    score = _clamp(score, 0.0, 100.0)

    return {
        "available": True,
        "mean_rgb": mean_rgb,
        "saturation_mean_0_1": round(s_mean_0_1, 4),
        "saturation_p95_0_1": round(s_p95_0_1, 4),
        "warmth_r_minus_b": round(float(warmth), 2),
        "green_magenta_g_minus_avg_rb": round(float(g_minus_rb), 2),
        "score_0_100": round(score, 1),
        "notes": notes,
    }