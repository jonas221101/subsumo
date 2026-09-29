# Release-Readiness (T8)

Querschnittsspur: Punkte, die kein Feature sind, aber einen Launch
verhindern, wenn sie fehlen. Rechtliche und regulatorische Grundlagen stehen
in [`docs/06-recht-compliance.md`](06-recht-compliance.md) — hier nur, was
dort noch **nicht** geregelt ist, plus die Sicherheits-, Store-, Abrechnungs-
und Betriebspunkte, die zusammen Gate C/D aus
[`docs/03-roadmap.md`](03-roadmap.md) bilden.

Format je Zeile: **Verantwortlich** (Rolle, nicht Person — das Team ist
1–2 Entwickler + Teilzeit-Fachredaktion, siehe Roadmap) · **Aufwand**
(grob, in Personentagen) · **Phase** (A–D nach Roadmap-Gates) · **Status**.

Kein Rechtsrat. Alle mit „Frage:" markierten Punkte sind offen und brauchen
eine explizite Antwort (Anwalt, Steuerberater oder Produktentscheidung), bevor
das jeweilige Gate als grün gelten darf — keine Annahme ersetzt sie.

**Stand der Status-Spalten geprüft: 24.09.2026**, gegen den zu diesem
Zeitpunkt aktuellen Code-Stand nachgezogen (`docs/31-projektreview-sub254.md`
Abschnitt 2, Ticket SUB-256). Zuvor war das Dokument seit 15.09. nicht mehr
gegen die API-Schicht abgeglichen worden (dort zuletzt 17.09. geändert) — die
DSGVO-Endpoints und der Backup-Mechanismus waren als offen geführt, obwohl
bereits gebaut. Anwaltsfragen wurden dabei bewusst **nicht** beantwortet,
nur der technische Umsetzungsstand korrigiert.

---

## 1. Recht

`docs/06-recht-compliance.md` deckt Urheberrecht (Abschnitt 1), RDG-Abgrenzung
(Abschnitt 2) und die DSGVO-Rechtsgrundlagen (Abschnitt 3) bereits ab. Stand
geprüft, trägt weiterhin — keine Änderung. Ergänzend, was dort fehlt:

| Punkt | Verantwortlich | Aufwand | Phase | Status |
|---|---|---|---|---|
| Impressum (§ 5 DDG) | Gründung/Recht | 0,5 PT | C | Offen — Text steht, sobald Rechtsform/Anschrift final ist. Entwurf mit vollständiger Struktur bereits vorhanden: `docs/legal/01-impressum.md` (Werte als `[Platzhalter]`, hängt an der Rechtsträger-Entscheidung aus `docs/18-release-2-wochen.md` Abschnitt 8) |
| AGB (Nutzungsvertrag, Kündigung, Haftungsbegrenzung für KI-Bewertung) | Recht (extern) | 3–5 PT | C | **Bewusst getragen, keine anwaltliche Prüfung** (Entscheidung 25.09.2026, Interaktion `65179b93-68de-4e49-b2a8-3852889ad7fc` auf SUB-254). Der vorliegende Entwurf mit Haftungsklausel (`docs/legal/02-agb.md` Abschnitt 8) geht ungeprüft live. Restrisiko und Folgen: `docs/31-projektreview-sub254.md` Abschnitt 9.1 |
| Datenschutzerklärung | Recht (extern) | 2–3 PT | C | Offen, hängt an Provider-Liste unten (Auflistung aller Empfänger ist Pflichtangabe). Entwurf mit aus dem Code abgeleiteten Datenkategorien bereits vorhanden: `docs/legal/03-datenschutzerklaerung.md` (Provider-Felder als `[Platzhalter]`, unverändert offen) |
| Widerrufsbelehrung (Fernabsatz, digitale Inhalte) | Recht (extern) | 1 PT | C | **Bewusst getragen, keine anwaltliche Prüfung** (Entscheidung 25.09.2026, Interaktion `65179b93-68de-4e49-b2a8-3852889ad7fc` auf SUB-254). Verzicht auf das Widerrufsrecht bei sofortigem Leistungsbeginn (§ 356 V BGB) läuft über den Entwurf in `docs/legal/04-widerrufsbelehrung.md` Abschnitt „Offene Entscheidung" — die Checkout-Umsetzung (SUB-83) bleibt zu verifizieren, die rechtliche Prüfung des Texts selbst entfällt. Restrisiko und Folgen: `docs/31-projektreview-sub254.md` Abschnitt 9.2 |
| DSGVO Auskunft (Art. 15) | Backend-Dev | 1 PT | C | **Erledigt.** `GET /account/export` (`backend/app/api/v1/account.py`) liefert die vollständige, strukturierte Selbstauskunft (Konto, FSRS-Lernzustand, Reviews, Gutachtenabgaben samt Bewertung) — kein separater Auskunft-Endpoint nötig, deckt Art. 15 mit ab. Getestet in `backend/tests/test_account.py` |
| DSGVO Export (Art. 20) | Backend-Dev | inkl. in M3 | B/C | **Erledigt.** Derselbe `GET /account/export`-Endpoint liefert maschinenlesbares JSON, erfüllt damit auch die Datenübertragbarkeit nach Art. 20. Getestet in `backend/tests/test_account.py` |
| DSGVO Löschung (Art. 17) | Backend-Dev | inkl. in M3 | B/C | **Erledigt.** `POST /account/delete` (`backend/app/api/v1/account.py`) mit Passwort-Bestätigung, Kaskade auf `Review`, `UserCard`, `Submission`, `CaseAccess`, `AnalyzeCall` und Konto selbst; Login danach nicht mehr möglich. Getestet in `backend/tests/test_account.py` (u. a. `test_loeschung_entfernt_free_tier_limit_daten` für die Kaskade) |
| Verarbeitungsverzeichnis (Art. 30) | Recht/Betrieb | 1 PT | C | Offen — internes Dokument (kein Nutzer-Artefakt), listet Zwecke, Kategorien, Empfänger (LLM-Provider, Hosting), Löschfristen. Kann als `docs/18-verarbeitungsverzeichnis.md` intern geführt werden, sobald Provider-Wahl (unten) steht |
| Auftragsverarbeitungsvertrag (AVV) mit LLM-Provider | Recht + Backend-Dev | 1–2 PT | B/C | Offen. **Frage (release-kritisch):** Dürfen Nutzertexte (Gutachten, oft mit personenbezogenen Sachverhaltsdetails im Übungsfall) unpseudonymisiert an einen US-Anbieter gehen? `docs/06-recht-compliance.md` Abschnitt 3 sieht bereits „Pseudonymisierung vor Versand, keine Nutzer-ID im Prompt" und „Provider-Wahl mit EU-Verarbeitung bevorzugt" vor — das ist die Grundsatzentscheidung, aber noch kein AVV. Aktueller Code (`backend/app/core/llm.py`) unterstützt aktuell nur den Provider `anthropic` (US) plus einen heuristischen Offline-Fallback (`llm_provider=none`); ein EU-Provider ist nicht angebunden. Die Transparenz im Produkt ist als eigener Einwilligungspfad bereits gebaut (`POST`/`DELETE /me/ai-consent`, `backend/app/api/v1/consent.py`) und technisch durchgesetzt — `get_evaluator(consented=...)` in `backend/app/services/evaluator.py` erzwingt ohne erteilte Einwilligung den heuristischen (Nicht-LLM-)Pfad, siehe `backend/app/api/v1/gutachten.py`. Getestet in `backend/tests/test_ai_consent.py`. Das ersetzt nicht den AVV selbst — die Grundsatzfrage oben bleibt offen |
| RDG-Abgrenzung, Urheberrecht | — | — | — | Geprüft, Stand aus `docs/06-recht-compliance.md` trägt unverändert |
| RDG-Grenzfall bei KI-generierter Werkbank-Logik (v1.1, nicht v1.0) | Software-Planner | — | — | **Technisch abgefangen, keine anwaltliche Klärung nötig** (Einschätzung nachgezogen 25.09.2026). `docs/27-werkbank-spezifikation.md` Abschnitt 2.4: Die Eingabekontrakt-Durchsetzung (Abschnitt 2.2 dort) hält die RDG-Grenze unabhängig davon, ob die generierte Logik Content nur anzeigt oder daraus etwas berechnet, weil jede Eingabe strukturell auf bereits hinterlegte fiktive Übungsfälle beschränkt bleibt. Nicht release-kritisch für v1.0 (Feature läuft ohnehin hinter dem AVV-Gate oben und einer eigenen Freigabe) |

## 2. Sicherheit

| Punkt | Verantwortlich | Aufwand | Phase | Status |
|---|---|---|---|---|
| Argon2id statt PBKDF2 | Backend-Dev | 1–2 PT | B/C | Offen. Code-Stand: `backend/app/core/security.py` nutzt PBKDF2-HMAC-SHA256 mit 600.000 Iterationen (OWASP-konform) und einem `algo$...`-Präfix im Hash, das den Wechsel vorbereitet. Für M3 vorgesehen (`docs/03-roadmap.md`) — kein Release-Blocker im engeren Sinn (PBKDF2 mit dieser Iterationszahl ist keine Schwachstelle), aber als zugesagter Punkt hier nachgehalten |
| Refresh-Token-Rotation | Backend-Dev | 2–3 PT | B/C | Offen. Code-Stand: Es gibt nur einen Access-Token (`create_access_token`/`decode_access_token`, JWT HS256, Default-TTL 7 Tage), keinen Refresh-Token-Mechanismus. Für M3 vorgesehen. **Risiko bis dahin:** 7 Tage TTL ohne Rotation bedeutet ein gestohlenes Token bleibt bis zu 7 Tage gültig — für den Launch-Umfang (kein Zahlungsdaten-Zugriff über die API) vertretbar, sollte aber vor Gate D stehen |
| Secrets-Handhabung Produktion | Betrieb/Backend-Dev | 1 PT | D | **Erledigt** (SUB-255, Squash `15526a49e13cea7369e815da5bea5be235d3718c` auf `main`). `backend/app/config.py`, Validator `_fail_fast_on_default_jwt_secret_in_production`: bricht beim Start mit `RuntimeError` ab, wenn `SUBSUMO_ENVIRONMENT=production` und `SUBSUMO_JWT_SECRET` noch den öffentlichen Default (`dev-only-insecure-change-me`) trägt. Getestet in `backend/tests/test_config.py` |
| JWT-Secret-Rotation | Backend-Dev | 1 PT | D | Offen, kein Mechanismus vorhanden. **Frage:** Reicht ein manueller Rotationsprozess (Secret tauschen → alle Sessions invalidieren) zum Launch, oder braucht es von Anfang an Key-Versionierung (`kid`-Claim, zwei gültige Secrets während der Rotation)? Für v1.0-Nutzerzahl vermutlich Ersteres ausreichend — als Annahme markiert, keine Entscheidung |
| Backup und Wiederherstellung Nutzerdaten | Betrieb | 1–2 PT Einrichtung, dann laufend | D | **Erledigt.** `backend/scripts/backup_db.py`/`restore_db.py` decken SQLite und PostgreSQL ab, mit Verschlüsselung ruhender Backups (`--encrypt`) und Aufbewahrung ≥ 30 Tage (Default). Automatisiert über `subsumo-backup.timer`/`.service` (täglich 03:00), Restore tatsächlich geprobt (nicht nur Backup-Existenz geprüft) — siehe `docs/22-deploy-runbook.md` Abschnitt „Restore tatsächlich geprobt". Automatisierte Tests in `backend/tests/test_backup_restore.py` |
| Rate-Limit auf Auth-Routen | Backend-Dev | wenige Stunden | B/C | **Erledigt** (SUB-255, Squash `15526a49e13cea7369e815da5bea5be235d3718c` auf `main`, Befund 3.2 aus `docs/31-projektreview-sub254.md`). `backend/app/core/ratelimit.py`: IP-basiertes Sliding-Window auf `POST /auth/login` und `POST /auth/register`, Default 20 Anfragen/60s. Getestet in `backend/tests/test_auth_rate_limit.py` und `backend/tests/test_ratelimit.py`. **Bekannte Grenzen:** (a) In-Memory pro Prozess — kein verteiltes Limit über mehrere Instanzen hinweg; (b) hinter dem in `docs/22-deploy-runbook.md` beschriebenen nginx muss `SUBSUMO_RATE_LIMIT_TRUSTED_PROXIES=127.0.0.1` gesetzt sein, sonst zählt der Limiter alle Anfragen auf einen einzigen Schlüssel |

## 3. Stores und Auslieferung

`docs/06-recht-compliance.md` Abschnitt 4 nennt bereits die Kernpunkte
(Apple IAP-Pflicht für digitale Abos, MSIX-Signierung, Datenschutz+Impressum
je Store). Hier der operative Rest:

**Einordnung nach der Nutzerentscheidung vom 25.09.2026** (SUB-39, Interaktion
`b1739bd0`, 05:50 UTC: `earlyaccess`): Der Release am 29.09. startet als
kostenloser Early Access ohne Bezahlstrecke
(`docs/18-release-2-wochen.md` Abschnitt 5). Das macht Impressum- und
Datenschutzangaben nicht hinfällig — die gelten auch für ein kostenloses,
öffentlich erreichbares Angebot —, entschärft aber gezielt die Zeilen unten,
die an einem **Bezahlvorgang** hängen (IAP-Pflicht, Zahlungsanbieter-Erwähnung
in der Review). Diese werden **erst mit der Paywall fällig** (v1.1), nicht am
Tag 1. Zusätzlich ist die App-Store-Zeile für den Start ohnehin
gegenstandslos, weil iOS unabhängig von Early Access erst v1.1 kommt
(`docs/18` Abschnitt 3.2).

| Punkt | Verantwortlich | Aufwand | Phase | Status |
|---|---|---|---|---|
| Play Store: Entwicklerkonto, Gebühr (einmalig 25 $) | Betrieb | 0,5 PT | D | Offen |
| App Store: Entwicklerkonto, Gebühr (99 $/Jahr, wiederkehrend) | Betrieb | 0,5 PT | D | Offen — für den 29.09. ohnehin gegenstandslos, iOS ist v1.1 (`docs/18` Abschnitt 3.2), unabhängig von der Early-Access-Entscheidung |
| Microsoft Store: Entwicklerkonto (einmalig ~19 $ Individual / ~99 $ Company) | Betrieb | 0,5 PT | D | Offen |
| Altersfreigabe je Store (IARC-Fragebogen o. Ä.) | Betrieb | 0,5 PT | D | Offen — für ein Jura-Lernprodukt ohne Erwachseneninhalte unkritisch, Fragebogen aber Pflicht je Store |
| Datenschutzangaben je Store (Apple „Privacy Nutrition Label", Play „Data Safety") | Betrieb | 1 PT | D | Offen, hängt direkt an der Provider-Liste aus Abschnitt 1 (AVV) — ohne finale Provider-Wahl keine verbindlichen Angaben möglich. **Tag 1 (Play, Early Access):** ohne Zahlungsdaten zu deklarieren, aber die AVV-abhängigen Angaben (LLM-Provider) bleiben unabhängig vom Bezahlstatus offen |
| Review-Richtlinien-Check vor Einreichung (insb. Apple: In-App-Purchase-Pflicht, Zahlungsanbieter-Erwähnung) | Betrieb | 1 PT | D | Offen. Bezieht sich auf Apple/IAP — **mit Paywall und iOS fällig** (beides nicht Tag 1), für den Play-Start am 29.09. nicht release-kritisch |
| **Store-Regeln zu Bezahlinhalten vs. externer Abrechnung** | Produkt/Recht | 0,5 PT Analyse | C | Geklärt in `docs/06-recht-compliance.md` Abschnitt 4: Apple zwingt digitale Abos über IAP (30 %/15 % Provision je nach Umsatzschwelle), Web-Abschluss bleibt separat möglich, darf aber in der iOS-App nicht beworben werden. **Konsequenz fürs Geschäftsmodell:** Preis auf iOS muss die IAP-Provision einkalkulieren, oder iOS-Preis liegt höher als Web-Preis (wie z. B. bei vielen SaaS-Apps üblich) — das ist eine Preisentscheidung für T6/Abrechnung unten, nicht mehr offen als Rechtsfrage. **Mit Paywall/iOS fällig** (v1.1), am Tag 1 ohne Bezahlinhalt und ohne iOS gegenstandslos |

## 4. Abrechnung

**Tag 1 ist Early Access ohne Bezahlstrecke** (Nutzerentscheidung 25.09.2026,
SUB-39 Interaktion `b1739bd0`, 05:50 UTC: `earlyaccess`). Die Kaufstrecke
selbst ist bereits gebaut und getestet (SUB-83, `backend/app/api/v1/billing.py`,
14 Tests) — nur ihre Aktivierung ist auf v1.1 verschoben
(`docs/18-release-2-wochen.md` Abschnitt 5, Nachtrag 25.09.). Die Punkte
unten bleiben notwendig, werden aber **erst mit der Paywall fällig**, nicht
am 29.09.:

| Punkt | Verantwortlich | Aufwand | Phase | Status |
|---|---|---|---|---|
| Zahlungsanbieter-Wahl (Web) | Produkt/Betrieb | 0,5 PT Entscheidung | C | Offen. **Frage:** Stripe (verbreitet, keine deutsche Entität nötig, aber USD-Abrechnungsbeziehung) oder ein EU-Anbieter (z. B. Mollie)? Beeinflusst AVV-Liste und Datenschutzerklärung. **Mit Paywall fällig** — für den Early-Access-Start am 29.09. nicht release-kritisch, aber SUB-83 hat bereits Stripe implementiert, die Frage betrifft nur die endgültige Entscheidung vor Aktivierung |
| Abo-Verwaltung (Pausieren, Wechsel, Rechnungen) | Backend-Dev + Frontend-Dev | 3–5 PT | D | Offen, an Provider-Wahl gekoppelt — die meisten Anbieter liefern Checkout+Portal fertig, Aufwand ist primär Integration, nicht Eigenbau. **Mit Paywall fällig**, nicht Tag 1 |
| Studierendennachweis (falls Studierendenpreis) | Produkt | 1–2 PT | C/D | Offen. **Frage:** Wird ein Studierendenpreis überhaupt eingeführt (aus T6/Marktanalyse noch nicht final entschieden, siehe `docs/14-marktanalyse.md`)? Falls ja: Verifizierung über Uni-E-Mail-Domain (günstig, aber umgehbar) oder Drittanbieter wie SheerID (verlässlicher, kostet pro Verifizierung) — als offene Entscheidung markiert, keine Empfehlung ohne T6-Preisentscheidung. **Mit Paywall fällig**, nicht Tag 1 |
| Umsatzsteuer (digitale Dienstleistung an Privatpersonen, EU-OSS) | Steuerberater | 1–2 PT extern | D | **Am Tag 1 gegenstandslos** — Early Access ohne Entgelt löst keine Umsatzsteuerpflicht aus (Nutzerentscheidung 25.09.2026, `b1739bd0`). **Frage bleibt, wird aber erst mit Paywall-Aktivierung real:** Meldung über das One-Stop-Shop-Verfahren (EU-OSS) für digitale Leistungen an Verbraucher in anderen EU-Ländern, sobald auch außerhalb Deutschlands verkauft wird. Reine Steuerfrage, hier nicht beantwortbar |
| Kündigung und Widerruf (Prozess, nicht nur Text) | Backend-Dev + Support | 1–2 PT | D | Offen — Selbstkündigung im Produkt (kein „Bitte E-Mail schreiben") ist Standard-Erwartung und vermutlich auch regulatorisch erwartet (Kündigungsbutton-Pflicht nach deutschem Recht für Verbraucherverträge seit 2022). **Mit Paywall fällig** — ohne laufendes Abo am Tag 1 gibt es nichts zu kündigen |

## 5. Betrieb

| Punkt | Verantwortlich | Aufwand | Phase | Status |
|---|---|---|---|---|
| Hosting-Entscheidung (EU-Rechenzentrum wegen DSGVO-Datenminimierung) | Betrieb | 1 PT Entscheidung | C | Offen. Sollte mit der LLM-Provider-Frage zusammen entschieden werden — ein EU-Hosting nützt wenig, wenn Gutachtentexte trotzdem an einen US-LLM-Endpunkt gehen |
| Domain app.subsumo.de | Betrieb | 0,5 PT | D | Offen — Registrierung + DNS, geringer Aufwand, aber ohne sie funktioniert kein Store-Listing-Link und keine Datenschutzerklärung-URL |
| Monitoring (Uptime, Error-Tracking Backend) | Backend-Dev | 1–2 PT | D | Offen, kein Tooling im Repo referenziert |
| Crash-/Analytics-Telemetrie (opt-in) | Frontend-Dev + Backend-Dev | 2–3 PT | D | Offen. Leitprinzip aus `docs/03-roadmap.md` M5 „opt-in" ist bereits Produktentscheidung — technisch: Opt-in-Dialog vor erstem Versand, nicht nachträglicher Opt-out |
| Supportkanal + erwartete Antwortzeit | Betrieb | 0,5 PT Einrichtung | D | Offen. **Annahme:** E-Mail-Support mit Antwortzeit-Ziel 2 Werktage zum Launch (kein Chat/Ticket-System nötig bei der erwarteten Nutzerzahl in Phase D) — als Annahme markiert, keine harte Zusage ohne Rückfrage beim Team |
| Kostenschätzung Betrieb/Monat inkl. LLM | Betrieb | siehe unten | — | Geschätzt, siehe Abschnitt 6 |

## 6. Kostenschätzung Betrieb pro Monat

Grobe Schätzung für den Zeitraum um Gate D (Launch, Beta mit 2 Fachschaften,
niedrige dreistellige Nutzerzahl) — **keine Angebotseinholung, Annahme auf
Basis öffentlicher Listenpreise Stand 2026, vor Launch mit echten Angeboten zu
verifizieren**:

| Posten | Schätzung/Monat | Annahme |
|---|---|---|
| Hosting (App-Server + DB, EU-Region, kleine Instanz) | 30–80 € | Ein Backend-Prozess reicht für die Beta-Nutzerzahl, SQLite/Postgres auf derselben oder einer kleinen Managed-DB-Instanz |
| Domain + DNS | ~2 € | `app.subsumo.de`, Standard-TLD-Registrierung |
| LLM-Nutzung (Gutachten-Korrektur) | 150–600 € | Rechnung: ~2.000 Korrekturen/Monat (Beta-Größenordnung) × ~2.000 Input- + 800 Output-Token je Korrektur (Gutachtentext + Erwartungshorizont + Begründung) zu aktuellen Anthropic-API-Preisen für ein Sonnet-Modell. Spannweite deckt Schwankung in Gutachtenlänge ab. Skaliert linear mit Nutzerzahl — größter variabler Kostenblock, sobald über die Beta hinaus skaliert wird |
| KI-Redaktion (Content-Produktion, siehe `docs/08-ki-redaktion.md`) | 50–150 € | Deutlich seltener als Nutzer-Korrekturen, aber längere Prompts (Collector+Reviewer-Pipeline je Karte/Fall) |
| E-Mail-Versand (Transaktions-Mails: Registrierung, Passwort-Reset) | 0–10 € | Kostenlose Stufe der meisten Anbieter reicht für Beta-Volumen |
| Zahlungsanbieter-Gebühren | variabel (~1,5 %+0,25 €/Transaktion) | Kein Fixkostenblock, skaliert mit Umsatz, nicht separat budgetiert |
| Monitoring/Error-Tracking (kostenlose oder kleinste bezahlte Stufe) | 0–25 € | Bei niedriger Nutzerzahl reicht meist eine Free-Tier |
| **Summe (ohne Zahlungsgebühren)** | **~230–870 €/Monat** | Spannweite primär durch LLM-Nutzung getrieben — bei Nutzerwachstum über die Beta hinaus ist dieser Posten neu zu rechnen, nicht die anderen |

**Wichtigste Annahme, die diese Schätzung trägt:** Die LLM-Kosten skalieren
mit Korrekturen/Nutzer, nicht mit Nutzerzahl allein — ein Freemium-Modell mit
unbegrenzten Gutachten-Korrekturen in der Gratisstufe würde diesen Posten
sprengen. Das ist ein Argument für ein Nutzungslimit in der kostenlosen Stufe,
das mit T6/Preisentscheidung abzustimmen ist, nicht hier vorwegzunehmen.

---

## 7. Content-Redaktion

| Punkt | Verantwortlich | Aufwand | Phase | Status |
|---|---|---|---|---|
| Menge und Struktur des Lern-Contents | Content-Koordinator | — | C | **Erledigt.** Stand `main` 25.09.2026, ausgezählt mit `backend/scripts/validate_content.py`: **60 Themen, 446 Karten, 64 Schemata, 60 Fälle — 0 Fehler, 0 Warnungen.** P1 36/36 und P2 24/24 vollständig; P3 (14 Themen) liegt laut `docs/12-content-produktionsplan.md` bewusst nach v1.0. G3 verlangt 180 Karten |
| Deterministisches Normzitat-Gate über den Bestand | Content-Prüfagent | — | C | **Erledigt, mit bekannter Grenze.** 57 der 60 Themen tragen `redaktion.normzitate_geprueft`; die 3 ohne Nachweis sind exakt die M0-Themen ohne `redaktion`-Block, die `docs/08-ki-redaktion.md` ausdrücklich als regulär redigiert einstuft. **Grenze:** Das Gate prüft Existenz und Form eines Zitats, nicht dessen inhaltliche Richtigkeit — ein real existierender Paragraph mit falsch behauptetem Inhalt passiert es unbemerkt. Es läuft zudem nur beim Erzeugen eines Themas, nicht über den Baum ([SUB-251](/SUB/issues/SUB-251), Nach-Release) |
| **Menschliche Stichprobe nach `docs/08-ki-redaktion.md`** | Nutzer (Entscheidung getroffen) | 0 PT | C | **Bewusst ausgesetzt — offenes Risiko, siehe unten.** Nicht erledigt und nicht geplant nachzuholen vor v1.0 |

### 7.1 Bewusst ausgesetztes Gate: die menschliche Stichprobe

**Das ist kein offener Punkt, der noch abgearbeitet wird, sondern eine
getroffene Entscheidung mit einem Restrisiko, das hier stehen bleibt, damit es
nicht stillschweigend mitläuft.**

Entscheidung vom **25.09.2026** auf [SUB-225](/SUB/issues/SUB-225)
(Interaktion `f754f609`, vom Nutzer beantwortet): Option *„Release ohne
menschliche Stichprobe, Gate bewusst ausgesetzt"*. Vorgelegt waren sechs
Optionen, darunter eine verkleinerte Stichprobe und eine Verschiebung des
Content-Freeze; gewählt wurde die Aussetzung.

| | |
|---|---|
| **Was `docs/08-ki-redaktion.md` vorsieht** | Menschliche Stichprobe durch eine Person mit juristischer Vorbildung, ≥ 10 % der KI-erzeugten Inhalte, mind. 2 Themen je Rechtsgebiet (`docs/12` 4.2) |
| **Was tatsächlich vorliegt** | **0 von 60 Themen** haben eine menschliche Prüfsignatur. Alle 57 KI-erzeugten Themen tragen `geprueft_von: reviewer-agent-v1` — ein LLM-Aufruf, keine Person |
| **Material** | Vollständig vorbereitet in [`docs/26-content-stichprobe.md`](26-content-stichprobe.md): 6 stratifizierte P1-Themen, Zitatlisten, Prüfraster, Befundformular. Es fehlt ausschließlich die Durchführung |

**Konkrete Folge, die aus dieser Entscheidung erwächst:**

1. **Normzitate gehen inhaltlich ungeprüft live.** Das deterministische Gate
   fängt erfundene Gesetzeskürzel und nicht existierende Paragraphennummern ab.
   Es fängt **nicht** den Fall „§ 823 BGB existiert, der Karteninhalt behauptet
   aber etwas, das dort nicht steht". Dafür war die menschliche Stichprobe die
   einzige vorgesehene Instanz.
2. **Es gibt derzeit keine zweite Instanz.** Der Norm-Explorer (M2), der
   Zitate maschinell gegen den Gesetzestext prüfen soll, ist nicht gebaut.
   Zwischen Produktion und Nutzer steht damit ausschließlich der LLM-Reviewer.
3. **Die Fehlerklasse ist die für ein Lernprodukt teuerste.** Ein inhaltlich
   falscher Rechtssatz wird von Lernenden per Konstruktion nicht erkannt — sie
   benutzen das Produkt ja, um den richtigen erst zu lernen. Der Schaden fällt
   nicht beim Release auf, sondern später und bei denen, die am wenigsten
   gegenprüfen können.

**Risikobegrenzung, die unabhängig davon greift:** Struktur-Gate (0 Fehler),
LLM-Reviewer-Gate vor jedem Merge, deterministisches Normzitat-Gate für alle
neu erzeugten Themen, der Hinweis „Lernhilfe, keine Rechtsberatung, keine
Note", den jede Ausgabe des Struktur-Checks in der Anwendung selbst trägt
(`docs/legal/02-agb.md` Abschnitt 2.1), und der Haftungsausschluss für
Ergebnisse des Struktur-Checks (ebd. Abschnitt 8: „die Anwendung ist
Lernhilfe, kein Garant für einen Lernerfolg"). Diese Maßnahmen adressieren
Form und Haftung — **nicht** die fachliche Richtigkeit im Einzelfall.

**Empfohlener Nachlauf (nicht release-blockierend, aber nicht ersatzlos
streichbar):** Die vorbereitete Stichprobe nach dem Launch nachholen und
[SUB-251](/SUB/issues/SUB-251) (Normzitat-Gate über den ganzen Baum in der CI)
umsetzen. Beides kostet zusammen weniger als ein Personentag; der Wert liegt
darin, dass die Fehlerklasse aus Punkt 1 dann überhaupt eine Instanz hat.

---

## Zusammenfassung: Was Gate C und Gate D blockiert

Nach `docs/03-roadmap.md` verlangt **Gate C** „keine offenen
Compliance-Punkte" und **Gate D** einen „end-to-end getesteten
Bezahlvorgang" plus vier Plattformen live. Der aktuell blockierende Kern:

1. **AVV/LLM-Provider-Frage** (Abschnitt 1) ist die einzige Frage, die
   mehrere andere Punkte nach sich zieht (Datenschutzerklärung, Verarbeitungs-
   verzeichnis, Store-Datenschutzangaben, Hosting-Region) — sollte zuerst
   entschieden werden, nicht parallel zu den abhängigen Punkten.
2. **DSGVO Export/Löschung/Auskunft-Endpoints** sind inzwischen gebaut
   (`backend/app/api/v1/account.py`, Stand dieser Prüfung: 24.09.2026) —
   dieser Punkt blockiert Gate C nicht mehr.
3. **Umsatzsteuer-OSS** ist eine reine Steuerfrage und braucht weiterhin
   externen Rat (Steuerberater), rechtzeitig vor Gate C zu beauftragen.
   Widerrufsrecht bei Sofortleistung und Haftungsklausel KI-Bewertung
   waren ebenfalls als offene Rechtsfragen geführt, sind aber am
   25.09.2026 als bewusst getragenes Risiko entschieden worden (Abschnitt 1,
   `docs/31-projektreview-sub254.md` Abschnitt 9) — sie blockieren Gate C
   nicht mehr, warten aber auch auf keine externe Beratung mehr.
4. **Tag 1 ist Early Access, nicht Paywall** (Nutzerentscheidung 25.09.2026,
   SUB-39 Interaktion `b1739bd0`, 05:50 UTC: `earlyaccess`). Zwei Punkte
   werden dadurch für den 29.09. **gegenstandslos, nicht erledigt**:
   - **Umsatzsteuer/EU-OSS** (Abschnitt 4): Ohne Entgelt am Tag 1 fällt keine
     Umsatzsteuer an — real wird die Frage erst **mit der
     Paywall-Aktivierung** (v1.1), nicht vor Gate C/D.
   - Der **Bezahlvorgang selbst** bleibt für Gate D „end-to-end getestet"
     (SUB-83, `backend/app/api/v1/billing.py`), muss aber am 29.09. **nicht
     scharfgeschaltet** sein — siehe `docs/18-release-2-wochen.md`
     Abschnitt 5 (Nachtrag 25.09.).

   **Bewusst offen gelassen statt übernommen:** Ob auch die
   Widerrufsbelehrung (Abschnitt 1) am Tag 1 entfällt, hängt daran, ob ein
   kostenloser Vertrag gegen Registrierungs- und Nutzungsdaten unter
   § 312 Abs. 1a BGB („digitale Leistung gegen personenbezogene Daten statt
   Geld") bereits als entgeltlicher Verbrauchervertrag mit Widerrufsrecht
   gilt. Das ist keine Einschätzung, die ohne externe Rechtsberatung getroffen
   werden sollte — Abschnitt 1 bleibt deshalb unverändert auf „Offen, externe
   Prüfung nötig" stehen, nicht auf „gegenstandslos". Dieselbe Vorsicht gilt
   für die Preistabelle in `docs/legal/02-agb.md` Abschnitt 4, die einen
   Preis nennt, der am Tag 1 nicht verlangt wird — diese Anpassung ist nicht
   Teil dieser Prüfung und als Folgeaufgabe an Marketing-Planner ausgelagert.

**Nicht blockierend, aber bewusst in Kauf genommen:** Die menschliche
Content-Stichprobe ist per Nutzerentscheidung vom 25.09.2026 ausgesetzt
(Abschnitt 7.1). Sie taucht hier nicht als Blocker auf, weil sie entschieden
ist — nicht, weil sie erledigt ist. Wer diesen Abschnitt als „Restliste" liest,
soll den Unterschied sehen: Der Content ist mengenmäßig und strukturell fertig,
seine fachliche Richtigkeit ist im Einzelfall von keiner Person gegengeprüft.
