# Content-Pruefagent Lehramt

Pruefinstanz der KI-Redaktion fuer die Fachrichtung **Lehramt**
(`docs/34-fachrichtungen.md`), analog zum Jura-Pruefagenten
(`ops/agents/content/content-pruefagent.md`), aber mit anderem Pruefradius:
Statt Normzitaten geht es um Einheiten, Rechenwege und Fachbegriffe.

1. Das deterministische **Fach-Gate** im Code
   (`backend/app/services/redaktion/fach_gate.py`, eingebunden in
   `pipeline.py` fuer alle Fachrichtungen mit `methodik.norm_gate: false`) -
   kein LLM-Aufruf, laeuft bei jedem Pipeline-Durchlauf.
2. Der Paperclip-Firmenagent `Content-Pruefagent-LA` (reportsTo
   Content-Koordinator-LA), der fertige Entwuerfe nach bestandenem
   Struktur- und Fach-Gate inhaltlich prueft.

## Was das Code-Gate prueft

- Jede Fallvignette hat `steps` (gefuehrte Fallanalyse) und mindestens
  einen Pruefpunkt mit `keywords`.
- Keine Einheiten- oder Paragraphenpruefung: Lehramt zitiert Schulgesetze,
  GG und SGB zu Recht (`methodik.einheiten_gate: false`).

## Was der Firmenagent zusaetzlich prueft

- Theorien korrekt zugeordnet (Autor, Kernaussage); keine erfundenen
  Studien, Effektstaerken oder Jahreszahlen.
- Rechtsgrundlagen im Schulrecht stimmen mit dem amtlichen Text ueberein
  (GG, SGB VII/VIII, BeamtStG, zitierte Urteile existieren) - hier
  uebernimmt der Firmenagent die Rolle des Normzitat-Gates von Hand.
- Fallvignetten sind vollstaendig fiktiv, ohne reale Schulen oder Personen;
  Musterloesungen nennen Landesunterschiede, statt ein Bundesland als
  Bundesrecht auszugeben.
- Pruefpunkt-`keywords` enthalten Fachbegriffe mit Umlaut- und
  ASCII-Variante (`Verstärkung`, `Verstaerkung`).

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
