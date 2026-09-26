# Recht & Compliance

Kein Rechtsrat — Arbeitsgrundlage für die Produktentwicklung. Für die
AGB-Haftungsklausel (`docs/legal/02-agb.md` Abschnitt 8) und den
Widerrufsverzicht (§ 356 V BGB, `docs/legal/04-widerrufsbelehrung.md`) gilt:
**bewusst getragen, keine anwaltliche Prüfung** (Entscheidung 25.09.2026,
siehe `docs/31-projektreview-sub254.md` Abschnitt 9 und
`docs/17-release-readiness.md` Abschnitt 1). Für die übrigen Rechtstexte
(insbesondere die Datenschutzerklärung) ist die anwaltliche Prüfung vor dem
Launch weiterhin offen (Budgetposten in M5).

## 1. Urheberrecht an Inhalten

| Inhaltstyp | Status | Regel im Projekt |
|---|---|---|
| Gesetzestexte | Amtliches Werk, § 5 I UrhG — gemeinfrei | Direkter Import aus gesetze-im-internet.de (XML) erlaubt. Quelle + Abrufdatum mitführen |
| Gerichtsentscheidungen | Amtliches Werk, § 5 I UrhG | Volltext/Leitsatz nutzbar. **Amtliche Leitsätze sind frei, redaktionelle Leitsätze von Verlagen sind es nicht** |
| Lehrbuch-/Kommentartexte | Voll geschützt | **Nie übernehmen.** Nur bibliografisch zitieren (Fundstelle) |
| Prüfungsschemata | Regelmäßig kein Werk (Idee/Struktur), aber Formulierungen können geschützt sein | Immer eigenständig formulieren, nie abschreiben |
| Klausursachverhalte der JPAs | Uneinheitlich, oft geschützt | Nur mit Genehmigung; im Zweifel eigene Sachverhalte |
| Nutzergenerierte Gutachten | Beim Nutzer | Nutzungsrecht per AGB nur für Betrieb/Anzeige, kein Verkauf, Opt-in für Trainingszwecke |

**Durchsetzung im Code:** Jeder Inhalt in `content/` trägt Pflichtfelder
`quellen` und `stand`; die CI lehnt Inhalte ohne Quellenangabe ab.

## 2. RDG — Abgrenzung zur Rechtsberatung

Subsumo bewertet ausschließlich **fiktive Übungssachverhalte** aus der eigenen
Fall-Datenbank gegen einen vorab definierten Erwartungshorizont. Das ist
Ausbildung, keine Rechtsdienstleistung i. S. d. § 2 RDG.

Konkrete Maßnahmen:
- Freitext-Bewertung ist **immer** an eine `case_id` mit hinterlegtem
  Erwartungshorizont gebunden — es gibt keinen Endpunkt „bewerte diesen
  beliebigen Sachverhalt"
- Hinweis im Produkt an jeder Bewertungsausgabe: Lernhilfe, keine Rechtsberatung
- Kein Feature zum Hochladen echter Verträge, Bescheide oder Schriftsätze

## 3. DSGVO

- **Rechtsgrundlage:** Vertragserfüllung (Art. 6 I b) für Lerndaten;
  Einwilligung (Art. 6 I a) für optionale Telemetrie und KI-Training
- **Datenminimierung:** E-Mail + Hash + Lerndaten. Kein Klarname, kein
  Geburtsdatum, keine Uni-Zuordnung außer freiwillig
- **Auftragsverarbeitung:** AV-Vertrag mit dem LLM-Provider; Gutachtentexte sind
  personenbeziehbar. Pseudonymisierung vor Versand (keine Nutzer-ID im Prompt);
  Provider-Wahl mit EU-Verarbeitung bevorzugt
- **Betroffenenrechte:** Export (JSON) und vollständige Löschung als Endpunkte
  in M3, nicht als Support-Prozess
- **Kinder:** Zielgruppe volljährig; keine Vermarktung an Minderjährige

## 4. Plattform-Anforderungen

- Apple: Digitale Abos müssen über In-App-Purchase laufen (30 %/15 %). Web-
  Abschluss außerhalb der App bleibt möglich, darf in der iOS-App aber nicht
  beworben werden — Preisgestaltung entsprechend kalkulieren
- Microsoft Store: MSIX-Signierung, alternativ Direct-Download mit EV-Zertifikat
- Alle Stores: Datenschutzerklärung + Impressum (§ 5 DDG) verlinkt

## 5. Claims und Werbeaussagen

Aussagen wie Durchfallquoten, Repetitoriumskosten oder Notenverteilungen dürfen
nur mit belegter Primärquelle verwendet werden. Die Zahlen in
`docs/00-problemanalyse.md` sind **interne Arbeitshypothesen** und vor jeder
externen Verwendung gegen JPA-Jahresberichte bzw. das Statistische Bundesamt zu
verifizieren. Keine Erfolgsversprechen („Bestehensgarantie", „2 Punkte besser").
