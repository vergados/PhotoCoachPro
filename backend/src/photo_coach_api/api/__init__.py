"""
Photo Coach Pro — API router wiring
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON
"""

from __future__ import annotations

from fastapi import APIRouter

from .routes_health import router as health_router
from .routes_critique import router as critique_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(critique_router)