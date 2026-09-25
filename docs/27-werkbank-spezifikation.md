# Werkbank: Spezifikation KI-generierter Lernwerkzeuge (SUB-259, neu gefasst durch SUB-308)

> **Auftrag** ([SUB-259](/SUB/issues/SUB-259), Kind-Ticket zu
> [SUB-254](/SUB/issues/SUB-254)): Spezifikation des in
> `docs/31-projektreview-sub254.md` Abschnitt 5 bewerteten Features. Ein
> Nutzer beschreibt ein Lernwerkzeug in eigenen Worten, ein Modell generiert
> dafür **echten, ausführbaren Code**, das Werkzeug steht dem Nutzer sofort
> und **unübersehbar als Vorschlag gekennzeichnet** zur Verfügung, und
> derselbe Vorschlag geht als Rückmeldung an dieses Board, wo über den festen
> Einbau entschieden wird.
>
> **Neufassung durch [SUB-308](/SUB/issues/SUB-308):** Die Vorversion dieses
> Dokuments (Stand SUB-259) hatte die Reichweite auf die Komposition aus 7
> festen Bausteinen verengt — „kein frei programmierbares Programm und keine
> KI-Codegenerierung". Der Auftraggeber hat diese Verengung in Interaktion
> `8559c558-09b5-476d-979d-f5e36204559d` auf SUB-254 (beantwortet
> 2026-09-25, `human_only`, die angebotene Bestätigungsoption „Ja, Lernwerkzeug
> in der App ist die richtige Reichweite" wurde **nicht** gewählt)
> ausdrücklich zurückgewiesen: *„Es geht genau um eine KI Codegenerierung. Der
> kunde soll es klar als vorschlag gekennzeichnet bekommen."* Diese Fassung
> ersetzt die Abschnitte 1–4, 6–8 der Vorversion vollständig. Abschnitt 5
> (Rückkanal-Architektur) ist **unverändert** und bewusst nicht Gegenstand
> dieser Neufassung — die dortige Detailkorrektur läuft separat als SUB-307.
>
> **Einordnung (nicht Gegenstand dieses Dokuments, siehe `docs/31` Abschnitt
> 5.4):** nicht v1.0, frühestens v1.1, hinter demselben AVV-Gate wie die
> KI-Korrektur (`docs/17-release-readiness.md` Abschnitt 1,
> `docs/23-llm-provider-avv.md`). v1.0 läuft mit `llm_provider=none`
> (`docs/18-release-2-wochen.md` Abschnitt 2).
>
> **Leitplanke dieser Neufassung:** Die KI generiert echten, ausführbaren
> Code. Damit das nicht beliebige Codeausführung mit App- oder
> Backend-Rechten bedeutet, läuft dieser Code ausschließlich in einer Sandbox
> ohne jede Capability (Abschnitt 1) — das ist eine vom Host erzwungene
> Eigenschaft der Ausführungsumgebung, keine Anweisung an das Modell.

---

## 1. Ausführungsmodell (Sicherheit)

### 1.1 Entscheidung

**Variante (b)** aus der Bewertung in 1.2: Das Modell generiert echten Code
für eine **reine Funktion** `execute(input) -> output`. Ausführung geschieht
ausschließlich im Flutter-Client, in einer Sandbox mit einer **leeren**
Capability-Liste: kein Netzwerk, keine Datei, kein Platform-Channel, kein
Zugriff auf Session/Token/Secure-Storage, kein Zugriff auf andere
App-Services. Die einzige Schnittstelle zur Außenwelt ist ein einzelnes
JSON-Argument, das der Host vor dem Aufruf befüllt, und ein einzelner
JSON-Rückgabewert, den der Host gegen den `output_contract` (Abschnitt 3.1)
validiert, bevor er ihn über **hosteigene** UI-Komponenten rendert — nie als
HTML/DOM-Injektion, nie als roher Widget-Baum aus generiertem Code.

Konkrete Runtime:

- **Mobile/Desktop:** ein eingebetteter QuickJS-Interpreter (z. B. über das
  `flutter_js`-Paket oder eine direkte QuickJS-FFI-Bindung), pro Ausführung
  neu instanziiert und danach verworfen — kein Zustand überlebt einen Aufruf.
- **Web:** Flutter Web läuft im Browser; dort läuft der generierte Code in
  einem eigenen, same-origin `<iframe sandbox="allow-scripts">` **ohne**
  `allow-same-origin` — das Iframe hat keinen Zugriff auf Cookies,
  `localStorage` oder das DOM der Host-Seite. Kommunikation ausschließlich
  über `postMessage` mit demselben JSON-Vertrag wie auf Mobile/Desktop.
- Aktuell ist im Repository keine JS-/WebView-Engine eingebunden
  (`app/pubspec.yaml` vermerkt für G2 explizit „kein In-App-WebView nötig");
  die Integration ist Ticket 5 (Abschnitt 7), nicht Gegenstand dieser
  Spezifikation.

Ressourcengrenzen, vom Host erzwungen, nicht vom generierten Code:

- Wall-Clock-Timeout **300 ms** je Aufruf; überschritten → Interpreter/Iframe
  wird hart beendet.
- Interpreter-Schrittzähler als Rückfallgrenze gegen Endlosschleifen, die
  innerhalb von 300 ms viele kurze Yield-Punkte erzeugen.
- Speicherobergrenze der Engine-Instanz (QuickJS-Konfigurationsparameter bzw.
  das Prozesslimit des Browsers für das Iframe).
- Ausgabegröße begrenzt auf `resource_limits.max_output_bytes` (Abschnitt
  3.1).
- Grenze überschritten → Stufe D im Fehlerpfad (Abschnitt 4.3), Werkzeug wird
  **nicht** erzeugt, feste Nutzermeldung.

### 1.2 Bewertete Varianten

| Variante | Kern | Bewertung |
|---|---|---|
| (a) Deklarativ generiert, festes Interpreter-Gerippe führt aus | Modell erzeugt nur Daten/Konfiguration, keinen Code | **Verworfen.** Das ist strukturell die vom Auftraggeber zurückgewiesene enge Variante (Vorversion) — Ausdrucksstärke reicht nicht für „Es geht genau um eine KI Codegenerierung." |
| (b) Echter generierter Code in einer Sandbox ohne Capabilities | siehe 1.1 | **Gewählt.** Erfüllt den Auftrag wörtlich; das Risiko wird durch das Fehlen von Capabilities begrenzt, nicht durch Vertrauen in den generierten Code. Kosten: nichttriviale Sandbox-Integration auf der Flutter-Seite (Ticket 5); Ausdrucksstärke bleibt an den Eingabe-/Ausgabevertrag gebunden (Abschnitt 1.3, 3.1) |
| (c) Generiert, aber erst nach menschlicher Prüfung lauffähig | Board/Mensch schaltet frei, bevor der Nutzer es nutzen kann | **Verworfen als alleiniges Modell.** Widerspricht der in SUB-254 verlangten sofortigen Verfügbarkeit für den Kunden. Die vorgesehene menschliche Prüfung bleibt bestehen — aber als **Rückkanal-Entscheidung über den dauerhaften Einbau** (Abschnitt 5, unverändert), nicht als Voraussetzung fürs erste Ausführen. Die „Vorschlag"-Kennzeichnung (Abschnitt 3.2) übernimmt die Erwartungssteuerung, die (c) sonst über Verzögerung erreicht hätte |
| (zur Einordnung, nicht ernsthaft erwogen) Nativer Code / voller Plattformzugriff | — | Das wäre beliebige Codeausführung mit App-Rechten — exakt das im Auftrag benannte Risiko |

### 1.3 Eingabekontrakt bleibt beschränkt — auch wenn der Code es nicht mehr ist

Die Vorversion verhinderte RDG-Verstöße dadurch, dass jeder der 7 Bausteine
*strukturell* nur Stil, nie Inhalt bewerten konnte. Bei echter
Codegenerierung trägt dieses Argument nicht mehr — generierter Code kann
grundsätzlich beliebige Logik über seine Eingabe ausführen. Die Linie
verschiebt sich deshalb auf die **Eingabe**: Der Host reicht dem generierten
Code ausschließlich strukturierte Referenzen (bestehende Content-IDs, Enums,
Zahlen, den eigenen SRS-/Planungsstand des Nutzers) — **niemals** ein
Freitextfeld, über das ein realer Sachverhalt hineingelangen könnte
(Eingabekontrakt in Abschnitt 3.1, RDG-Einordnung in Abschnitt 2). Diese
Beschränkung entscheidet der Host beim Befüllen des Eingabeobjekts, nicht das
Modell beim Schreiben des Codes — sie gilt deshalb unabhängig davon, ob sich
das Modell an eine Anweisung hält.

---

## 2. RDG-Grenze bei generierter Logik

`docs/06-recht-compliance.md` Abschnitt 2 zieht die Grenze über die
**Eingabe**: „Freitext-Bewertung ist immer an eine `case_id` mit hinterlegtem
Erwartungshorizont gebunden — es gibt keinen Endpunkt ‚bewerte diesen
beliebigen Sachverhalt'." Das gilt für die Werkbank unverändert, jetzt aber
ohne die strukturelle Rückendeckung der festen Bausteine (Abschnitt 1.3).

### 2.1 Zulässige vs. unzulässige generierte Werkzeugarten

- **Zulässig:** Werkzeuge, deren Eingabe ausschließlich aus Referenzen auf
  bestehenden Lern-/Übungscontent (Card-, Case-, Schema-IDs, `Area`/`Topic`,
  Zahlenparameter) oder auf den eigenen, bereits gespeicherten Lernstand des
  Nutzers (SRS-Zustand, Planungsdaten) besteht — inhaltlich dieselbe Grenze
  wie die 7 Bausteine der Vorversion, jetzt als Eingabe-*Vertrag*
  (Abschnitt 3.1) statt als feste Bausteinliste.
- **Unzulässig:** jedes Werkzeug, dessen Beschreibung oder Eingabe einen
  **eigenen, realen, noch nicht in der Fall-Datenbank hinterlegten
  Sachverhalt** des Nutzers voraussetzt (das Vermieterkündigungs-Beispiel aus
  `docs/31` Abschnitt 5.1) — unabhängig davon, wie das Werkzeug diesen
  Sachverhalt anschließend verarbeiten würde.
- Die Trennlinie verläuft dabei eine Stufe früher als im bestehenden Produkt:
  `struktur_check` durfte Freitext annehmen, weil seine *Ausgabe* strukturell
  nie eine Rechtsfolge behaupten konnte (Abschnitt 1.1 der Vorversion). Bei
  generiertem Code lässt sich das nicht mehr über die Ausgabe absichern —
  deshalb entscheidet jetzt die Eingabe.

### 2.2 Durchsetzungspunkt

Zwei voneinander unabhängige Ebenen, nicht eine:

1. **Intent-Check** (Abschnitt 4.1): erkennt am Beschreibungstext, ob ein
   realer Sachverhalt zur Bewertung angeboten wird, und lehnt vor jedem
   Generierungsaufruf ab.
2. **Eingabekontrakt-Durchsetzung** (Abschnitt 1.3, 3.1): selbst wenn Stufe 1
   einen Fall übersieht (Modellfehler, geschickte Umschreibung), kann der
   generierte Code strukturell keinen realen Sachverhalt entgegennehmen, weil
   der Host niemals ein Freitextfeld für „eigener Fall" in das Eingabeobjekt
   einspeist. Diese Ebene gilt unabhängig vom Modellverhalten.

### 2.3 Verhältnis zur „Vorschlag"-Kennzeichnung

Die Kennzeichnung aus Abschnitt 3.2 **ergänzt** die Abgrenzung, **ersetzt**
sie nicht: Sie steuert die Erwartung des Nutzers (kein geprüftes
Subsumo-Feature), verhindert aber für sich genommen nicht, dass ein Werkzeug
faktisch eine Rechtsdienstleistung erbringt. Beide Mechanismen gelten
parallel — 2.1/2.2 entscheiden, *ob* ein Werkzeug entstehen darf, Abschnitt
3.2 entscheidet, *wie* es dem Nutzer gegenübertritt.

### 2.4 Offene Anwaltsfrage

Ob ein Werkzeug, dessen Eingabe strikt auf zulässige Referenzen (2.1)
beschränkt ist, dessen vom Modell frei entworfene **Logik** aber neue, im
referenzierten Content nicht hinterlegte rechtliche Schlussfolgerungen
synthetisiert (Beispiel: ein generiertes Werkzeug, das aus einer
`Case`-Referenz eine eigene Lösung „berechnet", statt nur vorhandene
`Card`-/`Schema`-Inhalte anzuzeigen), noch innerhalb der Lernhilfe-Grenze aus
`docs/06` Abschnitt 2 liegt oder eine zusätzliche Laufzeitprüfung braucht.
Eingetragen in `docs/17-release-readiness.md` Abschnitt 1.

---

## 3. Tool-Artefakt: JSON-Schema und „Als Vorschlag gekennzeichnet"

### 3.1 JSON-Schema-Entwurf: Tool-Spec v2

Analog zum bestehenden Validierungsprinzip aus
`backend/scripts/validate_content.py` / `app/services/content.py`: **was
nicht im Schema steht, existiert nicht.** `additionalProperties: false` auf
jeder Ebene. `input_field.source` ist bewusst eine geschlossene Enum-Liste
**ohne** einen Freitext-/„eigener Sachverhalt"-Wert — das ist die
Schema-gewordene Fassung von Abschnitt 1.3/2.1.

```json
{
  "$id": "subsumo.werkbank.tool_spec.v2",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema", "tool_id", "title", "area_scope", "input_contract",
    "output_contract", "code", "runtime", "resource_limits",
    "labeling", "created_at", "prompt_fingerprint"
  ],
  "properties": {
    "schema": { "const": "subsumo.werkbank.tool_spec.v2" },
    "tool_id": { "type": "string", "format": "uuid" },
    "title": { "type": "string", "minLength": 1, "maxLength": 80 },
    "description": { "type": "string", "maxLength": 280 },
    "area_scope": {
      "type": "string",
      "enum": ["zivilrecht", "strafrecht", "oeffentliches-recht", "alle"]
    },
    "input_contract": {
      "type": "object",
      "additionalProperties": false,
      "required": ["fields"],
      "properties": {
        "fields": {
          "type": "array",
          "maxItems": 10,
          "items": { "$ref": "#/$defs/input_field" }
        }
      }
    },
    "output_contract": {
      "type": "object",
      "additionalProperties": false,
      "required": ["render_as", "fields"],
      "properties": {
        "render_as": {
          "type": "string",
          "enum": ["list", "checklist", "text_block", "counter", "tabs"]
        },
        "fields": {
          "type": "array",
          "maxItems": 10,
          "items": { "$ref": "#/$defs/output_field" }
        }
      }
    },
    "code": {
      "type": "object",
      "additionalProperties": false,
      "required": ["language", "source", "source_sha256"],
      "properties": {
        "language": { "const": "javascript_es2020" },
        "source": { "type": "string", "maxLength": 20000 },
        "source_sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" }
      }
    },
    "runtime": {
      "type": "string",
      "enum": ["quickjs_sandboxed_v1", "web_iframe_sandboxed_v1"]
    },
    "resource_limits": {
      "type": "object",
      "additionalProperties": false,
      "required": ["timeout_ms", "max_output_bytes"],
      "properties": {
        "timeout_ms": { "const": 300 },
        "max_output_bytes": { "const": 8192 }
      }
    },
    "labeling": {
      "type": "object",
      "additionalProperties": false,
      "required": ["is_suggestion", "badge_text"],
      "properties": {
        "is_suggestion": { "const": true },
        "badge_text": { "const": "KI-Vorschlag · ungeprüft" }
      }
    },
    "created_at": { "type": "string", "format": "date-time" },
    "prompt_fingerprint": { "type": "string", "maxLength": 64 }
  },
  "$defs": {
    "input_field": {
      "type": "object",
      "additionalProperties": false,
      "required": ["name", "source"],
      "properties": {
        "name": { "type": "string", "maxLength": 40 },
        "source": {
          "type": "string",
          "enum": [
            "topic_slug_ref", "case_slug_ref", "schema_slug_ref",
            "card_type_enum", "difficulty_int", "count_int",
            "own_srs_state", "own_plan_state"
          ]
        }
      }
    },
    "output_field": {
      "type": "object",
      "additionalProperties": false,
      "required": ["name", "type"],
      "properties": {
        "name": { "type": "string", "maxLength": 40 },
        "type": { "type": "string", "enum": ["string", "number", "boolean", "string_array"] }
      }
    }
  }
}
```

`tool_id` wird serverseitig vergeben, nicht vom Modell — verhindert
Kollisionen und macht die Zuordnung zu `created_by_user_id` (DB-seitig, nicht
im Spec selbst, siehe Abschnitt 6) eindeutig. `code.source_sha256` erlaubt dem
Rückkanal (Abschnitt 5, unverändert), den generierten Code eindeutig zu
referenzieren, ohne ihn zwingend vollständig zu übertragen. `labeling` ist
bewusst Teil des persistierten Artefakts, nicht ein clientseitiges Flag (siehe
3.2).

### 3.2 Kennzeichnung zum Kunden

- Jedes generierte Werkzeug trägt eine **dauerhafte, nicht schließbare**
  Kennzeichnung im eigenen Kopfbereich mit dem Text aus `labeling.badge_text`
  (Abschnitt 3.1) — analog zur bestehenden Praxis, KI-Bewertungen im Produkt
  als Lernhilfe zu kennzeichnen (`docs/06` Abschnitt 2).
- Die Kennzeichnung ist Teil des persistierten Tool-Spec, nicht ein
  clientseitiger Zustand — sie überlebt App-Neustart und jeden erneuten
  Aufruf desselben Werkzeugs, weil `is_suggestion`/`badge_text` bei jeder
  Anzeige aus demselben gespeicherten Artefakt gelesen werden.
- Geteilte Ansichten existieren im Produkt aktuell nicht (kein
  Share-Mechanismus im Repository); falls künftig eingeführt, gilt dieselbe
  Kennzeichnungspflicht unverändert für jede Ansicht, in der das Werkzeug
  erscheint.
- Exakter Wortlaut ist bereits im Schema festgelegt (`badge_text` als
  `const`); Platzierung (Screen-Header vs. Badge-Widget) ist
  Entwurfsentscheidung des UI-Developers (Ticket 4b, Abschnitt 7).

### 3.3 Kennzeichnung zum Auftraggeber

Unverändert aus der Vorversion — der Vorschlag läuft über den Rückkanal
(Abschnitt 5, hier nicht angefasst) an dieses Board, wo über den festen
Einbau entschieden wird (SUB-254 wörtlich: „Die Idee soll dann hierher an
einen Agenten rückgekoppelt werden und dann kann ich entscheiden, ob es fest
verbaut wird."). Der Proposal-Payload aus Abschnitt 5.2 muss dafür jetzt
`code.source_sha256` und einen Code-Auszug statt nur eine Bausteinstruktur
transportieren (Ticket 7, Abschnitt 7) — die Zustellmechanik selbst ändert
sich nicht.

---

## 4. Promptvertrag und Validierungs-/Fehlerpfad

**Zwei Modellaufrufe, nicht einer** — das hält die RDG-Grenze auch bei einem
Modellfehler strukturell, nicht nur durch eine Anweisung.

### 4.1 Stufe 1 — Intent-Check (vor jedem Generierungsaufruf)

- Eingabe: die Nutzerbeschreibung, ohne weiteren Kontext.
- Aufgabe: klassifizieren, ob die Beschreibung ein **Lernwerkzeug innerhalb
  des Eingabekontrakts** (Abschnitt 2.1, 3.1) beschreibt, oder ob sie die
  Bewertung eines **realen, konkreten Sachverhalts** verlangt (das
  Vermieterkündigungs-Beispiel aus `docs/31` Abschnitt 5.1).
- Ausgabe: `{"allow": bool, "reason": string}` — festes, kleines Schema, kein
  Freitext im Erfolgsfall.
- Bei `allow=false`: kein Generierungsaufruf, keine Kosten für Stufe 2, feste
  Nutzermeldung (Stufe A unten).
- Diese Stufe ist **zusätzlich** zur Eingabekontrakt-Durchsetzung aus
  Abschnitt 1.3/2.2 — sie fängt Fälle ab, in denen der Nutzer versucht, über
  die Werkzeug-*Beschreibung* selbst (nicht über einen Eingabeparameter) eine
  Rechtsdienstleistung zu erschleichen.

### 4.2 Stufe 2 — Generierungsaufruf (nur bei `allow=true`)

- Systemprompt enthält: die zulässigen `input_field.source`-Werte (Abschnitt
  3.1) mit Kurzbeschreibung, die Sicherheitsgrenzen der Sandbox (leere
  Capability-Liste, 300-ms-Budget, Abschnitt 1.1) als feste Vorgabe an den
  generierten Code, 2–3 versionierte Few-Shot-Beispiele bereits gültiger
  Tool-Specs (inkl. `code.source`), sowie eine vom Server vorab geladene,
  begrenzte Liste gültiger Slug-Werte für das vom Nutzer genannte
  Rechtsgebiet (nicht der gesamte Content-Bestand — Kontextgröße und
  Halluzinationsfläche bleiben klein).
- Der Systemprompt ist **versioniert**; `prompt_fingerprint` im Tool-Spec ist
  ein Hash dieser Version — dasselbe Prinzip wie das `schema`-Feld in
  `backend/mission_control/messages.py` (`subsumo.message.v1`).
- Ausgabe: **ausschließlich** ein JSON-Objekt nach Abschnitt 3.1, erzwungen
  über Tool-Calling/Structured-Output des Modells, nicht über
  Prompt-Disziplin allein.
- Das Modell erzeugt **keine** neuen Slug-Werte — nur Referenzen auf die im
  Kontext übergebene Liste, und **keine** neuen `input_field.source`-Werte
  außerhalb der Enum aus Abschnitt 3.1.

### 4.3 Validierungsstufen A–E

Fünf unabhängige Prüfstufen (zwei mehr als in der Vorversion, weil
generierter Code mehr Fehlerklassen hat als eine reine
Bausteinkomposition), jede mit definiertem Fehlerverhalten — keine stille
Reparatur, kein „wahrscheinlich richtig":

| Stufe | Prüfung | Bei Fehlschlag |
|---|---|---|
| A | Intent-Check (4.1) | Feste Nutzermeldung „Beschreibt bitte ein Lernwerkzeug, keine Bewertung eines echten Falls." Kein weiterer Aufruf, kein Tool-Spec, kein Eintrag im Rückkanal. |
| B | JSON-Schema-Validierung des Tool-Spec (3.1), serverseitig, nach demselben Muster wie `load_content()`/`validate_content.py` | Gebundener Reparatur-Retry (siehe unten). |
| C | Statische Prüfung von `code.source`: valides JavaScript, keine verbotenen Konstrukte (`eval`, dynamischer `import`, `Function`-Konstruktor) als zusätzliche Verteidigungsebene, obwohl die Sandbox dafür ohnehin keine Capabilities bereitstellt | Gebundener Reparatur-Retry. |
| D | Sandbox-Probelauf mit synthetischen, aus `input_contract` abgeleiteten Testeingaben, innerhalb des Timeout-/Speicherbudgets aus Abschnitt 1.1: `execute()` wirft nicht, Ausgabe entspricht `output_contract`, Budget nicht überschritten | Gebundener Reparatur-Retry. |
| E | Slug-Re-Auflösung: jede referenzierte Slug-Ressource wird bei **jedem tatsächlichen Aufruf** (nicht nur bei Erstellung) erneut gegen die aktuelle DB/Content-Basis geprüft | Slug ungültig → feste Nutzermeldung „Aktuell nicht verfügbar". Slug gültig, aber Ergebnismenge leer (z. B. Topic ohne fällige Karten) → Tool wird **trotzdem ausgeführt**, aber sichtbar als „aktuell leer" markiert, nicht verschwiegen. |

**Reparatur-Retry (B/C/D):** Validierungs-/Compile-/Laufzeitfehler wird dem
Modell als Kontext zurückgegeben, maximal **zwei** weitere
Generierungsaufrufe (mehr als der eine Retry der Vorversion, weil
Codefehler — Syntax, Laufzeitfehler im Probelauf — erfahrungsgemäß mehr
Versuche brauchen als eine reine Schema-Verletzung). Schlagen auch diese
fehl → feste Nutzermeldung „Konnte mit den vorhandenen Möglichkeiten nicht
umgesetzt werden.", kein Tool-Spec, kein Eintrag im Rückkanal. Fehlgeschlagene
Versuche zählen nicht gegen das Erstellungs-Kontingent, aber gegen ein
separates Versuchslimit (Abschnitt 6.2).

---

## 5. Rückkanal-Architektur

### 5.1 Ausgangslage

`backend/mission_control/` (`client.py`, `outbox.py`, `verification.py`,
`messages.py`) ist für den **Agentenbetrieb** gebaut: `PaperclipClient`
erwartet `PAPERCLIP_AGENT_ID`/`PAPERCLIP_RUN_ID` für Mutationen
(`client.py` — *„PAPERCLIP_RUN_ID is required for mutations when
PAPERCLIP_AGENT_ID is set"*), `messages.py` bindet jede Nachricht an
Sender-/Empfänger-Agenten-IDs und einen Lauf. `ops/mission-control/README.md`
hält ausdrücklich fest: die heutige Instanz ist **Pilot**, lokal, nicht
nutzerseitig betrieben. Das Produkt-Backend ist kein Agent mit eigener
`PAPERCLIP_RUN_ID` — es braucht einen eigenen Weg.

### 5.2 Vorgeschlagener Weg

1. **Neue, schmale Backend-Komponente** (kein Import von
   `backend/mission_control/`, das Modul bleibt agentenspezifisch): ein
   Service-Client, der ausschließlich
   `POST /api/issues/{festes-Zielticket}/comments` (oder wahlweise
   `POST /api/companies/{id}/issues` mit fixem `parentId`, je nach
   Board-seitiger Präferenz) aufruft — dieselbe HTTP-Schicht, aber ohne
   Agenten-/Lauf-Bindung.
2. **Payload-Umschlag**, versioniert wie `messages.py`
   (`schema: "subsumo.werkbank.proposal.v1"`), enthält: `tool_spec` (Abschnitt
   2, ohne Nutzer-Freitext-Titel/-Beschreibung, falls die als
   personenbeziehbar gelten könnten — im Zweifel pseudonymisieren, dieselbe
   Regel wie beim LLM-Prompt selbst, `docs/06` Abschnitt 3), einen
   Nutzungszähler (wie oft Nutzer dieses komponierte Tool seit Erstellung
   genutzt haben, aggregiert über alle Nutzer mit strukturell identischem
   Tool-Spec — **kein** Nutzerbezug im Zähler), und `prompt_fingerprint`.
3. **Zustellung nach dem Outbox-Prinzip**, konzeptionell wie
   `outbox.py`, aber auf einer Produkt-DB-Tabelle statt einer lokalen JSONL-
   Datei (Mehrprozess-Backend, kein gemeinsames Dateisystem garantiert):
   Zustände `pending → confirmed | unknown | failed`, „Netzwerkfehler sind
   mehrdeutig, kein automatischer Retry" — dieselbe Regel wie im Original.
4. **Auslösezeitpunkt:** nicht bei jeder Werkzeug-Erstellung einzeln, sondern
   gebündelt (z. B. täglich, oder ab einer Nutzungsschwelle je Tool) — verhindert,
   dass jeder erste Prototyp-Versuch eines Nutzers das Board flutet, und passt
   zum Auftrag „die *Idee*, nicht jede Erstellung, soll rückgekoppelt werden".

### 5.3 Authentisierung Backend → Board — technisch geklärt (SUB-307), jetzt eine Risikoentscheidung

Geprüft gegen `GET /api/openapi.json` (529 Pfade) und live mit einem
Agent-Token: Ein Board-API-Key (`POST /api/board-api-keys`) kennt **keinen
Scope**. Der Request-Body nimmt ausschließlich `name`, `expiresAt`,
`requestedCompanyId` — kein `scope`/`permission`/`issueId`/`readOnly`/`role`.
Laut `x-paperclip-authorization` ist ein Board-API-Key ein Aktor der Klasse
`board`, also derselbe, company-weite Aktortyp wie eine menschliche
Board-Session — **breiter** als ein Agent-Token, nicht schmaler. Außerdem
akzeptieren `GET`/`POST /api/board-api-keys` nur `BoardSessionAuth`/
`BoardApiKeyAuth`; ein Agent kann so einen Key weder anlegen noch lesen (live
verifiziert: Agent-Token auf `GET /api/board-api-keys` → `401 {"error":"Board
authentication required"}`). Die im ursprünglichen Entwurf genannte
„schmalste Lösung" — ein Company-Key mit Schreibrecht nur auf Kommentare
eines einzelnen Zielissues — **existiert in der Paperclip-API nicht**.

Real verfügbar sind drei Varianten:

- **(a) Board-API-Key mit kurzem `expiresAt`, akzeptierter Blast-Radius.**
  Einfachste Umsetzung. Kompromittierung des Produkt-Backends bedeutet vollen
  Board-Schreibzugriff auf die ganze Company, nicht nur einen Issue-Thread —
  einzige eingebaute Eindämmung ist die Ablauffrist.
- **(b) Laufgebundener Low-Privilege-Agent.** `POST /api/issues/{id}/comments`
  akzeptiert `AgentBearerAuth`, ein dedizierter „Werkbank-Eingang"-Agent
  könnte also grundsätzlich schreiben. Aber Agent-Mutationen sind
  laufgebunden: `backend/mission_control/client.py` wirft
  `ValueError("PAPERCLIP_RUN_ID is required for mutations when
  PAPERCLIP_AGENT_ID is set")`, und `X-Paperclip-Run-Id` ist auf dem
  Comments-Endpunkt kein deklarierter Parameter — die Durchsetzung ist
  serverseitig an einen echten Agentenlauf gebunden, den ein
  Produkt-Backend-Request nicht hat. Ein synthetischer `run_id`-Ersatz ist in
  der Spec nirgends dokumentiert; diese Variante braucht also entweder eine
  Plattformänderung oder einen Trigger, der einen echten Lauf auslöst (siehe
  (c)).
- **(c) Kein automatischer Rückkanal vom Produkt-Backend — Zustellung über
  einen bestehenden Agentenlauf.** Das Produkt-Backend hält **gar kein
  Board-Secret**. Statt selbst gegen Paperclip zu mutieren, schreibt es
  Vorschläge in eine eigene Warteschlange (Produkt-DB-Tabelle oder Datei,
  konzeptionell wie `backend/mission_control/outbox.py`, ohne dass das
  Backend `backend/mission_control/` importiert). Ein ohnehin laufender,
  bestehender Agent — z. B. über eine selbst zugewiesene Routine — holt die
  Warteschlange in seinem eigenen Lauf ab und stellt die Vorschläge per
  eigenem `PaperclipClient` als Kommentar zu. Erfüllt den Auftrag aus SUB-254
  unverändert und gibt dem Produkt-Backend keinerlei Board-Zugriff. Nachteil:
  Zustellung folgt dem Takt der abholenden Routine statt Echtzeit — deckt
  sich aber mit der ohnehin gebündelten, nicht sofortigen Zustellung aus
  Abschnitt 5.2 Punkt 4, also kein zusätzlicher Kompromiss.

Von den dreien ist **(c)** die einzige Variante, die dem Produkt-Backend kein
Board-Secret gibt, und sie ist mit dem Rückkanal-Entwurf aus Abschnitt 5.2
kompatibel. Die Wahl zwischen (a)/(b)/(c) ist aber eine
**Risikoentscheidung** des Board-/Paperclip-Betreibers, keine offene
technische Frage mehr — siehe Ticket 7 (Abschnitt 7) und Abschnitt 8 Punkt 2.

---

## 6. Kontingent- und Kostenmodell

### 6.1 Kosten je Erstellung

Nach der Rechenmethode aus `docs/19-kosten-preis-budget.md` Abschnitt 5
(Sonnet-Listenpreise 3 $/Mio Eingabe, 15 $/Mio Ausgabe). Codegenerierung
braucht einen deutlich größeren Systemprompt (Sandbox-API-Referenz,
Sicherheits-/Eingabekontrakt-Vorgaben, Few-Shot-Beispiele mit Code) und
erzeugt eine deutlich größere Ausgabe (JavaScript-Quelltext statt eines
kleinen Struktur-JSON):

| Aufruf | Eingabe (Token) | Ausgabe (Token) | Kosten |
|---|---|---|---|
| Intent-Check (4.1) | ≈ 150 (nur Nutzertext) | ≈ 20 (`allow`/`reason`) | ≈ 0,0005 $ |
| Generierungsaufruf (4.2) | ≈ 6.000–9.000 (Systemprompt + Sandbox-/Sicherheitsvorgaben + Few-Shot-Beispiele + Slug-Katalog) | ≈ 800–1.500 (Tool-Spec-JSON inkl. `code.source`, geschätzt 40–80 Zeilen JS) | ≈ 0,03–0,05 € |
| **Summe pro Erstellung (kein Retry)** | | | **≈ 0,03–0,05 €** |

Mit den bis zu **zwei** gebundenen Reparatur-Retries aus Abschnitt 4.3 im
ungünstigsten Fall **verdreifacht**: ≈ **0,09–0,14 €/Erstellung**. Das ist im
Regelfall 2–3× teurer als die 0,01–0,02 €/Erstellung der reinen
Bausteinkomposition (Vorversion), im Reparatur-Fall bis zu einer
Größenordnung teurer als deren typischer Fall — die im Auftrag angekündigte
Kostensteigerung durch „lange Ausgaben, Retries, ggf. Reparaturschleifen"
bestätigt sich damit. Wie bei der KI-Korrektur (`docs/19` Abschnitt 5):
**vorläufige Rechnung, vor Preisfestsetzung an echten Erstellungen zu
messen.**

### 6.2 Kontingent

Nach demselben Muster wie `app/services/limits.py` (`upgrade_required`-Fehlerform,
Zählung tatsächlich erfolgter Aktionen statt Client-Parameter):

- **Free:** 1 Werkzeug-Erstellung pro Kalendermonat (Kennenlern-Kontingent,
  unverändert aus der Vorversion — der Absolutbetrag bleibt klein, auch im
  Reparatur-Fall).
- **Pro:** 5 Erstellungen pro Kalendermonat, danach **gedrosselt statt
  abgerechnet** — dieselbe Formulierung wie in `docs/19` Abschnitt 5 für die
  KI-Korrektur.
- **Neu, wegen der breiteren Kostenstreuung aus 6.1:** ein von der
  Erstellungs-Zählung **unabhängiges** Versuchslimit (Platzhalter: 10
  Versuche/Tag, erfolgreiche und endgültig gescheiterte zusammen). Ohne diese
  Grenze könnte ein Nutzer durch absichtlich fehlschlagende Beschreibungen
  wiederholt die teureren Reparaturschleifen aus Abschnitt 4.3 auslösen, ohne
  je gegen das Erstellungs-Kontingent zu zählen.
- Gezählt werden für das **Erstellungs**-Kontingent weiterhin nur
  **persistierte** Tool-Erstellungen (analog `due_cards_quota_remaining`) —
  ein abgelehnter Intent-Check oder ein endgültig fehlgeschlagener
  Generierungsversuch (Abschnitt 4.3) zählt dagegen nur gegen das neue
  Versuchslimit, nicht gegen das Erstellungs-Kontingent.
- **Nach der Erstellung: null weitere Modellnutzung.** Ausführung geschieht
  ausschließlich lokal in der Sandbox (Abschnitt 1) — direkte Folge daraus,
  dass kein Aufruf zur Laufzeit einen Modellaufruf braucht.
- Konkrete Zahlen sind **Platzhalter**, wie in `docs/19` Abschnitt 5 verlangt
  vor Preisfestsetzung zu messen — kein Freigabegegenstand dieses Dokuments.

---

## 7. Zerlegung in Tickets (v1.1, nach AVV — keine Ausführung vor Freigabe)

| # | Ticket | Rolle | Abhängigkeit |
|---|---|---|---|
| 1 | Slug-Katalog-Endpunkt: serverseitig versionierte, auf das vom Nutzer genannte Rechtsgebiet begrenzte Liste gültiger `topic_slug`/`schema_slug`-Werte für den Generierungs-Kontext (Abschnitt 4.2) — dient dem Systemprompt der Stufe 2, nicht dem statischen `input_field.source`-Enum aus Abschnitt 3.1, der bereits vollständig im JSON-Schema (Ticket 2) steht und keinen eigenen Endpunkt braucht | Backend-Developer | Voraussetzung für 3 |
| 2 | JSON-Schema + Validator für Tool-Spec v2 (Abschnitt 3.1, inkl. `code`, `input_contract`, `output_contract`, `labeling`), nach dem Muster von `app/services/content.py` — ersetzt den Tool-Spec-Validator der Vorversion | Backend-Developer | keine |
| 3 | Intent-Check + Promptvertrag + Generierungsaufruf mit gebundener Reparaturschleife (Abschnitt 4) | Backend-Developer | 1, 2, AVV/`llm_provider` |
| 4a | Fehlerpfad-UI für die Fehlerklassen A–E aus Abschnitt 4.3 | Frontend-Developer | 3 |
| 4b | Vorschlags-Kennzeichnung: dauerhaftes, nicht schließbares Badge (Abschnitt 3.2) auf jedem generierten Werkzeug | UI-Developer | 5 |
| 5 | Sandbox-Runtime im Flutter-Client: QuickJS-Einbindung (Mobile/Desktop) und sandboxed Iframe (Web), leere Capability-Liste, Timeout-/Speicherdurchsetzung (Abschnitt 1.1) — ersetzt den Bausteinaufruf-Interpreter der Vorversion | Frontend-Developer | 2 |
| 6 | Kontingent + separates Versuchslimit, Erweiterung von `limits.py` nach demselben Muster (Abschnitt 6.2) | Backend-Developer | keine |
| 7 | Rückkanal: Proposal-Tabelle, Outbox-Zustellung. **Voraussetzung: Risikoentscheidung des Board-/Paperclip-Betreibers zwischen Variante (a)/(b)/(c) aus Abschnitt 5.3 muss vor Implementierung vorliegen** — keine der drei baut auf die dort ursprünglich angenommene, nicht existierende scope-enge Option. Payload muss jetzt `code.source_sha256` und einen Code-Auszug statt nur eine Bausteinstruktur transportieren (Abschnitt 3.3) | Backend-Developer + Rückfrage | keine, aber blockiert auf die Risikoentscheidung Abschnitt 5.3 |
| 8 | Board-seitige Annahme/Ablehnung eines Vorschlags (fester Einbau ja/nein) — Interaktionsform mit dem Auftraggeber klären (neue Paperclip-Interaktion vs. eigene Ansicht) | Software-Planner + Auftraggeber | 7 |
| 9 | Sandbox-Sicherheitsabnahme: Testsuite, die gezielt versucht, aus der Sandbox auszubrechen (Netzwerk-, Datei-, Storage-, Timing-Seitenkanal-Versuche); muss vor Rollout von Ticket 5 grün sein | Backend-Developer + Frontend-Developer | 5 |

Reihenfolge: 1–2 können parallel zueinander laufen, 3 hängt an beiden, 5 kann
unabhängig von 1–3 starten, 9 ist das Abnahme-Gate für den Rollout von 5, 7
kann unabhängig von 1–6 starten, weil die Risikoentscheidung des Board-/
Paperclip-Betreibers (Abschnitt 5.3) die längste Vorlaufzeit hat.

---

## 8. Offene Punkte — nicht Gegenstand dieser Spezifikation

1. **Reichweitenfrage — entschieden.** Der Auftraggeber hat in Interaktion
   `8559c558` auf SUB-254 die enge Reichweite (nur Bausteinkomposition)
   zurückgewiesen und echte, als Vorschlag gekennzeichnete Codegenerierung
   verlangt. Diese Neufassung (SUB-308) setzt das um — kein offener Punkt
   mehr.
2. **Risikoentscheidung Authentisierungsweg Backend → Board** (Abschnitt 5.3)
   — die technische Klärung ist abgeschlossen (SUB-307): keine der drei real
   verfügbaren Varianten ist so eng wie die ursprünglich angenommene, nicht
   existierende Option. Offen ist jetzt, ob der Board-/Paperclip-Betreiber den
   company-weiten Blast-Radius von (a), den Plattform-/Trigger-Aufwand von (b)
   oder die getaktete statt sofortige Zustellung von (c) trägt — eine
   Entscheidung, kein weiterer Rechercheschritt, und kein Punkt, den der
   Auftraggeber allein entscheiden kann.
3. **Endgültige Kontingent- und Versuchslimit-Zahlen** (Abschnitt 6.2) —
   Platzhalter bis zur Messung an echten Erstellungen; die Kosten streuen
   jetzt breiter als bei reiner Bausteinkomposition (Abschnitt 6.1).
4. **Interaktionsform für Ticket 8** (Board-Interaktion vs. eigene
   In-App-Admin-Ansicht) — Entwurfsentscheidung, die erst nach Freigabe dieser
   Spezifikation sinnvoll getroffen wird.
5. **RDG-Grenzfall bei generierter Logik über zulässigen Eingaben**
   (Abschnitt 2.4) — offene Anwaltsfrage, eingetragen in
   `docs/17-release-readiness.md` Abschnitt 1.

---

## Verweise

- Bewertung und Bauplan (Ursprung dieses Tickets):
  `docs/31-projektreview-sub254.md` Abschnitt 5
- Entscheidung zur Neufassung: Interaktion `8559c558-09b5-476d-979d-f5e36204559d`
  auf SUB-254 (2026-09-25), Ticket SUB-308
- RDG-Abgrenzung: `docs/06-recht-compliance.md` Abschnitt 2
- Kostenrechnung-Methode: `docs/19-kosten-preis-budget.md` Abschnitt 5
- AVV-Gate: `docs/17-release-readiness.md` Abschnitt 1, `docs/23-llm-provider-avv.md`
- Content-Validierung als Vorbild: `backend/scripts/validate_content.py`,
  `backend/app/services/content.py`
- Bestehender Rückkanal-Baustoff: `backend/mission_control/client.py`,
  `outbox.py`, `verification.py`, `messages.py`
- Pilot-Status des Rückkanals: `ops/mission-control/README.md`
- Einwilligungspfad: `backend/app/api/v1/consent.py`
- Free-Tier-Kontingentmuster: `backend/app/services/limits.py`
