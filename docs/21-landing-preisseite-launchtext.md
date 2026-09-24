# Landing Page, Preisseite, Launch-Text — G5 (29.09.2026)

> Lieferung zu [SUB-88](/SUB/issues/SUB-88), Gate **G5** aus
> `docs/18-release-2-wochen.md` Abschnitt 5/9. Ersetzt nicht die laufende
> GTM-Spur [SUB-46](/SUB/issues/SUB-46)/T7 — dieses Dokument ist die konkrete
> Text-Lieferung für den Releasetag, T7 bleibt die übergeordnete
> Kanal-/Wachstumsplanung danach.
>
> Fakten (Umfang, Preis, Positionierung) sind aus `docs/18-release-2-wochen.md`,
> `docs/19-kosten-preis-budget.md` und `docs/14-marktanalyse.md` **übernommen,
> nicht neu hergeleitet** — Abweichungen von diesen Quellen sind Fehler, keine
> redaktionelle Freiheit.
>
> **Status:** Text-Entwurf, bereit zur Umsetzung. Technische Implementierung
> (Landing Page/Preisseite im Produkt bauen) ist **nicht** Teil dieser Aufgabe
> — siehe Abschnitt 5.
>
> **Update 16.09.2026 ([SUB-136](/SUB/issues/SUB-136)):** Abschnitt 2.3 ergänzt
> eine **Austauschfassung** für den Fall, dass die KI-Klausurkorrektur laut
> Stichtagsentscheid `docs/18-release-2-wochen.md` Abschnitt 2.1 noch in v1.0
> aktiviert wird (Entscheidung [SUB-135](/SUB/issues/SUB-135), spätestens
> So 27.09., 18:00). Der Standardtext in diesem Dokument (Fassung A) ist davon
> **nicht** betroffen und bleibt bis zu dieser Entscheidung die geltende
> Fassung.
>
> **Update 24.09.2026 ([SUB-260](/SUB/issues/SUB-260), Befund aus
> `docs/26-projektreview-sub254.md` Abschnitt 4):** Der Struktur-Check wird
> vom Nebenargument zum **Hauptargument**, solange die KI-Korrektur aus ist
> (`llm_provider=none`). Grund: `docs/14-marktanalyse.md` Abschnitt 2 belegt
> inzwischen vier Wettbewerber mit KI-Klausurkorrektur — das Feature, das der
> Markt am lautesten bewirbt, ist bei uns zum Start aus und wäre selbst
> eingeschaltet kein Alleinstellungsmerkmal mehr. Was bleibt, sind zwei
> Dinge, die kein Wettbewerber belegt anbietet: **unbegrenztes
> Struktur-Feedback ohne Grenzkosten** (`backend/app/services/gutachten.py`
> ist regelbasiert, offline, ohne LLM — jeder KI-Korrektur-Wettbewerber zahlt
> pro Abgabe und muss kontingentieren) und **echtes Offline auf vier
> Plattformen** (Kartencache + Review-Outbox überstehen Neustart und
> Netzausfall, `app/lib/state.dart` — Jurafuchs' Offline-Modus dagegen
> verliert heruntergeladene Inhalte bei jedem App-/OS-Update, die drei
> reinen KI-Korrektur-Anbieter haben laut `docs/14` Abschnitt 3 gar keinen
> Offline-Modus). Betroffen: Hero (2.2), Feature-Liste (2.2 Punkt 3),
> Preisseite (3.1/3.2), Kanaltexte (4.2). Fassung-A/B-Umschaltregel aus
> Abschnitt 2.3 bleibt unverändert bestehen — die Reihenfolge der Argumente
> ändert sich, nicht die Leitplanken aus Abschnitt 1.

---

## 1. Redaktionelle Leitplanken (bindend für jeden Text in diesem Dokument)

Aus der Aufgabenstellung SUB-88, zwei Punkte, an denen es „sonst scheitert":

1. **Umfang offen kommunizieren, nicht beschönigen.** Jeder Text, der die
   Kartenzahl nennt, nennt **180 Karten über drei Rechtsgebiete** — nie
   „umfassend", „vollständig" oder vergleichbare Superlative. Der Vergleich zu
   Jurafuchs (8.000+ Fälle, `docs/14-marktanalyse.md` Abschnitt 2) wird nicht
   versteckt, sondern als Kontext für den Gründerpreis benutzt.
2. **Keine Werbung für KI-Klausurkorrektur.** Das Wort „KI" fällt in keinem
   Launch-Text im Zusammenhang mit dem Struktur-Check. Beworben wird der
   **heuristische Struktur-Check**, **ausdrücklich ohne Note** — Formulierung
   „Lernhilfe, keine Rechtsberatung, keine Note" ist wörtlich aus
   `docs/legal/02-agb.md` Abschnitt 2.1 übernommen, damit Marketing- und
   Rechtstext nicht auseinanderlaufen.

Zusätzlich, aus den Rechtstexten (`docs/legal/`), damit nichts behauptet wird,
was die AGB nicht deckt:

3. **Preise nur wie in `docs/19` §4 / `docs/legal/02-agb.md` §4.** Free/Pro,
   3,99 €/Monat oder 39 €/Jahr, Preisgarantie für Bestandskund:innen. Keine
   abweichenden Zahlen, keine befristeten Rabatte, die nicht auch im AGB-Text
   stehen.
4. **Kündigung nicht als „ein Klick" behaupten, solange die Selbstbedienung
   nicht gebaut ist.** `docs/legal/02-agb.md` §5 macht das explizit: Der
   Kündigungsabsatz „darf erst veröffentlicht werden, wenn die Funktion
   tatsächlich verfügbar ist". Texte hier sagen nur „jederzeit zum Ende der
   laufenden Laufzeit kündbar, Details siehe AGB" — ohne den Weg zu
   spezifizieren, bis SUB-99/SUB-102 (Kündigungs-UI, siehe
   `docs/20-release-g2-bezahlstrecke.md`) bestätigt sind.
5. **Keine unsicheren Fakten behaupten.** Rechtsträger-Name, Anschrift, USt.
   sind in `docs/legal/01-impressum.md` noch `[Platzhalter]` (offene
   Entscheidung G1, `docs/18` Abschnitt 8 Punkt 1). Kein Launch-Text nennt
   einen Firmennamen oder eine Rechtsform — nur die Marke „Subsumo".

---

## 2. Landing Page

### 2.1 Struktur

| # | Sektion | Zweck |
|---|---|---|
| 1 | Hero | Kernversprechen + Preis-Ankerpunkt + primärer CTA |
| 2 | Für wen | Zielgruppe in einem Satz |
| 3 | Was du heute bekommst | Feature-Liste, ehrlich, mit Struktur-Check-Abgrenzung |
| 4 | Wie es funktioniert | 3 Schritte |
| 5 | Ehrlich über den Umfang | 180-Karten-Offenlegung + Gründerpreis-Begründung |
| 6 | Die drei Rechtsgebiete | Zivilrecht/Strafrecht/Öffentliches Recht Teaser |
| 7 | Preis-Teaser | Free/Pro Kurzvergleich, Link zu `/preise` |
| 8 | FAQ | 3 Fragen, die Missverständnisse vorwegnehmen (KI, Umfang, Kündigung) |
| 9 | Footer | Rechtstexte-Links, Support-Kontakt |

### 2.2 Volltext

**1. Hero**

> **H1:** Unbegrenztes Feedback zum Aufbau deiner Gutachten — sofort, offline,
> ohne Limit.
>
> **Subheadline:** Subsumo prüft deine eigene Lösung automatisch auf Aufbau
> und Stil, so oft du willst, auch offline auf dem Handy, Tablet oder Laptop —
> weil es uns nichts kostet, es zu verschenken. Dazu 180 geprüfte Karten,
> 8+ Schemata und 6+ geführte Fälle über Zivilrecht, Strafrecht und
> Öffentliches Recht. Zum Gründerpreis ab 3,99 €/Monat, dauerhaft garantiert.
>
> **Primärer CTA:** „Kostenlos starten"
> **Sekundärer CTA:** „Preise ansehen" → `/preise`

**2. Für wen**

> Für Jurastudierende ab dem ersten Semester, die nicht nur lesen, sondern
> wiederholen, anwenden und ihre eigenen Lösungen überprüfen wollen — auch in
> der Bibliothek ohne WLAN oder im Zug.

**3. Was du heute bekommst**

> - **Struktur-Check für deine Gutachten, ohne Limit:** Lade deine eigene
>   Lösung zu einem Übungsfall hoch und bekommst automatisiert Rückmeldung zu
>   Aufbau und Stil — beliebig oft im Pro-Tarif, weil der Check regelbasiert
>   und offline läuft und uns deshalb pro Nutzung nichts kostet.
> - **Funktioniert ohne Internet:** Karten, Schemata, Fälle und der
>   Struktur-Check laufen auf Android, iOS, Windows und im Web — einmal
>   geladen, übersteht das auch einen Neustart oder Netzausfall.
> - **Karteikarten mit automatischer Wiederholung** (FSRS-Verfahren) — die App
>   entscheidet, wann eine Karte wieder fällig ist, du entscheidest, was du
>   lernst.
> - **Prüfungsschemata** zum Nachschlagen (Pro: zusätzlich als
>   Reihenfolge-Drill).
> - **Geführte Übungsfälle** mit hinterlegtem Erwartungshorizont.
>
> **Was der Struktur-Check ist — und was nicht:** Lernhilfe, keine
> Rechtsberatung, keine Note. Er ist ein regelbasierter (heuristischer) Check
> gegen den in der Anwendung hinterlegten Erwartungshorizont deines
> Übungsfalls — kein Ersatz für eine Korrektur durch Lehrpersonal, keine
> Bewertung deiner Studien- oder Examensklausuren.
>
> *Zugabe-Absatz, nur bei Aktivierung (Fassung B, siehe Abschnitt 2.3 —
> ersetzt hier nichts, sondern ergänzt den Absatz oben):* Zusätzlich bekommst
> du optional ein maschinelles Feedback zu deiner Lösung — eine **Zugabe**,
> kein beworbenes Kernversprechen: Die Bewertung ist bislang nicht gegen
> Dozent:innen-Gutachten kalibriert, keine verbindliche Note, und dein Text
> geht dafür nur mit deiner ausdrücklichen Zustimmung an einen externen
> Anbieter. Kernangebot bleibt in jedem Fall: Karten, Schemata, Fälle,
> Struktur-Check ohne Note.

**4. Wie es funktioniert**

> 1. Konto anlegen, Rechtsgebiet wählen.
> 2. Karten lernen, Schemata nachschlagen, Fälle bearbeiten.
> 3. Eigene Lösung zum Struktur-Check hochladen und Rückmeldung bekommen.

**5. Ehrlich über den Umfang**

> Subsumo ist neu. Zum Start stehen **180 Karten, 8+ Schemata und 6+ geführte
> Fälle** über drei Rechtsgebiete bereit — spürbar weniger als etablierte
> Anbieter mit tausenden Fällen. Das sagen wir offen, weil wir lieber jede
> Karte selbst prüfen, als früh eine Vollständigkeit zu behaupten, die es
> nicht gibt.
>
> Deshalb der **Gründerpreis**: Wer jetzt einsteigt, sichert sich einen Preis,
> der niedriger bleibt, als der Umfang — und der Preis für neue Kund:innen —
> mit der Zeit wächst.

**6. Die drei Rechtsgebiete**

> Zivilrecht · Strafrecht · Öffentliches Recht — Karten, Schemata und Fälle
> zu den Themen, die in der Pflichtfachprüfung zählen. [Teaser-Kacheln mit
> Themenbeispielen je Gebiet, aus `content/<gebiet>/`.]

**7. Preis-Teaser**

> **Free:** 20 fällige Karten/Tag in einem Rechtsgebiet, 2 geführte Fälle,
> 3 Struktur-Checks/Woche.
> **Pro (Gründerpreis):** alle drei Rechtsgebiete, unbegrenzt Karten, Fälle
> und **Struktur-Checks ohne Limit** — **3,99 €/Monat oder 39 €/Jahr**, Preis
> bleibt dir erhalten, auch wenn er für neue Kund:innen steigt.
> CTA: „Alle Preise ansehen" → `/preise`

**8. FAQ**

> **Ist das eine KI, die meine Klausur korrigiert?**
>
> *Fassung A — ohne KI-Korrektur (Standard, gilt bis zum Stichtagsentscheid):*
> Nein. Der Struktur-Check ist heuristisch (regelbasiert) und vergibt keine
> Note. Eine KI-gestützte Korrektur ist nicht Teil des aktuellen Angebots.
>
> *Fassung B — bei Aktivierung (siehe Abschnitt 2.3, nur ziehen, wenn
> [SUB-135](/SUB/issues/SUB-135) die Aktivierung bestätigt):*
> Zusätzlich zum heuristischen Struktur-Check gibt es dann ein maschinelles
> Feedback zu deiner Gutachtenlösung. Das ist **keine verbindliche Bewertung**
> und **kein Ersatz** für eine Korrektur durch Lehrpersonal: Die Punktevergabe
> ist bisher nicht gegen echte Dozent:innen-Gutachten kalibriert (Zielwert:
> durchschnittliche Abweichung ≤ 2 Punkte — der Nachweis dafür steht noch aus,
> siehe `docs/24-kalibrierungspaket.md`). Dein Text wird dafür nur mit deiner
> ausdrücklichen, jederzeit widerrufbaren Zustimmung zur Auswertung an einen
> externen Anbieter übertragen; ohne Zustimmung bekommst du weiterhin nur den
> heuristischen Struktur-Check.
>
> **Funktioniert der Struktur-Check auch offline?**
> Ja. Karten, Schemata, Fälle und der Struktur-Check laufen ohne
> Internetverbindung — praktisch für die Bibliothek ohne WLAN oder unterwegs.
> Einmal geladene Inhalte übersteht auch ein Neustart oder Netzausfall.
>
> **Wie viele Karten gibt es wirklich?**
> Zum Start 180 geprüfte Karten über drei Rechtsgebiete. Wir zeigen die
> aktuelle Zahl hier auf der Seite, nicht nur im Kleingedruckten.
>
> **Kann ich kündigen?**
> Ja, jederzeit zum Ende der laufenden Laufzeit. Details in den AGB.

**9. Footer**

> Impressum · AGB · Datenschutzerklärung · Widerrufsbelehrung ·
> Cookie-Einstellungen · Kontakt: `[Support-E-Mail, sobald eingerichtet —
> siehe docs/18 Tagesplan 25.09.]`

### 2.3 Austauschfassung: falls die KI-Korrektur zum Start aktiviert wird

Hintergrund: `docs/18-release-2-wochen.md` Abschnitt 2.1 hält die
KI-Klausurkorrektur bedingt in v1.0 offen — sie aktiviert sich, wenn der AVV
mit dem LLM-Anbieter vor dem Code-Freeze (28.09.) unterschrieben ist. Der
Stichtagsentscheid fällt auf [SUB-135](/SUB/issues/SUB-135), spätestens
**So 27.09., 18:00**. Bis dahin gilt ausschließlich **Fassung A** (die
Standardtexte oben in Abschnitt 2.2, unverändert). Diese Auswahlregel gilt
für **alle** Fassung-A/B-Stellen in diesem Dokument — nicht nur die FAQ.

**Was zu tun ist, wenn SUB-135 die Aktivierung bestätigt (nicht vorher):**

1. In Abschnitt 2.2, FAQ, Frage „Ist das eine KI, die meine Klausur
   korrigiert?": Fassung A durch Fassung B ersetzen.
2. In Abschnitt 2.2, „3. Was du heute bekommst": den mit *Zugabe-Absatz*
   markierten Absatz zusätzlich zum bestehenden Struktur-Check-Absatz
   veröffentlichen (er ergänzt, ersetzt nichts).
3. Alle anderen Texte in diesem Dokument (Preisseite, Kanaltexte) bleiben
   unverändert — sie erwähnen die KI-Korrektur nicht und werden durch die
   Aktivierung nicht falsch.
4. Vor dem Ziehen prüfen, ob die Selbstbedienungs-Widerrufsfunktion für die
   Einwilligung live ist (`backend/app/api/v1/consent.py`, SUB-133) — Fassung
   B behauptet „jederzeit widerrufbar" und darf nur online gehen, wenn das
   stimmt (gleiche Regel wie beim Kündigungsabsatz, Abschnitt 1 Punkt 4).
5. **Nicht Teil dieser Textlieferung, aber zwingend vor Veröffentlichung von
   Fassung B nachzuziehen:** `docs/legal/02-agb.md` Abschnitt 2.1 schließt
   ein Sprachmodell für v1.0 explizit aus und die Datenschutzerklärung nennt
   noch keine Auftragsverarbeitung für die Korrektur — beide Rechtstexte
   müssen vor Fassung B live angepasst sein (Zuständigkeit: Rechtstexte-Gate
   G4, nicht Marketing-Planner).

**Was Fassung B bewusst nicht tut:** Sie bewirbt die Korrektur nicht als
geprüftes, verlässliches Bewertungsinstrument — der Kalibrierungsnachweis
(MAE ≤ 2 Punkte gegen 30 Dozentengutachten, `docs/24-kalibrierungspaket.md`)
steht zum Stichtag noch aus. Formulierungen wie „präzise", „zuverlässig" oder
ein direkter Vergleich zu einer menschlichen Korrektur gehören nicht in
Fassung B, auch nicht in spätere Überarbeitungen dieses Absatzes.

---

## 3. Preisseite (`/preise`) — zwei Varianten

Der Auftrag verlangt beide Varianten vorzubereiten, weil laut
`docs/18-release-2-wochen.md` Abschnitt 8 Punkt 3 offen ist, ob am Tag 1
bezahlt wird, und weil `docs/20-release-g2-bezahlstrecke.md` (G2) einen
expliziten Notausgang kennt: Reicht die Zeit für die Paywall nicht,
wird `paywall_enabled=false` gesetzt und **alle** Nutzer:innen bekommen
unbegrenzten Zugriff, ohne dass das Release kippt.

**Umschaltregel (an das technische Flag gekoppelt, nicht an ein Datum):**
Variante A live, sobald `paywall_enabled=true` **und** G1 (Rechtsträger/
Zahlungskonto) abgeschlossen ist; sonst Variante B. Diese Kopplung an das
Flag aus SUB-95 ist eine Umsetzungsentscheidung und gehört in die technische
Aufgabe aus Abschnitt 5, nicht in dieses Dokument.

### 3.1 Variante A — mit Kauf

> **H1:** Preise
>
> | | Free | **Pro (Gründerpreis)** |
> |---|---|---|
> | Preis | 0 € | **3,99 €/Monat** oder **39 €/Jahr** *(inkl. gesetzlicher USt., sofern diese anfällt)* |
> | Struktur-Check (offline, alle Plattformen) | 3/Woche | **ohne Limit** |
> | Karteikarten | 20 fällige Karten/Tag, ein Rechtsgebiet | unbegrenzt, alle drei Rechtsgebiete |
> | Schemata | Lesen | Lesen + Reihenfolge-Drill |
> | Geführte Fälle | 2 | alle |
> | Preisgarantie | — | Bestandspreis bleibt dauerhaft, auch wenn der Listenpreis für Neukund:innen steigt |
>
> CTA (Pro-Spalte): „Pro werden"
>
> **Warum Gründerpreis?** Subsumo startet mit 180 Karten — deutlich weniger
> als etablierte Anbieter. Der Preis liegt deshalb bewusst niedrig, und wer
> jetzt einsteigt, behält ihn dauerhaft, auch wenn Umfang und Listenpreis
> wachsen.
>
> Zahlung über Stripe. Jederzeit zum Ende der laufenden Laufzeit kündbar,
> Details in den AGB.

**Hinweis zur USt.-Zeile:** Ob „inkl. USt." oder „zzgl., da Kleinunternehmer
nach § 19 UStG" korrekt ist, hängt an der noch offenen Rechtsträger-/
USt.-Entscheidung (`docs/legal/01-impressum.md`, G1). Die Preisseite darf erst
mit der zutreffenden Variante veröffentlicht werden — das ist ein
Rechts-/Buchhaltungspunkt, keine redaktionelle Wahl.

### 3.2 Variante B — Early Access (Preis ab X, kein Checkout live)

> **H1:** Preise (Early Access)
>
> Subsumo ist gerade gestartet. Die Bezahlstrecke ist noch nicht live — bis
> dahin nutzt du Subsumo **im vollen Pro-Umfang kostenlos**: alle drei
> Rechtsgebiete, unbegrenzte Karten, Schemata, Fälle und Struktur-Checks.
>
> Sobald die Bezahlstrecke startet, wechseln wir auf Free/Pro. Der Pro-Tarif
> kostet dann **ab 3,99 €/Monat** (39 €/Jahr) — mit **Gründerpreis-Garantie**:
> Wer sich jetzt registriert, sichert sich diesen Preis dauerhaft, auch wenn
> er für später hinzukommende Nutzer:innen steigt.
>
> CTA: „Kostenlos registrieren und Preis sichern"
>
> Feature-Tabelle wie Variante A, Spalte „Pro" umbenannt in „Pro (kommt
> bald, aktuell für alle inklusive)".

---

## 4. Launch-Ankündigungen je Kanal

### 4.1 Kanalauswahl

`docs/18-release-2-wochen.md` Abschnitt 8 Punkt 4 lässt die Tag-1-Reichweite
(Fachschaft, Jura-Kanal, Lerngruppe) bewusst offen — das ist eine
Nutzer-Entscheidung, nicht blockierend für den Termin. Ohne diese Entscheidung
lässt sich kein GTM-Plan mit fest benannten Kanälen (Instagram-Handle,
konkrete Fachschaft o. Ä.) schreiben. Diese drei Kanaltypen decken die in
`docs/18`/`docs/19` §6 genannten Optionen ab (organisch, kein bezahltes
Budget) und sind direkt einsetzbar, sobald konkrete Kanäle feststehen:

| Kanaltyp | Format | Wann laut Tagesplan |
|---|---|---|
| E-Mail/Warteliste | kurz, persönlich | Warteliste ab 22.09. angelegt, Versand am Launch-Tag |
| Eigene Social-Kanäle (Instagram/LinkedIn) | kurz, Bild/Karussell-tauglich | 28.09. terminiert, 29.09. live |
| Jura-Fachschaft/Studi-Kanal (Telegram/WhatsApp-Gruppe, Forum) | länger, zum Weiterleiten | sobald Kontakt aus offener Frage 4 steht |

### 4.2 Text je Kanal

**E-Mail/Warteliste**

> Betreff: Subsumo ist da
>
> Hallo,
>
> Subsumo ist ab heute live: ein automatischer Struktur-Check für deine
> eigenen Gutachten — ohne Limit, auch offline, als Lernhilfe ohne Note. Dazu
> Karteikarten, Schemata und geführte Fälle für Zivilrecht, Strafrecht und
> Öffentliches Recht.
>
> Ehrlich gesagt: Wir starten mit 180 Karten, nicht mit Tausenden. Dafür
> prüfen wir jede Karte selbst, und du bekommst als frühe Nutzerin/früher
> Nutzer den Gründerpreis von 3,99 €/Monat (39 €/Jahr) — dauerhaft, auch wenn
> er später steigt.
>
> [Jetzt kostenlos starten →]
>
> Viele Grüße
> Subsumo

**Social kurz (Instagram/LinkedIn)**

> Subsumo ist live 🎓
> Automatischer Struktur-Check für deine eigenen Gutachten — ohne Limit, auch
> offline, ohne Note (Lernhilfe). Dazu Karteikarten, Schemata, geführte Fälle
> für Zivilrecht, Strafrecht, Öffentliches Recht.
>
> Ehrlich: Wir starten mit 180 Karten, nicht mit Tausenden — dafür zum
> Gründerpreis von 3,99 €/Monat, dauerhaft.
>
> Link in Bio → kostenlos starten.

**Jura-Fachschaft/Studi-Kanal (länger, zum Weiterleiten)**

> Hallo zusammen,
>
> ich wollte euch kurz Subsumo vorstellen — eine neue Lern-App für Zivilrecht,
> Strafrecht und Öffentliches Recht, die heute live gegangen ist.
>
> Was drin ist: ein automatischer Struktur-Check, der eure eigene
> Gutachtenlösung auf Aufbau und Stil prüft — ohne Note, als Lernhilfe, und
> ohne Limit, weil er offline und ohne Sprachmodell läuft (funktioniert also
> auch in der Bibliothek ohne WLAN oder im Zug). Dazu Karteikarten mit
> automatischer Wiederholung, Prüfungsschemata und geführte Übungsfälle mit
> Erwartungshorizont.
>
> Der ehrliche Teil: Das Angebot ist neu und startet mit 180 Karten über die
> drei Rechtsgebiete — weniger als etablierte Anbieter mit Tausenden Fällen.
> Wer jetzt einsteigt, bekommt dafür den Gründerpreis (3,99 €/Monat oder
> 39 €/Jahr), der dauerhaft bleibt, auch wenn der Umfang wächst und der Preis
> für später hinzukommende Nutzer:innen steigt. Es gibt auch eine kostenlose
> Stufe zum Ausprobieren.
>
> Würde mich freuen, wenn der Link hier landet: [Link]
>
> Feedback — was fehlt, was nervt — geht direkt an [Support-Kontakt].

---

## 5. Offene Punkte vor Veröffentlichung (nicht Teil dieser Text-Lieferung)

| Punkt | Abhängig von | Blockiert |
|---|---|---|
| Technische Umsetzung (Landing Page + Preisseite im Produkt bauen, Umschaltung Variante A/B an `paywall_enabled` koppeln) | Software-Planner/Frontend-Developer | Landing live (Ziel 24.09.) |
| USt.-Zeile auf der Preisseite (inkl./zzgl.) | Rechtsträger-/USt.-Entscheidung, G1 | Preisseite-Veröffentlichung |
| Rechtstexte-Links im Footer müssen live sein, bevor die Landing Page live geht | G4, `docs/legal/` | Landing live |
| Support-Kontakt im Footer/Launch-Texten | Support-Postfach-Einrichtung (Tagesplan 25.09.) | Footer/Launch-Texte final |
| Konkrete Kanäle (Fachschaft, Social-Handles) für Abschnitt 4 | offene Frage 4, `docs/18` Abschnitt 8 | Versand der Kanal-Texte |
| Preiskonsistenz mit dem im Zahlungsdienstleister hinterlegten Preis (Abnahmekriterium SUB-88) | Stripe-Price-IDs aus SUB-97/G2 | Preisseite-Veröffentlichung — Preise hier sind identisch mit `docs/19`/`docs/20`, Prüfung gegen die tatsächliche Stripe-Konfiguration muss aber nachgeholt werden, sobald diese existiert |

Eine Unteraufgabe für die technische Umsetzung (erster Punkt) wird an den
Software-Planner übergeben — siehe Aufgabenkommentar zu SUB-88.

---

## Quellen

- Umfang, Tagesplan, Gates: `docs/18-release-2-wochen.md`
- Preis, Kostendeckung, Preispfad: `docs/19-kosten-preis-budget.md`
- Positionierung, Wettbewerbsvergleich: `docs/14-marktanalyse.md`
- Feature-/Preistabelle, Struktur-Check-Abgrenzung, Kündigungshinweis:
  `docs/legal/02-agb.md`
- Rechtsträger-Platzhalter: `docs/legal/01-impressum.md`
- Bezahlstrecke, Notausgang `paywall_enabled`: `docs/20-release-g2-bezahlstrecke.md`
- Stichtagsentscheid, AVV-Gate, Aktivierungsregel für die KI-Korrektur (Fassung
  B, Abschnitt 2.3): `docs/18-release-2-wochen.md` Abschnitt 2.1,
  [SUB-135](/SUB/issues/SUB-135)
- Kalibrierungsstand (MAE-Nachweis noch offen): `docs/24-kalibrierungspaket.md`
- Einwilligungs-/Widerrufsmechanismus für die KI-Korrektur:
  `backend/app/api/v1/consent.py` (SUB-133)
