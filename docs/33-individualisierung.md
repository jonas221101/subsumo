# Individualisierung als USP

Ergaenzt `docs/16-innovationsthesen.md` um eine fuenfte These und
`docs/32-examensvorbereitung.md` um die Schicht darueber. Kurzfassung: Kein
Wettbewerber im Feld (`docs/14-marktanalyse.md`) passt die *Lernmechanik*
an die Person an - Jurafuchs, Constellatio und Anki liefern denselben
Stapel und denselben Rhythmus fuer alle, die Repetitorien denselben
Jahreskurs. Subsumo kann es, weil die Bausteine dafuer schon da sind: FSRS
mit Ziel-Retention, ein Planer mit Prioritaeten, Themen mit Relevanz, ein
Erwartungshorizont mit Pruefpunkten. Dieses Dokument beschreibt, wie daraus
ein Produktversprechen wird, und was davon gebaut ist.

---

## 1. These

**Individualisierung ist der USP, wenn sie Verhalten aendert - nicht, wenn
sie Anzeige aendert.** Ein Profilbild, ein Name im Header und ein Dark Mode
sind Personalisierung; sie verkaufen nichts. Der Unterschied entsteht, wenn
dieselbe App fuer zwei Nutzer *anders lernt*: andere Karten zuerst, andere
Intervalle, ein anderer Wochenplan, ein anderer naechster Schritt, ein
anderer Technik-Tipp. Jede Stellschraube in Abschnitt 4 hat deshalb eine
Spalte "Wirkung im Code"; eine Stellschraube ohne Wirkung wird nicht gebaut.

Sieben Dimensionen, in denen sich Jurastudierende unterscheiden und in denen
Subsumo sie unterschiedlich behandelt:

| Dimension | Frage | Woher | Wirkt auf |
|---|---|---|---|
| Ort | Wo wird geprueft? | Bundesland, Universitaet (docs/32) | Landesrecht-Sichtbarkeit, Klausurgewichtung, Kurs-Decks |
| Zeit | Wann? Wie weit bin ich? | Examensdatum, Semester | Phase, Semesterstoff, Persona |
| Ziel | Wofuer lerne ich gerade? | Ziel, Zielnote | Persona, naechster Schritt, Tonalitaet der Empfehlung |
| Stoff | Was zaehlt fuer mich mehr, was gar nicht? | Schwerpunkte, Fokus, Pause, eigene Decks | Reihenfolge neuer Karten, Planer-Prioritaet, Stapelfilter |
| Rhythmus | Wann kann ich, wann nicht? | Ruhetage, Klausurtag, Wochenklausur, Tagesbudget, neue Karten/Tag | Planer, Kartenstapel, Klausurvorschlag |
| Gedaechtnis | Wie sicher muss es sitzen? | Sicherheitsniveau | FSRS-Ziel-Retention, damit Intervalle und Wiederholungslast |
| Fehler | Woran scheitere ich? | Abgaben (Pruefpunkte, Strukturfehler) | Schwachstellen, Technik-Tipp, naechster Schritt |

Ort und Zeit sind seit docs/32 gebaut. Dieses Dokument liefert die uebrigen
fuenf als **Lernprofil**.

---

## 2. Abgrenzung

- **Keine Gamification, keine Motivations-Personalisierung.** Streaks,
  Abzeichen und Konfetti sind in `docs/16` Abschnitt 5 verworfen; das gilt
  auch in personalisierter Form ("dein persoenlicher Streak").
- **Kein KI-Tutor.** Der naechste Schritt ist regelbasiert und erklaert
  (`lernprofil.next_step`), kein LLM-Chat. Die Regeln stehen im Code und
  in Abschnitt 5 - jeder Schritt hat eine Begruendung, die der Nutzer lesen
  kann.
- **Keine Prognose.** Die Zielnote steuert, was empfohlen wird, nicht eine
  "voraussichtliche Note". Examensreife bleibt Beschreibung (docs/32
  Abschnitt 5).
- **Kein Profiling ohne Nutzen.** Jedes Profilfeld ist vom Nutzer gesetzt,
  jederzeit aenderbar, in der Selbstauskunft (Art. 15 DSGVO) enthalten und
  wird mit dem Konto geloescht. Es gibt keine implizite Ableitung aus
  Nutzungsdaten ausser den Abgaben, die der Nutzer selbst einreicht.

---

## 3. Umsetzungsstand

| Baustein | Wo | Status |
|---|---|---|
| `User.lernprofil` (JSON), Schema `LernprofilIn` mit Defaults und Validierung | `backend/app/models.py`, `schemas.py` | vorhanden |
| `GET/PUT /v1/me/lernprofil` mit fachlicher Pruefung (Themen sichtbar, Fokus/Pause disjunkt, Deck-Slugs) | `backend/app/api/v1/lernprofil.py` | vorhanden |
| Wirkung im Kartenstapel: Pause, Fokus/Schwerpunkt-Sortierung, neue Karten/Tag | `backend/app/api/v1/learn.py` | vorhanden |
| Wirkung im Gedaechtnismodell: Sicherheitsniveau verschiebt die Ziel-Retention | `learn.py` (`submit_reviews`), `services/lernprofil.py` | vorhanden |
| Wirkung im Planer: Ruhetage, Klausurtag, Wochenklausur, Themengewicht | `services/planner.py`, `api/v1/plan.py` | vorhanden |
| Eigene Decks als Stapelfilter (`deck=mein-*`) und im Cockpit | `services/examen.py` | vorhanden |
| Persona und naechster Schritt (regelbasiert, mit Begruendung) | `services/lernprofil.py` | vorhanden |
| Semesterstoff-Reife, Technik-Tipp zum haeufigsten Strukturfehler | `services/examen.py`, `services/lernprofil.py` | vorhanden |
| App: Lernprofil-Seite, "Naechster Schritt"-Karte, Lernprofil-Karte, eigene Decks, Technik-Tipp | `app/lib/pages/lernprofil_page.dart`, `examen_page.dart` | vorhanden |
| Tests | `backend/tests/test_lernprofil.py` (16), `app/test/lernprofil_page_test.dart` (3), `examen_page_test.dart` (+1) | vorhanden |
| Selbstauskunft enthaelt Lernprofil, Bundesland, Universitaet | `api/v1/account.py` | vorhanden |

---

## 4. Das Lernprofil

Ein JSON-Feld am Nutzer, validiert ueber `LernprofilIn`. Jedes Feld hat
einen Default, mit dem sich die App exakt wie vor der Individualisierung
verhaelt - ein leeres Profil ist kein Sonderfall.

```json
{
  "semester": 4,
  "ziel": "semesterklausur",
  "zielnote": 9,
  "schwerpunkte": ["strafrecht"],
  "ruhetage": [6],
  "klausur_wochentag": 2,
  "wochenklausur": true,
  "neue_karten_pro_tag": 10,
  "sicherheitsniveau": "standard",
  "themen_fokus": ["sr-bt-betrug"],
  "themen_pausiert": ["zr-bgb-at"],
  "eigene_decks": [{"slug": "mein-vermoegen", "title": "Vermoegen", "topic_slugs": ["sr-bt-betrug", "sr-bt-diebstahl"]}]
}
```

### 4.1 Stoff: Schwerpunkte, Fokus, Pause

`lernprofil.topic_weight(profil, slug, area)` liefert je Thema ein Gewicht:
pausiert = 0, Fokus x 1,5, Schwerpunkt-Rechtsgebiet x 1,25 (kumulativ). Es
wirkt an drei Stellen:

- **Neue Karten** (`/cards/due`): Sortierschluessel `relevance x weight`
  statt nur `relevance`; pausierte Themen fallen aus faelligen *und* neuen
  Karten heraus. Sortiert wird ueber alle ungesehenen Karten, nicht ueber
  eine Vorauswahl - sonst liefe ein Fokus-Thema am Ende des Alphabets an der
  Gewichtung vorbei.
- **Planer** (`TopicInput.weight`): Prioritaet `relevance x (1 - mastery) x
  weight`; pausierte Themen erreichen den Planer gar nicht.
- **Naechster Schritt**: das schwaechste Thema wird nach derselben
  Prioritaet bestimmt.

Pause ist fuer Stoff, den jemand anderswo abgedeckt hat (Repetitorium,
bereits geschriebene Klausur), oder der fuer das aktuelle Ziel nicht zaehlt.
Die Coverage im Dashboard zaehlt pausierte Themen weiterhin - sie sind
Pflichtstoff, nur nicht *jetzt*. Das ist die ehrliche Variante; eine
"Coverage ohne Pausiertes" waere Selbstbetrug.

### 4.2 Eigene Decks

Ein eigenes Deck ist eine Themenauswahl mit Titel (`mein-<slug>`), sonst
nichts - keine kopierten Karten, keine eigene Lernhistorie. Es wird wie ein
Kurs-Deck aufgeloest (`examen.resolve_eigenes_deck`: Themen mit
Kartenzustand, Faelle) und ueber `/cards/due?deck=mein-...` gelernt. Typischer
Fall: "Vorlesungsklausur Schuldrecht in drei Wochen" - drei Themen, ein Deck,
fertig. Maximal 20 Decks, ein Deck mindestens ein Thema.

### 4.3 Gedaechtnis: Sicherheitsniveau

FSRS plant Intervalle auf eine Ziel-Retention (`srs.DESIRED_RETENTION_BY_TYPE`,
z. B. 0,92 fuer Definitionen). Das Sicherheitsniveau verschiebt sie um
-0,04 ("kompakt"), 0 ("standard") oder +0,04 ("sicher"), begrenzt auf
0,80 bis 0,97. Wirkung bei einer Karte mit 30 Tagen Stabilitaet und einer
"Gut"-Bewertung: "sicher" plant das naechste Intervall kuerzer als
"kompakt" (getestet in `test_sicher_plant_kuerzere_intervalle_als_kompakt`).
Ueber hunderte Karten ist das der Unterschied zwischen 40 und 60 faelligen
Karten am Tag - deshalb steht der Hinweis auf die Wiederholungslast direkt
neben dem Schalter.

Warum nicht frei einstellbar (0,80 bis 0,97 als Slider)? Weil niemand weiss,
was 0,87 bedeutet. Drei benannte Stufen mit einem Satz Konsequenz sind
verstaendlich; die Zahl dahinter steht im Code.

### 4.4 Zeit und Ziel: Semester, Ziel, Zielnote, Persona

Aus `ziel`, `semester` und `User.exam_date` folgt eine von vier Personas
(`lernprofil.persona`), benannt nach den Lernpfaden in
`docs/13-lernarchitektur.md` Abschnitt 2:

| Persona | Bedingung | Einstiegspunkt |
|---|---|---|
| `einstieg` (Lena) | Ziel Orientierung/Zwischenpruefung, oder Semester <= 2, oder nichts gesetzt | Deck mit der geringsten Reife im Semesterstoff |
| `aufbau` (Jonas) | Semester >= 3, Ziel Semesterklausur | Fall zum Schwachpunkt, sonst Fall zu einem gewussten Thema |
| `examen` (Mira) | Ziel Examen oder Examensdatum gesetzt | Klausurtag, Schwachstellen, dann Plan |
| `wiederholung` | Ziel Wiederholung | Schwachstellen zuerst |

Der **Semesterstoff** (`examen.semesterstoff`) ist die Reife ueber alle
Kurs-Decks bis zum aktuellen Semester - fuer Lena die relevante Zahl, waehrend
die Examensreife fuer sie noch bei 5 % steht. Die Zielnote aendert heute nur
die Begruendungen und ist als Feld fuer die Kalibrierung reserviert (Abschnitt
7); sie erzeugt bewusst keine Prognose.

### 4.5 Rhythmus: Ruhetage, Klausurtag, Wochenklausur, neue Karten

`generate_plan` bekommt `rest_weekdays`, `klausur_weekday` und `klausuren`
aus dem Profil (`plan.py`, Cockpit). Wer samstags arbeitet, schreibt
mittwochs; wer keine Wochenklausur will, bekommt im Plan keine - der
Klausurvorschlag im Cockpit bleibt sichtbar, damit die Entscheidung
umkehrbar ist. `neue_karten_pro_tag` ist der Default fuer `new_limit` in
`/cards/due`; ein Client kann ihn weiterhin explizit uebersteuern.

### 4.6 Fehler: Technik-Tipp

Der haeufigste Strukturfehler aus den letzten Abgaben (`weak_spots`) wird
ueber `lernprofil.TECHNIK_TIPPS` zu einem Tipp mit Titel und zwei Saetzen:
`kein_obersatz`, `sprung_zum_ergebnis`, `keine_subsumtion`, `urteilsstil`,
`offener_obersatz`, `keine_definition`, `kein_ergebnis`, `keine_norm`,
`gesetz_fehlt`, `schachtelsatz`. Das ist die Kategorie-A-Konsequenz aus
`docs/13` Abschnitt 3.2 in ihrer einfachsten Form - statt einer
"Technik-Karte" im FSRS-Stapel ein Hinweis an der Stelle, an der der Nutzer
seine Schwachstellen ohnehin ansieht. Technik-Karten als eigener Kartentyp
bleiben Folgeticket (Abschnitt 7).

---

## 5. Der naechste Schritt

`lernprofil.next_step` ist eine geordnete Regelliste; die erste passende
Regel gewinnt, jede liefert Titel, Begruendung und genau eine Handlung:

1. **Kein Lernprofil** -> "Lernprofil einrichten".
2. **Faellige Karten** (ohne pausierte Themen) -> "n faellige Karten
   wiederholen". Wiederholungen haben immer Vorrang (Planer-Regel 1).
3. **Klausurtag** (Wochenklausur aktiv, heute ist der gewaehlte Tag) ->
   Klausurvorschlag im Klausurmodus.
4. **Persona einstieg** -> Deck mit der geringsten Reife innerhalb des
   Semesterstoffs, Examenskurse ausgenommen.
5. **Persona aufbau/examen/wiederholung mit Schwachstellen** -> leichtester
   Fall zum Thema mit den meisten verfehlten Pruefpunkten; ohne Fall die
   Karten des Themas.
6. **Schwaechstes Thema nach individueller Prioritaet** -> Fall, wenn das
   Thema schon >= 50 % reif ist und die Persona nicht einstieg ist; sonst
   die Karten.
7. **Sonst** -> "Nichts faellig, nichts offen."

Die Regeln sind bewusst kurz und lesbar (`test_naechster_schritt_regelreihenfolge`
prueft jede Verzweigung). Sie ersetzen den in `docs/13` Abschnitt 2 als
fehlend benannten "Naechster-Schritt"-Endpunkt und das Onboarding: das
Lernprofil *ist* der Fragebogen, die Persona *ist* die Pfadwahl.

---

## 6. In der App

Examen-Reiter, oberhalb der Examensreife:

- **Naechster Schritt** (Hero-Flaeche): Titel, Begruendung, ein Button, der
  direkt in die Handlung fuehrt (Profil, Stapel, Deck, Thema, Fall).
- **Lernprofil**: Persona-Label und eine Zeile Zusammenfassung; Stift oeffnet
  die Lernprofil-Seite.
- **Lernprofil-Seite**: Semester, Ziel (Chips), Zielnote (Schalter + Slider),
  Schwerpunkte, Ruhetage, Wochenklausur und Klausurtag, neue Karten/Tag,
  Sicherheitsniveau (drei Segmente mit Konsequenz-Satz), Themen je
  Rechtsgebiet mit Fokus-/Pause-Umschalter, eigene Decks mit Dialog
  (Titel + Themenauswahl). Speichern ersetzt das Profil komplett und laedt das
  Cockpit neu.
- **Examensreife** zeigt zusaetzlich den Semesterstoff; **Kurs-Decks** listet
  eigene Decks; **Schwachstellen** zeigt den Technik-Tipp; die
  **Klausur-Karte** sagt, wenn die Wochenklausur ausgeschaltet ist.

Gestaltung unveraendert nach `docs/25` Abschnitt 6: keine wertabhaengige
Farbe, Outline-Icons, Flaeche statt Schatten.

---

## 7. Offen und Folgetickets

| Punkt | Warum offen | Vorschlag |
|---|---|---|
| FSRS-Gewichte je Nutzer optimieren | `srs.DEFAULT_WEIGHTS` sind global; die echte Individualisierung des Gedaechtnismodells ist die Optimierung aus dem eigenen Review-Strom (Backlog M4) | Optimizer ueber `reviews` je Nutzer, ab ~1.000 Reviews |
| Technik-Karten als Kartentyp | docs/13 3.2 Kategorie A, hier nur als Tipp | `CardType.TECHNIK` mit eigener Retention, ausgeloest durch Strukturfehler |
| Zielnote nutzen | keine Kalibrierung | wenn Examensergebnisse aus der Beta vorliegen: Zielnote gegen Reife-Komponenten legen |
| Adaptive Fallschwierigkeit | Klausurvorschlag nimmt den schwersten Fall | Schwierigkeit aus den letzten Punktzahlen ableiten |
| Onboarding-Dialog beim ersten Start | Profil ist heute eine Seite im Examen-Reiter | nach erster Anmeldung einmalig anbieten, ueberspringbar |
| Lernzeit-Fenster (morgens/abends) | keine Wirkung im Code, deshalb nicht aufgenommen | erst mit Erinnerungen (Push) sinnvoll |
| Pro-Gating | Individualisierung ist ein Pro-Argument (docs/19) | Entscheidung mit Preisstruktur: Profil frei, eigene Decks und Sicherheitsniveau Pro? |

---

## 8. Messung

Ob Individualisierung als USP traegt, ist messbar, ohne neue Telemetrie:

- Anteil Nutzer mit eingerichtetem Lernprofil (Feld nicht leer) nach 7 Tagen.
- Retention (Wiederkehr nach 14 Tagen) mit vs. ohne Lernprofil.
- Faellige-Karten-Rueckstand je Sicherheitsniveau - bestaetigt oder
  widerlegt die +/-0,04.
- Klickrate auf "Naechster Schritt" vs. freie Navigation.
- Nennung "passt zu meinem Studium" in der Fachschafts-Beta (docs/28).
