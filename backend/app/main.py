"""Subsumo API - Einstiegspunkt."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.api.v1 import account, auth, billing, consent, content, gutachten, learn, plan, public
from app.config import get_settings
from app.core.observability import configure_logging
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
    configure_logging(json_format=settings.log_json)
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
        consent.router,
        content.router,
        learn.router,
        gutachten.router,
        plan.router,
        billing.router,
        public.router,
    ):
        app.include_router(router, prefix="/v1")

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        # Signal fuer Fehler-Tracking/Alerting, siehe docs/22-deploy-runbook.md
        # Abschnitt "Monitoring" - unbehandelte Exceptions sind ein Weck-Signal.
        log.error(
            "Unbehandelte Exception",
            exc_info=exc,
            extra={"path": request.url.path, "method": request.method},
        )
        return JSONResponse(status_code=500, content={"detail": "Interner Fehler"})

    @app.get("/health", tags=["meta"])
    def health() -> JSONResponse:
        try:
            with SessionLocal() as db:
                db.execute(text("SELECT 1"))
            return JSONResponse({"status": "ok", "environment": settings.environment})
        except Exception as exc:  # noqa: BLE001 - Health-Check meldet jeden DB-Fehler
            log.error("Health-Check: Datenbank nicht erreichbar", exc_info=exc)
            return JSONResponse(
                {
                    "status": "degraded",
                    "environment": settings.environment,
                    "detail": "database unreachable",
                },
                status_code=503,
            )

    return app


app = create_app()
