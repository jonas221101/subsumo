# Werkbank: Spezifikation KI-komponierter Lernwerkzeuge (SUB-259)

> **Auftrag** ([SUB-259](/SUB/issues/SUB-259), Kind-Ticket zu
> [SUB-254](/SUB/issues/SUB-254)): Spezifikation des in
> `docs/31-projektreview-sub254.md` Abschnitt 5 bewerteten Features — **keine
> Implementierung.** Ein Nutzer beschreibt ein Lernwerkzeug in eigenen Worten,
> ein Modell komponiert es aus bestehenden Bausteinen, es steht dem Nutzer
> sofort zur Verfügung, und der Vorschlag geht als Rückmeldung an dieses Board,
> wo über den festen Einbau entschieden wird.
>
> **Einordnung (nicht Gegenstand dieses Dokuments, siehe `docs/31` Abschnitt
> 5.4):** nicht v1.0, frühestens v1.1, hinter demselben AVV-Gate wie die
> KI-Korrektur (`docs/17-release-readiness.md` Abschnitt 1,
> `docs/23-llm-provider-avv.md`). v1.0 läuft mit `llm_provider=none`
> (`docs/18-release-2-wochen.md` Abschnitt 2).
>
> **Leitplanke, die dieses Dokument nicht neu verhandelt:** *Die KI schreibt
> keinen Code, sie füllt eine Spezifikation aus.* Der Client führt nur aus, was
> als Bausteinaufruf bereits im Produkt existiert.

---

## 1. Bausteinliste

Jeder Baustein ist ein bereits vorhandener, getesteter Codepfad. Die Werkbank
fügt keine neue Fachlogik hinzu — sie parametrisiert Bestehendes. Das ist die
strukturelle Voraussetzung für Abschnitt 3 (Codeausführung) und Abschnitt 2 der
RDG-Auflösung: kein Baustein nimmt einen freien Sachverhalt als Eingabe an.

| # | Baustein-ID | Bestehender Codepfad | Was er tut | Was er *nicht* kann |
|---|---|---|---|---|
| 1 | `kartenfilter_drill` | `app/services/srs.py` (FSRS), `app/services/limits.py` (`due_cards_quota_remaining`) | Filtert fällige/neue Karten nach `Area`/`Topic.slug`/`Card.type` und startet eine Drill-Session | Erzeugt keine neuen Karten, keine neuen Inhalte |
| 2 | `schema_checkliste` | `Schema`-Modell (`backend/app/models.py:172`), `Schema.steps` | Zeigt ein bestehendes Prüfungsschema als abhakbare Checkliste | Erzeugt kein neues Schema, ändert `Schema.steps` nicht |
| 3 | `fallauswahl` | `Case`-Modell (`backend/app/models.py:188`), `CaseAccess` | Wählt aus der **bestehenden** Fall-Datenbank nach `Area`/`Topic.slug`/`difficulty` aus | Nimmt **keinen** vom Nutzer beschriebenen Sachverhalt an — nur Auswahlkriterien über vorhandene `Case.slug`-Einträge mit hinterlegtem `expectation` |
| 4 | `timer_pacing` | `app/services/planner.py` (Tagesbudget, `MAX_REVIEW_SHARE`) | Blendet einen Countdown/Pacing-Hinweis über eine Lernsession, abgeleitet aus dem bestehenden Tagesbudget | Ändert den Planungsalgorithmus nicht, keine neue Zeitlogik |
| 5 | `struktur_check` | `app/services/gutachten.py` (regelbasiert, offline, ohne LLM) | Lässt den bestehenden Obersatz/Definition/Subsumtion/Ergebnis-Check auf einen frei eingegebenen **Gutachtentext** laufen, mit wählbarer Strenge | Bewertet **keinen Sachverhalt inhaltlich** — reine Stilanalyse, wie im Original; siehe Abschnitt 2 unten |
| 6 | `planaenderung` | `app/services/planner.py` (`TopicInput.relevance`) | Erlaubt Gewichtung einzelner `Topic.slug` (Relevanz 1–5) innerhalb des bestehenden Plans | Ändert `exam_date`/`daily_minutes` nicht, kein neuer Planalgorithmus |
| 7 | `glossar` | `Card` mit `type=CardType.DEFINITION` (`backend/app/models.py:42`) | Nachschlage-Ansicht über bestehende Definitionskarten, gefiltert nach `Area`/`Topic.slug` | Erzeugt keine neuen Definitionen; es gibt **kein eigenständiges Glossar-Modul** — dieser Baustein ist ein zweiter Blickwinkel auf `Card.type=definition` |

Die Liste ist **fest und geschlossen**. Ein achter Baustein erfordert eine
Erweiterung dieser Spezifikation, nicht eine Modellentscheidung zur Laufzeit.

### 1.1 Warum `struktur_check` (Baustein 5) keine RDG-Ausnahme ist

`gutachten.py` bewertet nur *Stil* (Obersatz-Verschachtelung,
Urteilsstil-Verstöße, Normzitat-Form) — nie den *Inhalt* eines Sachverhalts.
Das gilt unverändert, ob der Text aus einer bestehenden `Case`-Bearbeitung oder
aus einem Werkbank-Tool kommt. Ein Nutzer kann in `struktur_check` zwar freien
Text eingeben, aber die Ausgabe ist strukturell unfähig, eine reale
Rechtsfrage zu beantworten — sie zählt Sätze und Verschachtelungstiefe, nicht
Rechtsfolgen. Damit bleibt die Abgrenzung aus `docs/06-recht-compliance.md`
Abschnitt 2 gewahrt.

---

## 2. JSON-Schema-Entwurf: Tool-Spec

Analog zum bestehenden Validierungsprinzip aus `backend/scripts/validate_content.py`
/ `app/services/content.py`: **was nicht im Schema steht, existiert nicht.**
`additionalProperties: false` auf jeder Ebene, jeder Slug wird serverseitig
gegen die lebende Content-/DB-Basis re-aufgelöst (Abschnitt 4).

```json
{
  "$id": "subsumo.werkbank.tool_spec.v1",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "tool_id", "title", "area_scope", "blocks", "created_at", "prompt_fingerprint"],
  "properties": {
    "schema": { "const": "subsumo.werkbank.tool_spec.v1" },
    "tool_id": { "type": "string", "format": "uuid" },
    "title": { "type": "string", "minLength": 1, "maxLength": 80 },
    "description": { "type": "string", "maxLength": 280 },
    "area_scope": {
      "type": "string",
      "enum": ["zivilrecht", "strafrecht", "oeffentliches-recht", "alle"]
    },
    "blocks": {
      "type": "array",
      "minItems": 1,
      "maxItems": 4,
      "items": { "$ref": "#/$defs/block" }
    },
    "layout": { "type": "string", "enum": ["sequence", "tabs"], "default": "sequence" },
    "created_at": { "type": "string", "format": "date-time" },
    "prompt_fingerprint": { "type": "string", "maxLength": 64 }
  },
  "$defs": {
    "block": {
      "type": "object",
      "additionalProperties": false,
      "required": ["block", "params"],
      "oneOf": [
        { "$ref": "#/$defs/kartenfilter_drill" },
        { "$ref": "#/$defs/schema_checkliste" },
        { "$ref": "#/$defs/fallauswahl" },
        { "$ref": "#/$defs/timer_pacing" },
        { "$ref": "#/$defs/struktur_check" },
        { "$ref": "#/$defs/planaenderung" },
        { "$ref": "#/$defs/glossar" }
      ]
    },
    "kartenfilter_drill": {
      "properties": {
        "block": { "const": "kartenfilter_drill" },
        "params": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "topic_slugs": { "type": "array", "items": { "type": "string" }, "maxItems": 10 },
            "card_types": {
              "type": "array",
              "items": { "enum": ["definition", "schema_step", "streitstand", "norm", "rechtsprechung"] }
            },
            "max_cards": { "type": "integer", "minimum": 5, "maximum": 50, "default": 20 }
          }
        }
      }
    },
    "schema_checkliste": {
      "properties": {
        "block": { "const": "schema_checkliste" },
        "params": {
          "type": "object",
          "additionalProperties": false,
          "required": ["schema_slug"],
          "properties": { "schema_slug": { "type": "string" } }
        }
      }
    },
    "fallauswahl": {
      "properties": {
        "block": { "const": "fallauswahl" },
        "params": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "topic_slugs": { "type": "array", "items": { "type": "string" }, "maxItems": 10 },
            "difficulty_max": { "type": "integer", "minimum": 1, "maximum": 5, "default": 3 },
            "count": { "type": "integer", "minimum": 1, "maximum": 10, "default": 3 }
          }
        }
      }
    },
    "timer_pacing": {
      "properties": {
        "block": { "const": "timer_pacing" },
        "params": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "minutes_per_session": { "type": "integer", "minimum": 5, "maximum": 120, "default": 25 },
            "reviews_first": { "type": "boolean", "default": true }
          }
        }
      }
    },
    "struktur_check": {
      "properties": {
        "block": { "const": "struktur_check" },
        "params": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "strictness": { "enum": ["locker", "standard", "streng"], "default": "standard" }
          }
        }
      }
    },
    "planaenderung": {
      "properties": {
        "block": { "const": "planaenderung" },
        "params": {
          "type": "object",
          "additionalProperties": false,
          "required": ["relevance_overrides"],
          "properties": {
            "relevance_overrides": {
              "type": "array",
              "maxItems": 20,
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": ["topic_slug", "relevance"],
                "properties": {
                  "topic_slug": { "type": "string" },
                  "relevance": { "type": "integer", "minimum": 1, "maximum": 5 }
                }
              }
            }
          }
        }
      }
    },
    "glossar": {
      "properties": {
        "block": { "const": "glossar" },
        "params": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "topic_slugs": { "type": "array", "items": { "type": "string" }, "maxItems": 10 }
          }
        }
      }
    }
  }
}
```

`tool_id` wird serverseitig vergeben, nicht vom Modell — verhindert
Kollisionen und macht die Zuordnung zu `created_by_user_id` (DB-seitig, nicht
im Spec selbst, siehe Abschnitt 6) eindeutig. `title`/`description` sind
Nutzer-zugewandter Text, den das Modell aus der Beschreibung ableitet, aber
**nicht** Träger von Fachlogik — sie werden nirgends ausgeführt.

---

## 3. Promptvertrag

**Zwei Modellaufrufe, nicht einer** — das hält die RDG-Grenze auch bei einem
Modellfehler strukturell, nicht nur durch eine Anweisung.

### 3.1 Stufe 1 — Intent-Check (vor jedem Kompositionsaufruf)

- Eingabe: die Nutzerbeschreibung, ohne weiteren Kontext.
- Aufgabe: klassifizieren, ob die Beschreibung ein **Lernwerkzeug aus
  Baustein 1–7** beschreibt, oder ob sie die Bewertung eines **realen,
  konkreten Sachverhalts** verlangt (das Vermieterkündigungs-Beispiel aus
  `docs/31` Abschnitt 5.1).
- Ausgabe: `{"allow": bool, "reason": string}` — festes, kleines Schema, kein
  Freitext im Erfolgsfall.
- Bei `allow=false`: kein Kompositionsaufruf, keine Kosten für Stufe 2, feste
  Nutzermeldung (Abschnitt 5.1).
- Diese Stufe ist bewusst **zusätzlich** zur strukturellen Grenze aus
  Abschnitt 1.1 — sie fängt Fälle ab, in denen der Nutzer versucht, über die
  Baustein-*Beschreibung* selbst (nicht über einen Baustein-Parameter) eine
  Rechtsdienstleistung zu erschleichen, z. B. durch eine sehr lange, Fall-artige
  Freitexteingabe als „Werkzeug-Wunsch".

### 3.2 Stufe 2 — Komposition (nur bei `allow=true`)

- Systemprompt enthält: die Bausteinliste aus Abschnitt 1 mit Kurzbeschreibung
  und Parametergrenzen, sowie eine vom Server vorab geladene, begrenzte Liste
  gültiger `topic_slug`/`schema_slug`-Werte für das vom Nutzer genannte
  Rechtsgebiet (nicht der gesamte Content-Bestand — Kontextgröße und
  Halluzinationsfläche bleiben klein).
- Der Systemprompt ist **versioniert**; `prompt_fingerprint` im Tool-Spec ist
  ein Hash dieser Version — dasselbe Prinzip wie das `schema`-Feld in
  `backend/mission_control/messages.py` (`subsumo.message.v1`), das
  Nachrichtenformat und -herkunft auditierbar macht.
- Ausgabe: **ausschließlich** ein JSON-Objekt nach Abschnitt 2, erzwungen über
  Tool-Calling/Structured-Output des Modells, nicht über Prompt-Disziplin
  allein.
- Das Modell erzeugt **keine** neuen `topic_slug`/`schema_slug`-Werte — nur
  Referenzen auf die im Kontext übergebene Liste. Das schließt aus, dass ein
  Halluzinationsfehler zu einem *gültig aussehenden, aber falschen* Slug führt,
  der erst in Abschnitt 4 auffällt statt gar nicht erst möglich zu sein.

---

## 4. Validierungs- und Fehlerpfad

Drei unabhängige Prüfstufen, jede mit definiertem Fehlerverhalten — keine
stille Reparatur, kein „wahrscheinlich richtig":

| Stufe | Prüfung | Bei Fehlschlag |
|---|---|---|
| A | Intent-Check (Abschnitt 3.1) | Feste Nutzermeldung „Beschreibt bitte ein Lernwerkzeug, keine Bewertung eines echten Falls." Kein weiterer Aufruf, kein Tool-Spec, kein Eintrag im Rückkanal. |
| B | JSON-Schema-Validierung (Abschnitt 2), serverseitig, nach demselben Muster wie `load_content()`/`validate_content.py` | Ein gebundener Retry: Validierungsfehler wird dem Modell als Kontext zurückgegeben, maximal **ein** weiterer Kompositionsaufruf. Schlägt auch der fehl → feste Nutzermeldung „Konnte mit den vorhandenen Bausteinen nicht abgebildet werden.", kein Tool-Spec. |
| C | Slug-Re-Auflösung: jeder `topic_slug`/`schema_slug` wird nach der Schema-Validierung erneut gegen die **aktuelle** DB/Content-Basis geprüft (Race zwischen Prompt-Kontext-Ladezeit und Antwort ist unwahrscheinlich, aber nicht ausgeschlossen) | Slug ungültig → wie Stufe B (ein Retry, dann fester Fehler). Slug gültig, aber Ergebnismenge leer (z. B. Topic ohne fällige Karten) → Tool wird **trotzdem erzeugt**, aber sofort sichtbar als „aktuell leer" markiert, nicht verschwiegen. |

**Kein Baustein führt etwas aus, was nicht bereits als getesteter Codepfad
existiert** (Abschnitt 1) — das ist die vierte, strukturelle Prüfstufe, die
gar nicht als Fehlerfall auftreten kann, weil der Client nur die sieben
Bausteinaufrufe kennt und alles andere im JSON-Schema (Abschnitt 2) gar nicht
repräsentierbar ist.

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
(Sonnet-Listenpreise 3 $/Mio Eingabe, 15 $/Mio Ausgabe):

| Aufruf | Eingabe (Token) | Ausgabe (Token) | Kosten |
|---|---|---|---|
| Intent-Check (3.1) | ≈ 150 (nur Nutzertext) | ≈ 20 (`allow`/`reason`) | ≈ 0,0005 $ |
| Komposition (3.2) | ≈ 2.000–3.000 (Systemprompt + Bausteinliste + Slug-Katalog) | ≈ 300–600 (Tool-Spec-JSON) | ≈ 0,011–0,018 $ |
| **Summe pro Erstellung** | | | **≈ 0,012–0,019 $ ≈ 0,01–0,02 €** |

Mit einem gebundenen Retry (Abschnitt 4, Stufe B) im ungünstigsten Fall
**doppelt**: ≈ 0,02–0,04 €/Erstellung. Das liegt **unter** der
0,09-€/Korrektur-Rechnung aus `docs/19` Abschnitt 5, weil die Ausgabe
strukturiertes JSON statt Fließtext ist. Wie dort: **vorläufige Rechnung, vor
Preisfestsetzung an echten Erstellungen zu messen** (`docs/19` fordert das für
die Korrektur ausdrücklich; dieselbe Auflage gilt hier).

### 6.2 Kontingent

Nach demselben Muster wie `app/services/limits.py` (`upgrade_required`-Fehlerform,
Zählung tatsächlich erfolgter Aktionen statt Client-Parameter):

- **Free:** 1 Werkzeug-Erstellung pro Kalendermonat (Kennenlern-Kontingent).
- **Pro:** 5 Erstellungen pro Kalendermonat, danach **gedrosselt statt
  abgerechnet** — exakt die Formulierung, die `docs/19` Abschnitt 5 für die
  KI-Korrektur festlegt, hier konsistent übernommen.
- Gezählt werden **persistierte** Tool-Erstellungen (analog
  `due_cards_quota_remaining`, das echte `Review`-Zeilen zählt, nicht den
  Client-Parameter) — ein abgelehnter Intent-Check oder ein endgültig
  fehlgeschlagener Kompositionsversuch (Abschnitt 4) zählt **nicht** gegen das
  Kontingent, weil kein Tool entstanden ist.
- **Nach der Erstellung: null weitere Modellnutzung.** Das Tool läuft über
  bestehende, kostenlose Codepfade (Abschnitt 1) — das ist keine Annahme,
  sondern die direkte Folge daraus, dass kein Baustein zur Laufzeit einen
  Modellaufruf braucht.
- Konkrete Zahlen sind **Platzhalter**, wie in `docs/19` Abschnitt 5 verlangt
  vor Preisfestsetzung zu messen — kein Freigabegegenstand dieses Dokuments.

---

## 7. Zerlegung in Tickets (v1.1, nach AVV — keine Ausführung vor Freigabe)

| # | Ticket | Rolle | Abhängigkeit |
|---|---|---|---|
| 1 | Bausteinkatalog-Endpunkt: serverseitig versionierte Liste gültiger `topic_slug`/`schema_slug`/Auswahlkriterien je Rechtsgebiet für den Promptkontext | Backend-Developer | Voraussetzung für 3 |
| 2 | JSON-Schema + Validator für Tool-Spec (Abschnitt 2), nach dem Muster von `app/services/content.py` | Backend-Developer | keine |
| 3 | Intent-Check + Promptvertrag + Kompositionsaufruf mit Retry-Grenze (Abschnitt 3, 4) | Backend-Developer | 1, 2, AVV/`llm_provider` |
| 4 | Fehlerpfad-UI für die drei Fehlerklassen aus Abschnitt 4 | Frontend-Developer | 3 |
| 5 | Client-Interpreter: die 7 Bausteine als Aufrufe auf bestehende Screens/Services verdrahten, kein neuer Codepfad | Frontend-Developer | 2 |
| 6 | Kontingent + Zähler, Erweiterung von `limits.py` nach demselben Muster (Abschnitt 6.2) | Backend-Developer | keine |
| 7 | Rückkanal: Proposal-Tabelle, Outbox-Zustellung. **Voraussetzung: Risikoentscheidung des Board-/Paperclip-Betreibers zwischen Variante (a)/(b)/(c) aus Abschnitt 5.3 muss vor Implementierung vorliegen** — keine der drei baut auf die dort ursprünglich angenommene, nicht existierende scope-enge Option | Backend-Developer + Rückfrage | keine, aber blockiert auf die Risikoentscheidung Abschnitt 5.3 |
| 8 | Board-seitige Annahme/Ablehnung eines Vorschlags (fester Einbau ja/nein) — Interaktionsform mit dem Auftraggeber klären (neue Paperclip-Interaktion vs. eigene Ansicht) | Software-Planner + Auftraggeber | 7 |

Reihenfolge: 1–2 können parallel zueinander laufen, 3 hängt an beiden, 7 kann
unabhängig von 1–6 starten, weil die externe Klärung die längste Vorlaufzeit
hat.

---

## 8. Offene Punkte — nicht Gegenstand dieser Spezifikation

1. **Reichweitenfrage** („Tool" = Lernwerkzeug in der App, nicht frei
   programmierbares Programm) — läuft als eigene Rückfrage auf SUB-254, nicht
   hier wiederholt.
2. **Risikoentscheidung Authentisierungsweg Backend → Board** (Abschnitt 5.3)
   — die technische Klärung ist abgeschlossen (SUB-307): keine der drei real
   verfügbaren Varianten ist so eng wie die ursprünglich angenommene, nicht
   existierende Option. Offen ist jetzt, ob der Board-/Paperclip-Betreiber den
   company-weiten Blast-Radius von (a), den Plattform-/Trigger-Aufwand von (b)
   oder die getaktete statt sofortige Zustellung von (c) trägt — eine
   Entscheidung, kein weiterer Rechercheschritt, und kein Punkt, den der
   Auftraggeber allein entscheiden kann.
3. **Endgültige Kontingentzahlen** (Abschnitt 6.2) — Platzhalter bis zur
   Messung, wie in `docs/19` für die KI-Korrektur bereits verlangt.
4. **Interaktionsform für Ticket 8** (Board-Interaktion vs. eigene
   In-App-Admin-Ansicht) — Entwurfsentscheidung, die erst nach Freigabe dieser
   Spezifikation sinnvoll getroffen wird.

---

## Verweise

- Bewertung und Bauplan (Ursprung dieses Tickets):
  `docs/31-projektreview-sub254.md` Abschnitt 5
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
