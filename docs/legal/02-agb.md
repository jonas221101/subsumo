# Allgemeine Geschäftsbedingungen (Entwurf)

> Entwurf zur Prüfung, keine Rechtsberatung. `[Platzhalter]` markiert Werte,
> die an der offenen Rechtsträger-Entscheidung oder an noch nicht
> abgeschlossenen Bau-Aufgaben (SUB-83, SUB-84) hängen.

## 1. Geltungsbereich, Vertragspartner

Diese AGB gelten für die Nutzung der Lernplattform **Subsumo**
(Web: `app.subsumo.de`, Android-App), angeboten von
`[Platzhalter: Anbieter aus 01-impressum.md]` („Anbieter"). Vertragspartner
sind volljährige Nutzer:innen; Subsumo richtet sich an Jurastudierende ab dem
1. Fachsemester und wird nicht an Minderjährige vermarktet.

## 2. Leistungsbeschreibung

Subsumo ist eine digitale Lernanwendung für die drei Rechtsgebiete der
Pflichtfachprüfung (Zivilrecht, Strafrecht, Öffentliches Recht) mit:

- Karteikarten mit spaced-repetition-gestützter Wiederholung (FSRS-Verfahren),
- Prüfungsschemata,
- geführten Übungsfällen mit vorgegebenem Erwartungshorizont,
- einem automatisierten **Struktur- und Stil-Check** zu selbst verfassten
  Gutachtentexten.

### 2.1 Ausdrückliche Abgrenzung des Struktur-Checks

Der Struktur-Check ist **heuristisch** (regelbasiert), bewertet ausschließlich
gegen den in der Anwendung hinterlegten Erwartungshorizont eines konkreten
Übungsfalls und vergibt **keine verbindliche Note**. Er ist:

- **keine Rechtsberatung** im Sinne des § 2 Rechtsdienstleistungsgesetz (RDG)
  — es werden ausschließlich fiktive Übungssachverhalte aus der
  anwendungseigenen Falldatenbank bewertet, kein Nutzer kann eigene reale
  Sachverhalte, Verträge, Bescheide oder Schriftsätze zur Bewertung einreichen;
- **keine Ersatzkorrektur** durch akademisches Lehrpersonal und kein
  Ersatz für eine Klausurkorrektur im Rahmen des Studiums oder der
  Staatsprüfung;
- **kein KI-Sprachmodell**: Zum Zeitpunkt dieser Fassung wird kein von
  Nutzer:innen eingegebener Text an einen externen Sprachmodell-Anbieter
  übermittelt (`llm_provider=none`). Ändert sich das (geplant ab v1.1 mit
  kalibrierter KI-Korrektur), wird diese Klausel vor Einführung angepasst und
  die Datenschutzerklärung um die dann bestehende Auftragsverarbeitung
  ergänzt.

Jede Ausgabe des Struktur-Checks trägt in der Anwendung selbst den Hinweis
„Lernhilfe, keine Rechtsberatung, keine Note".

## 3. Registrierung, Nutzerkonto

Die Nutzung von Kernfunktionen setzt ein Nutzerkonto voraus (E-Mail-Adresse,
Passwort). Nutzer:innen sind verpflichtet, wahrheitsgemäße Angaben zu machen
und ihre Zugangsdaten geheim zu halten. Ein Konto ist nicht übertragbar.

## 4. Tarife, Preise

| | Free | Pro (Gründerpreis) |
|---|---|---|
| Preis | 0 € | **3,99 €/Monat oder 39 €/Jahr**, jeweils inkl. gesetzlicher Umsatzsteuer, sofern diese anfällt `[Platzhalter — abhängig von Rechtsträger/Kleinunternehmerregelung, siehe 01-impressum.md]` |
| Karteikarten | 20 fällige Karten/Tag, ein Rechtsgebiet | unbegrenzt, alle drei Rechtsgebiete |
| Schemata | Lesen | Lesen + Reihenfolge-Drill |
| Geführte Fälle | 2 | alle |
| Struktur-Check | 3/Woche | unbegrenzt |
| Preisgarantie | — | Bestandskund:innen behalten ihren Einstiegspreis dauerhaft, auch wenn der Listenpreis für Neukund:innen später steigt |

Die Preisgarantie ist eine vertragliche Zusage an Bestandskund:innen des
Pro-Tarifs zum Zeitpunkt ihres Vertragsschlusses; sie gilt nicht für neu
hinzukommende, im Vertrag nicht enthaltene Zusatzleistungen.

## 5. Zahlung, Vertragslaufzeit, Kündigung

Die Zahlungsabwicklung erfolgt über den externen Zahlungsdienstleister
**Stripe** (siehe `03-datenschutzerklaerung.md`). Das Pro-Abo verlängert sich
automatisch um die gewählte Laufzeit (Monat/Jahr), sofern es nicht vorher
gekündigt wird.

**Kündigung:** Nutzer:innen können das Pro-Abo jederzeit zum Ende der
laufenden Laufzeit **direkt im Produkt** kündigen (Selbstbedienung, kein
E-Mail-Erfordernis), entsprechend der seit 2022 geltenden Pflicht zu einer
leicht auffindbaren Kündigungsmöglichkeit (§ 312k BGB). **Zum Zeitpunkt
dieses Entwurfs ist diese Funktion noch nicht gebaut** — siehe
`00-uebersicht.md` Punkt 3. Dieser Absatz darf erst veröffentlicht werden,
wenn die Funktion tatsächlich verfügbar ist; andernfalls ist er selbst durch
falsche Tatsachenbehauptung angreifbar und der Kündigungsweg muss stattdessen
den tatsächlich verfügbaren Weg (z. B. Support-E-Mail) benennen.

## 6. Nutzungsrechte an Inhalten

Alle Lerninhalte (Karteikarten, Schemata, Fallmaterial) bleiben Eigentum des
Anbieters bzw. der jeweiligen Rechteinhaber. Nutzer:innen erhalten ein
einfaches, nicht übertragbares Recht zur persönlichen Nutzung im Rahmen des
eigenen Studiums für die Vertragsdauer.

An von Nutzer:innen selbst verfassten Gutachtentexten (Einreichungen zum
Struktur-Check) verbleiben alle Rechte bei den Nutzer:innen. Der Anbieter
erhält ein einfaches Nutzungsrecht, das ausschließlich zum Betrieb und zur
Anzeige der Funktion innerhalb des eigenen Kontos erforderlich ist — **kein**
Weiterverkauf, keine Veröffentlichung. Eine Nutzung zu Trainingszwecken eines
Sprachmodells findet in v1.0 nicht statt (siehe 2.1) und würde, sollte sie
später eingeführt werden, eine gesonderte Einwilligung (Opt-in) voraussetzen.

## 7. Verfügbarkeit, Änderungen

Der Anbieter ist bestrebt, die Anwendung ohne Unterbrechung bereitzustellen,
übernimmt hierfür jedoch keine Garantie (Wartungsfenster, technische
Störungen möglich). Funktionsänderungen, die den vertraglich geschuldeten
Kernumfang eines bestehenden Tarifs zum Nachteil bestehender Kund:innen
verändern, werden mit angemessener Vorlauffrist angekündigt; bei
wesentlichen Verschlechterungen steht Bestandskund:innen ein
Sonderkündigungsrecht zu.

## 8. Haftung

Der Anbieter haftet unbeschränkt für Vorsatz und grobe Fahrlässigkeit sowie
nach dem Produkthaftungsgesetz und bei Verletzung von Leben, Körper oder
Gesundheit. Bei leicht fahrlässiger Verletzung wesentlicher Vertragspflichten
(Kardinalpflichten) ist die Haftung auf den vertragstypisch vorhersehbaren
Schaden begrenzt. Im Übrigen ist die Haftung für leichte Fahrlässigkeit
ausgeschlossen. **Ausdrücklich klargestellt:** Für Ergebnisse des heuristischen
Struktur-Checks (Abschnitt 2.1) sowie für Prüfungs- oder Examensergebnisse der
Nutzer:innen wird keine Haftung übernommen — die Anwendung ist Lernhilfe, kein
Garant für einen Lernerfolg.

## 9. Verbraucherstreitbeilegung

Der Anbieter ist nicht verpflichtet und nicht bereit, an einem
Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle im Sinne
des Verbraucherstreitbeilegungsgesetzes (VSBG) teilzunehmen.
`[Platzhalter/Entscheidung: Falls doch Teilnahmebereitschaft gewünscht ist,
Formulierung entsprechend anpassen und zuständige Schlichtungsstelle nennen.]`
**Hinweis zur Aktualität:** Die frühere EU-weite OS-Plattform für
Online-Streitbeilegung wurde von der EU-Kommission 2025 abgeschaltet; ein
Verweis darauf entfällt in diesem Entwurf bewusst. Bitte vor Veröffentlichung
gegenprüfen, da sich hieraus abgeleitete Musterformulierungen häufig noch
nicht aktualisiert im Umlauf befinden (siehe `00-uebersicht.md` Punkt 7).

## 10. Schlussbestimmungen

Es gilt deutsches Recht unter Ausschluss des UN-Kaufrechts. Für Verbraucher
mit gewöhnlichem Aufenthalt in einem anderen EU-Mitgliedstaat bleiben
zwingende Verbraucherschutzvorschriften dieses Staates unberührt. Ein
Gerichtsstand wird gegenüber Verbraucher:innen nicht vereinbart.

---

**Quellen/Begründung:** Leistungsbeschreibung und Preise aus
`docs/19-kosten-preis-budget.md` Abschnitt 4; RDG-Abgrenzung und
Nutzungsrechte an nutzergenerierten Gutachten wörtlich sinngemäß aus
`docs/06-recht-compliance.md` Abschnitt 1/2; Kündigungsbutton-Pflicht nach
§ 312k BGB, offen laut `docs/17-release-readiness.md` Abschnitt 4;
Haftungsfrage zur KI-Bewertung als „Frage" bereits in
`docs/17-release-readiness.md` Abschnitt 1 aufgeworfen. **Menschliche
Rechtsprüfung nötig:** Kündigungsabsatz erst veröffentlichen, wenn die
Funktion existiert (Punkt 3 in `00-uebersicht.md`); Haftungsklausel für den
Struktur-Check anwaltlich absichern; VSBG/OS-Hinweis auf aktuellen Rechtsstand
prüfen (Punkt 7).
