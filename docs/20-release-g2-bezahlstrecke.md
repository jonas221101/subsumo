# Release G2: Bezahlstrecke v1.0 — Abnahmekriterien und Zerlegung

> Zerlegung zu [SUB-83](/SUB/issues/SUB-83), Gate G2 aus
> [`docs/18-release-2-wochen.md`](18-release-2-wochen.md) Abschnitt 5, Termin
> **Mi 23.09.2026**. Übernimmt Preise/Limits unverändert aus
> [`docs/19-kosten-preis-budget.md`](19-kosten-preis-budget.md) Abschnitt 4 und
> den Widerrufs-Rahmen aus [`docs/06-recht-compliance.md`](06-recht-compliance.md).
> Reiner Planungs-Output — kein Code in dieser Aufgabe.

## 1. Die Kette, die auf Staging laufen muss

Registrierung → Lernen → Kauf → Pro-Freischaltung → Kündigung, end-to-end,
gegen den Stripe-Testmodus. Web-only (iOS/IAP ist laut `docs/18` Abschnitt 3.2
aus v1.0 gestrichen).

## 2. Preise und Limits (unverändert aus docs/19 §4, nicht neu erfunden)

| | Free | Pro (Gründerpreis) |
|---|---|---|
| Preis | 0 € | 3,99 €/Monat oder 39 €/Jahr, Bestandspreisgarantie |
| Karteikarten | 20 fällige Karten/Tag, ein Rechtsgebiet | unbegrenzt, drei Rechtsgebiete |
| Schemata | lesen | lesen + Reihenfolge-Drill |
| Geführte Fälle | 2 | alle |
| Struktur-Check (Gutachten) | 3/Woche | unbegrenzt |

## 3. Teilaufgaben

| ID | Titel | Verantwortlich | Voraussetzung |
|---|---|---|---|
| B1 | Entitlement-Datenmodell + serverseitige Durchsetzung | Backend-Developer | — |
| B2 | Free-Tier-Limits serverseitig | Backend-Developer | B1 |
| B3 | Stripe-Checkout-Integration | Backend-Developer | B1 |
| B4 | Stripe-Webhook-Verarbeitung | Backend-Developer | B3 |
| B5 | Kündigung + Widerrufsfall (14 Tage) | Backend-Developer | B4 |
| F1 | Pro-Gating im Flutter-Client | Frontend-Developer | B1 (Feldnamen), B2 (Fehlerformat) |
| F2 | Checkout-Flow im Client | Frontend-Developer | B3 |
| F3 | Kündigungs-UI | Frontend-Developer | B5, F1 |

Build-Reihenfolge (nicht Gate-Reihenfolge): B1+B3 zuerst (Mi 16.09, deckungsgleich
mit dem Tagesplan aus `docs/18` Abschnitt 6), dann B2+F1 (Do 17.09), dann B4
(Do/Fr), dann F2 (Fr–Mo), dann B5 (Mo 21.09), dann F3 (Di 22.09). Der 23.09.
selbst ist Testtag für die Gesamtkette, kein Pufferentwicklungstag.

## 4. Abnahmekriterien je Teilaufgabe

### B1 — Entitlement-Datenmodell + serverseitige Durchsetzung
Betrifft `backend/app/models.py`, `app/schemas.py`, `app/config.py`.

- `users` bekommt `stripe_customer_id` (str|null), `stripe_subscription_id`
  (str|null), `pro_until` (datetime|null), `cancel_at_period_end`
  (bool, default false). Kein Alembic nötig (`docs/04` — M0-Stand,
  `Base.metadata.create_all` deckt es ab).
- Neuer Helper `User.has_pro_access(now) -> bool` = rein zeitbasierter
  Vergleich `pro_until is not None and pro_until > now`. Keine Client-Eingabe
  beeinflusst das Ergebnis.
- `GET /auth/me` liefert `pro_active`, `pro_until`, `cancel_at_period_end`
  zusätzlich im `UserOut`. `UserUpdateIn` erlaubt **keins** dieser Felder.
- Neues Setting `paywall_enabled: bool = False` (`SUBSUMO_PAYWALL_ENABLED`).
  Bei `False` verhält sich jeder Nutzer wie Pro — das ist der Schalter für den
  Notausgang in Abschnitt 5.
- Test: neuer Nutzer → `pro_active=False`; `pro_until` in der Zukunft →
  `True`; `pro_until` in der Vergangenheit → `False`, ohne manuellen Reset.

### B2 — Free-Tier-Limits serverseitig
Betrifft `app/api/v1/learn.py`, `app/api/v1/gutachten.py`.

- Nur wirksam bei `paywall_enabled=True`.
- `GET /cards/due`: Free-Nutzer max. 20 fällige Karten/Tag (serverseitig über
  die Reviews des Tages gezählt, nicht über den Client-`limit`-Parameter) und
  nur ein Rechtsgebiet.
- `GET /cases/{slug}`: Free-Nutzer bekommen ab dem dritten unterschiedlichen
  Fall `403` mit `upgrade_required: true` im Body.
- `POST /gutachten/analyze`: Free-Nutzer max. 3 Aufrufe/Woche, serverseitig
  gezählt, Reset-Zeitpunkt in der Fehlermeldung.
- Pro-Nutzer (`has_pro_access=True`) sind von allen drei Limits ausgenommen —
  ein Test pro Limit belegt das.
- Einheitliches Fehlerformat (`upgrade_required: true`) über alle drei Limits,
  damit F1 gezielt reagieren kann statt auf generische Fehler.

### B3 — Stripe-Checkout-Integration
Neu: `app/services/billing.py`, `app/api/v1/billing.py`.

- `POST /billing/checkout-session` (auth) mit `{"plan": "monthly"|"yearly"}`
  erstellt eine Stripe-Checkout-Session (Mode `subscription`) mit den Preisen
  aus Abschnitt 2 und liefert `{"checkout_url": "..."}`.
- Session referenziert den Nutzer eindeutig (`client_reference_id=user.id`
  oder vorhandene `stripe_customer_id`), damit B4 zuordnen kann.
- Erfolg → `?checkout=success`, Abbruch → `?checkout=cancelled` (Ziel-URLs
  konfigurierbar für Staging/Prod).
- Price-IDs kommen aus Konfiguration, nicht hartcodiert — echte IDs existieren
  erst nach G1 (Zahlungskonto verifiziert); Test-Keys erlauben Entwicklung
  vorher.
- Kein Entitlement wird hier gesetzt — ausschließlich über B4. Ein
  manipulierter Client darf sich über diesen Endpunkt keinen Zugriff
  verschaffen.
- Test (gemockter Stripe-Client): korrekte Price-ID je Plan, `401` ohne
  Token, `400` bei unbekanntem `plan`.

### B4 — Stripe-Webhook-Verarbeitung
`POST /billing/webhook` in `app/api/v1/billing.py`.

- Signaturprüfung (`Stripe-Signature` gegen `STRIPE_WEBHOOK_SECRET`);
  ungültig → `400`, keine DB-Schreibung.
- Jede `event.id` wird einmalig persistiert (neue Tabelle, unique constraint,
  analog zum `client_id`-Muster bei `reviews`, `docs/04`) — erneut zugestellte
  Events wirken nicht doppelt.
- `checkout.session.completed` → setzt `stripe_customer_id`,
  `stripe_subscription_id`, `pro_until` = Periodenende.
- `invoice.payment_failed` → kein sofortiger Downgrade (Stripe retried selbst
  vor Ablauf der bezahlten Periode).
- `charge.dispute.created` (Rückbuchung) → sofortiger Entzug
  (`pro_until = jetzt`), unabhängig vom bezahlten Zeitraum.
- `customer.subscription.updated` mit `cancel_at_period_end=true` → setzt das
  gleichnamige Feld, `pro_until` bleibt unverändert (Grundlage für den
  Client-Zustand „gekündigt, läuft noch bis X" in F1).
- `customer.subscription.deleted` → `cancel_at_period_end` zurückgesetzt.
- Test je Event-Typ mit Beispiel-Payload, plus ein Test „gleiches Event
  zweimal zugestellt → keine doppelte Wirkung".

### B5 — Kündigung + Widerrufsfall (14 Tage)
`POST /billing/cancel` in `app/api/v1/billing.py`.

- Regulärer Fall: storniert bei Stripe mit `cancel_at_period_end=true`,
  Zugriff bleibt bis Periodenende (`mode: "period_end"` in der Antwort).
- Widerrufsfall: Kauf liegt ≤ 14 Tage zurück → sofortige Stornierung bei
  Stripe **und** volle Rückerstattung (Stripe Refund API), `pro_until = jetzt`
  (`mode: "immediate_refund"` in der Antwort).
- Kein aktives Abo → `409`.
- Test: Kauf vor 20 Tagen simuliert → `period_end`; Kauf vor 5 Tagen
  simuliert → `immediate_refund` inkl. gemocktem Refund-Aufruf.
- Diese Fristgrenze prüft nur die Frist-Logik im Code, nicht den Text der
  Widerrufsbelehrung selbst. Die rechtliche Prüfung des Texts entfällt
  bewusst (Entscheidung 25.09.2026, `docs/31-projektreview-sub254.md`
  Abschnitt 9.2) — nicht `SUB-85` (dort ging es nur um den Entwurf, nicht
  um eine rechtliche Prüfung).

### F1 — Pro-Gating im Flutter-Client
Betrifft `app/lib/state.dart`, betroffene Screens in `app/lib/pages/`.

- App-State bildet `proActive`, `proUntil`, `cancelAtPeriodEnd` aus
  `/auth/me` ab.
- Limit-Antworten (402/403 mit `upgrade_required`, siehe B2) zeigen einen
  Upgrade-Hinweis statt eines generischen Fehlers oder Absturzes.
- `cancelAtPeriodEnd == true` → persistenter Hinweis auf dem Dashboard
  „Abo gekündigt, Zugriff bis {proUntil}" (Format nach `app/lib/design/`).
- `proActive == false` ohne Kündigungszustand → Call-to-Action Richtung F2.
- Ist `paywall_enabled` serverseitig aus, liefert `/auth/me` für alle
  `proActive=true` — der Client braucht dafür **keine** Sonderlogik.
- Manueller Test/Screenshot: Free-, Pro- und Gekündigt-Zustand je einmal
  gezeigt.

### F2 — Checkout-Flow im Client
Neue Seite in `app/lib/pages/`.

- Zeigt beide Pläne (3,99 €/Monat, 39 €/Jahr) inkl. Preisgarantie-Hinweis.
- Ruft `POST /billing/checkout-session` auf, öffnet `checkout_url` extern
  (Web-Redirect, keine iOS-WebView-Sonderbehandlung nötig).
- Rückkehr `?checkout=success` → `/auth/me`-Refresh mit kurzem
  Polling/Retry (Webhook trifft asynchron zur Redirect-Rückkehr ein), zeigt
  Bestätigung sobald `proActive=true`.
- Rückkehr `?checkout=cancelled` → neutrale Meldung, kein Fehlerzustand.
- Manueller Test gegen Stripe-Testmodus auf Staging: Testkarten-Kauf →
  Pro-Zustand erscheint innerhalb weniger Sekunden.

### F3 — Kündigungs-UI
Neue Konto-/Einstellungsseite in `app/lib/pages/` (existiert noch nicht).

- Zeigt Abo-Status (Plan, `proUntil`, `cancelAtPeriodEnd`) und
  „Kündigen"-Button, nur sichtbar bei `proActive=true`.
- Bestätigungsdialog vor `POST /billing/cancel`, erklärt je nach
  Server-`mode` (siehe B5) „läuft bis Periodenende" vs. „sofortige
  Rückerstattung (Widerruf)".
- Nach Erfolg: State-Refresh ohne App-Neustart, zeigt den F1-Gekündigt-Banner.
- `409`-Fehlerfall → verständliche Meldung, kein technischer Fehlertext.
- Manueller Test/Screenshot: Dialog + Ergebniszustand auf Staging.

## 5. Notausgang, wenn die Zeit bis 23.09. nicht reicht

**Kein Teilausbau der Paywall.** `docs/18` Abschnitt 5 definiert G2 als
Alles-oder-nichts: entweder die volle Kette Kauf→Freischaltung→Kündigung läuft
auf Staging, oder die Paywall fällt komplett aus v1.0 (`paywall_enabled=false`
aus B1, alle Nutzer bekommen unbegrenzten Zugriff). Ein Zwischenzustand — z. B.
Kauf funktioniert, aber Kündigung/Widerruf nicht — wird **nicht** ausgeliefert:
Geld annehmen ohne verlässliche Rückabwicklung ist ein größeres Risiko
(rechtlich und für das Vertrauen) als gar keine Paywall.

Deshalb ist B1 bewusst so geschnitten, dass der Notausgang ein einzelner
Konfigurationsschalter ist, kein Code-Rollback: Das Lernprodukt (Registrierung,
Karteikarten, Schemata, Fälle, Struktur-Check) bleibt in jedem Fall lauffähig,
unabhängig vom Stand von B2–B5/F1–F3.

**Go/No-Go-Checkpoint: Do 17.09. Feierabend.** Bis dahin müssen B1 und B3
(Entitlement-Feld, Checkout-Session-Erstellung) auf Staging laufen. Stehen sie
nicht, ist absehbar, dass B4/B5 (Webhook, Kündigung) bis 23.09. nicht mehr
solide zu schaffen sind — dann sollte die Entscheidung für den Notausgang
spätestens am Wochenende (19.–20.09.) fallen, nicht erst am 23.09. selbst, weil
der 23.09. laut Tagesplan der Testtag ist, kein Pufferentwicklungstag.

## 6. Was bewusst nicht Teil dieser Zerlegung ist

- DSGVO-Export/Löschung → [SUB-84](/SUB/issues/SUB-84).
- Widerrufsbelehrung/AGB-Text selbst (juristischer Text, nicht Code) →
  [SUB-85](/SUB/issues/SUB-85).
- Welcher Rechtsträger das Stripe-Konto hält und ob am Tag 1 überhaupt
  kostenpflichtig gestartet wird → offene Interaktion an
  [SUB-39](/SUB/issues/SUB-39), blockiert nur die Produktivschaltung der
  echten Price-IDs, nicht die Entwicklung gegen Stripe-Testmodus.
