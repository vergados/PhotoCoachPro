"""
Photo Coach Pro — Critique Service (backend)
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

This module owns the "critique an image" business logic for the API layer.
"""

from __future__ import annotations

import io
import sys
from pathlib import Path
from typing import Any, Dict


def _repo_root() -> Path:
    # backend/src/photo_coach_api/services/critique_service.py -> ... -> repo root
    return Path(__file__).resolve().parents[5]


def _ensure_core_importable() -> None:
    core_src = _repo_root() / "core" / "src"
    if core_src.exists() and str(core_src) not in sys.path:
        sys.path.insert(0, str(core_src))


def _fallback_metrics(image_bytes: bytes) -> Dict[str, Any]:
    """
    Minimal analysis using Pillow only (works even if core isn't importable yet).
    """
    try:
        from PIL import Image, ImageStat  # type: ignore
    except Exception as e:
        return {
            "ok": False,
            "used_core": False,
            "error": f"Pillow not installed yet. Install backend requirements. Error: {e}",
        }

    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    stat = ImageStat.Stat(img)

    mean_rgb = [round(float(x), 2) for x in stat.mean]
    brightness = round(sum(stat.mean) / 3.0, 2)
    contrast = round(sum(stat.stddev) / 3.0, 2)
    warmth = round(float(stat.mean[0] - stat.mean[2]), 2)

    return {
        "ok": True,
        "used_core": False,
        "result": {
            "fallback": True,
            "image": {"width": img.width, "height": img.height, "mode": "RGB"},
            "exposure": {"brightness_mean_0_255": brightness, "contrast_stddev": contrast},
            "color": {"mean_rgb": mean_rgb, "warmth_r_minus_b": warmth},
            "note": "Core engine not loaded; this is a lightweight fallback.",
        },
    }


def critique_image_bytes(image_bytes: bytes, filename: str | None = None) -> Dict[str, Any]:
    """
    Main entry used by API routes.
    Returns a JSON-serializable dict.
    """
    _ensure_core_importable()

    # Try core engine first
    try:
        from photo_coach_core.io.exif import read_exif_summary  # type: ignore
        from photo_coach_core.critique.exposure import exposure_metrics  # type: ignore
        from photo_coach_core.critique.sharpness import sharpness_metrics  # type: ignore
        from photo_coach_core.critique.color import color_metrics  # type: ignore
        from photo_coach_core.scoring.aggregate import score_image  # type: ignore

        # Core functions currently expect a file path, so write to a temp file in-memory-safe way:
        # We’ll keep it simple here by using a temp file inside /tmp-like area.
        import tempfile

        suffix = Path(filename or "upload").suffix or ".jpg"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
            tmp.write(image_bytes)
            tmp.flush()
            temp_path = Path(tmp.name)

            exif = read_exif_summary(temp_path)
            exp = exposure_metrics(temp_path)
            shp = sharpness_metrics(temp_path)
            col = color_metrics(temp_path)

            score = score_image(
                exposure=exp if exp.get("available") else {"score_0_100": 50},
                sharpness=shp if shp.get("available") else {"score_0_100": 50},
                color=col if col.get("available") else {"score_0_100": 50},
            )

            return {
                "ok": True,
                "used_core": True,
                "filename": filename,
                "exif": exif,
                "metrics": {"exposure": exp, "sharpness": shp, "color": col},
                "score": score,
            }

    except Exception:
        # If core isn't ready yet, fall back
        return _fallback_metrics(image_bytes)