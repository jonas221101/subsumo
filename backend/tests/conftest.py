"""Test-Fixtures: frische SQLite-Datenbank je Test, echte Inhalte aus content/."""

from __future__ import annotations

import uuid
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import REPO_ROOT, get_settings


@pytest.fixture
def client(tmp_path, monkeypatch) -> Iterator[TestClient]:
    get_settings.cache_clear()
    monkeypatch.setenv("SUBSUMO_DATABASE_URL", f"sqlite:///{tmp_path}/test.db")
    monkeypatch.setenv("SUBSUMO_JWT_SECRET", "test-secret")
    monkeypatch.setenv("SUBSUMO_CONTENT_DIR", str(REPO_ROOT / "content"))

    import app.db as db_module

    engine = create_engine(
        f"sqlite:///{tmp_path}/test.db", connect_args={"check_same_thread": False}
    )
    monkeypatch.setattr(db_module, "engine", engine)
    monkeypatch.setattr(
        db_module,
        "SessionLocal",
        sessionmaker(bind=engine, autoflush=False, expire_on_commit=False),
    )

    import app.main as main_module

    monkeypatch.setattr(main_module, "engine", engine)
    monkeypatch.setattr(main_module, "SessionLocal", db_module.SessionLocal)

    with TestClient(main_module.create_app()) as test_client:
        yield test_client
    get_settings.cache_clear()


@pytest.fixture
def auth_client(client: TestClient) -> TestClient:
    """Angemeldeter Client."""
    email = f"{uuid.uuid4().hex[:10]}@uni-beispiel.de"
    response = client.post(
        "/v1/auth/register", json={"email": email, "password": "examen2029!"}
    )
    assert response.status_code == 201, response.text
    client.headers["Authorization"] = f"Bearer {response.json()['access_token']}"
    return client
