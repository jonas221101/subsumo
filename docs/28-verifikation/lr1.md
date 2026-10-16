# Quellenprüfung lr1 (Landesrecht BY/BW/NW/HE sowie BB/BE-Punkte aus L2/L3 und lr-00), Stand 2026-10-15

Geprüft gegen die Landesportale (Abruf 2026-10-15). Status der Redaktion bleibt `in-pruefung`, `normzitate_geprueft` unverändert.

Basis-URLs: https://www.gesetze-bayern.de, https://www.landesrecht-bw.de, https://recht.nrw.de, https://www.rv.hessenrecht.hessen.de, https://gesetze.berlin.de, https://bravors.brandenburg.de. In den Tabellen steht als Quelle das jeweilige Gesetz der genannten Plattform.

## Abrufwege

| Land | Portal | Abruf |
|---|---|---|
| BY | gesetze-bayern.de | Gesamttext je Gesetz über `/Content/Document/<Kürzel>/true` (PAG, LStVG, GO, BayBO, VwZVG, AGVwGO, BayVwVfG, BV, VfGHG) |
| BW, HE, BE | landesrecht-bw.de, rv.hessenrecht.hessen.de, gesetze.berlin.de (juris-Portal, JavaScript) | Seiten nur per Skript lesbar; Abruf der Gesamtausgaben über die portaleigene REST-Schnittstelle (`/jportal/wsrest/recherche3`, Suche + Dokument Teil `X`) in einer Headless-Sitzung; jeweils aktuellste Gesamtausgabe gewählt (BW PolG vom 06.10.2020, LBO Fassung 16.03.2026, GemO, LVwVG; HE HSOG, HGO, HBO, HV, StGHG; BE ASOG, BezVG, BauO Bln, VvB, LOG BE, VwVfG Bln) |
| NW | recht.nrw.de | Weboberfläche ohne Volltext; amtliche PDF der aktuellen Fassungen (PolG NRW 13.12.2025, OBG 01.07.2026, GO 01.01.2026, BauO NRW 01.09.2026, VwVG NRW 01.04.2025, JustG NRW 24.12.2024, LV NRW, VerfGHG NRW) |
| BB | bravors.brandenburg.de | Gesamttext je Gesetz über `/gesetze/<kürzel>` (bbgpolg, obg, bbgkverf, bbgbo_2016, vwvgbbg, vwvfgbbg, verfggbbg) und `/de/gesetze-212792` (LV) |

## 1. Bestätigt

| Punkt | Quelle |
|---|---|
| BY PAG Art. 2 I/II, 3, 4, 5, 7, 8, 10, 13, 17 I, 87 (Entschädigung Nichtstörer) | BayPAG |
| BY LStVG Art. 6, Art. 7 Abs. 2 | BayLStVG |
| BY GO Art. 23, 26, 29, 108, 110 | BayGO |
| BY BayBO Art. 55, 57 (Katalog), 60, 2 IV, 75, 76 | BayBO |
| BY lra: BV Art. 120, 98 S.4, VfGHG Art. 51, BayGO Art. 30/34/29 | BayVerf/BayVfGHG |
| BW PolG §§ 1, 3, 6, 7, 28 LVwVfG, § 46 LVwVfG, § 19 LVwVG | landesrecht-bw.de |
| BW GemO §§ 11, 24, 35, 42, 118 ff. | GemO BW |
| BW LBO §§ 56, 58, 64, 65; VerfGHG § 55 | landesrecht-bw.de |
| NW PolG §§ 1 I 3, 2, 3, 4, 5, 6, 8, 9, 12, 34, 35, 39, 43, 67; OBG §§ 1, 14-19, 25, 39; VwVG NRW §§ 55 II, 57, 63; JustG § 110 | recht.nrw.de |
| NW BauO NRW §§ 6 (0,4 H, min. 3 m), 62, 69, 74; BauNVO § 3 | recht.nrw.de |
| NW lra: Art. 75 Nr. 5a LV NRW, §§ 53 ff. VerfGHG NRW, in Kraft 01.01.2019 | recht.nrw.de LV NRW (16.01.2026), VerfGHG NRW (30.11.2024) |
| HE HSOG §§ 4, 6, 7, 9, 11, 12, 18 (Titel), 31, 32 (Titel) | HSOG |
| HE HGO §§ 19, 25 I-V, 66 | HGO |
| HE HBO §§ 63, 64, 65 (Titel), 73 I (soll) | HBO |
| HE lra: Art. 131 HV, § 43 StGHG (Grundrechtsklage) | rv.hessenrecht.hessen.de |
| BE ASOG § 17 I (Gefahr-Legaldefinition), §§ 13, 14, 16, 29, 30 (Titel), § 1 IV (Schutz privater Rechte), UZwG Bln | gesetze.berlin.de |
| BE VvB Art. 1 I, 4, 66, 67, 72, 74; BezVG § 2 I, 35, 36, 44-46 | gesetze.berlin.de |
| BE BauO Bln § 6 V (0,4 H, min. 3 m; Fall viergeschossig, 10 m -> 4 m korrekt) | gesetze.berlin.de |
| BE lra: § 49 VerfGHG Bln (Verfassungsbeschwerde) | gesetze.berlin.de |
| BB BbgPolG §§ 1, 3, 4, 5-7, 10, 16 (Titel), 17, 70; BbgOBG §§ 13-18, 38 | bravors |
| BB BbgKVerf §§ 2, 28, 54 | bravors |
| (Runde 2) BW AGVwGO § 4 (Normenkontrolle VGH auch gegen sonstige Rechtsvorschriften unter dem Landesgesetz), §§ 15 ff. (Vorverfahren Regel, Ausschluss nur § 15 AGVwGO BW) | landesrecht-bw.de AGVwGO (Fassung gültig ab 22.10.2008, Abruf 16.10.2026 über juris-REST) |
| (Runde 2) HE HessAGVwGO § 15 (Normenkontrolle), § 16a + Anlage (Vorverfahren entfällt nur im Katalog; Bauaufsicht/allgemeine Gefahrenabwehr nicht darin), § 16 | www.rv.hessenrecht.hessen.de HessAGVwGO (Gesamtausgabe 12.02.2026-31.12.2027) |
| (Runde 2) BB BbgVwGG § 4 Abs. 1 (Normenkontrolle OVG auch gegen sonstige Rechtsvorschriften), § 8 Abs. 2 (Behördenprinzip); BbgVwGG enthält keinen Ausschluss des Vorverfahrens (Fall bb-fall-bau-nachbarwiderspruch ok) | https://bravors.brandenburg.de/gesetze/bbgvwgg |
| (Runde 2) BY Art. 4 BayAGVwGO (Normenkontrolle) | https://www.gesetze-bayern.de/Content/Document/BayAGVwGO/true |
| (Runde 2) BE LOG BE §§ 2, 8, 13, 21-24 (Einheitsgemeinde, gesamtstädtische Bedeutung, Zuständigkeitskatalog per Rechtsverordnung, Bezirksaufsicht, Fachaufsicht) | gesetze.berlin.de LOG BE (gültig ab 01.01.2026) |
| (Runde 2) BVerfGE 141, 220 (BKAG) zu by-por-drohende-gefahr: hinreichend konkretisierte Gefahr verlangt bestimmte Tatsachen, allgemeine Erfahrungssätze genügen nicht; Prognose "wenigstens seiner Art nach konkretisiertes und zeitlich absehbares Geschehen", Sonderalternative für terroristische Straftaten (Leitentscheidung im Volltext gelesen) | https://www.bundesverfassungsgericht.de/SharedDocs/Entscheidungen/DE/2016/04/rs20160420_1bvr096609.html |

Rechtsprechungs-Fundstellen (nur Aktenzeichen/Datum über Webrecherche bestätigt, nicht der Inhalt): BVerfGE 141, 220 (BKAG, 1 BvR 966/09, 20.04.2016); BVerfGE 96, 27 (2 BvR 817/90, 30.04.1997); BVerwGE 52, 122 (IV C 22.75, 25.02.1977).

## 2. Korrigiert

| Punkt | alt -> neu | Quelle | Datei |
|---|---|---|---|
| BY PAG drohende Gefahr | Art. 11 Abs. 3 PAG -> Art. 11a PAG (+Wortlaut Art. 11a Abs. 1/2) | gesetze-bayern.de/Content/Document/BayPAG/true | by-polizei-ordnungsrecht.yaml |
| BY PAG Platzverweis Art. 16 | Tatbestand "Störung" -> Gefahr oder drohende Gefahr für bedeutendes Rechtsgut (Art. 16 Abs. 1) | BayPAG | by-polizei-ordnungsrecht.yaml |
| BY PAG Zwang | Art. 53 ff. (Datenverarbeitung) -> Art. 70 ff. PAG (Verwaltungszwang) | BayPAG Art. 53, 70, 75 | by-polizei-ordnungsrecht.yaml |
| BY PAG Gewahrsam | richterliche Entscheidung: Art. 18 PAG i.V.m. Art. 97 ergänzt | BayPAG Art. 18, 97 | by-polizei-ordnungsrecht.yaml |
| BY LStVG Störer/Nichtstörer | "Art. 9 bis 11 LStVG"/Nichtstörer Art. 11 -> Art. 9 LStVG (Art. 9 Abs. 3 Nichtstörer; Art. 10 = Sicherheitsbehörden und Polizei; Art. 11 = Entschädigung) | gesetze-bayern.de BayLStVG | by-polizei-ordnungsrecht.yaml |
| BY AGVwGO | Art. 15 AGVwGO (existiert nicht) -> Art. 12 AGVwGO (Widerspruchsverfahren, Optionsmodell in Katalogbereichen) | BayAGVwGO | by-polizei-ordnungsrecht.yaml |
| BY GO Wirkungskreis | eigener WK Art. 6 -> Art. 7 BayGO; übertragener Art. 7 -> Art. 8 (Art. 6 = allseitiger Wirkungskreis) | BayGO | by-kommunalrecht.yaml |
| BY GO Art. 37 | "Vollzug der Beschlüsse/dringende Anordnungen/übertragener WK" nicht in Art. 37 Abs. 1 -> Art. 36, Art. 37 Abs. 1 Nr. 2/3, Abs. 2, Abs. 3 | BayGO | by-kommunalrecht.yaml |
| BY GO Art. 38 | Formausnahme "laufende Verwaltung" -> "ständig wiederkehrende Geschäfte des täglichen Lebens, finanziell unerheblich"; unbelegte Rechtsfolge "schwebend unwirksam" neutralisiert | BayGO Art. 38 | by-kommunalrecht.yaml |
| BY GO Art. 49 | unbelegtes "Gruppeninteresse"-Argument entfernt; Abs. 3, 4 ergänzt | BayGO Art. 49 | by-kommunalrecht.yaml |
| BY GO Art. 24 | "dringendes öffentliches Bedürfnis" -> "aus Gründen des öffentlichen Wohls" (Fernwärme enger, Nr. 3) | BayGO Art. 24 | by-kommunalrecht.yaml |
| BY GO Art. 21 | Abs. 4 (jur. Personen), Abs. 1a ergänzt; Art. 109/110 Aufsicht präzisiert | BayGO | by-kommunalrecht.yaml |
| BY BayBO Art. 58 | "bestimmte Wohnbauvorhaben im qualifizierten B-Plan" -> jede bauliche Anlage, kein Sonderbau, Plan i.S.d. § 30 I/§§ 12, 30 II BauGB, Ausschlüsse Abs. 1 Nr. 4 | BayBO Art. 58 | by-bauordnungsrecht.yaml |
| BY BayBO Art. 59 | Prüfumfang um Abstandsflächen Art. 6, örtl. Bauvorschriften, Nr. 3 ergänzt | BayBO Art. 59 | by-bauordnungsrecht.yaml |
| BY BayBO Art. 6 | 0,2 H in GE/GI, Art. 6 Abs. 5a (Gemeinden > 250.000 EW) ergänzt | BayBO Art. 6 | by-bauordnungsrecht.yaml |
| BY BayBO Art. 63 | "kann/Ermessen" -> "soll" (Abs. 1 S. 1), Antrag Abs. 2 | BayBO Art. 63 | by-bauordnungsrecht.yaml |
| BY BayBO Art. 66 | "Unterschrift" -> schriftliche Zustimmung, Zustellung Abs. 1 S. 4 | BayBO Art. 66 | by-bauordnungsrecht.yaml |
| BW PolG Standardmaßnahmen | § 26 (jetzt OWi) -> § 27 Personenfeststellung; § 27a -> § 30 Platzverweis (PolG vom 6.10.2020, gültig ab 17.01.2021 bzw. 01.07.2026) | landesrecht-bw.de (juris-REST, Gesamtausgabe PolG) | bw-polizei-ordnungsrecht.yaml |
| BW PolG § 9 | Nichtstörer-Voraussetzungen "gegenwärtige erhebliche Gefahr / keine eigene Gefährdung" -> Wortlaut § 9 Abs. 1/2 (unmittelbar bevorstehende Störung, eigene Mittel reichen nicht) | PolG BW § 9 | bw-polizei-ordnungsrecht.yaml |
| BW PolG § 5 | Verhältnismäßigkeit: Platzhalter-norm -> § 5; unbelegte Dauer-Regel (Art. 4 III BayPAG) entfernt | PolG BW § 5 | bw-polizei-ordnungsrecht.yaml |
| BW PolG Zuständigkeit | Eilzuständigkeit "§ 60" (Datenübermittlung) -> § 105 Abs. 2/3, §§ 106, 107, 111 | PolG BW §§ 105-111 | bw-polizei-ordnungsrecht.yaml |
| BW PolG Entschädigung | "Ausgleichsanspruch § 55" (TK-Maßnahmen) -> §§ 100-103 PolG BW | PolG BW §§ 100-103 | bw-polizei-ordnungsrecht.yaml |
| BW LVwVG § 21 | "Sofortvollzug ohne VA" -> Abweichungsklausel § 21 (Vollstreckbarkeit, Androhung); unmittelbare Ausführung § 8 PolG; Zwangshaft ergänzt | LVwVG BW §§ 19-21 | bw-polizei-ordnungsrecht.yaml |
| BW GemO § 18 | Folge der Befangenheit: "unwirksam wenn Mitwirkung entscheidend" (= Art. 49 IV BayGO) -> § 18 Abs. 6 (rechtswidrig, Jahresfrist, Bürgermeister-Widerspruch/Beanstandung), Abs. 3 Gruppeninteresse, Abs. 2 Nr. 2, Abs. 5; Fall bw-fall-kom-befangenheit angepasst | landesrecht-bw.de GemO § 18 | bw-kommunalrecht.yaml |
| BW GemO § 4 Abs. 4 | Ausnahmenkatalog korrigiert (Öffentlichkeit, Genehmigung, Bekanntmachung; Widerspruch; Beanstandung/Rüge), gilt nur für Satzungen | GemO BW § 4 | bw-kommunalrecht.yaml |
| BW GemO § 54 | "handschriftlich" entfernt, Abs. 2/4 ergänzt | GemO BW § 54 | bw-kommunalrecht.yaml |
| BW GemO § 10 | Behauptung "auswärtige Personen nach Satzung zugelassen" -> § 10 Abs. 3, 4 | GemO BW § 10 | bw-kommunalrecht.yaml |
| BW GemO Aufsicht | § 129 (Fachaufsicht) ergänzt; §§ 43, 44 Abs. 2/3 präzisiert | GemO BW | bw-kommunalrecht.yaml |
| BW LBO § 51/52/49/50/5 VII/55 | Kenntnisgabe-Kreis, Prüfumfang § 52 II (§§ 14, 29-38 BauGB, §§ 5-7 LBO), § 49 (Errichtung und Abbruch), Nutzungsänderung § 50 II, Abstandsflächen-Staffelung 0,4/0,2/0,125 (min 2,5/2 m), Nachbarbeteiligung § 55 (nur bei Abweichungen, 5 Arbeitstage, 2 Wochen, Präklusion) + § 58 Zustellung | landesrecht-bw.de LBO (Fassung 16.03.2026) | bw-bauordnungsrecht.yaml |
| BW lra | "(seit 2013)" bei § 55 VerfGHG entfernt (nicht aus Portal belegbar) | VerfGHG BW § 55 | bw-landesrecht-allgemein.yaml |
| NW PolG § 34 | Tatbestand "oder Beseitigung einer Störung" entfernt (nur Gefahr); Abs. 1 S. 2 (Behinderung Rettungsdienst), Abs. 2 (Aufenthaltsverbot, 3 Monate) | recht.nrw.de PolG NRW (Fassung 13.12.2025) | nw-polizei-ordnungsrecht.yaml |
| NW OBG §§ 24 ff. | "Befugnisse der Ordnungsbehörden über § 24 OBG als Verweisung auf PolG" -> eigene Standardbefugnisse §§ 24 ff. OBG (§ 24o Platzverweis seit 01.07.2026) | recht.nrw.de OBG (Fassung 01.07.2026) | nw-polizei-ordnungsrecht.yaml |
| NW OBG §§ 3, 5 | Behördenaufbau präzisiert; "Bürgermeister" als örtliche Ordnungsbehörde entfernt | OBG NRW §§ 3, 5 | nw-polizei-ordnungsrecht.yaml |
| NW GO § 64 | Schriftform + zwei Unterschriften + handschriftlich -> Textform (§ 126b BGB), seit 17.07.2025; Ausnahme geldlich unerheblich | GO NRW (Fassung 01.01.2026) | nw-kommunalrecht.yaml |
| NW GO § 60 | "Bürgermeister entscheidet in Eilfällen" -> Hauptausschuss (Eilentscheidung), Bürgermeister mit Ratsmitglied (Dringlichkeitsentscheidung); laufende Verwaltung § 41 III | GO NRW §§ 41, 60 | nw-kommunalrecht.yaml |
| NW GO § 7 VI | Rügefrist unbestimmt -> sechs Monate; Ausnahmenkatalog; Hinweispflicht ist keine Ausnahme; NK: § 109a JustG | GO NRW § 7, JustG § 109a | nw-kommunalrecht.yaml |
| NW GO § 9 | "aus Gründen des öffentlichen Wohls" -> "bei öffentlichem Bedürfnis"; Einrichtungskreis | GO NRW § 9 | nw-kommunalrecht.yaml |
| NW GO § 31 | Kausalität: § 31 Abs. 6 (nur wenn für Abstimmungsergebnis entscheidend) | GO NRW § 31 | nw-kommunalrecht.yaml |
| NW GO §§ 8, 40, 62, 65, 119 | Abs. 3/4 (§ 8), Organstellung (§ 40 II), § 119 Abs. 1/2 präzisiert | GO NRW | nw-kommunalrecht.yaml |
| NW BauO NRW Generalklausel | "§ 61 BauO NRW" (= Vorrang anderer Gestattungsverfahren) als Ermächtigungsgrundlage -> § 58 Abs. 2 (Aufgaben/Befugnisse), § 81 (Einstellung), § 82 Abs. 1 (Beseitigung, Nutzungsuntersagung); Fall nw-fall-bau-nutzungsuntersagung angepasst | recht.nrw.de BauO NRW 2018 (Fassung 01.09.2026) | nw-bauordnungsrecht.yaml |
| NW BauO NRW §§ 63-65 | Verfahrensarten präzisiert (§ 63 Abs. 2, § 64 Abs. 1 Prüfumfang, § 65 große Sonderbauten) | BauO NRW | nw-bauordnungsrecht.yaml |
| NW BauO NRW § 72 | Nachbarbeteiligung nur vor Abweichungen/Befreiungen, 1 Monat, Präklusion, Zustellung | BauO NRW § 72 | nw-bauordnungsrecht.yaml |
| HE HSOG § 2 | "Begriffsbestimmung § 2 Nr. 1 (Gefahr)" -> § 2 = Aufgabenabgrenzung (Subsidiarität); Gefahr-Legaldefinition in § 11 | rv.hessenrecht.hessen.de HSOG (Fassung 19.12.2024/13.12.2025) | he-polizei-ordnungsrecht.yaml |
| HE HSOG § 5 | Ermessen "§ 3" (Geltungsbereich) -> § 5 | HSOG | he-polizei-ordnungsrecht.yaml |
| HE HSOG § 1 IV / § 2 | Eilzuständigkeit der Polizei "§ 1 Abs. 4" (= vorbeugende Straftatenbekämpfung) -> § 2 S. 1; Behördenstruktur §§ 82, 85 | HSOG | he-polizei-ordnungsrecht.yaml |
| HE HSOG §§ 47 ff. | Vollstreckung "maßgeblich HessVwVG" -> HSOG regelt Verwaltungszwang selbst (§§ 47-53, § 47 II ohne vorausgehenden VA bei "Gefahr" statt "gegenwärtiger Gefahr"), HessVwVG ergänzend; unmittelbare Ausführung § 8 | HSOG | he-polizei-ordnungsrecht.yaml |
| HE HSOG § 64 | "Schadensausgleichsvorschriften des HSOG" konkretisiert: §§ 64, 65, 70 | HSOG | he-polizei-ordnungsrecht.yaml |
| HE HGO § 25 VI | Befangenheit: "rechtswidrig, Kausalität nach Absätzen" -> Beschluss unwirksam, gilt nach 6 Monaten als wirksam (kein Kausalitätsvorbehalt); Abs. 1 S. 2, Abs. 4 | rv.hessenrecht.hessen.de HGO | he-kommunalrecht.yaml |
| HE HGO § 71 II | "handschriftlich" nicht im Gesetz -> Schriftform/QES; Unterschrift Bürgermeister/allg. Vertreter + weiteres Mitglied; Ausnahmen | HGO § 71 | he-kommunalrecht.yaml |
| HE HGO § 5 IV | Heilung: abschließender Katalog (§§ 4c, 8c, 53, 56, 58, 82 III, 88 II), 6 Monate Rüge | HGO § 5 | he-kommunalrecht.yaml |
| HE HGO §§ 50, 51, 65, 66, 70, 20, 135 | Organzuständigkeit präzisiert; § 20 Abs. 2/3 statt unbelegter Widmungsaussage; Aufsicht ohne unbelegte "Rechts-/Fachaufsicht"-Zuordnung | HGO | he-kommunalrecht.yaml |
| HE HBO § 6 V | Mindesttiefe "3 m" -> 2,50 m; GE/GI 0,2 H | HBO (Fassung 14.10.2025) | he-bauordnungsrecht.yaml |
| HE HBO §§ 62-66 | Genehmigungspflicht "Abbruch" nicht in § 62; Genehmigungsfreistellung-Voraussetzungen § 64 I; Prüfumfang § 65 I/§ 66; Platzhalter-norms durch §§ 61, 62, 71, 81, 82 ersetzt | HBO | he-bauordnungsrecht.yaml |
| HE HBO § 71 | Nachbarbeteiligung nur vor Abweichungen/Ausnahmen/Befreiungen, 2 Wochen; Zustimmende werden nicht benachrichtigt (statt "Einwendungen ausgeschlossen") | HBO § 71 | he-bauordnungsrecht.yaml |
| HE HBO §§ 61 II, 81, 82 | Ermächtigungsgrundlage Beseitigung/Nutzungsverbot: § 82 I, § 82 II (Verfahren verlangen) | HBO | he-bauordnungsrecht.yaml |
| BE VwVG-Anwendbarkeit | "VwVG des Bundes über § 5a VwVfG Bln" -> § 8 VwVfG Bln (Vollstreckung; § 5a alte Fassung bis 30.04.2016) | gesetze.berlin.de VwVfG BE 2016 § 8 | be-polizei-ordnungsrecht.yaml |
| BE ASOG §§ 2, 4 | Zuständigkeit: Ordnungsbehörden = Senatsverwaltungen und Bezirksämter (§ 2), Polizei subsidiär § 4 I (statt "Eilfall/keinen Aufschub"); Platzhalter-norm ersetzt | ASOG Bln (Fassung 2026) | be-polizei-ordnungsrecht.yaml |
| BE AZG | Allgemeines Zuständigkeitsgesetz (AZG) ist seit 01.01.2026 ersetzt (AZG gültig bis 31.12.2025) durch Landesorganisationsgesetz LOG BE (10.07.2025): Zuständigkeitsabgrenzung §§ 8, 13, Bezirksaufsicht §§ 21, 22, Eingriffsrecht § 23, Fachaufsicht § 24; Einheitsgemeinde § 2 LOG; alle AZG-Fundstellen in Karten/Schema/Fall ersetzt | gesetze.berlin.de LOG BE, AZG (Suchtreffer "gültig bis 31.12.2025"), BezVG § 3 II, ASOG § 2 IV | be-kommunalrecht.yaml |
| BE Bezirksaufsicht | "Rechtsaufsicht über Selbstverwaltung + Fachaufsicht bei Weisungsaufgaben + Eingriffsrecht bei Gefahr für Wohl des Landes" -> Bezirksaufsicht (Rechtmäßigkeit, Verwaltungsvorschriften), Eingriffsrecht bei erheblichen Gesamtinteressen Berlins (§ 23 LOG; Art. 67 I VvB) | LOG BE §§ 21-24 | be-kommunalrecht.yaml |
| BE Bürgerbegehren | "Kostendeckungsvorschlag"/"Angelegenheiten der Hauptverwaltung ausgeschlossen" -> § 45 BezVG (Angelegenheiten der BVV nach §§ 12, 13; finanzwirksam nicht unzulässig) | BezVG §§ 44-46 | be-kommunalrecht.yaml |
| BE Bezirke/Organe | BezVG § 2 I (Selbstverwaltungseinheiten ohne Rechtspersönlichkeit), Art. 4, 66 II, 67 II, 72, 74 VvB, § 35 BezVG konkretisiert | VvB, BezVG | be-kommunalrecht.yaml |
| BE BauO Bln §§ 61-64, 67, 70, 79, 80 | Platzhalter-norms "Bauordnung für Berlin (BauO Bln)" durch §§ 58, 61-64, 67, 70, 71, 79, 80, 81 ersetzt; Prüfprogramm § 63 I (inkl. §§ 4-6); Abstandsflächen § 6 V (0,2 H GE/GI, GK 1/2 3 m), Abweichung "soll" § 67 I, Abs. 11 zu § 6; unbelegte Behördenzuweisung "untere/obere Bauaufsicht" neutralisiert | gesetze.berlin.de BauO Bln (Fassung 23.07.2026) | be-bauordnungsrecht.yaml |
| BB BbgPolG § 2 | Eilzuständigkeit der Polizei "§ 1 BbgPolG" -> § 2 BbgPolG (Karten, Aufbau, Fall, Prüfpunkt-Norm) | bravors.brandenburg.de BbgPolG | bb-polizei-ordnungsrecht.yaml |
| BB BbgPolG §§ 53 ff. | Vollstreckung: Polizei nach §§ 53 ff. BbgPolG (§ 53 II), Ordnungsbehörden nach VwVGBbg (§§ 27, 28); statt "VwVGBbg regelt die Zwangsmittel" | BbgPolG, VwVGBbg | bb-polizei-ordnungsrecht.yaml |
| BB BbgOBG § 23 | Standardbefugnisse der Ordnungsbehörden nur über § 23 BbgOBG (Verweisung) konkretisiert; §§ 7, 18 Notstand, §§ 70/38 Entschädigung | BbgPolG, BbgOBG | bb-polizei-ordnungsrecht.yaml |
| BB BbgKVerf § 15 | Bürgerbegehren: Zulässigkeit entscheidet Kommunalaufsichtsbehörde (nicht Gemeindeorgan); Kostenschätzung statt "Kostendeckungsvorschlag"; 10 %-Quorum, 25 %-Zustimmungsquorum, Ausschlusskatalog Abs. 5 | bravors BbgKVerf § 15 | bb-kommunalrecht.yaml |
| BB BbgKVerf §§ 109, 121, 122 | Aufsicht: Rechtsaufsicht (Selbstverwaltung), Sonderaufsicht (Pflichtaufgaben nach Weisung), Fachaufsicht (Auftragsangelegenheiten) statt pauschal "Weisungsaufgaben = Fachaufsicht"; § 119 Rechtsmittel | BbgKVerf | bb-kommunalrecht.yaml |
| BB BbgKVerf § 12 II | "öffentliches Bedürfnis" -> "Gründe des öffentlichen Wohls"; Fall bb-fall-kom-anschlusszwang-wasser angepasst | BbgKVerf § 12 | bb-kommunalrecht.yaml |
| BB BbgKVerf § 3 IV / § 22 VI | Heilungsfrist konkretisiert: ein Jahr; Befangenheit: "entscheidend war" statt "ausschlaggebend sein konnte" | BbgKVerf | bb-kommunalrecht.yaml |
| BB BbgKVerf § 57 | Verpflichtungserklärung: Wortlaut (Schriftform/Schriftformersatz, HVB + Stellvertretung, Ausnahmen); § 57 V schwebend unwirksam gesetzlich geregelt | BbgKVerf § 57 | bb-kommunalrecht.yaml |
| BB BbgKVerf Platzhalter-norms | "Vorschriften der BbgKVerf zu ..." durch §§ 3, 12, 15, 22, 28, 54, 57, 109 ff., 133-138 ersetzt | BbgKVerf | bb-kommunalrecht.yaml |
| BB BbgBO §§ 59-64 | "Genehmigungsfreistellung für Wohnbauvorhaben" existiert in BbgBO (Fassung 2016) nicht -> Bauanzeigeverfahren § 62 (Wohngebäude GK 1-2, Wunsch der Bauherrschaft, 1 Monat), vereinfachtes Verfahren § 63 nur Wohngebäude GK 1-3 im B-Plan (Prüfung: Festsetzungen + andere Vorschriften), sonst § 64; Prüfumfang korrigiert | bravors.brandenburg.de/gesetze/bbgbo_2016 | bb-bauordnungsrecht.yaml |
| BB BbgBO § 67 | Abweichung "im Ermessen" -> "hat ... zuzulassen" (gebunden), Antrag in Textform Abs. 2, Nachbarbeteiligung § 70 II | BbgBO § 67, § 70 | bb-bauordnungsrecht.yaml |
| BB BbgBO §§ 6 V, 79, 80, 81 | Abstandsflächen GE/GI 0,2 H, GK 1-2 3 m; Eingriffsnormen und Anpassung bestehender Anlagen konkretisiert; Platzhalter-norms ersetzt | BbgBO | bb-bauordnungsrecht.yaml |
| (Runde 2) BY by-por-drohende-gefahr, BVerfG-Charakterisierung | "ein bloßer Gefahrenverdacht nicht genügt" -> "allgemeine Erfahrungssätze allein nicht genügen, bestimmte Tatsachen müssen die Prognose tragen; Alternative bei terroristischen Straftaten: individuelles Verhalten mit konkreter Wahrscheinlichkeit" | BVerfG 1 BvR 966/09, Rn. zu C IV 1 b (bundesverfassungsgericht.de) | by-polizei-ordnungsrecht.yaml |
| (Runde 2) HE Normenkontrolle | "setzt eine landesrechtliche Bestimmung voraus" -> konkret § 15 HessAGVwGO; Vorverfahren: § 16a HessAGVwGO + Anlage, § 16 | rv.hessenrecht.hessen.de HessAGVwGO | he-kommunalrecht.yaml, he-polizei-ordnungsrecht.yaml |
| (Runde 2) BW Normenkontrolle | "i. V. m. dem Landesrecht" -> § 4 AGVwGO BW | landesrecht-bw.de | bw-kommunalrecht.yaml |
| (Runde 2) BB Normenkontrolle | "soweit das Landesrecht sie eröffnet, sonst Inzidentkontrolle" -> § 4 Abs. 1 BbgVwGG (OVG), daneben Inzidentkontrolle | bravors BbgVwGG | bb-kommunalrecht.yaml |

## 3. Offen für menschliche Prüfung (Stand Runde 2, 2026-10-16)

| Punkt | Grund |
|---|---|
| Rechtsfolge von Formverstößen bei Verpflichtungserklärungen (BW § 54 GemO, NW § 64 GO, HE § 71 HGO, BY Art. 38 GO) | Für RP bestätigt (OLG Zweibrücken 30.11.2023 - 4 U 152/22 zitiert ständige BGH-Rspr.: Form-/Vertretungsmangel -> §§ 177 ff. BGB, schwebend unwirksam, BGHZ 32, 375), diese BGH-Linie gilt über Art. 55 EGBGB länderübergreifend; für BW/NW/HE/BY aber keine landesspezifische Entscheidung im Volltext gefunden, BGH-Volltexte (vor 2010) nicht frei abrufbar. Für BY gibt es Hinweise (nur Sekundärmeldung), dass das BayObLG 2025 anders argumentiert - nicht geprüft |
| Streitstände (Anscheinsgefahr/Kostenhaftung, Zweckveranlasser, Störerauswahl/Opfergrenze, formelle Illegalität, Kommunalverfassungsstreit) | reine Lehre, keine Primärquelle für "Streit" möglich; BVerfGE 102, 1 (Altlasten, Kostenlimit Zustandsstörer) im Volltext geprüft: Darstellung (Verkehrswert nach Sanierung als Anhaltspunkt, Ausnahme bei bewusst übernommenem Risiko) stimmt |
| BE: Behördenzuordnung der Bauaufsicht (Bezirksamt/Senatsverwaltung), Klage gegen das Land (§ 78 VwGO) | Praxis belegt (VG Berlin 19 K 192.14, 15.07.2016: Baugenehmigung und Widerspruchsbescheid durch das Bezirksamt), gesetzliche Zuweisung aber im Allgemeinen Zuständigkeitskatalog (AZG-Katalog), der nach § 51 LOG BE übergangsweise fortgilt und im Portal nicht (mehr) abrufbar ist. Hinweis: § 51 LOG BE relativiert die Runde-1-Angabe, der AZG sei durch das LOG "ersetzt" (Katalog gilt bis zur Rechtsverordnung nach § 13 LOG weiter). Karte bleibt neutral |
| BE: Datumsstand VerfGHG Bln § 49 | nicht erneut geprüft |
| Prüfpunkt-Keywords in Fällen (z. B. 'AZG', 'öffentliches Bedürfnis', 'Kausalität') | absichtlich als Zusatz-Keywords belassen; Redaktion kann bereinigen. 'AZG' bleibt sachlich vertretbar (§ 51 LOG BE) |
| BVerfGE 79, 127 (Rastede) in bb-kom-selbstverwaltung | Entscheidung vor 2010, kein amtlicher Volltext gefunden (bundesverfassungsgericht.de-Seite 404); nur Fundstelle/Datum sekundär |

## Runde 2 (2026-10-16)

Zahl (Tabelle 3 der Runde 1: 10 Zeilen, davon 3 Zeilen zusammengefasst bearbeitet): bestätigt 4 (Normenkontrolle BW/HE/BB/BY; Vorverfahren BW/HE/BB; BVerfG-BKAG-Inhalt; HE-AGVwGO), davon 4 Textstellen im Inhalt präzisiert (Tabelle 2: BY-BVerfG-Formulierung, HE, BW, BB), weiter offen 6 (Formfolgen BW/NW/HE/BY, Streitstände, BE-Bauaufsicht, BE VerfGHG-Datum, Keywords, Rastede). Zugang: juris-REST-Schnittstelle der Portale (Playwright-Sitzung) und Gesamtausgaben; zusätzlich bundesverfassungsgericht.de.
