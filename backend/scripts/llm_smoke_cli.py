#!/usr/bin/env python3
"""Smoke-Test gegen den echten Anthropic-Provider (SUB-311/SUB-135).

Schickt eine echte Abgabe durch den echten LLMEvaluator/AnthropicClient-Pfad
(app/services/evaluator.py, app/core/llm.py - gleicher Code, gleicher Prompt,
gleiches max_tokens wie im Produktionsbetrieb) und prueft:

1. Antwortform - JSON-parsebar, 'checkpoints' und 'summary' vorhanden (die
   gleiche Erwartung wie LLMEvaluator.evaluate() selbst stellt).
2. Latenz des Anthropic-Aufrufs.
3. Kosten je Durchlauf - gemessen aus der Token-Zaehlung der API-Antwort
   (usage.input_tokens/output_tokens) mal Anthropic-Listenpreis, nicht
   geschaetzt (docs/19-kosten-preis-budget.md Abschnitt 5 hat bisher nur
   geschaetzt - dieser Lauf liefert die erste echte Messung).

Wird ohne gueltigen SUBSUMO_LLM_API_KEY (SUBSUMO_LLM_PROVIDER=anthropic)
sauber uebersprungen - Exit-Code 0, damit CI gruen bleibt. Ein Lauf mit Key
kostet einen echten, kleinen Anthropic-API-Aufruf.

Beispiel:
    SUBSUMO_LLM_PROVIDER=anthropic SUBSUMO_LLM_API_KEY=sk-... \\
        python scripts/llm_smoke_cli.py
"""

from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import httpx  # noqa: E402

from app.config import get_settings  # noqa: E402
from app.core.llm import AnthropicClient  # noqa: E402
from app.services.evaluator import LLMEvaluator  # noqa: E402
from app.services.gutachten import analyze  # noqa: E402

# Anthropic-Listenpreise je 1 Mio Token (Eingabe, Ausgabe). Nur fuer das laut
# SUB-129 gewaehlte Modell hinterlegt - bei Modellwechsel oder Preisaenderung
# hier aktualisieren. Das Skript rechnet gemessene Token damit hoch, es
# schaetzt nicht.
PRICE_USD_PER_MTOK: dict[str, tuple[float, float]] = {
    "claude-sonnet-5": (3.00, 15.00),
}

# Naeherungswert fuer die EUR-Anzeige, kein Live-Wechselkurs (vgl.
# docs/19-kosten-preis-budget.md Abschnitt 5, das mit rund 0,92 rechnet).
USD_TO_EUR_APPROX = 0.92

SAMPLE_EXPECTATION = {
    "pruefpunkte": [
        {
            "id": "p1",
            "label": "Anspruchsgrundlage § 433 Abs. 2 BGB",
            "weight": 2.0,
            "required": True,
            "norms": ["§ 433 Abs. 2 BGB"],
        },
        {"id": "p2", "label": "Angebot", "weight": 1.0, "keywords": ["Angebot"]},
        {"id": "p3", "label": "Annahme", "weight": 1.0, "keywords": ["Annahme"]},
    ]
}

SAMPLE_GUTACHTEN = """
A koennte gegen B einen Anspruch auf Kaufpreiszahlung aus § 433 Abs. 2 BGB
haben. Dazu muesste ein Kaufvertrag vorliegen. Hier hat A ein Angebot
abgegeben und B hat die Annahme erklaert. Mithin besteht der Anspruch aus
§ 433 Abs. 2 BGB.
"""


def run() -> int:
    """Fuehrt den Smoke-Test aus. Rueckgabe 0 = ok/uebersprungen, 1 = Fehler."""
    settings = get_settings()
    client = AnthropicClient(settings)
    if not client.available:
        print(
            "SKIP: kein gueltiger SUBSUMO_LLM_API_KEY (SUBSUMO_LLM_PROVIDER="
            f"'{settings.llm_provider}') - Smoke-Test wird uebersprungen."
        )
        return 0

    captured: dict = {}
    real_post = httpx.post

    def capturing_post(*args: object, **kwargs: object) -> httpx.Response:
        # Faengt die rohe API-Antwort ab, um usage/Text zu messen, ohne den
        # echten AnthropicClient-Aufruf zu verdoppeln oder zu veraendern.
        response = real_post(*args, **kwargs)  # type: ignore[arg-type]
        try:
            data = response.json()
            captured["usage"] = data.get("usage", {})
            captured["text"] = data["content"][0]["text"]
        except Exception:  # noqa: BLE001 - Messung darf den Aufruf nie stoeren
            pass
        return response

    evaluator = LLMEvaluator(client=client)
    start = time.monotonic()
    with mock.patch("httpx.post", side_effect=capturing_post):
        result = evaluator.evaluate(
            text=SAMPLE_GUTACHTEN,
            expectation=SAMPLE_EXPECTATION,
            structure=analyze(SAMPLE_GUTACHTEN),
        )
    latency_s = time.monotonic() - start

    # evaluate() faellt bei JEDEM Fehler (Netz, Parsing, ...) lautlos auf die
    # Heuristik zurueck - engine bleibt dann "heuristik" statt "llm:<model>".
    reached_llm = result.engine.startswith("llm:")

    # evaluate() toleriert fehlende Felder per .get(..., default) und faellt
    # dabei NICHT zurueck - deshalb hier zusaetzlich explizit pruefen, mit
    # demselben Parsing wie evaluator.py (re.search(r"\{.*\}") + json.loads).
    raw_text = captured.get("text", "")
    match = re.search(r"\{.*\}", raw_text, re.S)
    fields_ok = False
    if match:
        try:
            parsed = json.loads(match.group(0))
            fields_ok = isinstance(parsed.get("checkpoints"), list) and isinstance(
                parsed.get("summary"), str
            )
        except json.JSONDecodeError:
            fields_ok = False

    usage = captured.get("usage") or {}
    input_tokens = int(usage.get("input_tokens", 0))
    output_tokens = int(usage.get("output_tokens", 0))
    price = PRICE_USD_PER_MTOK.get(settings.llm_model)

    print(f"Modell: {settings.llm_model}")
    print(f"Latenz: {latency_s:.2f}s")
    print(f"Ueber LLM-Pfad verarbeitet (kein Fallback auf Heuristik): {reached_llm}")
    print(f"Antwortform parsebar mit erwarteten Feldern (checkpoints/summary): {fields_ok}")
    print(f"Token gemessen: input={input_tokens} output={output_tokens}")

    if price is None:
        print(
            f"WARNUNG: keine hinterlegten Listenpreise fuer Modell "
            f"'{settings.llm_model}' - Kosten nicht berechenbar."
        )
    else:
        price_in, price_out = price
        cost_usd = (input_tokens / 1_000_000) * price_in + (output_tokens / 1_000_000) * price_out
        cost_eur = cost_usd * USD_TO_EUR_APPROX
        print(f"Kosten gemessen: {cost_usd:.4f} USD (~{cost_eur:.4f} EUR, Naeherungskurs)")

    if not reached_llm or not fields_ok:
        print("FEHLER: Smoke-Test gegen den echten Provider ist fehlgeschlagen.")
        return 1
    return 0


def main() -> int:
    return run()


if __name__ == "__main__":
    raise SystemExit(main())
