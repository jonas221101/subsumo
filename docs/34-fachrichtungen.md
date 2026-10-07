# Fachrichtungen: eine Plattform, viele Studiengaenge

Subsumo ist als Jura-Lernplattform entstanden (`docs/01-produktvision.md`).
Dieses Dokument beschreibt, wie dieselbe Plattform weitere Studiengaenge
traegt - zuerst Elektrotechnik, Maschinenbau und Lehramt - ohne den
Jura-Kern zu verwaessern und ohne drei Code-Forks zu pflegen. Es ergaenzt
`docs/32-examensvorbereitung.md` (Bundesland, Universitaet, Kurs) und
`docs/33-individualisierung.md` (Lernprofil) um die Dimension darueber:
**die Fachrichtung**.

---

## 1. Entscheidung: Dimension statt Fork

Drei Wege standen zur Wahl:

| Weg | Was es bedeutet | Warum nicht / warum doch |
|---|---|---|
| Ein Fork je Studiengang | eigenes Repo, eigenes Backend, eigene App | Jede Korrektur an FSRS, Planer, Billing, Datenschutz viermal. Nach einem Jahr vier verschiedene Produkte. |
| Ein "generischer" Lernbaukasten | Jura-Begriffe aus dem Kern entfernen, alles neutral benennen | Jura verliert seinen Vorsprung (Gutachtenstil-Analyse, Normzitat-Gate, Landesrecht), die anderen Faecher bekommen nichts Spezifisches. |
| **Fachrichtung als Datenprofil** | derselbe Code, ein Profil je Fachrichtung steuert Inhalte, Begriffe, Methodik-Schalter und Build-Flavor | Gewaehlt. Jura bleibt der Massstab, jedes weitere Fach bekommt dieselbe Mechanik (FSRS, Planer, Lernprofil, Examen-Cockpit) und dort Spezifik, wo sie zaehlt (Einheiten-Gate, Formelkarten, Fallvignetten). |

Konsequenz: Es gibt nicht "die Elektrotechnik-App", sondern **einen
Build-Flavor** (`SUBSUMO_FACH=elektrotechnik`), der die Registrierung
vorbelegt. Ein Konto hat genau eine Fachrichtung, kann sie aber im Profil
wechseln; die Oberflaeche folgt dem Profil, nicht dem Flavor.

## 2. Das Fachrichtungs-Profil

Jede Fachrichtung ist eine YAML-Datei unter `content/fachrichtungen/<slug>.yaml`
(Format in `docs/05-content-pipeline.md`):

| Feld | Zweck | Wirkung im Code |
|---|---|---|
| `areas` | Fachgebiete (Jura: Rechtsgebiete) mit `slug`, `title`, `kurz` | `bundle.area_map`: jedes Thema und jeder Kurs gehoert ueber `area` genau einer Fachrichtung; Schwerpunkte im Lernprofil, Examensreife je Fachgebiet, Filter-Chips in der App |
| `begriffe` | Oberflaechen-Wording (`fall` = Fall / Aufgabe / Fallvignette, `gutachten`, `schema`, `norm`, `examen`, ...) | `AppState.begriff(key, fallback)` in Tab-Labels, Ueberschriften, Buttons |
| `kartentypen` | erlaubte Kartentypen mit Anzeigename (`formel`, `verfahren` neu) | Content-Loader lehnt fremde Typen ab; Formelkarten brauchen `einheiten` |
| `methodik.gutachtenstil_analyse` | Obersatz/Definition/Subsumtion/Ergebnis pruefen? | `examen.gutachtenstil_aktiv`: aus → `neutral_report`, Bewertung nur gegen den Erwartungshorizont (`evaluator._gesamtquote`) |
| `methodik.norm_gate` | Paragraphen gegen die Positivliste pruefen? | KI-Redaktion: an → `norm_gate.check_norms`, aus → `fach_gate.check_fach` |
| `methodik.einheiten_gate` | technische Fachrichtung? | Fach-Gate: `§`-Zitate verboten, Formelkarten brauchen `einheiten` und eine Gleichung |
| `methodik.bundesland_profile` | gibt es landeseinheitliche Pruefungen? | App zeigt das Bundesland-Dropdown nur dann; Cockpit ohne Bundesland-Profil bleibt ehrlich leer |
| `methodik.landesrecht` | Landesrecht-Themen moeglich? | Kurse duerfen `landesrecht_kategorien` tragen (Lehramt: `schulrecht`) |
| `pruefung` | Name, Hinweis, Klausurverteilung ueber die eigenen Fachgebiete | Examensreife-Gewichtung ohne Bundesland-Profil |

Jura ist als `content/fachrichtungen/jura.yaml` selbst ein Profil
(`mensch-freigegeben`); laeuft der Server ohne geladene Profile, liefert
`examen.fachrichtung_info` einen Jura-Fallback mit den drei Rechtsgebieten,
damit bestehende Installationen nichts merken.

## 3. Was sich je Fachrichtung unterscheidet

| | Jura | Elektrotechnik | Maschinenbau | Lehramt |
|---|---|---|---|---|
| Fachgebiete | Zivilrecht, Strafrecht, Oeffentliches Recht | GET, Elektronik, Signale/Systeme/Regelung | Technische Mechanik, Thermodynamik, Konstruktion/Werkstoffe | Bildungswissenschaften, Didaktik, Schulrecht/Praxis |
| "Fall" heisst | Fall | Aufgabe | Aufgabe | Fallvignette |
| Methodik-Pruefung | Gutachtenstil-Analyse | keine (neutraler Report) | keine | keine |
| Redaktions-Gate | Normzitat-Gate | Fach-Gate mit Einheiten | Fach-Gate mit Einheiten | Fach-Gate (nur Loesungsschritte) |
| Pruefung | Staatsexamen je Bundesland | Modulklausuren der Hochschule | Modulklausuren | Staatsexamen oder M.Ed., je Land |
| Bundesland-Profil | ja (16) | nein | nein | noch nicht (Folgearbeit) |
| Landesrecht | ja | nein | nein | ja (`schulrecht`) |

Was gleich bleibt: FSRS mit Ziel-Retention je Kartentyp, Planer, Lernprofil
(Semester, Ziel, Schwerpunkte, Fokus/Pause, Sicherheitsniveau, Ruhetage),
Examen-Cockpit mit Kurs-Decks, Examensreife mit offengelegter Formel,
eigene Decks, Billing, Datenschutz.

## 4. Inhalte und Universitaeten

Startbestand je neuer Fachrichtung (alle `redaktion.status: in-pruefung`,
Zahlenwerte nachgerechnet, Texte Eigenformulierung):

| Fachrichtung | Themen | Karten | Schemata | Aufgaben | Kurse | Universitaeten |
|---|---|---|---|---|---|---|
| Elektrotechnik | 6 | 46 | 6 | 6 | 6 (inkl. Repetitorium) | 9 (TU9) |
| Maschinenbau | 6 | 48 | 6 | 6 | 6 (inkl. Repetitorium) | 9 (TU9) |
| Lehramt | 6 | 48 | 6 | 6 | 4 (inkl. Examenskurs) | 13 (TU9 + sechs Volluniversitaeten) |

Themen liegen unter `content/<fachrichtung>/` (Jura weiterhin je
Rechtsgebiet unter `content/zivilrecht/` usw.). Kurse folgen dem kanonischen
Studienverlauf (`content/examen/kurse/et-*.yaml`, `mb-*.yaml`, `la-*.yaml`);
jede Universitaet nennt in `fachrichtungen`, was sie anbietet, und fuehrt nur
Kurse dieser Fachrichtungen (der Validator prueft das). Nebenfach-Kurse
(Technische Mechanik fuer ET) stehen bewusst nicht im Plan: Themen sind je
Fachrichtung sichtbar, ein fremdes Deck waere im Cockpit leer.

Die neuen Themen mit ihren Aufgaben:

- **ET**: Ohm/Kirchhoff (Spannungsteiler), komplexe Wechselstromrechnung
  (RC-Reihe am Netz), Diode/Gleichrichter (B2 mit Ladekondensator),
  OPV-Grundschaltungen (invertierender Verstaerker mit Saettigung),
  LTI/Faltung/Uebertragungsfunktion (RC-Tiefpass), Regelkreis/PID
  (P-Regler an PT1).
- **MB**: Statik (Balken auf zwei Stuetzen), Festigkeit/Biegung
  (Rechteckquerschnitt), erster Hauptsatz (isochore Erwaermung),
  Kreisprozesse (Otto vs. Carnot), Zugversuch (Rundprobe),
  Schraubenverbindung (M10 8.8, Reibschluss).
- **Lehramt**: Lerntheorien (Mathe-Verweigerung), Classroom Management
  (Uebergang in die Gruppenarbeit), Unterrichtsplanung (Doppelstunde
  Industrialisierung), Leistungsbeurteilung (Aufsatzkorrektur),
  Aufsichtspflicht (Chemieraum), Inklusion/Nachteilsausgleich (LRS-Klausur).

## 5. Sichtbarkeit und Profilwechsel

- `examen.visible_topics_query` filtert auf `Topic.fachrichtung` (plus
  Landesrecht des eigenen Bundeslands). Faelligkeit, Lernplan, Cockpit,
  Lernprofil-Validierung und Decks haengen daran.
- Die oeffentlichen Katalog-Endpunkte (`/v1/content/topics|cards|schemata|cases`)
  nehmen `?fachrichtung=` entgegen; die App schickt den Slug aus Profil,
  Cockpit oder Flavor (`AppState.fachrichtungSlug`).
- Registrierung: `fachrichtung` optional (Default `jura`, unbekannt → 422).
- Profilwechsel (`PATCH /v1/auth/me`): Universitaet wird abgewaehlt, wenn sie
  die neue Fachrichtung nicht anbietet; Schwerpunkte, Fokus/Pause und eigene
  Decks werden geleert, weil sie auf fremde Fachgebiete zeigen wuerden.
  Lernfortschritt (`user_cards`) bleibt erhalten und wird beim Rueckwechsel
  wieder sichtbar.
- Universitaet muss die Fachrichtung anbieten (422 sonst).

## 6. KI-Redaktion je Fachrichtung (Paperclip)

Die Redaktion ist ein Firmenagenten-Baum (`ops/agents/content/`,
`ops/mission-control/README.md`): Der Jura-Content-Koordinator bleibt die
Spitze; je weiterer Fachrichtung gibt es ein Team aus Koordinator, einem
Redakteur je Fachgebiet und einem Pruefagenten
(`ops/agents/content/<fachrichtung>/`). Technisch:

- `redaktion_cli.py backlog --area <fachgebiet>` - das `BACKLOG`-Dict kennt
  alle neun neuen Fachgebiete mit drei bis vier Themen Rueckstand.
- Die Pipeline (`pipeline.py`) ermittelt das Fachrichtungs-Profil aus dem
  Fachgebiet (`fach_profil_fuer`), gibt dem Collector Begriffe, Kartentypen
  und Fachregeln mit (`prompts.regeln_fuer`), schaltet je `methodik` das
  Normzitat- oder das Fach-Gate und legt die Datei unter
  `content/<fachrichtung>/` ab.
- Das Fach-Gate (`fach_gate.py`) ist deterministisch: Formelkarten ohne
  `einheiten` oder Gleichung, `§`-Zitate in technischen Faechern und
  Aufgaben ohne `steps` werden abgelehnt.

## 7. Build-Flavors

`flutter build ... --dart-define=SUBSUMO_FACH=<slug>` setzt `kFachrichtung`.
Der manuelle Build-Workflow (`.github/workflows/manual-builds.yml`) hat
dafuer den Input `fach` (leer = jura). Ein Flavor aendert nur die
Vorbelegung bei der Registrierung und den Filter der oeffentlichen
Landing-Page - Begriffe, Fachgebiete und Decks kommen zur Laufzeit aus dem
Cockpit.

## 8. Grenzen und Folgearbeit

- Alle neuen Inhalte sind `in-pruefung`: fachliche Freigabe durch Menschen
  (Fachschafts-Beta, `docs/28`) steht aus; der Validator zaehlt sie als
  Warnung, nicht als Fehler.
- Lehramt hat noch keine Bundesland-Profile, obwohl das Staatsexamen
  Landesrecht ist; das Profil sagt das im `pruefung.hinweis`.
- Keine Formel-Eingabe oder Einheitenpruefung der Nutzerantwort: Die
  Bewertung technischer Aufgaben ist Keyword-Heuristik gegen Zahlenwerte
  (deutsche Schreibweise, Varianten in `keywords`). Ein Rechenweg-Parser ist
  Folgearbeit.
- Fachwissenschaften des Lehramts (Mathematik, Deutsch, ...) sind eigene
  Fachrichtungen, nicht Teil von `lehramt`.
- Universitaets-Kurslisten sind der kanonische Verlauf, keine lokalen
  Modulhandbuecher (`titel_lokal`, `semester` wie in docs/32 nachtragen).
