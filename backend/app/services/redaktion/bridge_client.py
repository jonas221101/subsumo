"""Datei-Bruecke: Claude (dieser Agent, live im Gespraech) spielt den
LLM-Client selbst, ohne API-Key. Fuer Offline-Tests der Redaktions-Pipeline,
bevor ein echter SUBSUMO_LLM_API_KEY vorhanden ist - siehe
docs/08-ki-redaktion.md, Abschnitt "Lokaler Bruecken-Modus".

Protokoll (pro Aufruf ``n``, aufsteigend nummeriert, in ``bridge_dir``):

1. Der Client schreibt ``request_{n}.txt`` (der vollstaendige Prompt) und
   danach ``request_{n}.ready`` (leerer Marker) - der Marker kommt bewusst
   NACH dem Inhalt, damit niemand eine halbgeschriebene Datei liest.
2. Der Agent liest request_{n}.txt, beantwortet ihn genau nach den Vorgaben
   des Prompts (Collector: YAML-Entwurf; Reviewer: JSON-Urteil) und schreibt
   response_{n}.txt + response_{n}.ready.
3. Der Client pollt auf response_{n}.ready und liefert den Inhalt zurueck.

Bewusst dateibasiert statt stdin/stdout: der Pipeline-Prozess laeuft im
Hintergrund, der Agent bedient ihn ueber normale Read/Write-Tool-Aufrufe auf
denselben Dateien - kein IPC, keine zusaetzliche Abhaengigkeit, und jeder
Austausch bleibt als Klartext im Bruecken-Verzeichnis nachvollziehbar.
"""

from __future__ import annotations

import time
from pathlib import Path

from app.core.llm import LLMError, LLMResponse


class FileBridgeLLMClient:
    """Ein ``LLMClient`` (siehe app.core.llm), der Anfragen ueber Dateien an
    einen Menschen oder - hier - denselben Agenten weiterreicht, der gerade
    im Gespraech mit dem Nutzer steht."""

    name = "claude-local-bridge"

    def __init__(
        self,
        bridge_dir: Path,
        *,
        timeout_s: float = 900.0,
        poll_interval_s: float = 1.0,
    ) -> None:
        self.bridge_dir = bridge_dir
        self.timeout_s = timeout_s
        self.poll_interval_s = poll_interval_s
        self._counter = 0
        self.bridge_dir.mkdir(parents=True, exist_ok=True)

    @property
    def available(self) -> bool:
        return True

    def complete(self, prompt: str, *, max_tokens: int = 4000) -> LLMResponse:
        self._counter += 1
        n = self._counter
        req_path = self.bridge_dir / f"request_{n:03d}.txt"
        req_ready = self.bridge_dir / f"request_{n:03d}.ready"
        resp_path = self.bridge_dir / f"response_{n:03d}.txt"
        resp_ready = self.bridge_dir / f"response_{n:03d}.ready"

        req_path.write_text(prompt, encoding="utf-8")
        req_ready.touch()

        waited = 0.0
        while not resp_ready.exists():
            time.sleep(self.poll_interval_s)
            waited += self.poll_interval_s
            if waited > self.timeout_s:
                raise LLMError(
                    f"Keine Antwort auf {req_path.name} innerhalb von "
                    f"{self.timeout_s:.0f}s - Bruecken-Modus abgebrochen."
                )

        text = resp_path.read_text(encoding="utf-8")
        return LLMResponse(text=text, model=self.name)
