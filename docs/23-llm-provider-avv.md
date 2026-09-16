# LLM-Provider-Wahl + AVV — Entscheidungsvorlage für v1.1

> **Herkunft:** [SUB-129](/SUB/issues/SUB-129), aus einer Nutzerfrage auf
> [SUB-39](/SUB/issues/SUB-39) („Warum haben wir die KI-Korrektur
> gestrichen?"). `docs/18-release-2-wochen.md` Abschnitt 2 nennt drei Gründe
> für die Verschiebung der KI-Klausurkorrektur auf v1.1; nur einer davon ist
> ein echtes Gate: der fehlende Auftragsverarbeitungsvertrag (AVV) mit einem
> LLM-Provider (`docs/17-release-readiness.md` Abschnitt 1). Dieses Dokument
> ist eine **Entscheidungsvorlage, keine Umsetzung** — es werden keine
> Provider-Verträge geschlossen und keine Keys gesetzt.
>
> Wichtig zur Reihenfolge: Der AVV blockt **jede** LLM-Variante der Korrektur,
> auch eine rein kommentierende ohne Punkte/Note — sobald Gutachtentext das
> eigene System verlässt, greift die Pflicht. Die Kalibrierung (MAE ≤ 2, siehe
> die Schwesteraufgabe zu [SUB-69](/SUB/issues/SUB-69)) ist nur für die
> *bewertende* Variante bindend und damit der zweite, nachgelagerte Schritt.

---

## 1. Ist-Stand im Code

Die KI-Korrektur ist **abgeschaltet, nicht entfernt** — v1.0 läuft ohne
Codeänderung LLM-frei:

- `backend/app/core/llm.py:35-49` implementiert genau einen Provider
  (`AnthropicClient`, US-Endpunkt `api.anthropic.com`). Die Klasse ist nur
  `available`, wenn `settings.llm_provider == "anthropic"` **und**
  `settings.llm_api_key` gesetzt ist (`llm.py:47-49`). Es gibt daneben keine
  weitere Provider-Implementierung im Code.
- `backend/app/config.py:33-36` setzt den Default `llm_provider: str = "none"`
  und `llm_api_key: str = ""`. Ohne explizite Umgebungsvariablen bleibt der
  Provider deaktiviert.
- `backend/app/services/evaluator.py:341-345` (`get_evaluator()`) liefert nur
  dann den `LLMEvaluator` aus, wenn `llm_provider == "anthropic"` **und**
  `llm_api_key` gesetzt sind — sonst immer den `HeuristicEvaluator`. Das ist
  der einzige Ort, an dem Nutzer-Gutachtentext potenziell an ein externes LLM
  ginge.
- `backend/app/api/v1/gutachten.py:20-41` (`POST /gutachten/analyze`, der
  Übungsmodus-Endpunkt) ruft ausschließlich `app.services.gutachten.analyze()`
  auf — rein heuristisch, kein LLM-Aufrufpfad vorhanden, unabhängig von jeder
  Konfiguration.
- `backend/app/services/evaluator.py:259-280` (`LLMEvaluator._build_prompt`)
  zeigt: Der Prompt enthält Erwartungshorizont und den vollen Gutachtentext,
  aber **keine Nutzerkennung** — die Pseudonymisierungsauflage aus
  `docs/06-recht-compliance.md` Abschnitt 3 („keine Nutzer-ID im Prompt") ist
  für die ID bereits erfüllt. Es gibt jedoch **keine Bereinigung des
  Gutachtentexts selbst** (z. B. vom Prüfling versehentlich genannte
  Klarnamen, Matrikelnummern o. Ä. im Fließtext) — dazu mehr in Abschnitt 3.
- Bei jedem Fehler (kein Key, Timeout, unparsbare Antwort) fällt
  `LLMEvaluator.evaluate()` lautlos auf `HeuristicEvaluator` zurück
  (`evaluator.py:282-295`) — ein Providerausfall blockiert nie die Abgabe.

**Konsequenz:** Um die KI-Korrektur in irgendeiner Form zu aktivieren, reicht
es nicht, `SUBSUMO_LLM_PROVIDER=anthropic` und einen Key zu setzen — dafür
muss zusätzlich der AVV stehen (Abschnitt 2) und der Sendepfad um
Datenminimierung ergänzt werden (Abschnitt 3). Für einen anderen Provider als
Anthropic direkt müsste `llm.py` zusätzlich um eine neue `LLMClient`-Variante
erweitert werden (Aufwand je Option in Abschnitt 2).

## 2. Optionen

Alle AVV-/DPA-Aussagen stammen aus einer Web-Recherche vom 16.09.2026 auf
öffentlich zugänglichen Anbieter- und Drittanbieterseiten (Quellen am Ende
dieses Abschnitts), **nicht aus einer eigenen Vertragsprüfung**. Sie sind eine
fundierte Grundlage für die Entscheidung, ersetzen aber keine anwaltliche
Prüfung des tatsächlich abzuschließenden Vertrags — entsprechend als
„recherchiert, zu verifizieren" markiert, nicht als geprüfte Tatsache.

### Option A — Anthropic direkt (US)

| Kriterium | Stand |
|---|---|
| AVV verfügbar? | **Ja, aber ohne EU-Verarbeitung.** Anthropic bietet ein Standard-DPA (Art.-28-Vertrag) mit EU-SCCs (Module 2/3 nach Durchführungsbeschluss (EU) 2021/914) für zahlende Kunden, das bei Annahme der kommerziellen Bedingungen automatisch eingebunden wird. Gerichtsstand Irland. **Zu klären:** ob der Self-Serve-API-Zugang (ohne Enterprise-Vertrag) automatisch das volle DPA umfasst oder ein gesondertes Opt-in/Sales-Gespräch nötig ist — das ist aus öffentlichen Quellen nicht abschließend zu belegen |
| Verarbeitungsort | USA. Anthropic bietet für Claude über den First-Party-API-Zugang **keine** EU-Datenresidenz an — jeder Prompt wird auf US-Infrastruktur verarbeitet |
| Unterauftragsverarbeiter | Nicht recherchiert — **zu klären** vor Vertragsschluss (Anthropic veröffentlicht eine Subprocessor-Liste, die für diese Vorlage nicht geprüft wurde) |
| Preis / 1M Token | Deckt sich mit der Schätzung in `docs/19-kosten-preis-budget.md` Abschnitt 5 (Sonnet-Modell, 3 $/Mio Eingabe, 15 $/Mio Ausgabe nach evtl. Launch-Rabattfenster) |
| Integrationsaufwand `llm.py` | **Keiner** — bereits implementiert (`AnthropicClient`). Nur Key setzen und AVV unterschreiben |

### Option B — Anthropic über EU-Hyperscaler-Endpunkt (AWS Bedrock / Google Vertex AI, EU-Region)

| Kriterium | Stand |
|---|---|
| AVV verfügbar? | **Ja, aber mit dem Hyperscaler als Vertragspartner, nicht mit Anthropic.** Bei Bedrock/Vertex ist AWS bzw. Google datenschutzrechtlich Auftragsverarbeiter für die Inferenz, nicht Anthropic — es gilt der AWS- bzw. Google-Cloud-AVV. **Zu klären:** ob für dieses Projekt bereits ein Rahmenvertrag mit AWS oder Google existiert (aktuell nicht ersichtlich, `docs/17-release-readiness.md` Abschnitt 5 nennt Hosting-Entscheidung noch als offen) — ein neuer Cloud-Vertrag zusätzlich zum eigentlichen App-Hosting wäre ein weiterer Verwaltungsaufwand |
| Verarbeitungsort | EU möglich: AWS Bedrock `eu-central-1` (Frankfurt), `eu-west-1` (Irland), `eu-west-3` (Paris); Google Vertex AI EU-Regionen mit vollständigem Claude-Modell-Lineup. Region ist dabei eine Eigenschaft des gewählten Cloud-Endpunkts, nicht von Anthropic |
| Unterauftragsverarbeiter | AWS bzw. Google selbst plus deren jeweilige Subprocessor-Kette — **nicht recherchiert, zu klären** |
| Preis / 1M Token | Bei AWS Bedrock in Standard-Regionen recherchiert identisch zum direkten Anthropic-Listenpreis (z. B. Sonnet 5: 2 $/10 $ bis 31.08.2026, danach 3 $/15 $ je Mio Token); ein regionaler/Multi-Region-Endpunkt kann laut Recherche einen Aufschlag von ca. 10 % gegenüber dem globalen Bedrock-Default tragen — **nicht verifiziert, als Annahme markiert**. Für Vertex AI keine belastbare Preisangabe recherchiert — **zu klären** |
| Integrationsaufwand `llm.py` | **Spürbar.** `AnthropicClient` müsste durch eine neue Implementierung ersetzt/ergänzt werden, die statt der Anthropic-REST-API (`llm.py:57-70`) die Bedrock- bzw. Vertex-AI-SDK-Aufrufe samt AWS-/GCP-Authentifizierung (IAM-Rollen bzw. Service-Account, kein einfacher API-Key wie bisher) nutzt. Grobschätzung 2–4 PT inkl. Tests — **nicht im Detail durchgeplant, Schätzung unsicher** |

### Option C — EU-eigener Anbieter (z. B. Mistral AI)

| Kriterium | Stand |
|---|---|
| AVV verfügbar? | **Ja.** Mistral veröffentlicht eine eigene Data Processing Addendum, referenziert die DSGVO direkt als Grundlage. **Zu klären:** laut Recherche garantieren die Standardbedingungen DSGVO-Konformität für EU-Betroffene nicht automatisch ohne ein gesondert ausgeführtes GDPR-DPA (separat vom allgemeinen DPA) — ob das für einen Self-Serve-Zugang ohne Sales-Kontakt gilt, ist nicht abschließend geklärt |
| Verarbeitungsort | Standardmäßig EU (Schweden primär, Irland als Backup laut Recherche); ein expliziter US-Endpunkt existiert optional, wird hier nicht gewählt |
| Unterauftragsverarbeiter | Nicht recherchiert — **zu klären** |
| Preis / 1M Token | Mistral Large 3 recherchiert mit 0,50 $ Eingabe / 1,50 $ Ausgabe je Mio Token — deutlich günstiger als die Anthropic-Sonnet-Kalkulation in `docs/19` Abschnitt 5. **Achtung:** Das ist ein reiner Preisvorteil, kein Qualitätsvorteil (siehe unten) |
| Integrationsaufwand `llm.py` | **Mittel.** Neue `LLMClient`-Implementierung gegen die Mistral-Chat-API (näher an einer klassischen REST-API als Bedrock/Vertex, daher voraussichtlich einfacher als Option B). Grobschätzung 1–2 PT inkl. Tests — **nicht im Detail durchgeplant** |
| **Qualitätsrisiko** | **Muss offen benannt werden:** Für die juristische Gutachtenbewertung braucht `LLMEvaluator._build_prompt` (`evaluator.py:259-280`) ein Modell, das komplexe, mehrschichtige Subsumtionsprüfungen zuverlässig gegen einen strukturierten Erwartungshorizont abgleicht und dabei nicht halluziniert (`evidence` muss wörtlich im Text stehen, `evaluator.py:302-304` prüft das serverseitig ab, fängt aber nur den Beleg ab, nicht die inhaltliche Fehleinschätzung). Es liegt **keine eigene Evaluation** vor, ob ein Mistral-Modell diese Aufgabe mit vergleichbarer Güte wie ein Claude-Sonnet-Modell löst. Der Kalibrierungs-Harness aus SUB-69 (MAE ≤ 2 gegen 30 Dozentengutachten) ist genau dafür gedacht, müsste aber **je Provider erneut durchlaufen werden** — ein Providerwechsel invalidiert eine bereits gelaufene Kalibrierung |

### Option D — Kein LLM (Status quo v1.0)

| Kriterium | Stand |
|---|---|
| AVV verfügbar? | **Entfällt** — kein Anbieter, kein Vertrag nötig |
| Verarbeitungsort | Ausschließlich das eigene System (`docs/legal/03-datenschutzerklaerung.md` Abschnitt 3 dokumentiert das bereits so für v1.0) |
| Unterauftragsverarbeiter | Keiner zu diesem Zweck |
| Preis / 1M Token | 0 € — entfällt als Kostenblock (`docs/19` Abschnitt 5: „Ohne sie sind die Betriebskosten praktisch fix") |
| Integrationsaufwand `llm.py` | Keiner — aktueller Zustand |
| Nachteil | Kein bewertendes oder kommentierendes KI-Feedback über das heuristische Struktur-/Stilfeedback aus `analyze()` hinaus |

**Quellen der Recherche (16.09.2026, nicht anwaltlich geprüft):**
Anthropic DPA/SCC-Übersichten (compound.law, Stork.AI, CompanyScope);
EU-Datenresidenz-Übersichten zu Bedrock/Vertex (Sonomos, Requesty, Omnifact,
compound.law); AWS-Bedrock-Preisvergleiche (TokenMix, Caylent, Claude
Platform Docs); Mistral-DPA- und Preisseiten (legal.mistral.ai,
help.mistral.ai, CloudZero, BenchLM). Durchweg Sekundärquellen bzw.
Anbieterseiten Stand September 2026 — vor einer Entscheidung mit
Vertragsdokumenten des gewählten Anbieters zu verifizieren.

## 3. Datenminimierung — konkrete Anforderung an den Sendepfad

`docs/06-recht-compliance.md` Abschnitt 3 verlangt „Pseudonymisierung vor
Versand (keine Nutzer-ID im Prompt)". Der Code erfüllt aktuell nur die
Nutzer-ID-Hälfte:

- **Erfüllt:** `LLMEvaluator._build_prompt` (`evaluator.py:259-280`) baut den
  Prompt ausschließlich aus Erwartungshorizont-Feldern (`id`, `label`,
  `weight`, `norms`) und dem rohen `text`-Parameter. Es wird nirgends
  `user.id`, `user.email` oder ein anderes Identifikationsmerkmal aus
  `CurrentUser` in den Prompt oder die Übertragung an `client.complete()`
  eingemischt — auch `gutachten.py:73-75` reicht nur `text`, `expectation`
  und `structure` durch, kein `user`-Objekt.
- **Nicht erfüllt:** Der Gutachtentext selbst (`payload.text` in
  `gutachten.py:72`) durchläuft **keine Prüfung oder Bereinigung**, bevor er
  im Prompt landet. Ein Prüfling kann im Fließtext des eigenen Übungs­gutachtens
  einen Klarnamen, eine Matrikelnummer oder andere personenbezogene Angaben
  nennen — dagegen existiert weder ein Filter noch ein Hinweis im Code.
- **Prüfbare Anforderung für die Umsetzung** (an der Stelle
  `LLMEvaluator.evaluate()`, `evaluator.py:282-295`, unmittelbar vor dem
  Aufruf von `client.complete()`): Der übertragene Text darf keine explizit
  vom System bekannten Identifikationsmerkmale enthalten (E-Mail-Adresse,
  Anzeigename, Nutzer-ID) — dafür reicht ein serverseitiger Abgleich/Redact
  der bekannten Nutzerdaten (`user.email`, `user.display_name`) gegen den
  Text, bevor er in `_build_prompt` eingesetzt wird. Was der Prüfling selbst
  ungebeten preisgibt (z. B. eigener Name im Sachverhaltstext), kann
  serverseitig nicht zuverlässig erkannt werden — das ist eine Grenze, keine
  Lücke im Sinne eines behebbaren Bugs, und gehört als Restrisiko in das
  Verarbeitungsverzeichnis (`docs/17-release-readiness.md` Abschnitt 1).

## 4. Produkt-Transparenz

`docs/17-release-readiness.md` Abschnitt 1 verlangt „Transparenz im Produkt
(Hinweis vor erster Gutachten-Abgabe, was mit dem Text passiert) [...], nicht
nur AGB-Text". Im aktuellen Code gibt es dafür **keine Stelle** — weder im
Backend noch (soweit aus diesem Repository ersichtlich) im Flutter-Client gibt
es einen Consent-/Hinweis-Dialog vor `POST /cases/{slug}/submit`. Für die
Umsetzung wäre das:

- Ein einmaliger Hinweis-Dialog im Client, der vor der **ersten** Gutachten-
  Abgabe eines Accounts erscheint (nicht bei jeder Abgabe erneut) und benennt,
  dass der eingereichte Text an den gewählten externen Anbieter geht.
- Serverseitig ein Flag am `User`-Modell (z. B. `llm_consent_at`), das beim
  ersten Bestätigen gesetzt wird, und ein serverseitiger Check in
  `submit_case` (`gutachten.py:56-98`), der ohne diese Zustimmung auf den
  heuristischen Pfad zurückfällt statt den LLM-Pfad zu nutzen — analog zum
  bestehenden Fallback-Verhalten bei fehlendem Provider.
- Das ist **Einwilligung nach Art. 6 I a DSGVO**, zusätzlich zur
  Vertragserfüllungs-Grundlage der übrigen Datenverarbeitung
  (`docs/06-recht-compliance.md` Abschnitt 3) — beide Rechtsgrundlagen
  bestehen nebeneinander, nicht alternativ.

Dieser Hinweis-Mechanismus existiert nicht und ist in keiner der vier
Optionen automatisch enthalten — er ist in jedem Fall zusätzlicher
Umsetzungsaufwand (grob 1–2 PT Backend + Frontend), unabhängig von der
Provider-Wahl.

## 5. Folgewirkungen einer LLM-Entscheidung

Alle vier hängen an dieser einen Wahl und wurden bislang mit Platzhaltern
bzw. „v1.0 ohne LLM" offengehalten:

- **Datenschutzerklärung** (`docs/legal/03-datenschutzerklaerung.md`
  Abschnitt 3 und 4): Der Entwurf sagt aktuell explizit „kein Einsatz von
  Sprachmodellen mit Nutzertexten (Stand v1.0)". Bei Aktivierung einer
  LLM-Option muss Abschnitt 3 ersetzt und Abschnitt 4 (Empfängerliste) um den
  gewählten Anbieter (und bei Option B zusätzlich um den Hyperscaler) ergänzt
  werden — inklusive Verarbeitungsort und Drittlandtransfer-Hinweis bei
  Option A.
- **Store-Datenschutzangaben** (`docs/17-release-readiness.md` Abschnitt 3):
  Apple „Privacy Nutrition Label" und Play „Data Safety" hängen laut diesem
  Dokument direkt an der Provider-Liste aus Abschnitt 1 — ohne finale
  Provider-Wahl keine verbindlichen Angaben möglich. Das gilt unabhängig
  davon, welche der vier Optionen gewählt wird (bei Option D entfällt der
  Punkt schlicht).
- **Kostenblock** (`docs/19-kosten-preis-budget.md` Abschnitt 5): Die dortige
  Kalkulation (0,09–0,30 €/Korrektur, Pro-Tarif-Fair-Use 20 Korrekturen/Monat)
  ist explizit auf ein Sonnet-Modell gerechnet. Option C (Mistral, ca. 3–6×
  günstiger je Token laut Abschnitt 2 dieser Vorlage) würde diese Rechnung
  spürbar entlasten, Option B ändert sie preislich kaum (Bedrock-Standardpreis
  ≈ Anthropic-Direktpreis), Option D lässt sie ganz entfallen.
- **Verarbeitungsverzeichnis** (`docs/17` Abschnitt 1): Noch nicht angelegt,
  wartet laut diesem Dokument ausdrücklich auf die Provider-Wahl.

## 6. Empfehlung

**Empfehlung: Option B (Anthropic über AWS Bedrock, EU-Region) für die
kommentierende/bewertende LLM-Korrektur, falls und sobald v1.1 sie einführt —
mit dem klaren Vorbehalt, dass die als „zu klären" markierten Punkte vor
Vertragsschluss verifiziert werden müssen.**

Begründung:

1. **Qualität ist für diese Aufgabe nicht verhandelbar.** Die Korrektur
   bewertet echte Klausurleistungen; Option C spart Kosten, aber ohne eigene
   Qualitätsevaluation eines EU-Modells für juristische Subsumtionsprüfung
   wäre das ein unbelegtes Risiko genau an der Stelle, die
   `docs/18-release-2-wochen.md` bereits als vertrauenskritisch markiert hat
   (Grund 1 der Streichung: „beschädigt genau das Vertrauen, von dem das
   Feature später lebt"). Option B behält das in `_build_prompt` bereits
   funktionierende Anthropic-Modell.
2. **AVV mit EU-Verarbeitung ist über Option B tatsächlich erreichbar**,
   während Option A (Anthropic direkt) laut Recherche **keine**
   EU-Datenresidenz anbietet — das widerspricht der in
   `docs/06-recht-compliance.md` Abschnitt 3 bereits getroffenen
   Grundsatzentscheidung „Provider-Wahl mit EU-Verarbeitung bevorzugt".
   Option B löst diesen Widerspruch, ohne das Modell zu wechseln.
3. **Der Mehraufwand ist real, aber einmalig und begrenzt** (grob 2–4 PT für
   eine zweite `LLMClient`-Implementierung plus AWS-Vertragsanbahnung),
   während das Qualitätsrisiko aus Option C bei jedem einzelnen
   Korrekturergebnis fortbesteht.
4. Diese Empfehlung ersetzt **nicht** die in Abschnitt 2 als „zu klären"
   markierten Punkte — insbesondere ob für dieses Projekt bereits ein
   AWS-Rahmenvertrag sinnvoll ist (gebündelt mit der ohnehin offenen
   Hosting-Entscheidung aus `docs/17` Abschnitt 5) oder ob der zusätzliche
   Vertragsaufwand gegenüber Option A für die Beta-Größenordnung
   unverhältnismäßig ist.

Falls der Zeitdruck vor v1.1 keinen zweiten Integrationsaufwand erlaubt und
die EU-Verarbeitungsfrage aufgeschoben werden kann (Produktentscheidung, kein
Automatismus), wäre Option A der pragmatischere Zwischenschritt — dann aber
mit einer expliziten, dokumentierten Abweichung von der
EU-Verarbeitungs-Präferenz aus `docs/06-recht-compliance.md`, nicht
stillschweigend.

## 7. Offene Punkte, die diese Vorlage nicht beantwortet

- Ob für Option A ein Self-Serve-DPA ausreicht oder ein Sales-Kontakt nötig
  ist.
- Die vollständigen Unterauftragsverarbeiter-Listen aller drei
  LLM-Optionen (A/B/C) — nicht recherchiert.
- Belastbare Vertex-AI-Preise für Claude-Modelle in EU-Regionen.
- Ob bereits ein Cloud-Rahmenvertrag (AWS/GCP) existiert, an den Option B
  andocken könnte, oder ob das ein komplett neuer Vertrag wäre.
- Tatsächliche Qualität eines EU-Modells (Option C) für juristische
  Subsumtionsprüfung — nur durch einen eigenen Kalibrierungslauf zu klären,
  nicht durch Recherche.

Diese fünf Punkte sind bewusst nicht in eine Tabellenzeile „geschätzt"
verwandelt worden — sie brauchen jeweils eine externe Abklärung (Anbieter,
Recht, oder einen eigenen Testlauf), keine weitere Dokumentenarbeit.
