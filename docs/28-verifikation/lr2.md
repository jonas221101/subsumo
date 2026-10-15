# Quellenprüfung lr2 (NI, HH, HB, SH, MV, SN, ST, TH, RP, SL) – 2026-10-15

Quelle des Normtexts: https://gesetze.co/<LAND>/<GESETZ>/<Paragraph> (serverseitig gerenderter Landesrecht-Volltext). Die amtlichen Landesportale (landesrecht-hamburg.de, voris, gesetze-rechtsprechung.sh.juris.de, landesrecht-mv.de, revosax.sachsen.de, landesrecht.sachsen-anhalt.de, landesrecht.thueringen.de, landesrecht.rlp.de, recht.saarland.de) liefern per curl nur JavaScript-Shells (ca. 5 KB, kein Normtext), transparenz.bremen.de antwortet mit HTTP 403; dejure.org/buzer.de führen kein Landesrecht. gesetze.co ist kein amtliches Portal: Aktualität/Stand daher für jeden Punkt mit "Quelle gesetze.co" menschlich gegenzulesen.
Status/`normzitate_geprueft` wurden nicht verändert.

## NI und HH

Quelle: Wortlaut der Landesgesetze über gesetze.co (SSR-Seiten, Pfad `<LAND>/<GESETZ>/<§>`), abgerufen 2026-10-15; die amtlichen Landesportale (landesrecht-hamburg.de, voris.niedersachsen.de) liefern nur JavaScript-Shells. Gesetzeskürzel dort: NI/NPOG, NKomVG, NBauO, NStGHG, NJG, NVwVfG, NVwVG, Verf; HH/SOG, PolDVG, BezVG, HBauO, Verf_HA, VerfGG_HA_1982, VwGOAG_HA, HmbVwVfG.

### 1. Bestätigt
| Punkt | Quelle |
|---|---|
| § 11 NPOG Generalklausel (Vorrang des Dritten Teils); §§ 17, 18 NPOG Platzverweisung/Gewahrsam; §§ 6, 7, 8 NPOG Verhaltens-/Zustands-/Nichtstörer | gesetze.co NI/NPOG/6,7,8,11,17,18 |
| § 3 Abs. 1 SOG HH Generalklausel; §§ 8, 9, 10 SOG HH Störer; § 13 SOG HH Gewahrsam | HH/SOG/3,8,9,10,13 |
| NI: keine Individual-VB zum Staatsgerichtshof; Art. 54 Nr. 5 NV kommunale VB | NI/Verf/54, NI/NStGHG/8 |
| HH: keine Individual-VB zum Hamburgischen Verfassungsgericht | HH/Verf_HA/65, VerfGG_HA_1982/14 |
| NI/HB-Landesverfassungsbeschwerde NI-Aussage (Karte ni-lra-verfassungsgericht) inhaltlich richtig | s. o. |
| Art. 57 NV Selbstverwaltung; §§ 45, 58, 74, 76, 80, 85 NKomVG Organe/Zuständigkeiten (Organbezeichnung korrigiert, s. u.); §§ 170 ff. NKomVG Aufsicht | NI/Verf/57, NI/NKomVG |
| § 41 NKomVG Mitwirkungsverbot (Kern: unmittelbarer Vorteil, Ausnahmen, Unwirksamkeit) | NI/NKomVG/41 |
| § 59, § 70 Abs. 1 NBauO Genehmigungsvorbehalt/Anspruch; § 79 NBauO Eingriffsbefugnis (Nr. 1, 4, 5); § 66 NBauO Abweichung | NI/NBauO |
| § 6 HBauO Abstandsflächen; § 67 HBauO Abweichung; §§ 79, 80 HBauO Eingriff; §§ 61-64 HBauO Verfahrensarten | HH/HBauO |
| NVwVfG = Verweisungsgesetz (§ 1 NVwVfG); HmbVwVfG = Vollgesetz; § 28 HmbVwVfG Anhörung | NI/NVwVfG/1, HH/HmbVwVfG/1,28 |
| BezVG: sieben Bezirke (§ 1), Organe (§§ 3, 34, 35), Bürgerbegehren (§ 32), Aufsicht/Evokation (§§ 42-45); Art. 4 HV Einheitsgemeinde/Bezirksämter | HH/BezVG, HH/Verf_HA/4 |
| Beklagter bei Bezirksamtsakt = FHH (kein Behördenprinzip im VwGOAG HA erkennbar) | HH/VwGOAG_HA |
| Normenkontrolle § 47 I Nr. 2 VwGO in NI vorgesehen (§ 75 NJG) | NI/NJG/75 |

### 2. Korrigiert
| Punkt | alt -> neu | Quelle | Datei |
|---|---|---|---|
| Platzverweis HH | § 12b SOG HH -> § 12a (§ 12b = Betretungs-/Aufenthaltsverbot, max. 6 Monate); Karte, Aufbau, Fall, Prüfpunkte, Keywords | HH/SOG/12a,12b | hh-polizei-ordnungsrecht.yaml |
| Nichtstörer HH | "gegenwärtige erhebliche Gefahr, Notstand" -> § 10 SOG HH: unmittelbar bevorstehende Gefahr, keine ausreichenden eigenen Kräfte, Entschädigung auf Antrag (Abs. 3) | HH/SOG/10 | hh-polizei-ordnungsrecht.yaml |
| Zustandsstörer HH | Reihenfolge Eigentümer zuerst (§ 9 SOG HH), Gewalt gegen Willen des Eigentümers -> allein verantwortlich | HH/SOG/9 | hh-polizei-ordnungsrecht.yaml |
| Zuständigkeit/Privatrechtsschutz HH | ergänzt § 3 Abs. 2 (Vollzugspolizei unaufschiebbar), § 3 Abs. 3 | HH/SOG/3 | hh-polizei-ordnungsrecht.yaml |
| Landes-VB HH | "Verfahrensgegenstand nur Landesgrundrechte" (impliziert VB) -> keine Individual-VB; Zuständigkeitskatalog Art. 65 III HV | HH/Verf_HA/65 | hh-landesrecht-allgemein.yaml |
| Landes-VB NI | Präzisiert: Art. 54 NV, § 8 NStGHG, Art. 54 Nr. 5 NV (Aussage selbst war richtig) | NI/Verf/54 | ni-landesrecht-allgemein.yaml, ni-kommunalrecht.yaml |
| Organ NI | "Verwaltungsausschuss" -> Hauptausschuss (§§ 74, 76 NKomVG); HVB: § 85 III, § 86 | NI/NKomVG | ni-kommunalrecht.yaml |
| § 58 NKomVG | "Angelegenheiten von grundsätzlicher Bedeutung" -> ausschließlicher Katalog § 58 I | NI/NKomVG/58 | ni-kommunalrecht.yaml |
| § 41 NKomVG | "Verwandte in gerader Linie" -> Ehegatte/Lebenspartner, Verwandte bis 3., Verschwägerte bis 2. Grad, Vertretene; Folge "unwirksam" (§ 41 VI); Ausnahmen Abs. 3 | NI/NKomVG/41 | ni-kommunalrecht.yaml |
| Normenkontrolle NI | "soweit Landesrecht vorsieht" -> § 47 I Nr. 2 VwGO i. V. m. § 75 NJG | NI/NJG/75 | ni-kommunalrecht.yaml |
| Kommunalaufsicht NI | Mittel mit §§ 172-175 belegt; öffentl. Einrichtung -> § 30 NKomVG statt "Gemeindeordnung" | NI/NKomVG | ni-kommunalrecht.yaml |
| NPOG Begriffe | Schutzgut: Sicherheit oder Ordnung (§ 2 Nr. 1); gegenwärtig/erheblich § 2 Nr. 2, 3; Polizei-Eilzuständigkeit § 1 II; Nichtstörer-Ausgleich § 80 I; Aufenthaltsverbot § 17 III; richterl. Entscheidung § 19; Vollstreckung = §§ 64 ff. NPOG (nicht primär NVwVG) | NI/NPOG/1,2,19,64-70,80 | ni-polizei-ordnungsrecht.yaml |
| Abstandsflächen NI | "Abstandsflächen § 5 NBauO" -> Grenzabstände, 0,4 H min. 3 m (Gewerbe 0,2 H) | NI/NBauO/5 | ni-bauordnungsrecht.yaml, ni-landesrecht-allgemein.yaml |
| Verfahrensarten NI | "Genehmigungsfreistellung" -> genehmigungsfreie Maßnahmen §§ 61, 62, verfahrensfrei § 60, vereinfacht § 63, regulär § 64; § 59 III | NI/NBauO | ni-bauordnungsrecht.yaml |
| Bauaufsichtsbehörden NI | -> § 57 I NBauO (Landkreise, kreisfreie und große selbständige Städte) | NI/NBauO/57 | ni-bauordnungsrecht.yaml |
| Eingriff NI/HH | allgemein -> § 79 I NBauO; §§ 79, 80 HBauO | s. o. | ni-/hh-bauordnungsrecht.yaml |
| Abweichung HH | "Ermessen, Nullreduktion" -> Soll-Vorschrift, gesonderter Antrag (§ 67 HBauO) | HH/HBauO/67 | hh-bauordnungsrecht.yaml |
| Abstandsflächen HH | konkretisiert: 0,4 H, min. 2,50 m; Gewerbe 0,2 H (§ 6 IV, V) | HH/HBauO/6 | hh-bauordnungsrecht.yaml |
| Verfahrensarten HH | -> §§ 61, 62, 63, 64 HBauO | HH/HBauO | hh-bauordnungsrecht.yaml |
| BezVG-Aussagen HH | Bezirksversammlung wirkt nicht "mit" an Wahl, sondern schlägt dem Senat vor, Senat bestellt (§ 34); Bürgerbegehren-Quoren (§ 32); Aufsicht §§ 42-45 | HH/BezVG | hh-kommunalrecht.yaml |

### 3. Offen für menschliche Prüfung
| Punkt | Grund |
|---|---|
| Amtlichkeit/Aktualität der Textquelle | gesetze.co ist kein amtliches Portal; amtliche Portale nicht maschinenlesbar |
| HH: Bezirksämter als Bauaufsichtsbehörden | HBauO § 58 sagt nur "Aufgabe des Staates"; Zuständigkeitsanordnung nicht geprüft |
| HH: Evokationsrecht Senat im Detail (Gesetz über Verwaltungsbehörden § 1 IV) | nicht in BezVG-Text, Gesetz nicht abgerufen |
| NI: § 85 I NKomVG Detailzuweisung HVB | nur Kerninhalt geprüft |
| Karte ni-kr-rastede (BVerfGE 79, 127) | Rechtsprechung, nicht Gegenstand dieser Landesrechtsprüfung |
| Mehrere Kartensätze in examen/bundeslaender/ni.yaml, hh.yaml (SOG HH § 12b-Zitate) | außerhalb des Auftrags (nur content/landesrecht), ggf. mitzuziehen |

## HB und SH

Quelle (alle Zeilen): gesetze.co (amtlicher Wortlaut der Landesgesetze, per curl abgerufen 2026-10-15; Pfad https://gesetze.co/<LAND>/<GESETZ>/<Nr>). Die Landesportale (landesrecht-hamburg.de, transparenz.bremen.de [403], gesetze-rechtsprechung.sh.juris.de usw.) liefern nur JavaScript-Shells; Ersatzweg dokumentiert.

### Bestätigt
| Punkt | Quelle |
|---|---|
| SH: § 174 LVwG Generalklausel (nur öffentliche Sicherheit), § 162 (Aufgaben, Abs. 2 Schutz privater Rechte), § 163/164/165/168 Behörden, § 201 Platzverweis/Aufenthaltsverbot, § 204 Gewahrsam, §§ 218-220 Verantwortlichkeit, § 221 Entschädigung, §§ 228 ff. Verwaltungszwang (§ 230 sofortiger Vollzug, § 235 Zwangsmittel, § 236 Androhung, § 249 Kosten) | gesetze.co/SH/LVwG/<Nr> |
| SH: Landesverfassungsgericht ohne allgemeine Individualverfassungsbeschwerde; nur kommunale VB (Art. 51 Abs. 2 Nr. 4 LV, § 3 Nr. 4 LVerfGG) | gesetze.co/SH/Verf_SH_2014/51, SH/LVerfGG/3 |
| SH: § 6 LBO Abstandsflächen 0,4 H, mind. 3 m; Art. 54 LV Selbstverwaltung; §§ 62, 63, 64, 67, 72, 79, 80 LBO (Verfahrensarten, Abweichung, Einstellung, Beseitigung/Nutzungsuntersagung) | gesetze.co/SH/LBO/<Nr>, SH/Verf_SH_2014/54 |
| SH: GO Satzung § 4, öffentliche Einrichtungen § 18, Vertretung § 27/28, Bürgermeister § 55 | gesetze.co/SH/GO/<Nr> |
| HB: BremPolG §§ 5, 6, 7 (Verhaltens-/Zustands-/Nichtstörer), § 10 Abs. 1 Generalklausel, § 11 Platzverweis/Aufenthaltsverbot, § 13/14 Gewahrsam/richterliche Entscheidung, § 117 Ausgleich, §§ 124-126 Behörden | gesetze.co/HB/BremPolG/<Nr> |
| HB: BremVwVG §§ 11, 13-19 (Verwaltungszwang, Sofortanwendung § 11 Abs. 2) | gesetze.co/HB/BremVwVG/<Nr> |
| HB: Keine Individualverfassungsbeschwerde zum Staatsgerichtshof (Art. 139-142 LV, §§ 10, 24, 28, 30-32 StGHG) | gesetze.co/HB/LV/139-142, HB/StGHG/10-32 |
| HB: Art. 143-148 LV (zwei Gemeinden, Stadtbürgerschaft + Senat), VerfBrhv §§ 5, 46, 50 (Stadtverordnetenversammlung, Magistrat, OB), Ortsgesetz Beiräte (OBG) | gesetze.co/HB/LV/143-148, HB/VerfBrhv, HB/OBG |
| HB: BremLBO § 6 Abstandsflächen 0,4 H, mind. 3 m; § 57 untere Bauaufsicht = Stadtgemeinden; § 62, § 79 | gesetze.co/HB/BremBO/<Nr> |

### Korrigiert
| Punkt | alt -> neu | Quelle | Datei |
|---|---|---|---|
| HB BremVwVfG | "Vollgesetz" -> Verweisungsgesetz (§ 1 Abs. 1 BremVwVfG ordnet Geltung des Bundes-VwVfG an); Zitierform "§ 35 VwVfG i. V. m. § 1 BremVwVfG" | gesetze.co/HB/BremVwVfG/1 | hb-landesrecht-allgemein.yaml |
| HB Staatsgerichtshof-Karte | Behauptung "Verfahrensgegenstand nur Verletzung von Landesgrundrechten" (falsch; kein solches Verfahren) -> tatsächliche Zuständigkeiten Art. 140, 142 LV, §§ 10, 24, 28, 30-32 StGHG; keine VB; Fachgerichte Art. 141 LV | gesetze.co/HB/LV/140-142, HB/StGHG | hb-landesrecht-allgemein.yaml |
| HB Generalklausel | "öffentliche Sicherheit oder Ordnung" -> nur öffentliche Sicherheit (§ 10 Abs. 1 BremPolG) | gesetze.co/HB/BremPolG/10 | hb-polizei-ordnungsrecht.yaml |
| HB Anhörung/Fehlerfolgen | "§ 28 / § 46 BremVwVfG" -> "§ 28 / § 46 VwVfG i. V. m. § 1 BremVwVfG"; § 46 ist Unbeachtlichkeit (nicht Heilung), erfasst nur Verfahrens-/Form-/örtliche Zuständigkeitsfehler | gesetze.co/HB/BremVwVfG/1 | hb-polizei-ordnungsrecht.yaml |
| HB Zuständigkeit | unbestimmt -> §§ 124-126, 125 Abs. 1 S. 2 BremPolG (Polizeivollzugsdienst nur bei Unaufschiebbarkeit) | gesetze.co/HB/BremPolG/125,126 | hb-polizei-ordnungsrecht.yaml |
| HB Vollstreckung/Kosten/Fall | "Sofortvollzug bzw. unmittelbare Ausführung" (Begriff im BremPolG/BremVwVG nicht vorhanden) -> Verwaltungszwang ohne vorausgehenden VA, § 11 Abs. 2 BremVwVG | gesetze.co/HB/BremVwVG/11 | hb-polizei-ordnungsrecht.yaml (Karten + hb-fall-por-unmittelbare-ausfuehrung) |
| HB Störer/Platzverweis | §§ 5, 6, 7, 117 BremPolG ergänzt; Platzverweis § 11 I, Aufenthaltsverbot § 11 II, Gewahrsam § 13, Richtervorbehalt § 14 | gesetze.co/HB/BremPolG | hb-polizei-ordnungsrecht.yaml |
| HB Abstandsflächen | Zwecke "Brandschutz, Besonnung, Wohnfrieden" -> Belichtung, Belüftung, Sozialabstand (§ 6 Abs. 1); nachbarschützend nur 3/4 der Tiefe, mind. 2,50 m (§ 6 Abs. 6 S. 4); Abweichung § 67 | gesetze.co/HB/BremBO/6, 67 | hb-bauordnungsrecht.yaml |
| HB Staatsaufsicht Bremerhaven | "Rechtsaufsicht + Fachaufsicht" -> Art. 147 LV: Senat, beschränkt auf Gesetzmäßigkeit; Landesverfassungsgericht -> Staatsgerichtshof (Art. 140 Abs. 1 S. 2 LV) | gesetze.co/HB/LV/140, 147 | hb-kommunalrecht.yaml |
| SH Verantwortlichkeit | "Verantwortlichkeitsvorschriften des LVwG SH" -> §§ 218-220, § 221; Nichtstörer: "gegenwärtige erhebliche Gefahr" -> "gegenwärtige Gefahr" (§ 220 SH) | gesetze.co/SH/LVwG/218-221 | sh-polizei-ordnungsrecht.yaml |
| SH Vollstreckung/Kosten | "Sofortvollzug bzw. unmittelbare Ausführung bei Gefahr im Verzug" -> sofortiger Vollzug bei gegenwärtiger Gefahr (§ 230 LVwG) | gesetze.co/SH/LVwG/230 | sh-polizei-ordnungsrecht.yaml |
| SH Zuständigkeit | ergänzt §§ 164, 165, 168 LVwG | gesetze.co/SH/LVwG/164-168 | sh-polizei-ordnungsrecht.yaml |
| SH Mitwirkungsverbot | "§ 22 GO" -> § 32 Abs. 3 i. V. m. § 22 GO; Unbeachtlichkeit § 22 Abs. 5 (nicht entscheidend / Jahresfrist) | gesetze.co/SH/GO/22, 32 | sh-kommunalrecht.yaml |
| SH Kommunalaufsicht | Aufsichtsmittel "Aufhebung, Beauftragter" (§ 126 GO aufgehoben) -> §§ 123-125 GO; Aufsichtsbehörde nach § 121 GO (Landrat bis 20.000 EW, sonst Innenministerium) | gesetze.co/SH/GO/121-126 | sh-kommunalrecht.yaml |
| SH Abstandsflächen | Zwecke Brandschutz/Besonnung/Wohnfrieden -> § 6 Abs. 1 Wortlaut; Abweichung § 67 | gesetze.co/SH/LBO/6, 67 | sh-bauordnungsrecht.yaml |
| SH Abweichung | "Ermessen, auf null reduziert" -> "soll" zulassen (§ 67 Abs. 1 LBO SH, intendiertes Ermessen) | gesetze.co/SH/LBO/67 | sh-bauordnungsrecht.yaml |

### Offen für menschliche Prüfung
| Punkt | Grund |
|---|---|
| Abkürzung BremLBO vs. BremBO | gesetze.co führt "BremBO"; Kürzel in den Karten (BremLBO) nicht gegen amtliche Ausfertigung verifiziert |
| BremPolG-Fassung | Portaltext enthält Stand 2026 (Verweise "am 16. Januar 2026 geltende Fassung"); Absatzzählungen gegenüber älteren Kommentaren prüfen |
| hb-kr-beiraete "Stadtbezirke und Ortsteile" | OBG nennt Stadt- und Ortsteile; Stadtbezirke nicht verifiziert |
| Bremen Grundrechtsschutz auf Landesebene | keine Verfassungsbeschwerde gefunden (Art. 140, StGHG §§ 10, 24-32); ob Landesgrundrechte anderweitig vor dem StGH geltend gemacht werden können, ohne Rspr.-Recherche nicht belegt |
| sh-fall-bo-bestandsschutz | Prüfpunkt 4/5 Treffer ("Eingriffsbefugnis der LBO SH"), Fall nicht geändert; §§ 79, 80 LBO SH könnten als Norm genannt werden |
| Rechtsprechungsangaben | Streitstände (Zweckveranlasser, Anscheinsgefahr, Kostenbescheid) nicht gegen Rspr. geprüft (Scope: Landesnormen) |

## MV und SN

Abrufweg: Landesportale (landesrecht-mv.de, revosax.sachsen.de) liefern nur JavaScript-Shells (ca. 5-10 KB, kein Normtext). Ersatzweg: Normtext per curl von https://gesetze.co/<LAND>/<GESETZ>/<Paragraph> (serverseitig gerendert, Pfade z. B. MV/SOG/13, MV/KV/24, MV/LBauO/6, MV/Verf/53, SN/SächsPVDG/12). Das ist ein Aggregator, kein amtliches Portal; Wortlaut daher als "gesichtet, nicht amtlich" einzustufen.

### 1. Bestätigt
| Punkt | Quelle |
|---|---|
| § 13 SOG M-V Generalklausel | https://gesetze.co/MV/SOG/13 |
| §§ 69, 70, 71 SOG M-V (Verhaltens-, Zustands-, Nichtstörer), § 72 Entschädigung | https://gesetze.co/MV/SOG/69 (70, 71, 72) |
| § 22 KV M-V (Gemeindevertretung, nicht übertragbare Angelegenheiten) | https://gesetze.co/MV/KV/22 |
| § 24 KV M-V Mitwirkungsverbote (Tatbestand, Ausnahmen) | https://gesetze.co/MV/KV/24 |
| Art. 72 Verf M-V (kommunale Selbstverwaltung) | https://gesetze.co/MV/Verf/72 |
| § 6 LBauO M-V Abstandsflächen (Tiefe nach Wandhöhe, Lage auf Baugrundstück, Überdeckung) | https://gesetze.co/MV/LBauO/6 |
| MV: Verfahrensfreiheit § 61, Genehmigungsfreistellung § 62, vereinfachtes Verfahren § 63 LBauO M-V | https://gesetze.co/MV/LBauO/61 (62, 63) |
| SächsPVDG/SächsPBG als getrennte Gesetze; § 12 beider Gesetze Generalklausel | https://gesetze.co/SN/SächsPVDG/12 , /SN/SächsPBG/12 |
| § 4 SächsGemO Satzungen, § 14 Anschluss-/Benutzungszwang, § 27/§ 51 Gemeinderat/Bürgermeister | https://gesetze.co/SN/SächsGemO/4 (14, 27, 51) |
| § 6 SächsBO Abstandsflächen (Lage, Überdeckung, Nachbarschutzzweck) | https://gesetze.co/SN/SächsBO/6 |
| Art. 81 Abs. 1 Nr. 4 SächsVerf (Individualverfassungsbeschwerde) | https://gesetze.co/SN/SächsVerf/81 |
| SächsVwVfZG ist Verweisungsgesetz (§ 1) | https://gesetze.co/SN/SächsVwVfZG/1 |
| SächsVwVG als Vollstreckungsgesetz (§§ 19-25) | https://gesetze.co/SN/SächsVwVG/19 |

### 2. Korrigiert
| Punkt | alt -> neu | Quelle | Datei |
|---|---|---|---|
| MV Vollstreckung: "VwVG M-V" | existiert nicht als eigenes Gesetz; Vollzug nach §§ 79 ff. SOG M-V (Zwangsmittel § 86, Androhung § 87, Ersatzvornahme § 89, sofortiger Vollzug § 81); "unmittelbare Ausführung" im MV-Text ersetzt durch "sofortiger Vollzug" | https://gesetze.co/MV/SOG/79 (81, 86, 89) | mv-polizei-ordnungsrecht.yaml (mv-por-vollstreckung, mv-por-kosten) |
| MV Nichtstörer: "gegenwärtige erhebliche Gefahr" | § 71 verlangt gegenwärtige Gefahr (bzw. Störungsbeseitigung), keine erhebliche eigene Gefährdung; Entschädigung § 72 | https://gesetze.co/MV/SOG/71 | mv-polizei-ordnungsrecht.yaml (mv-por-stoerer) |
| MV Zuständigkeit "Polizei bei Eilbedürftigkeit" | §§ 2, 7 Abs. 1 Nr. 3 SOG M-V ergänzt (Polizei trifft unaufschiebbare Maßnahmen) | https://gesetze.co/MV/SOG/7 | mv-polizei-ordnungsrecht.yaml |
| MV Platzverweis/Gewahrsam ohne Norm | § 52 Abs. 1, § 55 SOG M-V ergänzt (Aufenthaltsverbot steht nicht in § 52; Aussage bleibt neutral) | https://gesetze.co/MV/SOG/52 (55) | mv-polizei-ordnungsrecht.yaml |
| MV Mitwirkungsverbot Rechtsfolge: "fehlerhaft, wenn ursächlich" | § 24 Abs. 4: Entscheidung "ist unwirksam", keine Kausalitätsklausel; Jahresfrist/Rüge § 24 Abs. 5; Fall und Prüfpunkt p4 angepasst | https://gesetze.co/MV/KV/24 | mv-kommunalrecht.yaml |
| MV Zuständigkeit § 22 KV: "auf Ausschüsse übertragen", "wesentliche Vermögensgeschäfte" | Übertragung auf Hauptausschuss/Bürgermeister, § 22 Abs. 3 Katalog, § 22 Abs. 4 Wertgrenzen; § 38 Abs. 2, 3 Bürgermeister | https://gesetze.co/MV/KV/22 , /MV/KV/38 | mv-kommunalrecht.yaml |
| MV Kommunalaufsicht ohne Normen / unscharf | Rechtsaufsichtsbehörden § 79 (Landrat bzw. Ministerium für große kreisangehörige und kreisfreie Städte), Mittel §§ 81-83, Rechtsbehelfe § 85 | https://gesetze.co/MV/KV/79 (81-85) | mv-kommunalrecht.yaml |
| MV § 47 VwGO "soweit Landesrecht" | § 13 GerStrukGAG M-V eröffnet Normenkontrolle gegen untergesetzliche Normen | https://gesetze.co/MV/GerStrukGAG_MV/13 | mv-kommunalrecht.yaml |
| MV VwVfG M-V "Verweisung auf Bundes-VwVfG" | eigenes Vollgesetz (Normen §§ 1, 20, 35, 48 vorhanden) | https://gesetze.co/MV/VwVfG_M-V/35 | mv-landesrecht-allgemein.yaml |
| MV Landesverfassungsbeschwerde: "Ja - Art. 53 Nr. 6" | begrenzt: Nr. 6 nur gegen Landesgesetze (Frist 1 Jahr, § 52, 53 LVerfGG); Nr. 7 gegen öffentliche Gewalt nur Art. 6-10 Verf, nach Rechtswegerschöpfung, subsidiär zum BVerfG, 1 Monat (§§ 58, 59 LVerfGG); Kommunalverfassungsbeschwerde Nr. 8 | https://gesetze.co/MV/Verf/53 , /MV/LVerfGG_M-V/52 (58, 59) | mv-landesrecht-allgemein.yaml |
| MV Abweichung: "Ermessen, auf null reduziert" | § 67 Abs. 1 LBauO M-V ist Soll-Vorschrift | https://gesetze.co/MV/LBauO/67 | mv-bauordnungsrecht.yaml |
| MV Bauaufsicht: "Landkreise und kreisfreie Städte" / Eingriffsnormen fehlten | § 57 Abs. 1 (Landräte, OB kreisfreier und großer kreisangehöriger Städte), § 58, §§ 79, 80 (Beseitigung nur wenn nicht anders rechtmäßige Zustände), §§ 61-64, § 72 Abs. 1, § 6 Abs. 4, 5 ergänzt | https://gesetze.co/MV/LBauO/57 (58, 79, 80, 72) | mv-bauordnungsrecht.yaml |
| SN Platzhalter-norms ("Generalklausel", "Paragraphen hier nicht angegeben") | durch § 12 SächsPVDG/SächsPBG, §§ 6, 7, 9 SächsPVDG, §§ 14, 15, 17 SächsPBG, §§ 13 ff. SächsPVDG, §§ 18 ff. SächsPBG, § 2 Abs. 3 SächsPVDG, § 7 SächsPBG, §§ 19 ff. SächsVwVG ersetzt | https://gesetze.co/SN/SächsPVDG/6 (7, 9, 12) , /SN/SächsPBG/14 (15, 17) | sn-polizei-ordnungsrecht.yaml |
| SN Eilzuständigkeit "Einzelheiten nach Landesgesetz" | § 2 Abs. 3, § 3 SächsPVDG (Polizei nur, wenn Polizeibehörde nicht rechtzeitig; unverzügliche Unterrichtung); § 1, § 6, § 7 SächsPBG (Behördenaufbau, Gefahr im Verzug); Fall angepasst | https://gesetze.co/SN/SächsPVDG/2 (3) , /SN/SächsPBG/1 (6, 7) | sn-polizei-ordnungsrecht.yaml |
| SN Standardmaßnahmen "nur SächsPVDG" | auch SächsPBG §§ 18 ff. (Platzverweis § 20); Gewahrsam §§ 22, 23 und Aufenthaltsverbot § 21 nur im SächsPVDG | https://gesetze.co/SN/SächsPBG/20 , /SN/SächsPVDG/21 (22, 23) | sn-polizei-ordnungsrecht.yaml |
| SN Nichtstörer "gegenwärtige erhebliche Gefahr" | § 9 SächsPVDG/§ 17 SächsPBG: gegenwärtige Gefahr; Entschädigung § 47 SächsPVDG/§ 41 SächsPBG | https://gesetze.co/SN/SächsPVDG/9 , /SN/SächsPBG/17 | sn-polizei-ordnungsrecht.yaml |
| SN Vollstreckung/Kosten ohne Norm | §§ 19-25 SächsVwVG (Gefahr im Verzug § 21, Ersatzvornahme § 24), unmittelbare Ausführung § 8 SächsPVDG/§ 16 SächsPBG | https://gesetze.co/SN/SächsVwVG/21 | sn-polizei-ordnungsrecht.yaml |
| SN Mitwirkungsverbot "fehlerhaft, wenn ausschlaggebend; rechtswidrig oder unwirksam" | § 20 Abs. 5 S. 1 SächsGemO: Beschluss rechtswidrig, keine Kausalitätsklausel; Gültigkeitsfiktion nach 1 Jahr (S. 2, § 4 Abs. 4); § 20 Abs. 1-4 Details; Fall, Schema, Prüfpunkt angepasst | https://gesetze.co/SN/SächsGemO/20 | sn-kommunalrecht.yaml |
| SN Verpflichtungserklärung "regelmäßig Schriftform" | § 60 SächsGemO (Schriftform, handschriftliche Unterschrift des Bürgermeisters, Ausnahme laufende Verwaltung) | https://gesetze.co/SN/SächsGemO/60 | sn-kommunalrecht.yaml |
| SN Anschluss-/Benutzungszwang: "Straßenreinigung", "Volksgesundheit", "Satzung muss Befreiung vorsehen" | § 14 SächsGemO nennt Wasser, Abwasser, Fernwärme, Bestattung, Abfall, Schlachthöfe; "insbesondere Umweltschutz"; Ausnahmen sind "kann" (§ 14 Abs. 2) | https://gesetze.co/SN/SächsGemO/14 | sn-kommunalrecht.yaml |
| SN Bürgerbegehren: Quoren/Katalog "nach Landesrecht" | konkret § 25 (5 %, Kostendeckungsvorschlag, 3-Monatsfrist, Widerspruch zur Rechtsaufsicht), § 24 (Ausschlusskatalog, 25 %-Quorum) | https://gesetze.co/SN/SächsGemO/24 (25) | sn-kommunalrecht.yaml |
| SN Kommunalaufsicht ohne Normen | §§ 111-117 SächsGemO, Rechtsaufsichtsbehörden § 112 | https://gesetze.co/SN/SächsGemO/112 | sn-kommunalrecht.yaml |
| SN Satzung/§ 47 VwGO "soweit Landesrecht" | § 24 SächsJG eröffnet Normenkontrolle; § 4 Abs. 3, 4 SächsGemO (Ausfertigung, Jahresfrist) | https://gesetze.co/SN/SächsJG/24 | sn-kommunalrecht.yaml |
| SN Gemeindearten/KomZG ohne Norm | § 3 Abs. 2, 4 SächsGemO, SächsKomZG §§ 36 ff. | https://gesetze.co/SN/SächsGemO/3 | sn-kommunalrecht.yaml |
| SN Abstandsflächen "landesrechtlicher Faktor, nachschlagen" | § 6 Abs. 5 SächsBO: 0,4 H, min. 3 m; 0,2 H Gewerbe/Industrie; 3 m Wohngebäude GK 1-2 (<= 3 Geschosse) | https://gesetze.co/SN/SächsBO/6 | sn-bauordnungsrecht.yaml |
| SN Genehmigungsfreistellung "für bestimmte Wohnbauvorhaben, Anzeige" | § 62 SächsBO: allgemein bauliche Anlagen (ausgenommen Sonderbauten, UVP u. a.) im B-Plan-Bereich, Unterlagen vor Baubeginn, Gemeinde kann Genehmigungsverfahren verlangen | https://gesetze.co/SN/SächsBO/62 | sn-bauordnungsrecht.yaml |
| SN Bauordnung Platzhalter-norms | §§ 59, 61-64, 72 Abs. 1, 75, 79, 80, 67 Abs. 1 SächsBO; Abweichung "soll" | https://gesetze.co/SN/SächsBO/80 (79, 67, 72) | sn-bauordnungsrecht.yaml |
| SN Verfassungsbeschwerde | § 27 SächsVerfGHG ergänzt | https://gesetze.co/SN/SächsVerfGHG/27 | sn-landesrecht-allgemein.yaml |

### 3. Offen für menschliche Prüfung
| Punkt | Grund |
|---|---|
| Amtlichkeit des Wortlauts | Quelle gesetze.co ist kein amtliches Portal; landesrecht-mv.de und revosax.sachsen.de nicht maschinenlesbar (SPA-Shell) |
| MV: Kausalität bei Mitwirkungsverbot (§ 24 Abs. 4 KV M-V) | Wortlaut ohne Kausalitätsklausel; ob die Rechtsprechung dennoch Ergebnisrelevanz verlangt, ist hier nicht belegt (Entscheidung OVG Greifswald prüfen) |
| SN: dasselbe zu § 20 Abs. 5 SächsGemO | wie oben (Rspr. nicht verifiziert) |
| MV: Aufenthaltsverbot im SOG M-V | In § 52 Abs. 1 nicht enthalten; ob an anderer Stelle (Abs. 2 ist Wohnungsverweis) geregelt, nicht geklärt; Kartenaussage nur allgemein gehalten |
| MV: "Sondernutzungsrecht" im Fall mv-fall-por-zweckveranlasser | Im Sachverhalt nicht (mehr) vorhanden, keine Änderung nötig; Rechtsfrage Werbung auf Fahrbahn (Straßenrecht) nicht geprüft |
| MV/SN: Rechtsprechungsangaben (Rastede, Wesentlichkeit, Zweckveranlasser, Zustandsstörer-Kostenlimit Art. 14 GG) | nicht Teil der Landesnormprüfung, nicht gegen Primärquelle belegt |
| SN: Anpassungsverlangen an Bestandsbauten bei Gefahr | In den geprüften SächsBO-/LBauO-Paragraphen nicht gefunden; Aussage unverändert, Normstelle offen |
| MV/SN: Bestandsschutz-Begriffe (aktiver Bestandsschutz) | Rechtsprechung, nicht geprüft |
| MV: § 6 Abs. 5 LBauO M-V Gebäudeklassen-Tiefen (3/4/5 m) vs. 0,4 H | Text gesichtet; Verhältnis der Regeln und Nachbarschutzwirkung nicht abschließend bewertet |
| MV/SN: Bauordnungs-Prüfprogramm vereinfachtes Verfahren (Stellplätze, Gestaltung) | Text nur kursorisch gesichtet |

## ST und TH

Portale (landesrecht.sachsen-anhalt.de, landesrecht.thueringen.de) liefern nur JS-Shells (ca. 5 KB, kein Normtext). Ersatzweg: gesetze.co (server-seitig gerendertes Landesrecht, Pfad `https://gesetze.co/<ST|TH>/<Gesetz>/<§>`), Wortlaut paragraphenweise gelesen. Kein amtliches Portal – Wortlaut daher als "Sekundärabdruck", Endstand bei Bedarf gegen Portal gegenlesen.

### 1. Bestätigt
| Punkt | Quelle |
|---|---|
| § 13 SOG LSA Generalklausel; §§ 7, 8, 10 SOG LSA (Verhalten, Zustand, Nichtstörer; Voraussetzungen Notstand) | gesetze.co/ST/SOG_LSA/7, 8, 10, 13 |
| § 12 Abs. 1 ThürPAG; § 5 Abs. 1 ThürOBG; §§ 7, 8, 10 ThürPAG; §§ 10, 11 ThürOBG | gesetze.co/TH/PAG/7, 8, 10, 12; TH/OBG/5, 10, 11 |
| Schutz privater Rechte subsidiär (§ 1 Abs. 2 SOG LSA, § 2 Abs. 2 ThürPAG/ThürOBG) | ST/SOG_LSA/1; TH/PAG/2; TH/OBG/2 |
| Standardmaßnahmen existieren (Platzverweisung § 36 SOG LSA, § 18 ThürPAG, § 17 ThürOBG; Gewahrsam nur Polizei § 37 SOG LSA, § 19 ThürPAG) | ST/SOG_LSA/36, 37; TH/PAG/18, 19; TH/OBG/17 |
| Abstandsflächen 0,4 H, min. 3 m (§ 6 Abs. 5 BauO LSA / ThürBO) | ST/BauO/6; TH/ThürBO/6 |
| Bauaufsichtliche Befugnisse (Einstellung, Beseitigung, Nutzungsuntersagung) | ST/BauO/78, 79; TH/ThürBO/86, 87 |
| Baugenehmigung gebunden (§ 71 Abs. 1 BauO LSA, § 78 Abs. 1 ThürBO); Vorbescheid | ST/BauO/71, 74; TH/ThürBO/78, 82 |
| Rechtsaufsicht/Fachaufsicht, Aufsichtsmittel (KVG LSA §§ 143-149; ThürKO §§ 117-122) | ST/KVG/143, 146; TH/ThürKO/117, 120 |
| ThürKO: Mitwirkungsverbot-Rechtsfolge (nur unwirksam bei Ausschlaggebendheit, § 38 Abs. 4) | TH/ThürKO/38 |
| Verfassungsbeschwerde TH: Art. 80 Abs. 1 Nr. 1 ThürVerf (§ 31 ThürVerfGHG, Rechtswegerschöpfung) | TH/Verf/80; TH/ThürVerfGHG/31 |
| Ausschlusskatalog Bürgerbegehren inkl. Haushaltssatzung (§ 26 Abs. 2 S. 2 Nr. 3 KVG LSA) – Fall st-fall-kom-buergerbegehren-haushalt Ergebnis bestätigt | ST/KVG/26 |
| Verbandsgemeinde ST (§§ 89 ff. KVG LSA), Verwaltungsgemeinschaft TH (§§ 46 ff. ThürKO) | ST/KVG/89, 90; TH/ThürKO/46-48, 51 |
| § 47 Abs. 1 Nr. 2 VwGO: Normenkontrolle in ST und TH vom Landesrecht eröffnet | ST/AG_VwGO/10; TH/ThürAGVwGO/4 |

### 2. Korrigiert
| Punkt | alt → neu | Quelle | Datei |
|---|---|---|---|
| Nichtstörer ThürOBG | "§§ 10, 11, 12 ThürOBG" / "§ 12 ThürOBG" → § 13 ThürOBG (§ 12 = unmittelbare Ausführung) | TH/OBG/12, 13 | th-polizei-ordnungsrecht.yaml |
| Vollstreckung ST | "VwVG LSA regelt Verwaltungszwang, SOG ergänzend" → Zwang der Sicherheitsbehörden/Polizei in §§ 53 ff. SOG LSA, unmittelbare Ausführung § 9, VwVG LSA nur Kostenbeitreibung | ST/SOG_LSA/9, 53-59 | st-polizei-ordnungsrecht.yaml |
| Vollstreckung TH | "ThürVwZVG regelt Zwangsmittel, ThürPAG ergänzend" → Polizei: §§ 51 ff. ThürPAG; Ordnungsbehörden: ThürVwZVG (ThürOBG ohne Zwangsregeln); unmittelbare Ausführung § 12 ThürOBG | TH/PAG/51; TH/OBG/12 | th-polizei-ordnungsrecht.yaml |
| Zuständigkeit ST | Platzhalter → §§ 2 Abs. 2, 84 Abs. 1, 89 Abs. 2 SOG LSA (Polizei subsidiär) | ST/SOG_LSA/2, 84, 89 | st-polizei-ordnungsrecht.yaml |
| Zuständigkeit TH | "Paragraph nicht angegeben" → § 3 Abs. 1 ThürOBG (Vorrang), § 3 S. 1 ThürPAG (Subsidiarität) | TH/OBG/3; TH/PAG/3 | th-polizei-ordnungsrecht.yaml |
| Standardbefugnisse | Platzhalter → §§ 14 ff./35 ff. SOG LSA (gemeinsames Gesetz); ThürPAG §§ 13 ff., ThürOBG §§ 15 ff. (OBG ohne Gewahrsam) | s. o. | st-/th-polizei-ordnungsrecht.yaml |
| Gefahrenabwehrverordnung ST | "Verordnung zur Gefahrenabwehr" → Gefahrenabwehrverordnung (§ 94 SOG LSA) | ST/SOG_LSA/94 | st-polizei-ordnungsrecht.yaml |
| Bürgerbegehren ST | "Kostendeckungsvorschlag, Frist" → Kostenschätzung der Kommune (§ 26 Abs. 3a), 10 %-Quorum mit Höchstgrenzen, 6 Monate/2 Monate, Entscheid durch Vertretung; Fall, Schema und Keyword angepasst; Bürgerentscheid-Quorum 20 % | ST/KVG/26, 27 | st-kommunalrecht.yaml |
| Bürgerbegehren TH | generisch → ThürEBBG: Zulässigkeit entscheidet Gemeindeverwaltung (4 Wochen), 7 %/max. 7.000, 4 Monate, Kostendeckungsvorschlag nur Soll, Ausschlusskatalog § 1 Abs. 3 | TH/ThürEBBG/1, 6, 12, 14 | th-kommunalrecht.yaml |
| Mitwirkungsverbot ST | "rechtswidrig, wenn ausschlaggebend" → Beschluss unwirksam (§ 33 Abs. 5 S. 1 KVG LSA), Unbeachtlichkeit nach § 8 Abs. 2 | ST/KVG/33 | st-kommunalrecht.yaml |
| Anschlusszwang | ST: "öffentliches Bedürfnis" → "dringendes öffentliches Bedürfnis" (§ 11), Einrichtungsliste; TH: § 20 Abs. 2 ThürKO (Gründe des öffentlichen Wohls, kein Abfall genannt); "muss Befreiung vorsehen" → Satzung kann Ausnahmen zulassen | ST/KVG/11; TH/ThürKO/20 | st-/th-kommunalrecht.yaml |
| Verpflichtungserklärungen | allgemein → § 73 KVG LSA (HVB handschriftlich, Ausnahme laufende Verwaltung); § 31 Abs. 2 ThürKO | ST/KVG/73; TH/ThürKO/31 | st-/th-kommunalrecht.yaml |
| § 47 VwGO | "soweit Landesrecht eröffnet" → § 10 AG VwGO LSA / § 4 ThürAGVwGO; Unbeachtlichkeitsfristen §§ 8 Abs. 2 KVG LSA, 21 Abs. 4 ThürKO | s. o. | st-/th-kommunalrecht.yaml |
| Verwaltungsgemeinschaft TH | VG nimmt übertragenen Wirkungskreis wahr, eigener nur als Behörde nach Weisung (§ 47) | TH/ThürKO/47, 48 | th-kommunalrecht.yaml |
| Verbandsgemeinde ST | unbestimmt → Aufgabenkatalog § 90 | ST/KVG/90 | st-kommunalrecht.yaml |
| Genehmigungsfreistellung | "gegen Anzeige, qualifizierte B-Pläne" → § 61 BauO LSA / § 64 ThürBO (Gebäudeklassen, Monatsfrist, Gemeindeerklärung; TH Unterlagen bei Gemeinde); Verfahren §§ 62, 63 / 65, 66 | ST/BauO/61-63; TH/ThürBO/64-66 | st-/th-bauordnungsrecht.yaml |
| Abstandsflächen | "landesrechtlicher Faktor, nachzuschlagen" → 0,4 H, min. 3 m; 0,2 H Gewerbe; 3 m GK 1/2 | ST/BauO/6; TH/ThürBO/6 | st-/th-bauordnungsrecht.yaml |
| Abweichung | "kann" → "soll" (§ 66 BauO LSA, § 73 ThürBO), Antragsform | ST/BauO/66; TH/ThürBO/73 | st-/th-bauordnungsrecht.yaml |
| Anpassungsverlangen | ST § 86 Abs. 1 (Sicherheit/Gesundheit); TH § 98 Abs. 1 (erhebliche Gefahren) | ST/BauO/86; TH/ThürBO/98 | st-/th-bauordnungsrecht.yaml |
| Platzhalter-norms | alle "(Paragraphen hier nicht angegeben)" durch geprüfte Paragraphen ersetzt | – | alle st-/th-Dateien |
| ThürVwVfG | "Vollgesetz" → Verweisungsgesetz (§ 1 Abs. 1 ThürVwVfG) | TH/ThürVwVfG/1 | th-landesrecht-allgemein.yaml |
| Landes-VB ST | "Ja - Art. 75 Nr. 6" → nur gegen Landesgesetze unmittelbar (Nr. 6), kommunale VB Nr. 7; keine Urteils-/VA-Verfassungsbeschwerde | ST/Verf/75 | st-landesrecht-allgemein.yaml |

### 3. Offen für menschliche Prüfung
| Punkt | Grund |
|---|---|
| Wortlaut nur über gesetze.co | Landesportale ST/TH nicht maschinenlesbar (SPA-Shell); kein amtlicher Abdruck, Stand ("täglich aktualisiert") nicht verifizierbar |
| Rechtsprechungsaussagen (Zweckveranlasser, doppelfunktionale Maßnahmen, Anscheinsstörer-Kosten, Nachbarschutz Abstandsflächen, aktiver Bestandsschutz, formelle Nachbarrechte) | keine landesspezifische Norm; Rspr. nicht mit Primärquelle belegt |
| ThürPAG §§ 7, 8, 10; SOG LSA §§ 7, 8, 10 als Norm bestätigt, aber ob Zustandsstörer-Kostenbegrenzung (BVerfGE 102, 1) inhaltlich passend zitiert | Fundstelle nicht online geprüft |
| Nachbarschutz § 6 BauO LSA / ThürBO (Schutznormcharakter) | Rspr. der OVG nicht verifiziert |
| "Entschädigungsanspruch" Nichtstörer | Landesnormen: §§ 69 ff. SOG LSA (Schadensausgleich); ThürPAG/OBG-Entschädigungsvorschriften nicht gelesen |
| Fall th-fall-por-stoererauswahl-oelspur: Prüfpunkt "Konkrete gegenwärtige Gefahr" wird vom Muster nicht getroffen (vorbestehend, check_faelle "OK") | Redaktioneller Mangel, nicht Quellenfrage |
| § 5 Abs. 1 PartG (Fall th-fall-kom-aufsicht-stadthalle), Rastede-Beschluss | Bundesrecht/Rspr. außerhalb Landesrecht, nicht geprüft |

## RP und SL

Quelle: gesetze.co (serverseitig gerenderter Volltext der Landesgesetze, Abruf 2026-10-15), URL-Schema https://gesetze.co/<LAND>/<GESETZ>/<§>, z. B. /SL/SPolG/13, /RP/POG/9. Portalweg: recht.saarland.de und landesrecht.rlp.de liefern nur SPA-Shells (~5 KB, kein Normtext per curl); Ersatzweg dokumentiert.

### 1. Bestätigt
| Punkt | Quelle |
|---|---|
| § 8 Abs. 1 SPolG Generalklausel; §§ 4, 5, 6 SPolG Störer/Nichtstörer; § 1 Abs. 3 SPolG Schutz privater Rechte | https://gesetze.co/SL/SPolG/8 (/4, /5, /6, /1) |
| § 9 Abs. 1 POG RP Generalklausel; §§ 4, 5, 7 POG; § 1 Aufgaben | https://gesetze.co/RP/POG/9 (/4, /5, /7) |
| § 17a GemO RP Bürgerbegehren; § 22 Mitwirkungsverbot; § 24 Satzung; § 26 Anschluss-/Benutzungszwang | https://gesetze.co/RP/GemO/17a (/22, /24, /26) |
| § 12 KSVG Satzungen | https://gesetze.co/SL/KSVG/12 |
| § 8 LBauO RP (0,4 H, min. 3 m); § 7 LBO Saar (0,4 H, 3 m, min. 3 m) | https://gesetze.co/RP/LBauO/8 ; /SL/LBO/7 |
| Gewahrsam nur Vollzugspolizei, richterl. Entscheidung entbehrlich bei Wegfall des Grundes (§§ 13, 14 SPolG) | https://gesetze.co/SL/SPolG/13, /14 |
| Abwasserbeseitigung = Aufgabe der Verbandsgemeinde (§ 67 Abs. 1 Nr. 6 GemO RP) | https://gesetze.co/RP/GemO/67 |
| § 55 VerfGHG SL Individual-VB; Art. 130a LV RP / § 44 VGHG | https://gesetze.co/SL/VerfGHG/55 ; /RP/Verf_RP/130a ; /RP/VGHG_RP/44 |
| Normenkontrolle nach § 47 I Nr. 2 VwGO eröffnet: § 18 AGVwGO SL, § 4 AGVwGO RP | https://gesetze.co/SL/AGVwGO/18 ; /RP/AGVwGO/4 |
| Fall rp-fall-kom-ortsgemeinde-abwasser (Unzuständigkeit der Ortsgemeinde) | s. § 67 GemO, § 24 Abs. 6 GemO (Zuständigkeitsfehler nicht heilbar) |
| Fall sl-fall-por-schutzgewahrsam, rp-fall-por-hilferufe-wohnung (§ 20 Abs. 1 Nr. 3 POG), rp-fall-bau-bestandsschutz-altbau | https://gesetze.co/SL/SPolG/13 ; /RP/POG/20 ; /RP/LBauO/81, /85 |

### 2. Korrigiert
| Punkt | alt -> neu | Quelle | Datei |
|---|---|---|---|
| SVwVfG | "Vollgesetz" -> Verweisungsgesetz (§ 1 Abs. 1 SVwVfG) | /SL/SVwVfG/1 | sl-landesrecht-allgemein |
| LVwVfG RP | Verweisung ungenau -> § 1 Abs. 1 LVwVfG mit Ausnahmenliste | /RP/LVwVfG/1 | rp-landesrecht-allgemein |
| Landes-VB SL | "nur Landesgrundrechte" -> Grundrechte oder sonstige verfassungsmäßige Rechte, Rechtswegerschöpfung, Gemeinden Art. 123 SVerf | /SL/VerfGHG/55, /SL/SVerf/123 | sl-landesrecht-allgemein |
| Landes-VB RP | Bundesrecht-Aussage -> § 44 Abs. 2 VGHG (unzulässig bei Ausführung von Bundesrecht, Ausnahmen), Abs. 3 | /RP/VGHG_RP/44 | rp-landesrecht-allgemein |
| Vollstreckung SL | nur SVwVG -> Polizei: §§ 44-50 SPolG (Sofortvollzug § 44 II), andere Behörden SVwVG | /SL/SPolG/44-50 ; /SL/SVwVG | sl-polizei-ordnungsrecht |
| Vollstreckung RP | -> § 61 II LVwVG (Sofortvollzug, ohne Zwangsgeld), § 76 POG (Verweisung, unmittelbarer Zwang §§ 77-85) | /RP/LVwVG/61 ; /RP/POG/76 | rp-polizei-ordnungsrecht |
| Nichtstörer "Entschädigungsanspruch" | -> angemessener Schadensausgleich § 68 SPolG / § 87 POG | /SL/SPolG/68 ; /RP/POG/87 | sl-/rp-polizei-ordnungsrecht |
| Standardmaßnahmen "Paragraphen nicht angegeben" | -> §§ 9-25 SPolG (konkret § 9, 11, 12, 13, 17-21), §§ 10-26 POG | /SL/SPolG/9-21 ; /RP/POG/10-22 | sl-/rp-polizei |
| Gewahrsam-Schema/Fall | Verweise auf §§ 13, 14 SPolG ergänzt, Entbehrlichkeitsvoraussetzung exakt | /SL/SPolG/14 | sl-polizei-ordnungsrecht |
| KSVG: Verpflichtungserklärung | pauschal -> § 62 KSVG (Dienstsiegel, elektr. Form, Ausnahme laufende Verwaltung); Fall: Ausnahme geprüft | /SL/KSVG/62 | sl-kommunalrecht |
| KSVG: Anschlusszwang | "Abfallbeseitigung, Umweltschutz" -> § 22 KSVG nennt Wasser, Kanalisation, Straßenreinigung, Fernwärme, Volksgesundheit, Schlachthöfe | /SL/KSVG/22 | sl-kommunalrecht |
| KSVG: Bürgerbegehren | generisch -> § 21a (2 Monate, 15 %/Staffel, Kostendeckung, 30 %-Quorum, Ausschlusskatalog) | /SL/KSVG/21a | sl-kommunalrecht |
| KSVG: Mitwirkungsverbot | "ausschlaggebend" -> § 27 VI: Beschluss unwirksam, Heilung nach 1 Jahr | /SL/KSVG/27 | sl-kommunalrecht |
| KSVG: Aufsicht | -> §§ 127-136, Widerspruch § 136; Regionalverband § 194 | /SL/KSVG/127-136, 194 | sl-kommunalrecht |
| KSVG Satzung | Heilung § 12 VI, Normenkontrolle § 18 AGVwGO | /SL/KSVG/12 | sl-kommunalrecht |
| GemO RP: Organe/Verpflichtungserklärung | -> §§ 28, 32, 47, 49 (Schriftform, Amtsbezeichnung, Ausnahme § 49 III) | /RP/GemO/49 | rp-kommunalrecht |
| GemO RP: Anschlusszwang | "Abfallbeseitigung/Volksgesundheit/Umweltschutz" -> Katalog § 26 I | /RP/GemO/26 | rp-kommunalrecht |
| GemO RP: Bürgerbegehren | "Kostendeckungsvorschlag u. a." -> § 17a (4 Monate, 5-9 %, 15 %-Quorum, kein Kostenvorschlag) | /RP/GemO/17a | rp-kommunalrecht |
| GemO RP: Mitwirkung | "Verhandlungsraum verlassen / ausschlaggebend" -> § 22 IV (Zuhörerbereich), VI (unwirksam, 3 Monate Heilung) | /RP/GemO/22 | rp-kommunalrecht |
| GemO RP: Aufsicht | -> §§ 117-126; Satzungsheilung § 24 VI; AGVwGO § 4 | /RP/GemO/117-126 | rp-kommunalrecht |
| GemO RP: Struktur | -> §§ 64, 67 | /RP/GemO/64, 67 | rp-kommunalrecht |
| LBO Saar: Genehmigungsfreistellung | "bestimmte Wohnbauvorhaben, qual. BPlan, Anzeige" -> § 63 (GK 1-5, sonstige Anlagen, Bebauungsplan i. S. § 30 I / 12 / 30 II BauGB, Gemeinde-Erklärung); §§ 60, 64, 65 | /SL/LBO/60, 63, 64 | sl-bauordnungsrecht |
| LBO Saar: Abstandsflächen | "meist 0,4 H/3 m, nachschlagen" -> § 7 V (0,4 H; 3 m für WG GK 1-2; 0,2 H GE/GI; min. 3 m) | /SL/LBO/7 | sl-bauordnungsrecht |
| LBO Saar: Eingriff/Abweichung/Bestandsschutz/Nachbar | §§ 57, 68, 71, 73, 81, 82 ergänzt (u. a. Präklusion § 71 I) | /SL/LBO/57, 68, 71, 73, 81, 82 | sl-bauordnungsrecht |
| LBauO RP: Verfahren | Freistellung pauschal -> §§ 61, 62, 66, 67 (Wohngebäude GK 1-3, Gemeinde kann Verfahren verlangen); Abs. 6: 0,4 H, GE/GI 0,25 H | /RP/LBauO/61-67, 8 | rp-bauordnungsrecht |
| LBauO RP: Eingriff/Bestandsschutz/Abweichung | §§ 59, 69, 80, 81, 85 ergänzt (nachträgliche Anforderungen nur bei erheblicher Gefahr) | /RP/LBauO/59, 69, 80, 81, 85 | rp-bauordnungsrecht |
| Platzhalter-norms ("Paragraphen hier nicht angegeben") | in RP/SL durch konkrete Normen ersetzt | s. o. | alle 8 Dateien |
(Hinweis: Dateien wurden per YAML-Dump neu geschrieben, daher große Diffs bei Formatierung.)

### 3. Offen für menschliche Prüfung
| Punkt | Grund |
|---|---|
| gesetze.co ist kein amtliches Portal | Wortlaut stimmt mit Fassungshinweisen überein, Aktualität (Stand Abruf) nicht gegen amtliches Portal gegengelesen; recht.saarland.de/landesrecht.rlp.de nicht per curl lesbar |
| Haftung Kosten Sofortvollzug SL (Rechtsgrundlage Kostenbescheid unmittelbare Ausführung ohne Grundverfügung) | SPolG enthält kein § 6 POG entsprechendes Kostenerstattungsinstitut (nur § 46 Ersatzvornahme); Kostentragung im Sofortvollzug nicht eindeutig im Text belegt |
| Formverstoß § 62 KSVG / § 49 GemO: Unwirksamkeit vs. schwebende Unwirksamkeit, kein Rechtsschein | Rechtsprechungsaussage (nicht Normtext), keine Quelle abgerufen |
| rp/sl: Schemata und Fälle nur auf Norm-Ebene gegengelesen | Rechtsprechungs- und Streitstandsaussagen (Anscheinsstörer, Zweckveranlasser, doppelfunktional, BVerfGE 102, 1) nicht gegen Primärquelle geprüft |
| RP-Fall rp-fall-kom-ortsgemeinde-abwasser: Anschlussbescheid durch Ortsgemeinde | Zuständigkeit der Verbandsgemeinde bestätigt; spezialgesetzliche Satzungsbefugnis (LWG) nicht geprüft |
| Fall sl-fall-kom-verpflichtungserklärung / rp-fall-bau-bestandsschutz-altbau | Prüfpunkt-Keyword nicht getroffen (schon vor Änderung; check_faelle OK) |

