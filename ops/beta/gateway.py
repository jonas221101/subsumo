"""Geschlossener Test-Zugang (Private Beta) fuer einzelne Testerinnen.

Ein Prozess, ein Port, eine Origin:

- ``/api/...``   -> unveraendertes Subsumo-Backend (``app.main.create_app``)
- ``/api/beta/feedback`` -> Feedback aus der App (nur eingeloggt), landet als JSONL
- alles andere   -> statischer Flutter-Web-Build (SPA-Fallback auf index.html)

Abschottung (Allowlist ``SUBSUMO_BETA_EMAILS``, kommagetrennt):

- Registrierung, API-Doku und Bezahlstrecke sind gesperrt.
- Ohne Login erreichbar sind nur Login, ``/v1/public/config`` und ``/health``.
- Jeder andere API-Aufruf braucht ein gueltiges Token eines Nutzers, dessen
  E-Mail auf der Allowlist steht - auch Inhalte, die das Backend sonst
  oeffentlich ausliefert.
- Login fuer E-Mails ausserhalb der Allowlist wird abgelehnt, selbst wenn das
  Konto in der Datenbank existieren sollte.

Start: ``uvicorn gateway:app --app-dir ops/beta`` mit ``backend/`` im
PYTHONPATH (siehe ``run.sh``).
"""

from __future__ import annotations

import json
import os
import threading
from datetime import UTC, datetime
from pathlib import Path

from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import FileResponse, JSONResponse, Response
from starlette.routing import Mount, Route
from starlette.staticfiles import StaticFiles

from app.core.security import TokenError, decode_access_token
from app.db import SessionLocal
from app.main import create_app
from app.models import User

ALLOWED = {e.strip().lower() for e in os.environ.get("SUBSUMO_BETA_EMAILS", "").split(",") if e.strip()}
ADMINS = {e.strip().lower() for e in os.environ.get("SUBSUMO_BETA_ADMINS", "").split(",") if e.strip()}
WEB_ROOT = Path(os.environ["SUBSUMO_BETA_WEB_ROOT"]).resolve()
FEEDBACK_FILE = Path(os.environ["SUBSUMO_BETA_FEEDBACK_FILE"])
_feedback_lock = threading.Lock()

if not ALLOWED:
    raise RuntimeError("SUBSUMO_BETA_EMAILS ist leer - ohne Allowlist startet der Beta-Zugang nicht")

# Ohne Token erlaubt (Pfad relativ zu /api).
_PUBLIC = {("POST", "/v1/auth/login"), ("GET", "/v1/public/config"), ("GET", "/health")}
# Komplett gesperrt, auch mit Token.
_BLOCKED_PREFIXES = ("/v1/auth/register", "/v1/billing", "/docs", "/redoc", "/openapi.json")

_SECURITY_HEADERS = [
    (b"strict-transport-security", b"max-age=31536000"),
    (b"x-frame-options", b"DENY"),
    (b"x-content-type-options", b"nosniff"),
    (b"referrer-policy", b"no-referrer"),
    (b"x-robots-tag", b"noindex, nofollow"),
]


def _json(status: int, detail: str) -> Response:
    return JSONResponse({"detail": detail}, status_code=status)


def _user_from_token(authorization: str | None) -> User | None:
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    try:
        payload = decode_access_token(authorization.split(" ", 1)[1].strip())
        user_id = int(payload["sub"])
    except (TokenError, KeyError, ValueError):
        return None
    with SessionLocal() as db:
        user = db.get(User, user_id)
    if user is None or user.email.lower() not in ALLOWED:
        return None
    return user


class BetaGuard:
    """ASGI-Middleware vor dem Backend (sieht Pfade ohne /api-Praefix)."""

    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.inner(scope, receive, send)
        # Neuere Starlette-Versionen lassen das Mount-Praefix im Pfad stehen.
        path = scope["path"]
        root = scope.get("root_path", "")
        if root and path.startswith(root):
            path = path[len(root) :]
        method = scope["method"]
        if method == "OPTIONS":
            return await _json(405, "Nicht erlaubt")(scope, receive, send)
        if any(path.startswith(p) for p in _BLOCKED_PREFIXES):
            return await _json(403, "Im Test-Zugang nicht verfuegbar")(scope, receive, send)
        if (method, path) == ("POST", "/v1/auth/login"):
            return await self._login(scope, receive, send)
        if (method, path) in _PUBLIC:
            return await self.inner(scope, receive, send)
        headers = dict(scope.get("headers") or [])
        auth = headers.get(b"authorization", b"").decode("latin-1") or None
        if _user_from_token(auth) is None:
            return await _json(401, "Bitte anmelden")(scope, receive, send)
        return await self.inner(scope, receive, send)

    async def _login(self, scope, receive, send):
        # Body puffern, Allowlist pruefen, dann unveraendert ans Backend geben.
        chunks = []
        while True:
            message = await receive()
            chunks.append(message.get("body", b""))
            if not message.get("more_body"):
                break
        body = b"".join(chunks)
        try:
            email = str(json.loads(body or b"{}").get("email", "")).strip().lower()
        except (ValueError, AttributeError):
            email = ""
        if email not in ALLOWED:
            # Dieselbe Meldung wie das Backend bei falschem Passwort.
            return await _json(401, "E-Mail oder Passwort ist falsch")(scope, receive, send)

        sent = False

        async def replay():
            nonlocal sent
            if not sent:
                sent = True
                return {"type": "http.request", "body": body, "more_body": False}
            return await receive()

        return await self.inner(scope, replay, send)


async def feedback(request: Request) -> Response:
    user = _user_from_token(request.headers.get("authorization"))
    if user is None:
        return _json(401, "Bitte anmelden")
    if request.method == "GET":
        if user.email.lower() not in ADMINS:
            return _json(403, "Nur fuer Admins")
        if not FEEDBACK_FILE.exists():
            return JSONResponse([])
        lines = FEEDBACK_FILE.read_text(encoding="utf-8").splitlines()
        return JSONResponse([json.loads(line) for line in lines if line.strip()])

    try:
        data = await request.json()
    except ValueError:
        return _json(400, "Ungueltige Anfrage")
    message = str(data.get("message", "")).strip()
    if not message:
        return _json(422, "Bitte eine Nachricht eingeben")
    entry = {
        "at": datetime.now(UTC).isoformat(timespec="seconds"),
        "email": user.email,
        "category": str(data.get("category", "sonstiges"))[:40],
        "screen": str(data.get("screen", ""))[:80],
        "message": message[:5000],
        "user_agent": request.headers.get("user-agent", "")[:300],
    }
    with _feedback_lock:
        FEEDBACK_FILE.parent.mkdir(parents=True, exist_ok=True)
        with FEEDBACK_FILE.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
    return JSONResponse({"ok": True}, status_code=201)


async def spa(request: Request) -> Response:
    # Unbekannte Pfade ohne Dateiendung (z. B. /app) bekommen die SPA.
    path = request.path_params.get("path", "")
    candidate = (WEB_ROOT / path).resolve()
    if path and candidate.is_file() and WEB_ROOT in candidate.parents:
        return FileResponse(candidate)
    if "." in path.rsplit("/", 1)[-1]:
        return Response(status_code=404)
    return FileResponse(WEB_ROOT / "index.html", headers={"cache-control": "no-cache"})


class SecurityHeaders:
    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.inner(scope, receive, send)

        async def send_with_headers(message):
            if message["type"] == "http.response.start":
                message["headers"] = list(message.get("headers", [])) + _SECURITY_HEADERS
            await send(message)

        return await self.inner(scope, receive, send_with_headers)


_backend = create_app()
_starlette = Starlette(
    routes=[
        Route("/api/beta/feedback", feedback, methods=["GET", "POST"]),
        Mount("/api", app=BetaGuard(_backend)),
        Mount("/assets", app=StaticFiles(directory=WEB_ROOT / "assets")),
        Mount("/canvaskit", app=StaticFiles(directory=WEB_ROOT / "canvaskit")),
        Route("/{path:path}", spa),
    ],
    lifespan=lambda app: _backend.router.lifespan_context(_backend),
)
app = SecurityHeaders(_starlette)
