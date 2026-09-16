# Widerrufsbelehrung (Entwurf)

> Entwurf zur Prüfung, keine Rechtsberatung. Enthält eine noch offene
> **Produktentscheidung** — siehe Abschnitt „Offene Entscheidung" am Ende.

## Widerrufsrecht

Verbraucher:innen haben das Recht, binnen vierzehn Tagen ohne Angabe von
Gründen diesen Vertrag zu widerrufen.

Die Widerrufsfrist beträgt vierzehn Tage ab dem Tag des Vertragsschlusses.

Um das Widerrufsrecht auszuüben, muss die widerrufende Person
`[Platzhalter: Anbieter aus 01-impressum.md, Anschrift, E-Mail]` mittels
einer eindeutigen Erklärung (z. B. per E-Mail oder über eine
Widerrufsfunktion in der Anwendung) über den Entschluss, diesen Vertrag zu
widerrufen, informieren. Zur Wahrung der Widerrufsfrist genügt es, die
Mitteilung über die Ausübung des Widerrufsrechts vor Ablauf der
Widerrufsfrist abzusenden.

## Folgen des Widerrufs

Im Falle eines wirksamen Widerrufs werden alle Zahlungen, die von der
widerrufenden Person geleistet wurden, unverzüglich und spätestens binnen
vierzehn Tagen ab dem Tag zurückgezahlt, an dem die Mitteilung über den
Widerruf eingegangen ist. Für diese Rückzahlung wird dasselbe Zahlungsmittel
verwendet, das bei der ursprünglichen Zahlung eingesetzt wurde, sofern nicht
ausdrücklich etwas anderes vereinbart wurde.

## Vorzeitiges Erlöschen des Widerrufsrechts bei digitalen Produkten

Das Widerrufsrecht erlischt vorzeitig bei einem Vertrag über die
Bereitstellung digitaler Inhalte oder digitaler Dienstleistungen (hier: der
Pro-Zugang zur Anwendung), wenn der Anbieter mit der Ausführung des Vertrags
begonnen hat, nachdem die nutzende Person

1. ausdrücklich zugestimmt hat, dass der Anbieter vor Ablauf der
   Widerrufsfrist mit der Ausführung des Vertrags beginnt, **und**
2. ihre Kenntnis davon bestätigt hat, dass sie durch ihre Zustimmung mit
   Beginn der Ausführung ihr Widerrufsrecht verliert

(§ 356 Abs. 5 i. V. m. §§ 327 ff. BGB — Verträge über digitale Produkte).

**Konkret für Subsumo:** Wird der Pro-Tarif gebucht und die nutzende Person
stimmt beim Checkout ausdrücklich zu, dass der sofortige Zugriff auf
Pro-Inhalte vor Ablauf der 14-tägigen Widerrufsfrist beginnt, erlischt das
Widerrufsrecht mit vollständiger Erbringung der Leistung — bei einem
Abonnement praktisch mit dem ersten Zugriff auf eine zuvor gesperrte
Pro-Funktion nach Zahlungseingang.

## Muster-Widerrufsformular

*(Wenn Sie den Vertrag widerrufen wollen, füllen Sie bitte dieses Formular
aus und senden Sie es zurück.)*

An `[Platzhalter: Anbieter, Anschrift, E-Mail]`:

> Hiermit widerrufe(n) ich/wir den von mir/uns abgeschlossenen Vertrag über
> den Zugang zur Lernplattform Subsumo (Pro-Tarif).
>
> - Bestellt am: _______________
> - Name der/des Verbrauchers/Verbraucherin(nen): _______________
> - Anschrift der/des Verbrauchers/Verbraucherin(nen): _______________
> - Unterschrift (nur bei Mitteilung auf Papier): _______________
> - Datum: _______________

---

## Offene Entscheidung — betrifft den Checkout-Flow (SUB-83)

`docs/17-release-readiness.md` Abschnitt 1 stellt diese Frage bislang offen:
Räumt Subsumo beim Kauf ein volles 14-Tage-Widerrufsfenster **ohne** Nutzung
der Pro-Funktionen ein, oder verzichtet die nutzende Person ausdrücklich auf
das Widerrufsrecht im Austausch gegen sofortigen Zugriff (Abschnitt oben)?

**Empfehlung dieses Entwurfs:** Die Zustimmungs-Variante (sofortiger Zugriff,
Widerrufsrecht erlischt) ist branchenüblich bei SaaS-Produkten mit
sofortigem digitalem Nutzen und vermeidet eine 14-tägige „kostenlose Pro-
Phase" ohne Zahlungsbindung. Das setzt aber voraus, dass der Checkout-Flow
aus SUB-83 tatsächlich eine **granulare, ausdrückliche** Checkbox enthält
(kein vorangehakter Haken, siehe § 312j Abs. 3 BGB zur „Button-Lösung" und
Trennung von der allgemeinen AGB-Zustimmung), etwa:

> „Ich stimme ausdrücklich zu, dass Subsumo vor Ablauf der Widerrufsfrist mit
> der Bereitstellung des Pro-Zugangs beginnt. Mir ist bekannt, dass ich
> dadurch mein Widerrufsrecht verliere, sobald die Leistung vollständig
> erbracht ist."

**Diese Empfehlung ist eine Produktentscheidung, keine reine Rechtsfrage** —
sie muss vor oder spätestens mit SUB-83 final getroffen und im Checkout-Flow
umgesetzt werden. Ohne diese Checkbox gilt das volle 14-Tage-Widerrufsrecht
unabhängig vom Text hier.

---

**Quellen/Begründung:** Struktur nach dem gesetzlichen Muster für die
Widerrufsbelehrung (Anlage 1 zu Art. 246a § 1 Abs. 2 und 3 EGBGB) sowie
§ 356 Abs. 5, §§ 327 ff. BGB (Verträge über digitale Produkte, Regelung zum
vorzeitigen Erlöschen bei digitalen Inhalten/Dienstleistungen); offene
Entscheidung wörtlich aus `docs/17-release-readiness.md` Abschnitt 1
übernommen, dort als „Frage" markiert und nicht beantwortet.
**Menschliche Rechtsprüfung nötig:** Formulierung der Zustimmungs-Checkbox
anwaltlich absichern, Entscheidung mit dem Checkout-Flow aus SUB-83
abstimmen, bevor dieser Text produktiv geht.
