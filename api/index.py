"""
Photo Coach Pro — Vercel Serverless Entry Point
Name: Jason E Alaounis
Email: Philotimo71@gmail.com
Company: ALÁON

This file is the ASGI handler Vercel invokes for every Python function request.
Mangum adapts FastAPI (ASGI) to the Lambda-style execution model that Vercel uses.
"""

from __future__ import annotations

import os
import sys

# Make backend source importable regardless of where Vercel resolves __file__
_here = os.path.dirname(os.path.abspath(__file__))
_backend_src = os.path.abspath(os.path.join(_here, "..", "backend", "src"))
if _backend_src not in sys.path:
    sys.path.insert(0, _backend_src)

from mangum import Mangum  # type: ignore
from photo_coach_api.main import app  # noqa: E402  (import after sys.path patch)

# Vercel looks for a callable named `handler`
handler = Mangum(app, lifespan="off")
