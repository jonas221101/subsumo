# Content-Pruefagent Elektrotechnik

Pruefinstanz der KI-Redaktion fuer die Fachrichtung **Elektrotechnik**
(`docs/34-fachrichtungen.md`), analog zum Jura-Pruefagenten
(`ops/agents/content/content-pruefagent.md`), aber mit anderem Pruefradius:
Statt Normzitaten geht es um Einheiten, Rechenwege und Fachbegriffe.

1. Das deterministische **Fach-Gate** im Code
   (`backend/app/services/redaktion/fach_gate.py`, eingebunden in
   `pipeline.py` fuer alle Fachrichtungen mit `methodik.norm_gate: false`) -
   kein LLM-Aufruf, laeuft bei jedem Pipeline-Durchlauf.
2. Der Paperclip-Firmenagent `Content-Pruefagent-ET` (reportsTo
   Content-Koordinator-ET), der fertige Entwuerfe nach bestandenem
   Struktur- und Fach-Gate inhaltlich prueft.

## Was das Code-Gate prueft

- `formel`-Karten: `einheiten`-Liste vorhanden, jede Angabe im Format
  `Groesse in Einheit` oder `Groesse [Einheit]`, Gleichung (`=` oder `≈`) auf
  der Rueckseite.
- `norms` in Karten und Pruefpunkten: keine `§`-Zitate (Hinweis auf
  Jura-Modus des Collectors).
- Jede Aufgabe hat `steps` (gefuehrter Loesungsweg) und mindestens einen
  Pruefpunkt mit `keywords`.

## Was der Firmenagent zusaetzlich prueft

- Zahlenwerte jeder Aufgabe nachrechnen (eigene Rechnung, nicht nur
  lesen); Abweichung > 1 % oder falsche Einheit = Fail.
- Vorzeichen- und Zaehlpfeilkonventionen konsistent (z. B. Verbraucher-
  zaehlpfeilsystem, Arbeit zugefuehrt positiv).
- Formeln gegen Standardlehrbuch-Wissen pruefen (Grenzfaelle: ω → 0,
  ε → 1, T_k = T_w); Groessenordnungen plausibel.
- Fachbegriffe und Normbezeichnungen korrekt (DIN EN ISO 6892-1, VDI 2230);
  keine erfundenen Normnummern.
- Pruefpunkt-`keywords` enthalten die Zahl in deutscher Schreibweise
  (`0,69`) und sinnvolle Varianten (`690 mA`), damit die Heuristik trifft.

Ergebnis: Pass/Fail je Datei mit konkreter Begruendung (Karte/Aufgabe,
erwarteter Wert, gefundener Wert) im Aufgabenthread.

## Grenze, explizit benannt

Das Code-Gate prueft Form, nicht Richtigkeit: Eine falsche Formel mit
korrekten Einheiten passiert es. Die fachliche Richtigkeit traegt der
Firmenagent als unabhaengige Instanz neben Collector und Reviewer; bis die
Inhalte `mensch-freigegeben` sind, bleiben sie mit `redaktion.status:
in-pruefung` markiert und werden vom Validator als Warnung gezaehlt.

## Pro Lauf

**Firmenagent:** jede Datei des Batches oeffnen, Pruefliste oben
abarbeiten, Zahlenwerte nachrechnen, Pass/Fail posten. Bei Fail geht der
Batch an den Redakteur zurueck, nicht an den Reviewer.

**Entwickler-Aufgabe (Pflege des Gates):** Regeln in `fach_gate.py`
erweitern, Unit-Test in `backend/tests/test_fachrichtungen.py` ergaenzen,
`python -m pytest tests/test_fachrichtungen.py tests/test_redaktion.py` und
`python scripts/validate_content.py` ausfuehren.

## Rechte-Grenzen

Keine Freigabe- oder Merge-Entscheidung; Pass/Fail ist eine Empfehlung an
Redakteur und Reviewer. Keine Aenderung am Gate zur Laufzeit, kein direkter
Push auf `main`, kein Anlegen neuer Firmenagenten.
