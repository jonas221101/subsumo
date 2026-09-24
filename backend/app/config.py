"""Zentrale Konfiguration. Alles ueber Umgebungsvariablen mit SUBSUMO_-Praefix."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

REPO_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="SUBSUMO_", env_file=".env", extra="ignore")

    app_name: str = "Subsumo API"
    environment: str = "dev"

    # SQLite im Dev/Test, PostgreSQL in Produktion.
    database_url: str = "sqlite:///./subsumo.db"

    # In Produktion zwingend ueberschreiben. Der Default ist bewusst
    # offensichtlich unsicher, damit ein fehlendes Secret sofort auffaellt.
    jwt_secret: str = "dev-only-insecure-change-me"
    jwt_algorithm: str = "HS256"
    access_token_ttl_minutes: int = 60 * 24 * 7

    # IP-basiertes Rate-Limit fuer /auth/login und /auth/register
    # (docs/26-projektreview-sub254.md Abschnitt 3.2): bremst Credential-
    # Stuffing und Massen-Registrierung aus einer Quelle.
    auth_rate_limit_max_requests: int = 20
    auth_rate_limit_window_seconds: float = 60.0

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


@lru_cache
def get_settings() -> Settings:
    return Settings()
