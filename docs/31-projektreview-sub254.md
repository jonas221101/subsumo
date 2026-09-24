# Projektreview, USP-Bewertung und Werkbank-Konzept (SUB-254)

> **Auftrag** ([SUB-254](/SUB/issues/SUB-254), Nutzer, 24.09.2026): Review des
> ganzen Projekts (Optik, Code, Inhalt, Datensicherheit, Rechtliches, Aufbau,
> Sellingpoint), Antwort auf „Was macht uns attraktiver als andere?", ein neues
> Feature (KI-gebaute Nutzer-Tools mit Rückkopplung an einen Agenten), weitere
> USP-Recherche und ein Werbekonzept inkl. Erstkundengewinnung.
>
> **Dieses Dokument ist die Koordinations-Ebene:** eigener Befund mit
> nachgeprüften Stellen, Bewertung, und die Zerlegung in delegierte Tickets.
> Die Tiefenprüfungen je Spur laufen in den Kind-Tickets aus Abschnitt 7,
> nicht hier.
>
> **Stand: 24.09.2026.** Releasetermin 29.09.2026, Code-Freeze 28.09.2026
> (`docs/18-release-2-wochen.md` Abschnitt 5) — also **vier Arbeitstage**. Jede
> Empfehlung unten ist deshalb ausdrücklich einsortiert in *vor Freeze* oder
> *nach Release*.

---

## 1. Die wichtigste Randbedingung: der Termin steht, das Feature nicht

Der Auftrag enthält ein großes neues Feature. Der Freeze ist in vier Tagen.
`docs/18` Abschnitt 1 legt fest: *„Die Termintreue ist das Gate, nicht der
Umfang."* Beides zusammen geht nicht.

**Entscheidung dieses Dokuments:** Das Werkbank-Feature (Abschnitt 5) wird
jetzt *spezifiziert*, aber nicht mehr in v1.0 gebaut. Es hängt ohnehin am
selben harten Gate wie die KI-Korrektur — dem unterschriebenen AVV
(`docs/17-release-readiness.md` Abschnitt 1, `docs/23-llm-provider-avv.md`) —
und ohne den darf kein Nutzertext an einen LLM-Provider gehen. Ein Feature, das
ohne LLM gar nicht existiert, kann kein v1.0-Feature sein, solange
`llm_provider=none` gilt.

Was dagegen **vor den Freeze gehört**, sind drei Befunde aus Abschnitt 3, die
den Launch direkt beschädigen würden. Sie sind klein und einzeln behebbar.

---

## 2. Aufbau — tragfähig, Dokumentation teilweise überholt

Der Aufbau ist für ein Produkt dieser Größe überdurchschnittlich sauber:
`backend/app/services/` trennt Fachlogik (srs · gutachten · evaluator · planner
· content · billing · limits) von der API-Schicht `backend/app/api/v1/`, der
Content liegt als versioniertes, schema-validiertes YAML außerhalb des Codes
(`content/`, 60 Dateien), und `validate_content.py` läuft in der CI. Der
Flutter-Client hat mit `app/lib/design/` inzwischen eine echte Token- und
Komponentenebene statt verstreuter Stilwerte. Das ist keine Prototyp-Struktur.

**Ein Befund mit Folgen:** `docs/17-release-readiness.md` ist an mehreren
Stellen überholt und beschreibt das Produkt schlechter, als es ist. Das Dokument
wurde zuletzt am 15.09. angefasst, die API-Schicht am 17.09. Es führt

- „DSGVO Auskunft (Art. 15) — Offen, kein Endpoint" und
- „DSGVO Export (Art. 20) / Löschung (Art. 17) — kein Endpoint vorhanden"

als offen. Tatsächlich existiert `backend/app/api/v1/account.py` mit
`GET /account/export` (maschinenlesbare Selbstauskunft) und `POST
/account/delete` inklusive Kaskade auf `Review`, `UserCard`, `Submission`,
`CaseAccess`, `AnalyzeCall` — plus `backend/tests/test_account.py`. Ebenso
existiert die im Dokument geforderte Transparenz vor der ersten
KI-Verarbeitung inzwischen als eigener Einwilligungspfad
(`backend/app/api/v1/consent.py`, `backend/tests/test_ai_consent.py`).

Das ist nicht kosmetisch: Diese Liste ist die Grundlage der Gate-Bewertung vor
dem Release. Wenn sie erledigte Punkte als offen führt, kann sie umgekehrt auch
offene Punkte als erledigt führen. Sie muss vor dem Freeze einmal gegen den
Code nachgezogen werden (Ticket in Abschnitt 7).

---

## 3. Datensicherheit — drei konkrete Punkte vor dem Freeze

Alle drei sind an der angegebenen Stelle nachgeprüft, nicht aus der
Dokumentation übernommen.

### 3.1 Die Paywall steht per Default offen, und die Checkliste fängt das nicht

`backend/app/config.py:44` setzt `paywall_enabled: bool = False`. Das ist ein
bewusster Notausgang (`docs/20-release-g2-bezahlstrecke.md` Abschnitt 5) und als
Default auch richtig — bei `False` verhält sich **jeder** Nutzer wie Pro
(`backend/app/services/limits.py:31`, `backend/app/api/v1/auth.py:21`).

Das Problem ist nicht der Default, sondern die Lücke daneben: Die
Produktions-Checkliste in `docs/22-deploy-runbook.md` (Zeilen 27–30) listet
`SUBSUMO_JWT_SECRET`, `SUBSUMO_DATABASE_URL`, `SUBSUMO_ENVIRONMENT`,
`SUBSUMO_LOG_JSON` und `SUBSUMO_BACKUP_PASSPHRASE` — **`SUBSUMO_PAYWALL_ENABLED`
steht dort nicht.** Ein Deploy streng nach Runbook startet also mit
abgeschalteter Paywall, und zwar lautlos: kein Fehler, kein Log, alle Nutzer
bekommen Pro geschenkt. Das fällt erst auf, wenn am Monatsende keine Umsätze da
sind.

**Behebung (klein):** Variable in die Runbook-Checkliste aufnehmen **und** einen
Startup-Check ergänzen, der bei `SUBSUMO_ENVIRONMENT=production` zusammen mit
`paywall_enabled=False` mindestens laut warnt.

### 3.2 Kein Rate-Limit auf irgendeinem Endpoint

Eine Suche über `backend/app` nach `ratelimit|rate_limit|slowapi|limiter`
liefert **keinen einzigen Treffer**, und in `ops/` liegt keine
Reverse-Proxy-Konfiguration, die es vorgelagert übernähme (`ops/` enthält nur
Mission-Control-Skripte und Agentenprofile). Damit sind `POST /auth/login` und
`POST /auth/register` unbegrenzt oft aufrufbar.

Für den Launch heißt das: Credential-Stuffing gegen die Login-Route ist nicht
gebremst, und `register` erlaubt beliebig viele Konten aus einer Quelle —
relevant, weil das Free-Tier echte Leistung enthält (20 fällige Karten/Tag, 2
Fälle, 3 Struktur-Checks/Woche, `backend/app/services/limits.py`) und damit ein
Anreiz für automatisierte Massenanmeldung besteht.

Dieser Punkt steht **nicht** in `docs/17` Abschnitt 2 — er ist neu, nicht nur
überfällig. Ein einfaches IP-basiertes Limit auf die beiden Auth-Routen ist
wenige Stunden Arbeit und gehört vor den Freeze.

### 3.3 Default-JWT-Secret bricht in Produktion nicht ab

`backend/app/config.py:23` setzt `jwt_secret = "dev-only-insecure-change-me"`.
Der Kommentar dort sagt, der Default sei „bewusst offensichtlich unsicher, damit
ein fehlendes Secret sofort auffällt" — aber nichts im Code erzwingt das
Auffallen. Startet Produktion ohne gesetzte Variable, signiert der Server
Tokens mit einem öffentlich im Repository stehenden Secret; jeder kann sich
damit ein gültiges Token für eine beliebige `sub` ausstellen.

`docs/17` Abschnitt 2 führt den nötigen Fail-Fast bereits als Punkt für Gate D.
Er ist noch nicht umgesetzt und ist die billigste Absicherung im ganzen Release
(wenige Zeilen im Startup).

**Positiv, weil sonst leicht übersehen:** `decode_access_token`
(`backend/app/core/security.py`) liest den `alg`-Header gar nicht erst aus,
sondern prüft immer fest mit HMAC-SHA256. Die klassische
`alg=none`-Verwechslungslücke ist damit strukturell ausgeschlossen. PBKDF2 mit
600.000 Iterationen ist OWASP-konform; der Wechsel auf Argon2id ist eine
Verbesserung, kein Sicherheitsmangel.

---

## 4. Sellingpoint — die unbequeme Antwort auf „Was macht uns attraktiver?"

### 4.1 Was am Starttag wirklich differenziert

Die ehrliche Lage ist in den eigenen Dokumenten schon angelegt, wird aber
nirgends in einem Satz zusammengezogen:

`docs/14-marktanalyse.md` Abschnitt 2 hat belegt, dass **KI-Klausurkorrektur
kein Alleinstellungsmerkmal mehr ist** — Constellatio (seit 30.01.2026),
KorrekturKai und KlausurenKiste bieten sie an. Und `docs/18` Abschnitt 2 legt
fest, dass v1.0 mit `llm_provider=none` startet. Daraus folgt der Satz, der für
die Positionierung entscheidend ist:

> **Das am lautesten beworbene Feature des Marktes ist zum Start bei uns aus —
> und selbst eingeschaltet wäre es kein Unterscheidungsmerkmal.**

Verkauft werden kann am 29.09. also nur, was *live und exklusiv* ist. Nach
Prüfung des Codes bleiben genau zwei Dinge übrig:

**(1) Unbegrenztes Struktur-Feedback, das nichts kostet.**
`backend/app/services/gutachten.py` ist regelbasiert, deterministisch und
offline: Obersatz/Definition/Subsumtion/Ergebnis, Urteilsstil-Warnung,
Normzitat-Prüfung — ohne LLM, ohne AVV, ohne Grenzkosten pro Nutzung. Das ist
kein technisches Detail, sondern ein **ökonomischer Vorteil**: Jeder
Wettbewerber, der Strukturfeedback über ein Sprachmodell erzeugt, zahlt pro
Abgabe und muss deshalb kontingentieren. Subsumo kann dasselbe Feedback
unbegrenzt verschenken, dauerhaft, auch im Free-Tier. Das ist verteidigbar,
weil es nicht an einem Budget hängt.

**(2) Echtes Offline auf vier Plattformen.** Kartencache und Review-Outbox
überstehen Neustart und Netzausfall (`app/lib/state.dart`), eine Codebasis für
Android/iOS/Windows/Web. Die drei KI-Korrektur-Wettbewerber sind laut
`docs/14` Abschnitt 3 sämtlich Web-Einreichungswerkzeuge. Wer in der Bibliothek
ohne WLAN oder im Zug lernt, hat bei uns ein Produkt und bei denen eine
Fehlermeldung.

### 4.2 Was als USP behauptet, aber nicht gebaut ist

`docs/16-innovationsthesen.md` Abschnitt 2 hält die „Verzahnung" als These —
und stellt zugleich fest, dass sie im Code **nicht existiert**: `Card`, `Schema`
und `Case` teilen sich nur ein gemeinsames `topic_slug`
(`backend/app/models.py`), es gibt keine Kette von einem konkreten Fehler zu
einer konkreten Wiederholungskarte. Das gilt unverändert.

Das ist die wichtigste Erkenntnis dieses Reviews für die Frage „was macht uns
attraktiver":

> Der einzige USP, den **kein** Wettbewerber hat und der gleichzeitig **billig
> zu bauen** ist, ist der geschlossene Kreis: *Ein Fehler in der Klausur erzeugt
> automatisch die Wiederholungskarte, die genau diesen Fehler adressiert.*

`docs/13-lernarchitektur.md` Abschnitt 3.2 hat ihn bereits vollständig
entworfen — ein additives Feld `Pruefpunkt.card_slugs`, das bei
`pruefpunkt_verfehlt` die verknüpften Karten fällig setzt und bei einem
Pflichtprüfpunkt auf `relearning` zurückstuft. Keine Breaking Changes,
überwiegend redaktioneller Aufwand.

**Und — hier weicht dieses Dokument bewusst von `docs/16` ab:** `docs/16`
Abschnitt 2 ordnet die Verzahnung als „v1.1-Umsetzung, sobald die KI-Korrektur
aktiviert wird" ein, also hinter den AVV. Das ist beim Nachsehen im Code nicht
zwingend. Der Mechanismus hängt an *verfehlten Prüfpunkten*, und die erzeugt
`backend/app/services/evaluator.py` auch im heuristischen Betrieb, ohne jeden
LLM-Aufruf. Der Kreis lässt sich also **ohne AVV schließen** — schwächer in der
inhaltlichen Trefferquote, aber funktionsfähig. Damit ist er der schnellste Weg
zu einem echten Alleinstellungsmerkmal nach dem Release, unabhängig davon, ob
der AVV am 27.09. unterschrieben wird oder nicht. Das ist eine Empfehlung zur
Neubewertung, keine eigenmächtige Änderung an `docs/16`.

### 4.3 Konsequenz für die Launch-Kommunikation

Nicht „wir haben KI-Korrektur" (haben andere, und bei uns ist sie am Starttag
aus), sondern:

> **Unbegrenztes, sofortiges Struktur-Feedback zu jedem Gutachten — gratis,
> offline, auf jedem Gerät. Ohne Kontingent, weil es uns nichts kostet.**

Das ist zum 29.09. vollständig einlösbar. `docs/21-landing-preisseite-launchtext.md`
führt den Struktur-Check bereits als eigenes Argument; die Empfehlung ist, ihn
vom Nebenargument zum *Hauptargument* zu machen, solange die KI-Korrektur aus
ist. Die Ausarbeitung gehört zum Marketing-Ticket in Abschnitt 7.

---

## 5. Das neue Feature — „Werkbank": Bewertung und sicherer Bauplan

**Auftrag:** Ein Nutzer beschreibt, was für ein Tool er hätte; die KI baut es;
es steht ihm zur Verfügung; die Idee wird an einen Agenten hier
zurückgekoppelt; der Auftraggeber entscheidet über festen Einbau.

Das ist ein starkes Produktargument — **kein Wettbewerber aus `docs/14`
Abschnitt 2 bietet nutzerseitig komponierbare Lernwerkzeuge.** Es ist zugleich
der riskanteste Vorschlag im ganzen Projekt, wenn man ihn wörtlich nimmt.

### 5.1 Vier Risiken, wenn „Tool bauen" heißt „Code erzeugen und ausführen"

1. **Codeausführung.** KI-erzeugter Code, der im Backend-Prozess oder im Client
   mit App-Rechten läuft, ist eine Remote-Code-Execution-Fläche, die der
   Nutzer selbst per Texteingabe steuert. Das ist mit dem Sicherheitsniveau aus
   Abschnitt 3 nicht vereinbar.
2. **RDG.** `docs/06-recht-compliance.md` Abschnitt 2 trägt die Abgrenzung zur
   Rechtsberatung ausdrücklich darüber, dass ausschließlich **fiktive
   Übungsfälle** gegen einen hinterlegten Erwartungshorizont bewertet werden.
   Ein freies Tool-Eingabefeld hebelt genau diese Grenze aus: „Bau mir ein Tool,
   das prüft, ob die Kündigung meines Vermieters wirksam ist" ist eine
   Rechtsdienstleistung im Einzelfall — unabhängig davon, wie das Ergebnis
   beschriftet ist.
3. **DSGVO/AVV.** Das Feature ist ohne Sprachmodell nicht denkbar und steht
   damit hinter demselben harten Gate wie die KI-Korrektur.
4. **Kosten.** Freie Prompts pro Nutzer sind ein unbegrenzter variabler
   Kostenblock — gegen die Kostendeckungsvorgabe aus
   `docs/19-kosten-preis-budget.md`.

### 5.2 Der Bauplan, der alle vier entschärft: Komposition statt Codegenerierung

**Die KI schreibt keinen Code. Sie füllt eine Spezifikation aus.**

Das Modell erzeugt aus der Nutzerbeschreibung ein **deklaratives Tool-Spec
(JSON)**, das ausschließlich aus einer festen Liste bereits vorhandener,
geprüfter Bausteine komponiert werden darf — Kartenfilter und Drill, Schema als
Checkliste, Fallauswahl, Timer/Pacing, Struktur-Check, Planänderung,
Glossar-Nachschlag. Der Client interpretiert dieses Spec; er führt nichts aus,
was nicht schon im Produkt steckt.

Damit lösen sich die Risiken der Reihe nach auf:

| Risiko | Auflösung |
|---|---|
| Codeausführung | Es gibt keinen erzeugten Code. Das Spec wird gegen ein JSON-Schema validiert — dasselbe Prinzip, das `backend/scripts/validate_content.py` für Inhalte bereits in der CI fährt. Was nicht im Schema steht, existiert nicht. |
| RDG | Die Bausteinliste enthält keinen Baustein, der einen realen Sachverhalt bewertet. Ein Tool zur Vermieterkündigung ist nicht „verboten", es ist **nicht konstruierbar**. Das ist eine strukturelle Grenze statt eines Filters, den man umformulieren kann. Zusätzlich ein Intent-Check vor dem Modellaufruf. |
| AVV/DSGVO | Ein Modellaufruf pro *Erstellung*, nicht pro Nutzung; die Nutzerbeschreibung eines Lernwerkzeugs enthält typischerweise keine personenbezogenen Falldaten. Trotzdem: hinter demselben AVV-Gate, mit demselben Einwilligungspfad wie `consent.py`. |
| Kosten | Ein Aufruf je erzeugtem Tool, danach läuft das Tool dauerhaft lokal ohne jede Modellnutzung. Kalkulierbar statt unbegrenzt; Kontingent pro Nutzer und Monat obendrauf. |

### 5.3 Die Rückkopplung ist bereits zur Hälfte gebaut

Der vom Auftrag verlangte Rückkanal („die Idee soll hierher an einen Agenten
zurückgekoppelt werden") muss nicht erfunden werden: `backend/mission_control/`
enthält bereits einen Paperclip-Client (`client.py`), ein Outbox-Muster für
zuverlässige Zustellung (`outbox.py`) und Verifikation (`verification.py`), mit
eigenen Tests. Ein erzeugtes Tool-Spec plus Nutzungszähler lässt sich darüber
als Vorschlag in dieses Board stellen, wo dann die Entscheidung über den festen
Einbau fällt — genau der beschriebene Ablauf.

Wichtig für die Abgrenzung: `ops/mission-control/README.md` hält fest, dass
Mission Control heute **nicht** nutzerseitig betrieben wird. Der Rückkanal
braucht deshalb einen eigenen, authentifizierten Weg vom Produkt-Backend ins
Board — das ist Teil der zu erstellenden Spezifikation, kein erledigter Punkt.

### 5.4 Einordnung

**v1.1 frühestens, nach AVV.** Nicht in v1.0. Der nächste Schritt ist eine
Spezifikation durch den Software-Planner auf Basis von 5.2/5.3, keine
Implementierung (Ticket in Abschnitt 7).

---

## 6. Optik, Inhalt, Recht — Kurzbefund, Tiefenprüfung delegiert

- **Optik:** Mit `docs/25-ui-relaunch-brief.md` und der Token-Ebene
  (`app/lib/design/tokens/`, `app/lib/design/components/`) liegt seit PR #64
  ein Fundament vor, das vorher fehlte. Ob der Relaunch-Brief im gelieferten
  UI tatsächlich eingelöst ist, ist eine Sichtprüfung am laufenden Build und
  gehört zum UI-Developer, nicht in dieses Dokument.
- **Inhalt:** 60 YAML-Dateien über drei Rechtsgebiete, Normzitat-Gate zuletzt
  für acht Alt-Themen nachgezogen (Commit `9746172`, SUB-250). Die fachliche
  Prüfung gehört zum Content-Prüfagenten.
- **Recht:** `docs/legal/` enthält Impressum, AGB, Datenschutzerklärung,
  Widerrufsbelehrung und Cookie-Hinweis als Texte. Die in `docs/17`
  Abschnitt 1 mit „Frage:" markierten Punkte (Haftungsklausel für die
  KI-Bewertung, Widerrufsverzicht nach § 356 V BGB, AVV) sind
  **Anwaltsfragen, die kein Agent beantworten kann** — sie stehen in der
  Nutzerrückfrage zu diesem Ticket.

---

## 7. Zerlegung

| # | Ticket | Rolle | Zeitfenster |
|---|---|---|---|
| 1 | Sicherheits-Härtung vor Freeze: Rate-Limit auf Auth-Routen (3.2), Fail-Fast bei Default-JWT-Secret (3.3), `SUBSUMO_PAYWALL_ENABLED` in Runbook + Startup-Warnung (3.1) | Backend-Developer → Reviewer | **vor 28.09.** |
| 2 | `docs/17-release-readiness.md` gegen den Code nachziehen (Abschnitt 2) | Reviewer | **vor 28.09.** |
| 3 | Optik-Review gegen `docs/25` am laufenden Build | UI-Developer | vor 28.09., Befunde ggf. nach Release |
| 4 | Inhaltsreview der 60 Content-Dateien | Content-Prüfagent | vor 28.09. |
| 5 | Spezifikation „Werkbank" nach Abschnitt 5.2/5.3 | Software-Planner | nach Release |
| 6 | USP-Recherche, Werbekonzept, Erstkundengewinnung | Marketing-Planner | Konzept ab sofort, Umsetzung nach Release |
| 7 | Verzahnung `Pruefpunkt.card_slugs` (4.2) — der billigste echte USP | Software-Planner → Backend | v1.1, **ohne AVV möglich** |

---

## 8. Offene Punkte, die nur der Auftraggeber entscheiden kann

1. **Werbebudget.** `docs/19-kosten-preis-budget.md` Abschnitt 6 setzt „kein
   Werbebudget" fest, und `docs/15-go-to-market.md` schließt bezahlte
   Reichweite deshalb ausdrücklich aus. Der Auftrag verlangt jetzt ein
   Werbekonzept. Ob damit weiterhin rein organisch gemeint ist oder ob Budget
   bereitsteht, ändert das Konzept grundlegend.
2. **Anwaltsfragen** aus `docs/17` Abschnitt 1 (siehe 6).
3. **Reichweite des Werkbank-Features:** Bestätigung, dass „Tool" Lernwerkzeuge
   innerhalb der App meint (Abschnitt 5.2) und nicht frei programmierbare
   Programme.

---

## Verweise

- Schnittplan und Gates: `docs/18-release-2-wochen.md`
- Release-Readiness (nachzuziehen): `docs/17-release-readiness.md`
- Markt und Positionierung: `docs/14-marktanalyse.md`
- Innovationsthesen: `docs/16-innovationsthesen.md`
- Lernarchitektur, Verzahnung: `docs/13-lernarchitektur.md`
- Recht/Compliance: `docs/06-recht-compliance.md`
- Bezahlstrecke, Notausgang: `docs/20-release-g2-bezahlstrecke.md`
- Deploy: `docs/22-deploy-runbook.md`
