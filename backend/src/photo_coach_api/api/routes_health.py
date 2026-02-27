"""
Photo Coach Pro — Health Routes
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON
"""

from __future__ import annotations

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def health():
    return {"ok": True, "service": "photo-coach-pro-api"}