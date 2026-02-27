"""
Photo Coach Pro — Critique Routes
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON
"""

from __future__ import annotations

from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse

from photo_coach_api.services.critique_service import critique_image_bytes

router = APIRouter(prefix="/api/v1", tags=["critique"])


@router.post("/critique")
async def critique(file: UploadFile = File(...)) -> JSONResponse:
    if not file:
        raise HTTPException(status_code=400, detail="Missing file")

    # Basic guardrail (10 MB) to avoid accidental huge uploads in dev
    data = await file.read()
    if len(data) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 10MB in dev)")

    result = critique_image_bytes(data, filename=file.filename)
    return JSONResponse(result)