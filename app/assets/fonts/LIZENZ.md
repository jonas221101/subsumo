# Schriftart: Source Sans 3 (Familienname im Code: "Subsumo")

Quelle: Adobe, [adobe-fonts/source-sans](https://github.com/adobe-fonts/source-sans),
Release 3.052R, lizenziert unter der SIL Open Font License, Version 1.1
(voller Lizenztext: https://openfontlicense.org bzw. LICENSE.md im
Release-Archiv). Eingebunden sind die statischen Schnitte Regular, Italic,
Semibold (600) und Bold (700). Selbst gehostet, damit Flutter Web nicht von
Googles Font-CDN (fonts.gstatic.com) abhaengt - siehe
docs/07-spike-web-editor.md, Nebenbefund 2, und docs/01-produktvision.md
("Offline ist Pflicht, nicht Komfort").

Ersetzt DejaVu Sans (Relaunch "Kanzlei-Editorial", docs/11 Abschnitt 9):
Source Sans 3 ist eine humanistische Grotesk mit vollstaendigem
Latin-Extended-Umfang (Umlaute, ß, typografische Anfuehrungszeichen) und
tritt neben der Serife Fraunces ruhig zurueck. Fliesstext, UI-Beschriftung,
Eyebrow und Wortmarke (`displayLarge`/`displayMedium`) laufen in dieser
Familie.

# Schriftart: Fraunces

Quelle: [The Fraunces Project Authors](https://github.com/undercasetype/Fraunces)
ueber Google Fonts (https://fonts.google.com/specimen/Fraunces), lizenziert
unter der SIL Open Font License, Version 1.1 (voller Lizenztext:
https://openfontlicense.org). Als Variable-Font-Datei
(`Fraunces-Variable.ttf`, Achsen `SOFT`/`WONK`/`opsz`/`wght`) selbst
gehostet, aus demselben Grund wie bei `Subsumo`/DejaVu Sans oben - keine
Laufzeit-Abhaengigkeit von `fonts.gstatic.com`.

**Scope** (seit dem Relaunch "Kanzlei-Editorial", docs/11 Abschnitt 9):
`heroLarge`/`heroSmall` (Landing-/Preisseiten-Hero) sowie die App-Rollen
`headingLarge`/`headingMedium`/`headingSmall`, `numeral` und `reading`
(Seitentitel, Blocktitel, Kennzahlen, Kartenfragen) und ueber das Theme die
Material-Rollen `headlineMedium`/`headlineSmall`. Fliesstext, UI-Labels und
die Wortmarke bleiben bei Source Sans 3.
