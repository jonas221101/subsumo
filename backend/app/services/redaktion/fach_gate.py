"""Deterministisches Fach-Gate fuer Fachrichtungen ausserhalb Jura (docs/34).

Das Normzitat-Gate (``norm_gate.py``) prueft Paragraphen - fuer Elektrotechnik,
Maschinenbau oder Lehramt ist das die falsche Frage. Dieses Gate faengt
stattdessen ab, was einem Collector-Modell in technischen Faechern leicht
unterlaeuft:

- eine Formel-Karte ohne Einheiten (``einheiten``-Liste) oder ohne
  Gleichung (``=`` oder Naeherung ``≈``) - dann ist sie nicht pruefbar;
- Paragraphen-Zitate (``§``) in ``norms`` technischer Faecher, wo Formeln
  oder DIN-/VDE-Normen hingehoeren - ein sicheres Zeichen, dass das Modell
  in den Jura-Modus gefallen ist (Lehramt zitiert Schulgesetze und SGB zu
  Recht, dort greift die Pruefung nicht);
- Aufgaben ohne Loesungsschritte (``steps``) - der gefuehrte Modus ist fuer
  Rechenaufgaben das Kernstueck.

Wie die anderen Gates laeuft es ohne LLM-Aufruf und ist je Fachrichtung
ueber ``methodik.einheiten_gate`` in content/fachrichtungen/<slug>.yaml
zugeschaltet (Jura: aus).
"""

from __future__ import annotations

import re

_EINHEIT = re.compile(r"\[[^\]]+\]|\bin\s+\S+")


def check_fach(draft: dict, *, einheiten_gate: bool) -> list[str]:
    """Leere Liste = alles ok. ``einheiten_gate`` schaltet die Formelpruefung."""
    fehler: list[str] = []
    for i, card in enumerate(draft.get("cards") or []):
        wo = f"cards[{i}] ({card.get('slug', '?')})"
        if einheiten_gate:
            for norm in card.get("norms") or []:
                if "§" in str(norm):
                    fehler.append(f"{wo}: Paragraphen-Zitat '{norm}' in einem technischen Fach")
        if einheiten_gate and card.get("type") == "formel":
            einheiten = card.get("einheiten") or []
            if not einheiten:
                fehler.append(f"{wo}: Formel-Karte ohne 'einheiten'")
            for e in einheiten:
                if not _EINHEIT.search(str(e)):
                    fehler.append(
                        f"{wo}: Einheit '{e}' nicht im Format 'Groesse in Einheit' oder "
                        "'Groesse [Einheit]'"
                    )
            back = str(card.get("back", ""))
            if "=" not in back and "≈" not in back:
                fehler.append(
                    f"{wo}: Formel-Karte ohne Gleichung ('=' oder '≈') auf der Rueckseite"
                )
    for i, case in enumerate(draft.get("faelle") or []):
        wo = f"faelle[{i}] ({case.get('slug', '?')})"
        if not case.get("steps"):
            fehler.append(f"{wo}: Aufgabe ohne Loesungsschritte ('steps')")
        if not einheiten_gate:
            continue
        for p in (case.get("expectation") or {}).get("pruefpunkte") or []:
            for norm in p.get("norms") or []:
                if "§" in str(norm):
                    fehler.append(f"{wo}: Paragraphen-Zitat '{norm}' in einem Loesungsschritt")
    return fehler
