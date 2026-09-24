# Freischaltcode-/Redeem-Mechanismus — Spezifikation

> Spezifikation zu [SUB-262](/SUB/issues/SUB-262), aus dem in
> `docs/15-go-to-market.md` Abschnitt 1.1 benannten Befund: Die
> Fachschafts-Beta (kostenloser Pro-Zugang für sechs Monate gegen
> Verlinkung/Feedback) braucht einen Freischaltcode-Mechanismus, den es im
> Repo noch nicht gibt. **Kein Release-Blocker** — bis zur Umsetzung bleibt
> der in docs/15 §1.1 dokumentierte manuelle Ersatz (Pro-Status per
> E-Mail-Adresse) in Kraft. Diese Spezifikation ist die Zerlegung für die
> spätere Umsetzung, nicht die Umsetzung selbst.

## 1. Ausgangslage im Code

`backend/app/models.py` hat bereits das Entitlement-Feld, das gebraucht wird:
`User.pro_until` (Datetime, nullable) plus `User.has_pro_access()` (rein
zeitbasiert, `docs/20-release-g2-bezahlstrecke.md` B1). Ein Freischaltcode
muss also nur `pro_until` verlängern — kein neues Entitlement-System, keine
Stripe-Änderung (Ticket-Vorgabe, da kostenlos vergeben). `stripe_customer_id`/
`stripe_subscription_id` bleiben unberührt; `has_pro_access()` prüft
ausschließlich `pro_until` und funktioniert für Redeem-Zugänge unverändert.

## 2. Datenmodell (zwei neue Tabellen, `backend/app/models.py`)

**`redeem_codes`**

| Feld | Typ | Zweck |
|---|---|---|
| `id` | PK | — |
| `code` | `String`, unique, index | Eingabewert, z. B. `FACHSCHAFT-LMU-2026`; case-insensitiv normalisiert (upper) vor Vergleich und Speicherung |
| `campaign_slug` | `String` | Attribution, z. B. `fachschaft-lmu` — beantwortet die Abnahme „Einlösung ist einer Kampagnenquelle zuordenbar" und liefert direkt die Messgröße „aktivierte Freischaltcodes je Kooperation" aus docs/15 §4 |
| `pro_duration_days` | `Integer`, default 180 | Sechs Monate; konfigurierbar für andere Aktionen, nicht hartkodiert |
| `max_redemptions` | `Integer`, nullable | `NULL` = unbegrenzt viele verschiedene Nutzer:innen (Fachschafts-Fall: ein Code für alle Mitglieder); gesetzt = Obergrenze an Gesamteinlösungen (Einzel-Invite-Fall) |
| `expires_at` | `DateTime`, nullable | Verfallsdatum des Codes selbst (getrennt vom gewährten `pro_until`) |
| `active` | `Boolean`, default true | Manuelles Sperren eines kompromittierten Codes, ohne Historie zu löschen |
| `created_at` | `DateTime` | — |

**`redeem_code_redemptions`**

| Feld | Typ | Zweck |
|---|---|---|
| `id` | PK | — |
| `redeem_code_id` | FK → `redeem_codes.id` | — |
| `user_id` | FK → `users.id` | — |
| `redeemed_at` | `DateTime` | — |
| `UniqueConstraint(redeem_code_id, user_id)` | — | Erzwingt „pro Nutzer:in einmalig" strukturell, unabhängig von `max_redemptions` — verhindert, dass eine einzelne Person denselben Code mehrfach einlöst, um `pro_until` künstlich zu verlängern |

Damit deckt das Modell beide in der Abnahme genannten Fälle ab: „einmalig"
(`max_redemptions = 1`, ein Code für eine Person) und „pro Nutzer:in"
(`max_redemptions = NULL`, ein Code für alle Mitglieder einer Fachschaft,
aber jede Person nur einmal).

## 3. Endpoint

`POST /api/v1/account/redeem`, Auth erforderlich (`CurrentUser`, wie
`account.py`/`billing.py`), Body `{code: str}`.

Ablauf:

1. Code normalisieren (trim, uppercase) und nachschlagen. Kein Treffer oder
   `active = false` → 404, keine Unterscheidung in der Fehlermeldung
   (verhindert Code-Enumeration).
2. `expires_at` geprüft, falls gesetzt → 410 bei Ablauf.
3. Falls `max_redemptions` gesetzt: Gesamtzahl vorhandener Redemptions
   gegen das Limit prüfen → 410 bei Erschöpfung.
4. Existierende Redemption für `(code, user)` prüfen → 409, falls die
   Person diesen Code bereits eingelöst hat.
5. `user.pro_until = max(user.pro_until or now, now) + timedelta(days=pro_duration_days)`
   — verlängert einen bestehenden Zugang (auch einen zahlenden Stripe-Zugang),
   statt ihn zu verkürzen, falls `pro_until` weiter in der Zukunft liegt als
   `now`.
6. Redemption-Zeile einfügen, committen, `pro_until` zurückgeben.

Kein Stripe-Aufruf an keiner Stelle — Ticket-Vorgabe eingehalten.

**Offener Punkt, nicht Teil dieser Spezifikation:** `docs/26-projektreview-sub254.md`
Abschnitt 3.2 hält fest, dass aktuell kein Endpoint ein Rate-Limit hat. Ein
Redeem-Endpoint ist ein Brute-Force-Ziel (Codes erraten) und sollte an
derselben Stelle mitgelöst werden wie der generelle Rate-Limit-Befund, nicht
mit einer Einzellösung hier vorgezogen werden.

## 4. Code-Erstellung (kein UI nötig)

Bei der geplanten Größenordnung (2–5 Fachschafts-Kooperationen, docs/15 §1.1)
lohnt keine Admin-Oberfläche. Ein einzeiliges Management-Skript
(`backend/scripts/` oder ein CLI-Kommando nach demselben Muster wie
bestehende Skripte) legt eine Zeile in `redeem_codes` an. Codes ausschließlich
serverseitig/intern erzeugt, nie über einen Client-Endpoint — analog zur
bestehenden Regel „Entitlement nie per Client-Eingabe" (`models.py` Kommentar
über `stripe_customer_id`).

## 5. Frontend

Ein Eingabefeld im Account-Bereich (Flutter, `app/lib/pages/`, analog zu den
bestehenden Account-Screens), das `POST /account/redeem` aufruft und
Erfolg (neues `pro_until`-Datum) oder Fehler (ungültig/abgelaufen/bereits
eingelöst/ausgeschöpft) anzeigt. Kein neuer Checkout-Flow, kein
Zahlungs-UI.

## 6. Zerlegung

| ID | Titel | Verantwortlich | Voraussetzung |
|---|---|---|---|
| C1 | Datenmodell `redeem_codes`/`redeem_code_redemptions` + Migration | Backend-Developer | — |
| C2 | Redeem-Endpoint mit Validierung (Abschnitt 3) | Backend-Developer | C1 |
| C3 | Management-Skript zur Code-Erstellung | Backend-Developer | C1 |
| C4 | Redeem-UI im Account-Bereich | Frontend-Developer | C2 |

Build-Reihenfolge: C1 zuerst, C2/C3 parallel danach, C4 zuletzt.

## 7. Abgrenzung

- **Nicht Teil dieser Spezifikation:** der in docs/15 §4 genannte
  Herkunfts-Parameter (`?quelle=...`) für Warteliste/Registrierung — das ist
  eine eigene, kleinere Abhängigkeit für einen anderen Kanal (organische
  Anmeldung, nicht Fachschafts-Redeem) und liefert keine Voraussetzung für
  dieses Feature. Die Kampagnenattribution für Freischaltcodes ist über
  `campaign_slug` am Code selbst gelöst, ohne diese Abhängigkeit zu brauchen.
- **Nicht Teil dieser Spezifikation:** Stripe-Checkout-Änderungen (laut
  Ticket nicht nötig, da kostenlos vergeben).
- **Nicht Teil dieser Spezifikation:** Rate-Limiting des neuen Endpoints
  (Abschnitt 3, offener Punkt) — gehört zum generellen Rate-Limit-Befund aus
  docs/26 §3.2.
