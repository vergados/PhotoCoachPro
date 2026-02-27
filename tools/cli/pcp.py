"""
Photo Coach Pro — CLI
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

Purpose:
- Small command-line entry point for quick local testing.
- No fancy packaging yet; this runs from the repo.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _repo_root() -> Path:
    # tools/cli/pcp.py -> tools/cli -> tools -> repo root
    return Path(__file__).resolve().parents[2]


def _ensure_core_on_path() -> None:
    core_src = _repo_root() / "core" / "src"
    if core_src.exists():
        sys.path.insert(0, str(core_src))


def cmd_health(_: argparse.Namespace) -> int:
    print("✅ Photo Coach Pro CLI — health OK")
    return 0


def cmd_critique(args: argparse.Namespace) -> int:
    _ensure_core_on_path()

    img_path = Path(args.image).expanduser().resolve()
    if not img_path.exists():
        print(f"❌ File not found: {img_path}")
        return 2

    from photo_coach_core.io.exif import read_exif_summary
    from photo_coach_core.critique.exposure import exposure_metrics
    from photo_coach_core.critique.sharpness import sharpness_metrics
    from photo_coach_core.critique.color import color_metrics
    from photo_coach_core.scoring.aggregate import score_image

    exif = read_exif_summary(img_path)
    exp = exposure_metrics(img_path)
    shp = sharpness_metrics(img_path)
    col = color_metrics(img_path)

    score = score_image(
        exposure=exp if exp.get("available") else {"score_0_100": 50},
        sharpness=shp if shp.get("available") else {"score_0_100": 50},
        color=col if col.get("available") else {"score_0_100": 50},
    )

    print("=== EXIF ===")
    print(exif)
    print("\n=== METRICS ===")
    print({"exposure": exp, "sharpness": shp, "color": col})
    print("\n=== SCORE ===")
    print(score)
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="pcp", description="Photo Coach Pro CLI")
    sub = p.add_subparsers(dest="cmd", required=True)

    h = sub.add_parser("health", help="Quick health check")
    h.set_defaults(func=cmd_health)

    c = sub.add_parser("critique", help="Run critique on an image file")
    c.add_argument("image", help="Path to an image (jpg/png)")
    c.set_defaults(func=cmd_critique)

    return p


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())