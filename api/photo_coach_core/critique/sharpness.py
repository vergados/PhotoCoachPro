"""
Photo Coach Pro — Sharpness Metrics
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

Goal:
- Compute an explainable sharpness score (0–100) using a Laplacian-style edge energy.
- Keeps dependencies minimal: uses Pillow only.
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Any, Dict


def sharpness_metrics(image_path: Path) -> Dict[str, Any]:
    """
    Returns:
      - laplacian_stddev
      - laplacian_variance
      - score_0_100
      - notes (list)
    """
    try:
        from PIL import Image, ImageFilter, ImageStat  # type: ignore
    except Exception as e:
        return {"available": False, "error": f"Pillow not installed: {e}"}

    p = Path(image_path)
    if not p.exists():
        return {"available": False, "error": "File not found"}

    # Load and convert to grayscale (luminance)
    img = Image.open(str(p)).convert("L")

    # Downscale for speed/consistency (keeps score stable across huge images)
    max_dim = 1600
    if max(img.size) > max_dim:
        scale = max_dim / float(max(img.size))
        new_size = (max(1, int(img.size[0] * scale)), max(1, int(img.size[1] * scale)))
        img = img.resize(new_size)

    # Laplacian-ish kernel: stronger response to edges/fine detail
    lap = img.filter(
        ImageFilter.Kernel(
            size=(3, 3),
            kernel=[-1, -1, -1,
                    -1,  8, -1,
                    -1, -1, -1],
            scale=1,
            offset=0,
        )
    )

    stat = ImageStat.Stat(lap)
    # ImageStat gives mean/stddev per channel; grayscale => index 0
    stddev = float(stat.stddev[0])
    variance = stddev * stddev

    notes = []

    # Heuristic interpretation
    if variance < 60:
        notes.append("Image likely soft or slightly out of focus.")
    elif variance < 180:
        notes.append("Sharpness looks decent for typical viewing sizes.")
    else:
        notes.append("Strong fine detail; image appears very sharp.")

    # Score mapping:
    # Use a smooth curve so “good enough” sharpness doesn’t require extreme variance.
    # score = 100 * (1 - exp(-variance / k))
    k = 180.0
    score = 100.0 * (1.0 - math.exp(-variance / k))
    score = max(0.0, min(100.0, score))

    # Small penalty if extremely low variance (very blurry)
    if variance < 25:
        score = max(0.0, score - 20.0)
        notes.append("Very low edge energy detected (possible motion blur or heavy noise reduction).")

    return {
        "available": True,
        "laplacian_stddev": round(stddev, 3),
        "laplacian_variance": round(variance, 3),
        "score_0_100": round(score, 1),
        "notes": notes,
    }