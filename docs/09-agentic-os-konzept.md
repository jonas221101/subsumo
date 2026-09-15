# Subsumo Mission Control — Konzept und Recherche

Stand: 13. September 2026. Architekturvorschlag, keine installierte Agentenplattform.
Grundlage: Projektstruktur, Architektur und Roadmap, Backend-Einstieg und Datenmodell,
Redaktionscode und zugehörige Tests, Flutter-State/API/Theme sowie vorhandene CI.
Dies ist keine vollständige Sicherheitsprüfung; vorhandene Tests wurden für diese
Konzeptrecherche nicht erneut ausgeführt. Externe Produkte wurden anhand ihrer
Primärquellen untersucht, nicht installiert oder praktisch erprobt.

## Empfehlung

Subsumo bekommt eine eigene interne Betriebsoberfläche: **Mission Control**.
Die Lern-App bleibt das Produkt. Die Agentensteuerung läuft als separater Dienst
mit eigener Anmeldung, Datenhaltung und Ausführungsumgebung.

Zuerst **Paperclip in einem begrenzten Pilot evaluieren**, mit der vorhandenen UI.
Danach die hier entworfene Oberfläche als Erweiterung oder separaten Client
anbinden, abhängig von den im Pilot bestätigten Schnittstellen. So lässt sich
früh prüfen, ob Aufgaben tatsächlich zuverlässig bis zum Ergebnis gelangen.

Paperclip dokumentiert Organisation, Aufgaben, Budgets, Ausführungshistorie und
wiederkehrende Aufträge. Das passt fachlich am besten zum gewünschten Firmenmodell.
Die dokumentierten Funktionen sind keine Garantie für eine bereits fertige
Subsumo-Pipeline bis zum Merge und Deployment. Diese Integration muss der Pilot
nachweisen. [Paperclip](https://github.com/paperclipai/paperclip)

## Was im Projekt schon trägt

- `backend/`: FastAPI, SQLAlchemy, getrennte fachliche Services. Die vorhandenen
  Datenmodelle bilden Lernen ab; eine Agenten-, Aufgaben- oder Laufverwaltung fehlt.
- `app/`: Flutter-Produkt für mehrere Plattformen. `state.dart` enthält einen
  persistenten Kartencache und eine Review-Outbox auf SharedPreferences-Basis.
  Der laut Roadmap geplante umfassende Offline-Speicher ist noch nicht vorhanden.
- `content/`: versioniertes YAML mit gemeinsamem Validator für Anwendung und CI.
- `backend/app/services/redaktion/pipeline.py`: Collector → Strukturprüfung →
  Reviewer → lokale Datei, mit maximal drei Runden. Dieses Muster ist ein guter
  erster Fachworkflow für das OS; die Laufhistorie liegt bislang im Ergebnisobjekt.
- `.github/workflows/ci.yml`: Backend-Lint/Tests, Content-Validierung und
  Flutter-Analyse/Tests sind definiert. Remote-Läufe und Branch-Regeln sind hier
  nicht überprüft worden.

Zwei konkrete Lücken vor Automatisierung:

1. `reviewer.py:60` verwendet `bool(parsed.get("approved", False))`.
   Ein JSON-String `"false"` ist in Python wahr. Die Freigabe braucht ein strikt
   validiertes Ergebnis mit echtem Boolean, zulässigen Schweregraden und Prüfung
   widersprüchlicher Angaben. Ungültige Ergebnisse dürfen nicht freigeben.
   Die gelesenen Reviewer-Tests decken dieses String-Szenario nicht ab.
2. `docs/08-ki-redaktion.md` verweist auf `content-redaktion.yml`; diese Datei
   fehlt im aktuellen Checkout. Es existiert nur `ci.yml`. Hinweise auf einen
   noch auszugliedernden Unterordner sind ebenfalls überholt für die hier sichtbare
   Wurzelstruktur. PR-Erstellung und automatischer Merge sind nicht implementiert.

Der Bridge-Modus ist laut Projektdokumentation an eine aktive Unterhaltung
gebunden. Unbeaufsichtigte Arbeit braucht einen eigenständigen Worker mit
konfigurierter Agentenlaufzeit und Authentifizierung.

## Vergleich der Bausteine

Die Optionen liegen auf unterschiedlichen Ebenen. Die Einordnung ist meine
Bewertung für Subsumo, kein Produktbenchmark.

| Baustein | Dokumentierte Stärke | Einordnung für Subsumo |
|---|---|---|
| Paperclip | Firma, Rollen, Aufgaben, Budgets, Zeitpläne, Laufprotokolle | Erste Wahl für den Pilot der Firmensteuerung |
| LangGraph | Persistente Zustände und Wiederaufnahme über Checkpointer | Alternative für eine selbst entwickelte Python-Steuerung; Firmenoberfläche und Aufgabenverwaltung zusätzlich bauen |
| CrewAI Flows | Ereignisgesteuerte Abläufe mit strukturiertem Zustand und Persistenz | Kandidat für einzelne Fachprozesse; ersetzt allein keine vollständige Firmensteuerung |
| Temporal | Dauerhafte Workflows mit Ereignishistorie und Wiederaufnahme nach Ausfällen | Später prüfen, wenn lange Server- und Veröffentlichungsprozesse komplex werden |
| Codex SDK | Programmatische Ausführung von Coding-Agenten, auch in CI | Eine ausführende Laufzeit; keine Aufgabenverwaltung für die gesamte Firma |

Quellen: [Paperclip](https://github.com/paperclipai/paperclip),
[LangGraph-Persistenz](https://docs.langchain.com/oss/python/langgraph/persistence),
[CrewAI Flows](https://docs.crewai.com/en/concepts/flows),
[Temporal Workflows](https://docs.temporal.io/workflows),
[Codex SDK](https://learn.chatgpt.com/docs/codex-sdk).

Für den Pilot würde ich genau eine Firmensteuerung und eine Coding-Laufzeit
verwenden. LangGraph, CrewAI und Temporal sind Alternativen bzw. spätere
Ergänzungen, keine gemeinsam notwendige Grundausstattung.

Paperclip dokumentiert Adapter für Codex, Claude Code, Prozesse und HTTP.
Damit lässt sich die bestehende Python-Redaktion grundsätzlich über einen
Wrapper anbinden. Dessen Fehlerbehandlung und Ergebnisübergabe sind eigene
Integrationsarbeit. [Adapterübersicht](https://github.com/paperclipai/paperclip/blob/master/docs/adapters/overview.md)

Vorgeschlagener Datenfluss: Mission Control → Paperclip → isolierter Worker →
GitHub-PR/Checks → Release-Dienst → Zielsystem. Rückmeldungen fließen als
nachvollziehbare Ereignisse zurück. Paperclip bleibt führend für Aufgaben und
Zuständigkeiten, GitHub für Commits und Prüfstatus. Die zusätzliche Oberfläche
zeigt daraus abgeleitete Zustände; sie führt keine konkurrierende Aufgabenliste.
Subsumos Lern-Backend wird nur über definierte Fachschnittstellen eingebunden.

## Das kleine Team

Rollen sind konfigurierte Verantwortlichkeiten. Nicht jede Rolle braucht einen
ständig laufenden Prozess oder ein eigenes Modell. Aufgaben starten Arbeit;
Leerlauf erzeugt keine absichtlichen Endlosschleifen.

| Rolle | Verantwortung | Ergebnis |
|---|---|---|
| Du / Owner | Unternehmensziel, Prioritäten, Autonomieregeln, Ausnahmen | Freigegebener Arbeitsrahmen |
| Product / Planner | Anforderungen präzisieren, zerlegen, Abhängigkeiten klären | Ausführbare Tickets mit Abnahmekriterien |
| Developer | Backend oder Flutter in isoliertem Arbeitsbereich ändern | Commit, PR, passende Tests |
| Reviewer | Frischer Kontext; Anforderung, Diff und Nachweise prüfen | Strukturierte Befunde und Entscheidung |
| Release-Service | Freigaberegeln technisch durchsetzen | Geprüfter Merge und ggf. Deployment |
| Redaktion | Bestehender Collector und Fachreviewer | Validierte Inhalte mit Herkunft |
| Operations, später | Monitoring, Diagnose, geprüfte Runbooks | Nachvollziehbare Betriebsmaßnahme |
| Marketing | Zielgruppenrecherche, Entwürfe, Kampagnenvorschläge | Geprüftes Asset bzw. geplanter Beitrag |

Start: Planner, Developer, Reviewer; Release als deterministischer Dienst.
Backend- und Flutter-Spezialisierung waren anfangs Profile derselben
Developer-Rolle; seit SUB-64 sind sie eigene Firmenagenten (Backend-Developer,
Frontend-Developer, UI-Developer), ebenso die Planner-Aufteilung in
Software-Planner und Marketing-Planner - siehe `ops/agents/`. Auf Nutzer-Feedback
im selben Thread berichten die drei Developer seither an einen Lead-Developer
(`ops/agents/lead-developer.md`), der Aufgaben verteilt und Schnittstellenfragen
zwischen ihnen moderiert, statt selbst zu implementieren - der Software-Planner
übergibt an ihn statt einzeln an die drei Developer. Ebenso berichten
Software-Planner und Marketing-Planner an einen Hauptplaner
(`ops/agents/hauptplaner.md`), der Planungsanfragen verteilt und
Schnittstellenfragen zwischen den beiden moderiert, statt selbst zu planen. Ein
großes Management-Organigramm ist für dieses Projekt weiterhin nicht nötig; die
Aufteilung folgt konkretem Bedarf, nicht Vorratshaltung.

## Agentenkommunikation — verbindlicher Bestandteil des Piloten

Agenten müssen direkt miteinander Rückfragen klären, Ergebnisse teilen,
Unteraufgaben übergeben und Hindernisse auflösen können, ohne dass der Owner
Nachrichten weiterleitet. Dies gilt auch zwischen Fachbereichen: etwa wenn
Marketing beim Produktteam nach dem bestätigten Funktionsumfang fragt oder
Operations einen reproduzierbaren Fehler an Engineering übergibt.

Paperclip dokumentiert bereits Aufgabenthreads mit Agent-zu-Agent-Kommunikation
und strukturierten Erwähnungen, die den adressierten Agenten aktivieren.
Eine bloße Namensnennung im Text ist keine Zustellung oder Aufgabenzuweisung.
Diese vorhandenen Mechanismen sind die Grundlage; die folgenden Zustell- und
Abnahmeregeln sind Anforderungen an unsere Integration, keine Behauptung über
bereits getestete Produkteigenschaften.
[Paperclip: Aufgabenthreads und Übergaben](https://docs.paperclip.ing/guides/day-to-day/issues/)

### Kommunikationswege

- **Aufgabenthread:** gemeinsame, dauerhaft gespeicherte Unterhaltung mit Fragen,
  Antworten, Entscheidungen und Verweisen auf Dateien, PRs und Testberichte.
- **Gezielte Anfrage:** Empfänger über eine eindeutige Agent-ID adressieren;
  Nachricht im zugehörigen Thread speichern und den Empfänger einplanen.
  Rückfragen ändern nicht automatisch den Aufgabenverantwortlichen.
- **Arbeitsübergabe:** abgegrenzter Auftrag mit Abnahmekriterien, Empfänger,
  Ergebnisreferenzen und expliziter Annahme. Größere Hilfsaufträge werden eigene
  Unteraufgaben; der bestehende Bearbeiter behält seinen Auftrag.
- **Projektwissen:** bestätigte Schnittstellen und fachliche Entscheidungen als
  versionierte Dokumente mit Quelle hinterlegen und in Nachrichten verlinken.
  Eine Chat-Aussage wird nicht automatisch zu verbindlichem Projektwissen.

Jeder Agent erhält dieselben Kommunikationsfähigkeiten über seinen Adapter:
Thread lesen, Anfrage senden, auf eine konkrete Nachricht antworten, Übergabe
anfragen/annehmen und Blockade melden. Das funktioniert unabhängig davon,
welche Agentenlaufzeit den jeweiligen Fachbereich ausführt.

### Nachrichtenvertrag und zuverlässige Verarbeitung

Jede Nachricht hat mindestens eine eindeutige ID, Projekt-/Aufgaben-/Thread-ID,
Absender-ID aus der authentifizierten Laufidentität, Empfänger-ID, Run-ID,
Zeitpunkt, Nachrichtentyp, Inhalt und optional Antwortbezug, Artefaktreferenzen
und Antwortfrist. Nachrichtentypen sind `question`, `answer`, `handoff`,
`finding`, `decision` und `blocker`. Eine Übergabe verweist zusätzlich auf die
betroffene Aufgabenrevision bzw. den konkreten Commit.

Nachricht und ausstehende Zustellung werden dauerhaft und konsistent gespeichert;
erst danach wird ein Worker aktiviert. Die Integration nutzt vorhandene Paperclip-
Mechanismen, soweit sie diese Garantien erfüllen. Fehlende Garantien werden
gezielt ergänzt, ohne einen zweiten führenden Gesprächsverlauf aufzubauen.
Jeder Empfänger verarbeitet dieselbe Nachrichten-ID höchstens einmal wirksam;
erneute Zustellversuche nach Ausfällen dürfen keine doppelten Unteraufgaben oder
Aktionen erzeugen. „Gespeichert“, „zur Verarbeitung eingeplant“, „verarbeitet“
und „beantwortet“ bleiben unterscheidbare Zustände.

Wartende Agenten geben ihren Worker frei und werden bei einer Antwort wieder
aktiviert. Ein bereits beschäftigter Empfänger erhält die Anfrage über eine
geordnete Inbox; dieselbe Aufgabe wird dadurch nicht gleichzeitig erneut
gestartet. Bei Pause oder ausgeschöpftem Budget bleibt die Nachricht ausstehend
und sichtbar. Eine abgelaufene Antwortfrist erzeugt eine Blockade und informiert
den Planner; eine Nutzerentscheidung wird nur bei einer tatsächlichen Ausnahme
angefordert. Gegenseitige Warteabhängigkeiten werden erkannt und aufgelöst.

### Zusammenarbeit und unabhängige Prüfung

Der Reviewer darf sachliche Fragen stellen und konkrete Befunde mit dem Developer
besprechen. Sein erster Prüflauf beginnt dennoch mit Anforderungen, aktuellem
Diff und unabhängigen Nachweisen, ohne den vollständigen Entstehungsdialog als
Vorgabe zu übernehmen. Antworten ergänzen überprüfbare Fakten; die finale
Entscheidung bleibt ein strukturiertes Review des aktuellen Commits. Eine
Chat-Nachricht wie „passt“ ersetzt weder Review noch technische Freigaberegeln.

Kommunikation verleiht keine zusätzlichen Werkzeugrechte. Zugriff gilt nur für
berechtigte Projekte und Artefakte; Absender können nicht durch Nachrichtentext
imitiert werden. Pro Aufgabe gelten begrenzte Rückfragerunden, Lauf- und
Nachrichtenbudgets. Empfangsbestätigungen lösen keine weiteren Agentenläufe aus;
Massen-Erwähnungen und rekursive Delegation werden begrenzt. Bei fehlendem
Fortschritt geht eine zusammengefasste Blockade an den Planner.

### Beispiel und Abnahme

Beim Delta-Sync fragt der Flutter-Developer den Backend-Verantwortlichen nach
dem Verhalten bei gelöschten Karten. Dieser antwortet mit dem bestätigten
API-Vertrag und dessen Version. Der Developer setzt ihn um und übergibt Commit
und Testberichte an den Reviewer. Ein Befund wird im selben Thread beantwortet;
nach einer Korrektur prüft der Reviewer den neuen Commit. Der Release-Dienst
verwendet ausschließlich die dazugehörigen gültigen Prüfentscheidungen.

Der Pilot muss diesen Austausch ohne menschliches Weiterreichen demonstrieren,
einschließlich Nachricht an einen pausierten Empfänger, Wiederaufnahme nach
Neustart, doppelter Zustellung, verspäteter Antwort und abgelehnter Übergabe.

## Was eine Aufgabe enthalten muss

Titel und Beschreibung allein reichen für unbeaufsichtigte Ausführung nicht.
Eine Aufgabe speichert Ziel, messbare Abnahmekriterien, Verantwortlichen,
Reviewer, Abhängigkeiten, Repository/Umgebung, erlaubte Werkzeuge und Pfade,
Budget- und Zeitlimit sowie Freigabeklasse. Jeder Versuch bekommt eine eigene
Run-ID; Aufgabe und Ausführungsversuch sind getrennte Datensätze.

Beispiel: **„Content-Deltas im Flutter-Client laden“**. Fertig, wenn geänderte
Karten aktualisiert werden, die vorhandene Outbox erhalten bleibt, Netzfehler
den Cache nicht entfernen und geeignete Tests einschließlich Wiederverbindung
bestehen. Owner: Flutter-Developer. Reviewer: unabhängige QA-Rolle. Abhängigkeit:
Delta-Vertrag des Backends ist geklärt. Ergebnis: PR und Testnachweise.

## Ausführungsstrecke

1. **Vorschlag / Backlog:** Du oder ein Agent erstellt eine Aufgabe mit Quelle.
2. **Bereit:** Kriterien, Zuständigkeit, Budget und Abhängigkeiten sind geklärt.
3. **In Arbeit:** Worker beansprucht die Aufgabe atomar und erhält einen eigenen
   Branch/Worktree in einer isolierten Ausführungsumgebung.
4. **Prüfung:** passende Tests und bestehende CI laufen; unabhängiger Reviewer
   prüft Anforderung, Diff und Ergebnisse mit frischem Kontext.
5. **Nacharbeit oder Ausnahme:** konkrete Befunde gehen an den Developer zurück.
   Vorschlag: höchstens zwei Nachbesserungen; danach sichtbar blockieren.
6. **Freigabeprüfung:** ein Dienst prüft den aktuellen Commit, erforderliche
   Checks, Reviewer-Ergebnis, Rechte und die konfigurierte Autonomieregel.
7. **Merge / Ausführung:** Code wird integriert; Betriebs- und Marketingaufträge
   führen stattdessen das jeweils freigegebene Runbook oder Asset aus.
8. **Verifikation:** Deployment-Healthcheck, Runbook-Nachbedingung oder
   Veröffentlichungsbestätigung entscheidet über „Erledigt“.

Ein neuer Commit macht die vorherige Review-Freigabe ungültig. Beim Merge zählt
die geprüfte Kombination mit dem aktuellen Zielbranch. „Erledigt“ stammt aus
dem verifizierten Ergebnis und nicht allein aus einer Behauptung des Agenten.
Agenten schreiben nachvollziehbare Entscheidungen, Tool-Ergebnisse und Artefakte
ins Protokoll; die Oberfläche benötigt keine verborgenen Gedankengänge.

GitHub Merge Queue prüft Änderungen zusammen mit dem aktuellen Zielbranch und
vorgelagerten PRs. Sie ist nach aktueller Dokumentation an bestimmte Repository-
und Tarifkonstellationen gebunden; diese wurden für Subsumo nicht geprüft.
Bei Verwendung muss die bestehende CI um `merge_group` ergänzt werden.
Alternative: ein serialisierter Integrationsdienst mit Aktualisierung des
Branches, erneuten Checks und Merge gegen den erwarteten Commit.
[GitHub Merge Queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)

## Autonomie als feste Regel je Aufgabentyp

Empfohlene Startkonfiguration, später anhand tatsächlicher Ergebnisse erweitern:

- **Automatisch:** Analyse, Vorschläge, Entwürfe, Tests, PR-Erstellung.
- **Automatischer Abschluss nach Prüfungen:** kleine klar begrenzte Codeänderungen,
  freigegebene Staging-Runbooks und andere vorher definierte Routineaktionen.
- **Gezielte Freigabe:** produktive Datenmigrationen, Berechtigungsänderungen,
  neue Ausgaben und öffentliche Kampagnen. Später können konkrete wiederkehrende
  Aktionen dafür vorab freigegebene Regeln bekommen.

Dadurch muss nicht jedes Ticket erneut bei dir landen. Der Agent darf seine
eigene Freigabeklasse oder seine Rechte jedoch nicht erhöhen. Code-Worker erhalten
keine Merge- oder Produktionszugänge; diese gehören dem separaten Release-Dienst.
Ein Worktree trennt Dateien, ist aber allein keine Sicherheitsgrenze.

Für unbeaufsichtigten Betrieb erforderlich: persistente Aufträge, begrenzte
Wiederholungen, Worker-Leases mit Ablauf, Wiederaufnahme, Laufzeit-/Kostenlimits,
globale Pause, nachvollziehbare Ereignisse. Externe Aktionen brauchen
Idempotenzschlüssel oder vor Wiederholung einen Abgleich mit dem Zielsystem,
damit ein Neustart weder doppelt veröffentlicht noch doppelt deployt.

## Selbstständige Verbesserungen

Agenten dürfen regelmäßig CI-Fehler, Backlog-Lücken, technische Schulden und
anonymisierte Produktmetriken untersuchen. Jeder Vorschlag enthält Beleg,
erwarteten Nutzen, betroffenen Bereich, Aufwand, Abnahmekriterium und Duplikatprüfung.
Er erscheint in der **Chancen-Inbox**. Kleine Vorschläge innerhalb eines
vorab genehmigten Wartungsbudgets können automatisch in „Bereit“ gelangen;
größere Produktentscheidungen bleiben in der Priorisierung.

Konkrete erste Vorschläge aus diesem Checkout:

- Strikte Reviewer-Ergebnisse einschließlich `"false"`-Regressionstest.
- Dokumentationsverweise und tatsächliche CI-/PR-Automatisierung angleichen.
- Client-Delta-Sync aus M1 mit einer klaren Abnahme umsetzen.
- Nachweisbare Inhaltsprüfung und später Normindex gemäß Projektroadmap anbinden.

Jeder Vorschlag verweist auf ein Unternehmensziel. Wiederholte Vorschläge werden
zusammengeführt; begrenzte Vorschlags- und Laufbudgets verhindern eine sich
selbst vermehrende Aufgabenliste.

## Visualisierung

Eine ruhige Desktop-Oberfläche mit der dunkelblauen Subsumo-Farbwelt und fünf
zusammenhängenden Sichten:

1. **Mission Control:** wichtigste Aufgaben, Blockaden, aktuelle Arbeit und
   unmittelbar notwendige Entscheidungen.
2. **Aufgabenboard:** Bereit → In Arbeit → Review → Erledigt; Detailansicht zeigt
   die feineren Zustände inklusive CI, Freigabe, Merge und Verifikation.
3. **Team:** Zuständigkeiten je Bereich, aktuelle Aufgabe, freigegebene Werkzeuge,
   Status und Budget. Organigramm als ergänzende Orientierung.
4. **Chancen:** agentenseitig vorgeschlagene Verbesserungen mit Belegen und
   „In Backlog übernehmen“.
5. **Laufdetails:** Zeitleiste mit Commit, Artefakten, Testergebnissen,
   Review-Befunden und Abschlussnachweis. Später Betriebs- und Publikationsläufe
   in derselben Struktur.

Aufgaben erhalten zusätzlich den Reiter **Kommunikation**: Absender → Empfänger,
Fragen und Antworten, Zustellzustand, offene Antwortfristen und Übergaben. Die
Teamansicht zeigt „arbeitet“, „wartet auf Antwort von …“ oder „blockiert“ mit
Link zum betreffenden Thread. Diese Ergänzung ist eine Anforderung an die
umzusetzende Oberfläche und noch nicht Teil der interaktiven Konzeptansicht.

Das Board ist die tägliche Arbeitsfläche. Ein räumliches Büro mit Avataren könnte
später eine optionale Ansicht sein; entscheidend sind sichtbare Ergebnisse,
Hindernisse und nächste Entscheidungen. Die interaktive Konzeptansicht verwendet
ausschließlich Beispieldaten und simuliert Aktionen lokal im Arbeitsspeicher.
Sie speichert Aufgaben nicht dauerhaft. HTML-Fragmentformat und JavaScript-Syntax
wurden geprüft; eine visuelle Browserprüfung war mangels verbundenem Browser
nicht möglich.

## Umsetzbare Todo-Liste

- [ ] **P0 · Developer + Reviewer:** Reviewer-JSON strikt validieren; fehlerhafte
  Typen und widersprüchliche Freigaben durch Tests abdecken.
- [ ] **P0 · Owner:** Task-Typen, Abnahmekriterien, Autonomie, Lauf- und Kostenlimits
  festlegen; drei kleine Pilotaufgaben auswählen.
- [ ] **P0 · Platform:** getrennten Paperclip-Pilot aufsetzen, Version fixieren,
  eine Agentenlaufzeit und einen isolierten Arbeitsbereich anbinden.
- [ ] **P0 · Platform:** Aufgaben-/Run-IDs durchgehend mit Branch, PR, Review,
  Check-Ergebnissen und Abschlussnachweis verbinden.
- [ ] **P0 · Platform:** Agentenkommunikation über dauerhafte Aufgabenthreads,
  eindeutige Empfänger, strukturierte Erwähnungen und explizite Übergaben anbinden;
  Zustellung, Antworten und Wiederaufnahme in jedem Adapter unterstützen.
- [ ] **P0 · QA:** Agent-zu-Agent-Rückfrage und Review-Nacharbeit ohne Owner als
  Vermittler erproben; Neustart, Doppelzustellung, pausierten Empfänger,
  Antwortfrist, Wartezyklus und Zugriffsgrenzen prüfen.
- [ ] **P0 · Release:** vorhandene CI als Pflichtchecks anbinden, Reviewer-Freigabe
  an Commit binden und kontrollierten Auto-Merge im Pilot nachweisen.
- [ ] **P0 · QA:** Ablehnung mit Nacharbeit, Worker-Neustart, doppelte Zuweisung,
  abgelaufene Freigabe und Budgetüberschreitung gezielt erproben.
- [ ] **P1 · Product/UI:** Mission Control nach dem Entwurf mit echten Zuständen
  verbinden; Aufgabe anlegen, zuweisen, pausieren und Lauf prüfen ermöglichen;
  Kommunikationsreiter und sichtbare Warte-/Übergabezustände ergänzen.
- [ ] **P1 · Redaktion:** bestehende Pipeline als Worker anbinden; Ergebnisse im
  Arbeitsbranch erzeugen und denselben PR-/Review-Prozess nutzen.
- [ ] **P1 · Planner:** Chancen-Inbox mit Belegen, Duplikatprüfung und Wartungsbudget.
- [ ] **P2 · Operations:** Monitoring, Staging-Runbooks, Nachbedingungen und Rollback;
  danach gezielt produktive Maßnahmen freischalten.
- [ ] **P2 · Marketing:** Entwurf → Review → geplante Veröffentlichung → Nachweis;
  Kanalzugänge und Ausgaben separat begrenzen.

**Pilot bestanden**, wenn drei kleine Aufgaben vom Board bis zum geprüften Merge
laufen, ein abgelehnter Entwurf nachgebessert wird, ein Neustart keine Doppelaktion
auslöst und ein fehlgeschlagener Pflichtcheck den Merge technisch verhindert.
Zusätzlich müssen Agenten eine fachliche Rückfrage und eine Arbeitsübergabe
selbstständig miteinander abschließen. Gespräch, Zustellung, Antwort und
zugehöriges Ergebnis müssen in Mission Control nachvollziehbar sein.
Erst danach breitere Autonomie und die individuelle Oberfläche ausbauen.
