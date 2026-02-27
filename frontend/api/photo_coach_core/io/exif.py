"""
Photo Coach Pro — EXIF Reader (summary)
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

Goal:
- Extract a small, reliable EXIF summary for UI display.
- Uses Pillow if available; falls back gracefully if EXIF is missing.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Optional


def read_exif_summary(image_path: Path) -> Dict[str, Any]:
    """
    Returns a conservative EXIF summary.

    Output keys are stable, values may be None if not present.
    """
    try:
        from PIL import Image, ExifTags  # type: ignore
    except Exception as e:
        return {
            "available": False,
            "error": f"Pillow not installed: {e}",
        }

    p = Path(image_path)
    if not p.exists():
        return {"available": False, "error": "File not found"}

    try:
        img = Image.open(str(p))
        exif = img.getexif()
        if not exif:
            return {
                "available": True,
                "has_exif": False,
                "summary": {},
            }

        # Build tag-name map
        tag_map = {}
        for k, v in ExifTags.TAGS.items():
            tag_map[k] = v

        def get_tag(name: str) -> Optional[Any]:
            # Find numeric tag id by name (reverse lookup)
            for tag_id, tag_name in tag_map.items():
                if tag_name == name:
                    return exif.get(tag_id)
            return None

        summary: Dict[str, Any] = {}

        # Common photo metadata
        summary["make"] = get_tag("Make")
        summary["model"] = get_tag("Model")
        summary["lens_model"] = get_tag("LensModel")
        summary["datetime_original"] = get_tag("DateTimeOriginal")

        # Exposure settings
        summary["iso"] = get_tag("ISOSpeedRatings") or get_tag("PhotographicSensitivity")
        summary["f_number"] = get_tag("FNumber")
        summary["exposure_time"] = get_tag("ExposureTime")
        summary["focal_length"] = get_tag("FocalLength")

        # Image size (always available even without EXIF)
        summary["width_px"] = getattr(img, "width", None)
        summary["height_px"] = getattr(img, "height", None)

        # GPS is sensitive; include only presence by default
        gps = get_tag("GPSInfo")
        summary["has_gps"] = bool(gps)

        # Clean up values that are Pillow rationals
        def normalize(v: Any) -> Any:
            try:
                # Pillow's IFDRational behaves like a fraction
                if hasattr(v, "numerator") and hasattr(v, "denominator"):
                    if v.denominator:
                        return float(v.numerator) / float(v.denominator)
            except Exception:
                pass
            return v

        for k in list(summary.keys()):
            summary[k] = normalize(summary[k])

        return {
            "available": True,
            "has_exif": True,
            "summary": summary,
        }

    except Exception as e:
        return {
            "available": False,
            "error": f"EXIF parse failed: {e}",
        }