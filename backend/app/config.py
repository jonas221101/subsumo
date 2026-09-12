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


@lru_cache
def get_settings() -> Settings:
    return Settings()
