"""
Photo Coach Pro — FastAPI Application
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from photo_coach_api.api import api_router

app = FastAPI(title="Photo Coach Pro API", version="1.0.0")

# Allow all origins so the frontend works in local dev, on Vercel, and in any
# staging environment without hardcoding domains.
# Credentials are disabled to satisfy the CORS spec when origin is wildcard.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)
