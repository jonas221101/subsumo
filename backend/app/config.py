"""Zentrale Konfiguration. Alles ueber Umgebungsvariablen mit SUBSUMO_-Praefix."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

REPO_ROOT = Path(__file__).resolve().parents[2]

# Bewusst offensichtlich unsicher, damit ein fehlendes Secret sofort auffaellt
# (siehe Settings.jwt_secret). Der Fail-Fast-Check unten vergleicht dagegen.
_INSECURE_DEFAULT_JWT_SECRET = "dev-only-insecure-change-me"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="SUBSUMO_", env_file=".env", extra="ignore")

    app_name: str = "Subsumo API"
    environment: str = "dev"

    # SQLite im Dev/Test, PostgreSQL in Produktion.
    database_url: str = "sqlite:///./subsumo.db"

    # In Produktion zwingend ueberschreiben. Der Default ist bewusst
    # offensichtlich unsicher, damit ein fehlendes Secret sofort auffaellt.
    jwt_secret: str = _INSECURE_DEFAULT_JWT_SECRET
    jwt_algorithm: str = "HS256"
    access_token_ttl_minutes: int = 60 * 24 * 7

    # IP-basiertes Rate-Limit fuer /auth/login und /auth/register
    # (docs/26-projektreview-sub254.md Abschnitt 3.2): bremst Credential-
    # Stuffing und Massen-Registrierung aus einer Quelle.
    auth_rate_limit_max_requests: int = 20
    auth_rate_limit_window_seconds: float = 60.0

    # Kommagetrennte Liste vertrauenswuerdiger Reverse-Proxy-IPs (der
    # unmittelbare TCP-Peer aus Sicht von uvicorn). Nur wenn dieser Peer
    # hier eingetragen ist, liest der Rate-Limiter die vom Proxy gesetzte
    # X-Forwarded-For-IP statt der Peer-Adresse - sonst koennte jeder Client
    # den Header selbst faelschen und das Limit umgehen. Leer (Default) =
    # X-Forwarded-For wird ignoriert, es zaehlt der direkte TCP-Peer.
    # Siehe docs/22-deploy-runbook.md ("Voraussetzungen") fuer den
    # Produktionswert hinter dem dort dokumentierten nginx-Reverse-Proxy.
    rate_limit_trusted_proxies: str = ""

    # Verzeichnis mit den Lerninhalten (YAML).
    content_dir: Path = REPO_ROOT / "content"
    seed_on_startup: bool = True

    # LLM-Korrektur. Ohne Key laeuft der heuristische Fallback.
    llm_provider: str = "none"  # "none" | "anthropic"
    llm_model: str = "claude-sonnet-5"
    llm_api_key: str = ""
    llm_timeout_s: float = 60.0

    # Lernplanung
    default_daily_minutes: int = 90
    seconds_per_card: int = 20

    # Paywall-Notausgang (docs/20-release-g2-bezahlstrecke.md Abschnitt 5): bei
    # False verhaelt sich jeder Nutzer wie Pro, unabhaengig vom Entitlement-Feld.
    paywall_enabled: bool = False

    # Stripe (docs/20 B3/B4/B5). Echte Price-IDs existieren erst nach G1
    # (Zahlungskonto verifiziert) - Test-Keys erlauben Entwicklung vorher.
    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""
    stripe_price_monthly: str = "price_monthly_test"
    stripe_price_yearly: str = "price_yearly_test"
    billing_success_url: str = "https://app.subsumo.de/billing?checkout=success"
    billing_cancel_url: str = "https://app.subsumo.de/billing?checkout=cancelled"
    # Widerrufsfrist (docs/06-recht-compliance.md), ersetzt keine anwaltliche
    # Pruefung der endgueltigen Widerrufsbelehrung (SUB-85).
    withdrawal_period_days: int = 14

    # Strukturiertes JSON-Logging fuer Produktion, siehe
    # docs/22-deploy-runbook.md Abschnitt "Monitoring".
    log_json: bool = False

    @model_validator(mode="after")
    def _fail_fast_on_default_jwt_secret_in_production(self) -> Settings:
        # docs/17-release-readiness.md Abschnitt 2 (Gate D): ein Produktions-
        # Start mit dem oeffentlich im Repository stehenden Default-Secret
        # wuerde Tokens signieren, die jeder faelschen kann.
        if self.environment == "production" and self.jwt_secret == _INSECURE_DEFAULT_JWT_SECRET:
            raise RuntimeError(
                "SUBSUMO_JWT_SECRET ist nicht gesetzt: in Produktion "
                "(SUBSUMO_ENVIRONMENT=production) darf nicht der oeffentliche "
                "Default-Wert verwendet werden (openssl rand -hex 32)."
            )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
