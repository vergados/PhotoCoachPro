"""
Photo Coach Pro — DPI / Print Readiness
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

Goal:
- Given pixel dimensions and a target print size, compute effective DPI (PPI).
- Provide guidance for common quality tiers.

Notes:
- Strictly speaking it’s PPI (pixels per inch), but most users say DPI.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional, Tuple


def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))


@dataclass(frozen=True)
class PrintSizeInches:
    width_in: float
    height_in: float


def effective_ppi(px_w: int, px_h: int, size: PrintSizeInches) -> Dict[str, Any]:
    """
    Effective PPI for width and height (and a conservative min).
    """
    if size.width_in <= 0 or size.height_in <= 0:
        raise ValueError("Print size must be positive inches.")

    ppi_w = px_w / float(size.width_in)
    ppi_h = px_h / float(size.height_in)
    return {
        "ppi_width": round(ppi_w, 2),
        "ppi_height": round(ppi_h, 2),
        "ppi_min": round(min(ppi_w, ppi_h), 2),
    }


def quality_tier(ppi_min: float) -> Dict[str, Any]:
    """
    Returns a human-friendly quality tier based on conservative min PPI.

    Rough guidance:
      - 300+ : Excellent (gallery-quality)
      - 240+ : Very good
      - 200+ : Good (most viewing distances)
      - 150+ : Fair (okay for larger viewing distance)
      - <150 : Low (likely soft/pixelated)
    """
    p = float(ppi_min)
    if p >= 300:
        tier = "excellent"
        msg = "Excellent for high-quality prints (300+ PPI)."
    elif p >= 240:
        tier = "very_good"
        msg = "Very good print quality (240+ PPI)."
    elif p >= 200:
        tier = "good"
        msg = "Good print quality for most uses (200+ PPI)."
    elif p >= 150:
        tier = "fair"
        msg = "Fair quality; best for larger viewing distance (150+ PPI)."
    else:
        tier = "low"
        msg = "Low PPI; print may look soft/pixelated."

    return {"tier": tier, "message": msg}


def max_print_size_for_target_ppi(px_w: int, px_h: int, target_ppi: float) -> Dict[str, Any]:
    """
    Given pixels and a target PPI (e.g., 300), compute max print size (inches).
    """
    if target_ppi <= 0:
        raise ValueError("target_ppi must be positive.")

    w_in = px_w / float(target_ppi)
    h_in = px_h / float(target_ppi)
    return {
        "max_width_in": round(w_in, 2),
        "max_height_in": round(h_in, 2),
        "target_ppi": float(target_ppi),
    }


def dpi_recommendations(
    px_w: int,
    px_h: int,
    target_print_w_in: Optional[float] = None,
    target_print_h_in: Optional[float] = None,
) -> Dict[str, Any]:
    """
    Main helper:
    - If target print size given, compute effective PPI + tier.
    - Always compute max print sizes for common targets (300/240/200/150).

    Returns a dict ready for UI.
    """
    if px_w <= 0 or px_h <= 0:
        raise ValueError("Pixel dimensions must be positive integers.")

    out: Dict[str, Any] = {
        "pixels": {"width_px": int(px_w), "height_px": int(px_h)},
        "targets": {
            "max_print_at_300ppi": max_print_size_for_target_ppi(px_w, px_h, 300),
            "max_print_at_240ppi": max_print_size_for_target_ppi(px_w, px_h, 240),
            "max_print_at_200ppi": max_print_size_for_target_ppi(px_w, px_h, 200),
            "max_print_at_150ppi": max_print_size_for_target_ppi(px_w, px_h, 150),
        },
    }

    if target_print_w_in and target_print_h_in:
        size = PrintSizeInches(float(target_print_w_in), float(target_print_h_in))
        eff = effective_ppi(px_w, px_h, size)
        out["target_print_size_in"] = {"width_in": size.width_in, "height_in": size.height_in}
        out["effective_ppi"] = eff
        out["quality"] = quality_tier(eff["ppi_min"])

    return out