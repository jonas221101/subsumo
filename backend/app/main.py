"""Subsumo API - Einstiegspunkt."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import account, auth, billing, content, gutachten, learn, plan
from app.config import get_settings
from app.db import Base, SessionLocal, engine
from app.services.content import load_content, seed

log = logging.getLogger("subsumo")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    Base.metadata.create_all(bind=engine)
    if settings.seed_on_startup:
        bundle = load_content(settings.content_dir)
        for error in bundle.errors:
            log.error("Content-Fehler: %s", error)
        for warning in bundle.warnings:
            log.warning("Content-Hinweis: %s", warning)
        if bundle.ok:
            with SessionLocal() as db:
                stats = seed(db, bundle)
            log.info("Inhalte geladen: %s", stats)
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        description=(
            "Backend der Jura-Lern-App Subsumo. Lernhilfe, keine Rechtsberatung: "
            "Gutachten werden ausschliesslich gegen den hinterlegten "
            "Erwartungshorizont eines Uebungsfalls bewertet."
        ),
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        # Fuer den Web-Client. In Produktion auf die eigene Domain einschraenken.
        allow_origins=["*"] if settings.environment == "dev" else ["https://app.subsumo.de"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    for router in (
        auth.router,
        account.router,
        content.router,
        learn.router,
        gutachten.router,
        plan.router,
        billing.router,
    ):
        app.include_router(router, prefix="/v1")

    @app.get("/health", tags=["meta"])
    def health() -> dict:
        return {"status": "ok", "environment": settings.environment}

    return app


app = create_app()
