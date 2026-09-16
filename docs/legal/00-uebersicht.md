# Rechtstexte v1.0 — Übersicht (G4)

> **Kein Rechtsrat.** Dieses Verzeichnis liefert **Entwürfe zur Prüfung**, keine
> rechtsverbindlichen Texte. Vor Produktivschaltung ist eine anwaltliche
> Durchsicht einzuholen (Budgetposten in `docs/19-kosten-preis-budget.md`
> Abschnitt 2/6: 300–1.500 € für anwaltliche Erstellung/Durchsicht als
> Alternative zum Generator-Abo). Diese Entwürfe ersetzen diese Prüfung nicht,
> sie verkürzen sie — die Fakten (Datenmodell, Verarbeitungszwecke, Empfänger)
> sind bereits aus Code und Projektdokumenten abgeleitet, nicht geraten.

**Auftrag:** [SUB-85](/SUB/issues/SUB-85), Gate G4 aus
[`docs/18-release-2-wochen.md`](../18-release-2-wochen.md) Abschnitt 5 —
das einzige Release-Gate ohne Notausgang, weil ein öffentliches, bezahltes
Angebot ohne Impressum, AGB und Datenschutzerklärung abmahnfähig ist.

## Dokumente

| Dokument | Inhalt | Status |
|---|---|---|
| [01-impressum.md](01-impressum.md) | Anbieterkennzeichnung nach § 5 DDG | Struktur steht, Rechtsträger-Angaben als Platzhalter |
| [02-agb.md](02-agb.md) | Nutzungsvertrag, Tarife, Kündigung, Haftung, Struktur-Check-Abgrenzung | Entwurf vollständig |
| [03-datenschutzerklaerung.md](03-datenschutzerklaerung.md) | DSGVO-Informationspflichten, Art. 13/14 | Entwurf vollständig, Empfänger teils Platzhalter |
| [04-widerrufsbelehrung.md](04-widerrufsbelehrung.md) | Fernabsatz-Widerrufsrecht, vorzeitiges Erlöschen bei digitalen Produkten | Entwurf vollständig, eine Produktentscheidung offen |
| [05-cookie-hinweis.md](05-cookie-hinweis.md) | Technisch notwendige Speicherung, kein Tracking in v1.0 | Entwurf vollständig |

Jedes Dokument trägt am Ende eine **Quellen-/Begründungszeile**, die belegt,
woraus der Inhalt abgeleitet wurde (Code, Projektdokument oder Gesetzestext).

## Warum diese Inhalte — nicht aus Vorlagen geraten

- **v1.0 läuft mit `llm_provider=none`** (`docs/18-release-2-wochen.md`
  Abschnitt 2, bestätigt in `backend/app/config.py`: `llm_provider: str = "none"`).
  Kein Nutzertext verlässt das System an einen LLM-Anbieter. Die
  Datenschutzerklärung beschreibt deshalb **keine** KI-Auftragsverarbeitung —
  das wäre für v1.0 schlicht falsch. Der Punkt ist in
  `docs/17-release-readiness.md` Abschnitt 1 ausdrücklich als Vorbedingung für
  **v1.1** vermerkt, nicht für v1.0.
- **Datenkategorien** stammen aus `backend/app/models.py` (`User`, `Review`,
  `UserCard`, `Submission` u. a.), nicht aus einer generischen Annahme.
- **Auth-Mechanismus:** Bearer-JWT (`backend/app/core/security.py`,
  `app/lib/api.dart`), Token liegt clientseitig in `SharedPreferences`
  (`app/lib/state.dart`) — kein Session-Cookie, keine Tracking-Cookies im
  Code. Das bestimmt den schlanken Cookie-Hinweis.
- **Zahlungsdienstleister Stripe** wird als Empfänger geführt, sobald die
  Kaufstrecke aus [SUB-83](/SUB/issues/SUB-83) live ist (Gate G2, 23.09.) —
  vorher ist der Passus in der Datenschutzerklärung als „ab Zahlungsstart"
  markiert.
- **RDG-Abgrenzung und Urheberrechtslage** sind in
  `docs/06-recht-compliance.md` Abschnitt 1/2 bereits durchgearbeitet; die
  AGB übernehmen die dortige Formulierung („Lernhilfe, keine
  Rechtsdienstleistung i. S. d. § 2 RDG") wörtlich sinngemäß.

## Offene Vorbedingung: Rechtsträger (blockiert nur das Impressum)

Aus `docs/18-release-2-wochen.md` Abschnitt 8, Punkt 1 — als Interaktion an
[SUB-39](/SUB/issues/SUB-39) gestellt, zum Zeitpunkt dieses Entwurfs
unbeantwortet: Firma, Gewerbe oder Privatperson als Betreiber. Das Impressum
ist strukturell fertig, alle rechtsträgerabhängigen Zeilen sind in
`01-impressum.md` als `[Platzhalter]` markiert. AGB, Datenschutzerklärung,
Widerrufsbelehrung und Cookie-Hinweis hängen an derselben Antwort nur in der
Kopfzeile (Anbietername) und sind sonst unabhängig nutzbar.

## Liste: Wo menschliche Rechtsprüfung nötig ist

Diese Liste ist die zweite geforderte Abnahme-Lieferung. Punkte sind nach
Dringlichkeit sortiert (blockiert G4 zuerst).

1. **Rechtsträger fehlt** (s. o.) — ohne Antwort ist das Impressum nicht
   veröffentlichbar. **Blockiert G4 direkt.** Eigentümer: Nutzer, via
   SUB-39-Interaktion.
2. **Anwaltliche Freigabe aller fünf Texte vor Produktivschaltung** — dieser
   Entwurf ist keine Rechtsberatung (siehe Kopfzeile). `docs/17-release-readiness.md`
   Abschnitt 1 nennt für AGB 3–5 PT, Datenschutzerklärung 2–3 PT, Widerruf
   1 PT externen Aufwand. **Blockiert G4**, wenn keine Prüfkapazität vor dem
   28.09. verfügbar ist — dann ist das der Punkt, der den Termin nach
   Abschnitt 5 der Roadmap tatsächlich verschiebt.
3. **Kündigungsbutton-Pflicht (§ 312k BGB)** — die AGB (`02-agb.md`
   Abschnitt 5) beschreiben Selbstkündigung im Produkt als Zielzustand. Zum
   Zeitpunkt dieses Entwurfs existiert dafür kein Code (Abo-Verwaltung ist in
   `docs/17-release-readiness.md` Abschnitt 4 als „Offen" geführt, gehört zu
   [SUB-83](/SUB/issues/SUB-83)). **Vor G4 zu verifizieren:** Ist die
   Kündigungsfunktion bis 28.09. im Produkt live? Wenn nein, muss entweder
   die Funktion vor G4 fertig werden oder der AGB-Text auf den tatsächlich
   verfügbaren Kündigungsweg angepasst werden — ein Text, der eine
   nicht existierende Funktion behauptet, ist selbst ein Abmahnrisiko.
4. **Widerrufsrecht bei Vertragsbeginn — Produktentscheidung offen**
   (`04-widerrufsbelehrung.md` Abschnitt „Offene Entscheidung"). Der Entwurf
   schlägt die ausdrückliche Zustimmung zum sofortigen Vertragsbeginn mit
   Verlust des Widerrufsrechts vor (Standard bei SaaS mit Sofortzugriff),
   das muss aber am Checkout-Flow aus SUB-83 tatsächlich als Checkbox
   umgesetzt werden, sonst ist die Widerrufsbelehrung falsch für den
   gebauten Ablauf.
5. **DSGVO-Selbstbedienung (Export/Löschung) noch nicht gebaut** —
   `backend/app/api/v1/auth.py` hat nur `/me` GET/PATCH, keinen Export- oder
   Löschendpunkt (Stand dieses Entwurfs). `docs/17-release-readiness.md`
   Abschnitt 1 führt das unter Backend-Dev, [SUB-84](/SUB/issues/SUB-84)
   trägt die Umsetzung bis G4. Die Datenschutzerklärung (`03-...md`,
   Abschnitt „Betroffenenrechte") beschreibt Export/Löschung als Funktion im
   Produkt — **vor G4 zu verifizieren**, ob SUB-84 bis 28.09. live ist. Falls
   nicht, muss der Text auf den Support-Weg (E-Mail) zurückfallen.
6. **Support-E-Mail-Adresse ist Platzhalter** — `docs/18` nennt „Support-
   Postfach besetzt" erst als G5-Kriterium (29.09.), die Rechtstexte
   brauchen die Adresse aber schon für G4 (Kontaktangabe ist Pflichtangabe
   in Impressum und Datenschutzerklärung). Eigentümer: Betrieb/Lead-Developer
   ([SUB-86](/SUB/issues/SUB-86)).
7. **OS-Streitschlichtung / VSBG-Hinweis** (`02-agb.md`, Abschnitt 9) — die
   EU-Kommission hat die OS-Plattform 2025 abgeschaltet; der Entwurf verzichtet
   deshalb auf den klassischen OS-Link und nennt nur die VSBG-Pflichtangabe.
   **Diese Rechtslage bitte gesondert bestätigen** — Änderungen in diesem
   Bereich sind seit der Abschaltung noch nicht in jeder Vorlage aktuell und
   sind der Punkt in diesem Entwurf mit der größten Veraltungsgefahr.
8. **Verarbeitungsverzeichnis (Art. 30 DSGVO) fehlt weiterhin** —
   `docs/17-release-readiness.md` Abschnitt 1 führt es als offenes internes
   Dokument. Es ist keine Nutzer-Pflichtangabe und blockiert G4 nicht, sollte
   aber vor Skalierung über die Beta hinaus nachgezogen werden.
9. **Kleinunternehmerregelung / Umsatzsteuer-Ausweis** — hängt am
   Rechtsträger (Punkt 1) und an der USt-OSS-Frage aus
   `docs/17-release-readiness.md` Abschnitt 4 (offene Steuerfrage). Die AGB
   (`02-agb.md` Abschnitt 4) markieren die Preisangabe deshalb mit einem
   Platzhalter für den USt-Zusatz.

## Nicht Teil dieses Auftrags

- Store-Datenschutzangaben (Apple Privacy Nutrition Label, Play Data Safety)
  — eigener Punkt in `docs/17-release-readiness.md` Abschnitt 3, hängt an der
  finalen Provider-Liste aus Abschnitt 1 desselben Dokuments.
- Interne Dokumente (Verarbeitungsverzeichnis, AVV) — kein Nutzer-Artefakt,
  siehe Punkt 8 oben.
