# Datenschutzerklärung (Entwurf)

> Entwurf zur Prüfung, keine Rechtsberatung. Datenkategorien sind aus
> `backend/app/models.py` und dem tatsächlichen Code abgeleitet, nicht
> angenommen. `[Platzhalter]` markiert Werte, die an offenen
> Provider-Entscheidungen hängen.

## 1. Verantwortlicher

`[Platzhalter: Anbieter aus 01-impressum.md]`, Kontakt für
Datenschutzanfragen: `[Platzhalter E-Mail, z. B. datenschutz@subsumo.de]`.

Ein:e Datenschutzbeauftragte:r ist nach § 38 BDSG erst ab in der Regel 20
Personen bestellt, die ständig mit der automatisierten Verarbeitung
personenbezogener Daten befasst sind — bei der aktuellen Teamgröße (1–2
Entwickler:innen, Teilzeit-Fachredaktion, siehe
`docs/17-release-readiness.md`) nicht erreicht. **Vor Wachstum des Teams neu
zu prüfen.**

## 2. Welche Daten wir verarbeiten und wozu

Grundlage dieser Auflistung ist das tatsächliche Datenmodell
(`backend/app/models.py`), nicht eine generische Vorlage.

| Datenkategorie | Konkrete Felder | Zweck | Rechtsgrundlage |
|---|---|---|---|
| Kontodaten | E-Mail-Adresse, Passwort (als Hash gespeichert, PBKDF2-HMAC-SHA256, nie im Klartext), Anzeigename (optional) | Registrierung, Login, Konto­verwaltung | Art. 6 I b DSGVO (Vertragserfüllung) |
| Lernplanungsdaten | Examensdatum (optional), tägliches Lernbudget in Minuten | Personalisierter Lernplan | Art. 6 I b DSGVO |
| Lernfortschrittsdaten | Ereignisstrom je Wiederholung (`reviews`: welche Karte, Bewertung „nochmal/schwer/gut/leicht", Zeitstempel, Bearbeitungsdauer); daraus abgeleiteter Wiederholungszustand je Karte (`user_cards`: Intervall, Schwierigkeit, Fälligkeit) | Spaced-Repetition-Lernalgorithmus (FSRS), damit fällige Karten korrekt vorgeschlagen werden | Art. 6 I b DSGVO |
| Eingereichte Gutachtentexte | Volltext der Einreichung zu einem Übungsfall, Bearbeitungsdauer, Struktur-Score, ggf. Punktzahl, Auswertungsbericht (`submissions`) | Struktur- und Stil-Check als Lernhilfe | Art. 6 I b DSGVO |
| Zahlungsbezogene Daten | Tarifstatus (Free/Pro), **keine** Kartendaten im eigenen System — diese verarbeitet ausschließlich der Zahlungsdienstleister (Abschnitt 4) | Freischaltung des Pro-Tarifs | Art. 6 I b DSGVO |

**Was wir bewusst nicht erheben:** Klarname (Anzeigename ist frei wählbar und
optional), Geburtsdatum, Zuordnung zu einer bestimmten Universität, es sei
denn freiwillig im Anzeigenamen angegeben.

## 3. Kein Einsatz von Sprachmodellen mit Nutzertexten (Stand v1.0)

**Wichtiger Unterschied zu vielen KI-gestützten Lern-Apps:** In dieser
Version (v1.0) verlässt **kein** eingereichter Gutachtentext das eigene
System in Richtung eines externen Sprachmodell-Anbieters. Die Auswertung im
Struktur-Check erfolgt vollständig heuristisch auf dem eigenen Server
(`backend/app/services/evaluator.py`, `SUBSUMO_LLM_PROVIDER=none`). Es gibt
daher in v1.0 **keine Auftragsverarbeitung mit einem KI-Anbieter** und keine
Übermittlung von Gutachtentexten in ein Drittland zu diesem Zweck.

Sollte ab v1.1 eine kalibrierte KI-Korrektur eingeführt werden, wird diese
Erklärung vor Einführung um Auftragsverarbeiter, Verarbeitungsort und
Rechtsgrundlage ergänzt — das ist in `docs/17-release-readiness.md`
Abschnitt 1 bereits als Vorbedingung (AV-Vertrag, Pseudonymisierung vor
Versand) vermerkt.

## 4. Empfänger und Auftragsverarbeiter

| Empfänger | Zweck | Status |
|---|---|---|
| Hosting-Anbieter (App-Server, Datenbank) | Technischer Betrieb der Anwendung | `[Platzhalter: Anbietername]` — EU-Rechenzentrum vorgesehen (`docs/17-release-readiness.md` Abschnitt 5), Anbieter zum Zeitpunkt dieses Entwurfs noch nicht final gewählt |
| Transaktions-E-Mail-Versand | Versand von Registrierungs- und Passwort-Reset-E-Mails | `[Platzhalter: Anbietername]` — noch nicht final gewählt (`docs/19-kosten-preis-budget.md` Abschnitt 1) |
| Monitoring/Fehler-Tracking | Betriebssicherheit, Fehlerdiagnose | `[Platzhalter: Anbietername]` — noch nicht final gewählt, siehe [SUB-86](/SUB/issues/SUB-86) |
| **Stripe** (Zahlungsdienstleister) | Abwicklung von Zahlungen für den Pro-Tarif | **Ab Freischaltung der Kaufstrecke** ([SUB-83](/SUB/issues/SUB-83), Gate G2). Stripe verarbeitet Zahlungsdaten eigenverantwortlich als datenschutzrechtlich Verantwortlicher; welche Kontodaten (mind. E-Mail) an Stripe zur Kontozuordnung übermittelt werden, ist bei Integration final zu dokumentieren. Zu prüfen: EU-Vertragsentität (Stripe Payments Europe, Ltd.) vs. US-Entität und ggf. nötige Garantien (Standardvertragsklauseln) |

**Kein Empfänger in v1.0:** Analyse-/Tracking-Dienste, Werbenetzwerke,
Social-Media-Plug-ins. Es gibt keine solchen Integrationen im Code.

## 5. Speicherdauer

- **Kontodaten:** bis zur Löschung des Kontos durch die nutzende Person.
- **Lernereignisse (`reviews`):** Diese Tabelle ist bewusst ein
  unveränderlicher Ereignisstrom (`docs/04-datenmodell.md`), aus dem der
  aktuelle Lernstand jederzeit neu berechnet wird. Es gibt zum Zeitpunkt
  dieses Entwurfs **keine automatische Löschfrist** für einzelne
  Lernereignisse vor einer vollständigen Kontolöschung. **Menschliche Prüfung
  nötig:** Ist eine Speicherfristbegrenzung (z. B. Aggregation/Pseudonymisierung
  alter Ereignisse nach X Jahren) erforderlich, oder genügt vollständige
  Löschung bei Kontolöschung? Gehört ins noch offene Verarbeitungsverzeichnis
  (`docs/17-release-readiness.md` Abschnitt 1).
- **Eingereichte Gutachtentexte:** wie Kontodaten, bis zur Löschung des
  Kontos, sofern nicht vorher durch die nutzende Person entfernt.

## 6. Betroffenenrechte

Nutzer:innen haben nach Art. 15–21 DSGVO das Recht auf Auskunft,
Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit
und Widerspruch sowie ein Beschwerderecht bei einer Datenschutz-
Aufsichtsbehörde.

**Umsetzung im Produkt:** Export (Art. 20, maschinenlesbares Format) und
vollständige Löschung (Art. 17, inklusive Lernereignisse und Einreichungen)
sind als Selbstbedienungsfunktion in den Kontoeinstellungen vorgesehen
([SUB-84](/SUB/issues/SUB-84), Ziel-Termin Gate G4). **Zum Zeitpunkt dieses
Entwurfs existiert im Backend nur `/me` (GET/PATCH), noch kein Export- oder
Löschendpunkt** (`backend/app/api/v1/auth.py`). **Vor Veröffentlichung dieser
Erklärung zu verifizieren:** Ist die Funktion bis zum Redaktionsschluss live?
Falls nicht, muss dieser Absatz auf den tatsächlich verfügbaren Weg
(Anfrage per E-Mail an die Kontaktadresse in Abschnitt 1) angepasst werden —
sonst behauptet der Text eine nicht existierende Funktion.

## 7. Keine Verarbeitung für Kinder

Subsumo richtet sich an volljährige Jurastudierende und wird nicht gezielt an
Minderjährige vermarktet oder für sie angeboten.

## 8. Cookies und lokale Speicherung

Siehe gesonderten `05-cookie-hinweis.md`.

---

**Quellen/Begründung:** Datenkategorien und Zwecke direkt aus
`backend/app/models.py` (`User`, `Review`, `UserCard`, `Submission`) und
`docs/04-datenmodell.md`; Rechtsgrundlage Vertragserfüllung und
Datenminimierungs-Grundsatz wörtlich aus `docs/06-recht-compliance.md`
Abschnitt 3; kein-LLM-Feststellung aus `docs/18-release-2-wochen.md`
Abschnitt 2 und `backend/app/config.py` (`llm_provider: str = "none"`);
Empfänger-Liste aus `docs/17-release-readiness.md` Abschnitt 1/5/6 und
`docs/19-kosten-preis-budget.md` Abschnitt 1; Betroffenenrechte-Umsetzungsstand
aus `backend/app/api/v1/auth.py` (Code-Stand geprüft: nur `/me`, kein
Export/Delete) und `docs/17-release-readiness.md` Abschnitt 1.
**Menschliche Rechtsprüfung nötig:** Provider-Platzhalter befüllen sobald
final gewählt (Hosting, E-Mail, Monitoring), Stripe-Vertragsentität/Drittland-
Frage klären, DSB-Schwelle bei Teamwachstum neu prüfen, Speicherfrist für
Lernereignisse entscheiden, Betroffenenrechte-Absatz erst veröffentlichen,
wenn SUB-84 tatsächlich live ist.
