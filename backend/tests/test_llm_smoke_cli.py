"""Test des Skip-Pfads fuer den LLM-Smoke-Test (SUB-311).

Ohne gueltigen SUBSUMO_LLM_API_KEY muss das Skript sauber uebersprungen
werden (Exit-Code 0) - CI hat standardmaessig keinen Key und darf hier nie
rot werden. Ein Lauf mit echtem Key ist bewusst nicht Teil dieses Tests -
der wuerde einen echten, kostenpflichtigen Anthropic-Aufruf ausloesen.
"""

from __future__ import annotations

from app.config import get_settings
from scripts.llm_smoke_cli import run


def test_ohne_gueltigen_key_wird_sauber_uebersprungen(monkeypatch, capsys):
    monkeypatch.delenv("SUBSUMO_LLM_API_KEY", raising=False)
    monkeypatch.setenv("SUBSUMO_LLM_PROVIDER", "none")
    get_settings.cache_clear()

    exit_code = run()

    assert exit_code == 0
    assert "SKIP" in capsys.readouterr().out
    get_settings.cache_clear()
