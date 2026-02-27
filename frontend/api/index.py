"""
Photo Coach Pro — Vercel Serverless API
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

Self-contained FastAPI app bundled for Vercel deployment.
photo_coach_core/ lives alongside this file so Vercel bundles it automatically.
"""

from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from mangum import Mangum

from photo_coach_core.io.exif import read_exif_summary
from photo_coach_core.critique.exposure import exposure_metrics
from photo_coach_core.critique.sharpness import sharpness_metrics
from photo_coach_core.critique.color import color_metrics
from photo_coach_core.scoring.aggregate import score_image

app = FastAPI(title="Photo Coach Pro API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"ok": True, "service": "photo-coach-pro-api"}


@app.post("/api/v1/critique")
async def critique(file: UploadFile = File(...)) -> JSONResponse:
    if not file:
        raise HTTPException(status_code=400, detail="Missing file")

    data = await file.read()
    if len(data) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 10 MB)")

    suffix = Path(file.filename or "upload").suffix or ".jpg"

    with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
        tmp.write(data)
        tmp.flush()
        temp_path = Path(tmp.name)

        exif = read_exif_summary(temp_path)
        exp  = exposure_metrics(temp_path)
        shp  = sharpness_metrics(temp_path)
        col  = color_metrics(temp_path)

        score = score_image(
            exposure  = exp if exp.get("available") else {"score_0_100": 50},
            sharpness = shp if shp.get("available") else {"score_0_100": 50},
            color     = col if col.get("available") else {"score_0_100": 50},
        )

    return JSONResponse({
        "ok":        True,
        "used_core": True,
        "filename":  file.filename,
        "exif":      exif,
        "metrics":   {"exposure": exp, "sharpness": shp, "color": col},
        "score":     score,
    })


# Vercel invokes this handler for every request
handler = Mangum(app, lifespan="off")
