# Redaktions-Prüfliste: 21 neue Themen (September 2026)

> Status aller hier genannten Themen: `redaktion.status: in-pruefung`,
> `erzeugt_von: claude-fable-5-1`. Sie sind im Bestand und werden vom
> Validator (`backend/scripts/validate_content.py`) und vom Normzitat-Gate
> (`check_norms`) ohne Fehler durchgelassen, aber **noch von keinem Menschen
> gelesen**. Das ist die offene Bedingung aus Gate G3
> (`docs/18-release-2-wochen.md`). Diese Liste sammelt, was die erzeugenden
> Agenten selbst als fachlich prüfenswert markiert haben, damit die
> Durchsicht gezielt beginnen kann statt bei Null.
>
> Freigabe je Datei: `status` auf `mensch-freigegeben` setzen und
> `geprueft_von`/`geprueft_am` eintragen. Bis dahin erscheint pro Datei
> eine Validator-Warnung (gewollt).

Hinweis zur Entstehung: Die Normwiedergaben sind Paraphrasen aus dem
Modellgedächtnis, das Gate prüft nur Kürzel und Nummernbereich, nicht den
Inhalt. Jahreszahlen zu BGH/BVerfG-Entscheidungen sind kanonisch, aber
ungeprüft. Alle streitigen Punkte sind als `streitstand`-Karten mit
Ansichten und h.M./Rspr.-Zuordnung ausgewiesen; die Gewichtung ("h.M.",
"wohl h.L.", "vereinzelt") ist die Stelle, an der ein Mensch am ehesten
korrigieren wird.

## Zivilrecht (7 Themen, 61 Karten)

| Datei | Prüfen |
|---|---|
| `zr-schadensrecht-249-254` | Karte zum immateriellen Schaden leitet die Geldentschädigung bei APR-Verletzung "aus dem Schutzauftrag der Verfassung" her (ohne Art.-Zitat) - Formulierung prüfen. Rechtsprechungskarte zur 130-%-Grenze. |
| `zr-bereicherungsrecht-nichtleistungskondiktion` | Streitstände Zuweisungs- vs. Rechtswidrigkeitstheorie; Erlös vs. objektiver Wert bei § 816 Abs. 1 S. 1 BGB. |
| `zr-sr-ebv-987-ff` | Streitstand § 988 BGB analog beim rechtsgrundlosen Erwerb: BGH (Analogie) vs. "wohl h.L." (Ablehnung) - Gewichtung ist Einschätzung. Fall "Segelboot": Sperrwirkung auch gegenüber § 823 BGB für den gutgläubigen Eigenbesitzer angenommen, Fremdbesitzerexzess verneint. |
| `zr-goa-677-ff` | Vergütung berufstypischer Tätigkeit mit "Rechtsgedanke des § 1877 Abs. 3 BGB" begründet (Nachfolgenorm des § 1835 Abs. 3 BGB a.F. seit 2023) - **Absatznummer gegen aktuelle Fassung prüfen.** |
| `zr-sr-beseitigung-unterlassung-1004` | Umfang des Beseitigungsanspruchs: BGH-Linie als h.M., restriktive Literatur als Gegenmeinung - bewusst vereinfacht, Meinungsstand ist unübersichtlich. |
| `zr-deliktsrecht-831-833` | Streitstand "Verschulden des Verrichtungsgehilfen erforderlich?" - Gegenmeinung heute nur schwach vertreten, ggf. auf "vereinzelt" abschwächen. Fall "Schulpferd": Anrechnung eigener Tiergefahr analog § 254 BGB, Quote "etwa ein Drittel" ist Wertung (im Erwartungshorizont nur die Kürzung als solche). |
| `zr-abtretung-398` | Streitstand absolute vs. relative Wirkung des § 399 Alt. 2 BGB. § 354a HGB nur in Prosa (HGB nicht im Gate); Schuldner im Fall bewusst Verbraucher. |

## Strafrecht (7 Themen, 61 Karten)

| Datei | Prüfen |
|---|---|
| `sr-at-konkurrenzen` | Klammerwirkung: Formel "verklammerndes Delikt mindestens annähernd gleichwertig" - genaue BGH-Formel (Gleichwertigkeit mit dem *leichteren* der verbundenen Delikte) gegenprüfen. § 123 StGB konsumiert durch § 244 Abs. 1 Nr. 3 StGB als h.M.; § 303 StGB bewusst aus dem Fall gehalten. |
| `sr-at-rechtfertigende-einwilligung` | Willensmängel: Rspr.-Linie ("jeder täuschungsbedingte Irrtum") als "Rspr. und wohl h.M." - Literatur überwiegend rechtsgutsbezogen. |
| `sr-at-schuld-20-35` | § 21 StGB bei selbstverschuldeter Trunkenheit als Rspr.-Linie (Gesamtwürdigung) formuliert. § 20 StGB in aktueller Wortlautfassung. a.l.i.c.-Streitstand mit "BGH 1996" (§§ 315c, 316). |
| `sr-at-erlaubnistatbestandsirrtum` | Fall: Vermeidbarkeit durch Sachverhalt vorgegeben; bei C mittelbare Täterschaft kraft überlegenen Wissens vorrangig, Anstiftung nach h.M. zulässig. |
| `sr-bt-diebstahl-qualifikationen-244` | Gefährliches Werkzeug objektiv bestimmt ("BGH 2008"), Bandenbegriff ("BGH 2001", Großer Senat) - Jahreszahlen verifizieren. Zitierweise `Nr. 1a`/`Nr. 1b` (Gate akzeptiert kein `lit. a`). |
| `sr-bt-koerperverletzung-226-227` | "Glied" nur äußere Körperteile mit Gelenkverbindung als h.M. ("BGH 2007" wichtiges Glied). Konkurrenzen § 227/versuchtes Tötungsdelikt und § 224/§ 227 als h.M. (Tateinheit) - Literatur teils anders. |
| `sr-bt-anschlussdelikte-257-259` | § 257 StGB: Surrogate keine "Vorteile der Tat" als h.M., aber str. Absatzerfolg bei § 259 ("BGH 2013"). Fall: Versuchsbeginn der Strafvereitelung durch Verstecken des Rades angenommen (§ 258 Abs. 4 StGB) - vertretbar, prüfungswürdig. |

## Öffentliches Recht (7 Themen, 62 Karten)

| Datei | Prüfen |
|---|---|
| `or-vwgo-fortsetzungsfeststellungsklage` | Erledigung vor Klageerhebung: analog § 113 Abs. 1 S. 4 VwGO ohne Vorverfahren/Frist als h.M.; Präjudizinteresse dabei mit BVerwG verneint (Literatur teils anders, als Streitstand markiert). Erledigungsdefinition zitiert § 43 Abs. 2 VwVfG - Hinweis auf prozessuale Erledigung ggf. ergänzen. |
| `or-vwgo-allgemeine-leistungsklage-feststellungsklage` | Subsidiarität § 43 Abs. 2 S. 1 VwGO gegenüber Hoheitsträgern: Rspr.-Linie als h.M. |
| `or-vwgo-normenkontrolle-47` | Antragsbefugnis von Plannachbarn über Abwägungsgebot ohne § 1 Abs. 7 BauGB-Zitat (Gate). § 47 Abs. 2a VwGO a.F. bewusst nicht erwähnt. |
| `or-verfassungsprozessrecht-normenkontrolle-93-100` | Streit "Zweifel" (Art. 93 GG) vs. "für nichtig hält" (§ 76 BVerfGG). **Aufzählung der Erforderlichkeits-Titel in Art. 72 Abs. 2 GG (Nr. 4, 7, 11, 13, 15, 19a, 20, 22, 25, 26) gegen aktuelle GG-Fassung prüfen.** |
| `or-verfassungsprozessrecht-verfassungsbeschwerde` | EU-ausländische juristische Personen als beschwerdefähig (BVerfG-Rspr.). Prüfungsumfang bei Urteilsverfassungsbeschwerden als Streitstand. Subsidiaritäts-Ausnahme im Fall als "vertretbar auch anders". |
| `or-staatsorganisationsrecht-staatsstrukturprinzipien` | Rückwirkungsterminologie beider Senate; Fallgruppen der echten Rückwirkung. Sozialstaat/Republik nur eine Karte. Sperrklausel-Beispiel ohne Entscheidungsnennung. |
| `or-staatsorganisationsrecht-gesetzgebungskompetenzen` | Fall lehnt sich an die Mietendeckel-Konstellation an ("BVerfG (2021)", eigener Sachverhalt). "Absichtsvoller Regelungsverzicht" als Sperrwirkungs-Streitstand. Formulierung "lex posterior" zu Art. 72 Abs. 3 S. 3 GG redaktionell prüfen. |

## Qualitätsdurchgang an bestehenden Dateien (gleicher Lauf)

- 13 von 18 normlosen Karten haben jetzt `norms`. Offen bleiben 5 Karten
  in `or-sicherheitsrecht-generalklausel-standardmassnahmen` (Gefahrbegriff,
  Anscheinsgefahr, Gefahrenverdacht, Störerbegriffe): reines Landesrecht,
  kein Bundesgesetz trägt sie. Entscheidung nötig: PolG/MEPolG in die
  Positivliste `GESETZE` (`backend/app/services/redaktion/norm_gate.py`)
  aufnehmen oder normlos akzeptieren.
- `card_slugs`-Abdeckung der Fall-Prüfpunkte in 13 Themen von 29-60 % auf
  71-100 % gehoben. Unter 80 % bleiben `sr-notstand-34` (keine Karte zu
  § 303 StGB) und `zr-schuldrecht-at-unmoeglichkeit` (keine Karte zu § 433
  BGB / Differenzschaden - `zr-schadensrecht-249-254` könnte die
  Differenzhypothese-Karte liefern).
- Weiterhin offen aus dem Audit (nicht in diesem Lauf): Werkvertrag,
  Bürgschaft, Grundstücksrecht §§ 873/892 (ZR); § 263a, §§ 142/315c (SR);
  Störerauswahl, Baurecht, Kommunalrecht, Staatshaftung (ÖR) - die drei
  letzten brauchen zuerst eine Erweiterung der Gate-Positivliste (PolG,
  BauGB, Landesrecht).
