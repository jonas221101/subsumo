# Cookie- und Local-Storage-Hinweis (Entwurf)

> Entwurf zur Prüfung, keine Rechtsberatung.

## Was Subsumo tatsächlich speichert

Subsumo ist als Flutter-Anwendung gebaut, die als Web-App
(`app.subsumo.de`) und Android-App läuft. Die Anmeldung erfolgt über ein
Zugangs-Token (JWT), das der Server ausstellt und das der Client bei jeder
Anfrage im `Authorization`-Header mitschickt (`app/lib/api.dart`). Dieses
Token wird **lokal auf dem Gerät** über die Bibliothek `shared_preferences`
gespeichert (`app/lib/state.dart`) — im Browser technisch als lokaler
Speicher (vergleichbar mit einem Cookie in seiner Funktion, aber kein
serverseitig gesetztes Cookie).

Zusätzlich speichert die Anwendung lokal einen Zwischenspeicher für fällige
Karten und noch nicht synchronisierte Lernereignisse (Offline-Fähigkeit),
ebenfalls über `shared_preferences`.

## Warum das keinen Cookie-Consent-Banner auslöst

Diese Speicherung ist **technisch notwendig**, um die Kernfunktion der
Anwendung (angemeldet bleiben, offline weiterlernen und später synchron
abgleichen) überhaupt zu ermöglichen. Nach § 25 Abs. 2 Nr. 2
Telekommunikation-Telemedien-Datenschutz-Gesetz (TTDSG) ist für unbedingt
erforderliche Speicherung **keine Einwilligung** erforderlich.

**Zum Zeitpunkt dieses Entwurfs enthält der Code kein Tracking, keine
Analyse-Cookies und keine Werbe-Cookies.** Eine Prüfung des Repositorys
findet keine Integration von Analytics-, Tracking- oder
Werbe-Bibliotheken. Ein Consent-Banner ist deshalb für v1.0 **nicht**
erforderlich.

## Was sich ändert, sobald Analytics/Crash-Reporting dazukommt

`docs/17-release-readiness.md` Abschnitt 5 führt „Crash-/Analytics-Telemetrie
(opt-in)" als offenen, noch nicht gebauten Punkt — ausdrücklich als
**Opt-in** geplant, nicht als nachträglicher Opt-out. Sobald ein solcher
Dienst eingeführt wird:

1. Dieser Hinweis ist um die konkreten Cookies/Speicherarten, ihre
   Laufzeit und den Anbieter zu ergänzen.
2. Ein Einwilligungsdialog **vor** dem ersten Versand ist verpflichtend
   (§ 25 Abs. 1 TTDSG), nicht nachträglich einholbar.
3. Die Datenschutzerklärung (`03-datenschutzerklaerung.md` Abschnitt 4) ist
   um den neuen Empfänger zu ergänzen.

Dieser Hinweis darf **nicht** unverändert weiterverwendet werden, sobald ein
Analytics-/Crash-Reporting-Dienst live geht — er würde dann eine falsche
Tatsache behaupten.

---

**Quellen/Begründung:** Speichermechanismus verifiziert im Code
(`app/lib/api.dart`: Bearer-Token im Header statt Cookie; `app/lib/state.dart`:
`shared_preferences` für Token und Offline-Zwischenspeicher;
`app/pubspec.yaml`: keine Analytics-/Tracking-Abhängigkeit gelistet);
Einwilligungspflicht nach § 25 TTDSG; geplanter Opt-in-Telemetrie-Punkt aus
`docs/17-release-readiness.md` Abschnitt 5. **Menschliche Rechtsprüfung
nötig:** Diesen Hinweis erneut prüfen, sobald Analytics/Crash-Reporting oder
ein Werbe-Kanal (z. B. Tracking-Pixel auf einer Landing-Page außerhalb der
App) hinzukommt — dieser Text deckt nur den aktuellen Code-Stand ab.
