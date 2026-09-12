"""Tests der Datei-Bruecke fuer den lokalen KI-Redaktions-Modus."""

from __future__ import annotations

import threading
import time
from pathlib import Path

import pytest

from app.core.llm import LLMError
from app.services.redaktion.bridge_client import FileBridgeLLMClient


def _answer_after(bridge_dir: Path, n: int, text: str, delay: float = 0.05) -> None:
    """Simuliert den Agenten, der die Anfrage beantwortet - mit realistischer
    Verzoegerung, damit der Test das Polling tatsaechlich durchlaeuft."""

    def worker() -> None:
        time.sleep(delay)
        (bridge_dir / f"response_{n:03d}.txt").write_text(text, encoding="utf-8")
        (bridge_dir / f"response_{n:03d}.ready").touch()

    threading.Thread(target=worker, daemon=True).start()


def test_schreibt_anfrage_und_liefert_die_antwort_zurueck(tmp_path: Path):
    client = FileBridgeLLMClient(tmp_path, poll_interval_s=0.01)
    _answer_after(tmp_path, 1, "Antwort auf die erste Anfrage")

    response = client.complete("Erste Frage")

    assert (tmp_path / "request_001.txt").read_text() == "Erste Frage"
    assert (tmp_path / "request_001.ready").exists()
    assert response.text == "Antwort auf die erste Anfrage"
    assert response.model == "claude-local-bridge"


def test_mehrere_aufrufe_zaehlen_hoch_und_kollidieren_nicht(tmp_path: Path):
    client = FileBridgeLLMClient(tmp_path, poll_interval_s=0.01)
    _answer_after(tmp_path, 1, "erste")
    erste = client.complete("Frage 1")
    _answer_after(tmp_path, 2, "zweite")
    zweite = client.complete("Frage 2")

    assert erste.text == "erste"
    assert zweite.text == "zweite"
    assert (tmp_path / "request_001.txt").read_text() == "Frage 1"
    assert (tmp_path / "request_002.txt").read_text() == "Frage 2"


def test_marker_kommt_nach_dem_inhalt_kein_race_beim_lesen(tmp_path: Path):
    """Der Client darf die Antwort erst lesen, wenn der .ready-Marker existiert
    - sonst koennte eine halbgeschriebene Datei gelesen werden."""
    client = FileBridgeLLMClient(tmp_path, poll_interval_s=0.01)

    def worker() -> None:
        time.sleep(0.03)
        path = tmp_path / "response_001.txt"
        # Absichtlich in zwei Schritten schreiben, mit Pause dazwischen -
        # ohne Marker wuerde ein schlecht getimter Client hier zugreifen.
        path.write_text("unvollstaendig", encoding="utf-8")
        time.sleep(0.03)
        path.write_text("vollstaendige Antwort", encoding="utf-8")
        (tmp_path / "response_001.ready").touch()

    threading.Thread(target=worker, daemon=True).start()
    response = client.complete("Frage")
    assert response.text == "vollstaendige Antwort"


def test_timeout_wirft_llm_error_statt_ewig_zu_warten(tmp_path: Path):
    client = FileBridgeLLMClient(tmp_path, timeout_s=0.05, poll_interval_s=0.01)
    with pytest.raises(LLMError, match="Keine Antwort"):
        client.complete("Nie beantwortete Frage")


def test_available_ist_immer_true(tmp_path: Path):
    assert FileBridgeLLMClient(tmp_path).available is True


def test_bridge_verzeichnis_wird_bei_bedarf_angelegt(tmp_path: Path):
    ziel = tmp_path / "tief" / "verschachtelt"
    assert not ziel.exists()
    FileBridgeLLMClient(ziel)
    assert ziel.exists()
