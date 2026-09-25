# Schriftart: DejaVu Sans

Quelle: DejaVu-Fonts-Projekt (basierend auf Bitstream Vera), gemeinfrei bzw.
frei redistribuierbar unter der Bitstream-Vera-Lizenz. Als App-Standardschrift
eingebunden, damit Flutter Web nicht von Googles Font-CDN
(fonts.gstatic.com) abhaengt - siehe docs/07-spike-web-editor.md,
Nebenbefund 2, und docs/01-produktvision.md ("Offline ist Pflicht, nicht
Komfort").

Ein vollstaendiger Austausch gegen eine Marken-/Designschrift bleibt eine
spaetere, bewusste Entscheidung (M5, Store-Release). Die Wortmarke und der
oeffentliche Header/Login (`displayLarge`/`displayMedium`,
`SubsumoTypography`) bleiben bei `Subsumo`/DejaVu Sans - siehe unten fuer die
eng begrenzte Ausnahme.

# Schriftart: Fraunces

Quelle: [The Fraunces Project Authors](https://github.com/undercasetype/Fraunces)
ueber Google Fonts (https://fonts.google.com/specimen/Fraunces), lizenziert
unter der SIL Open Font License, Version 1.1 (voller Lizenztext:
https://openfontlicense.org). Als Variable-Font-Datei
(`Fraunces-Variable.ttf`, Achsen `SOFT`/`WONK`/`opsz`/`wght`) selbst
gehostet, aus demselben Grund wie bei `Subsumo`/DejaVu Sans oben - keine
Laufzeit-Abhaengigkeit von `fonts.gstatic.com`.

**Scope, bewusst eng** (SUB-227/SUB-228, UI-Relaunch-Brief): ausschliesslich
die `heroLarge`/`heroSmall`-Rolle in `design/tokens/typography.dart`, nur
fuer den H1 auf dem Landing-/Preisseiten-Hero (`pages/public/`).
`displayLarge`/`displayMedium` (Wortmarke, oeffentlicher Header, Login,
SUB-159) und der gesamte Fliesstext (`bodyLarge/Medium/Small`,
`titleLarge/Medium/Small`) bleiben unveraendert bei `Subsumo`/DejaVu Sans -
kein Bruch mit der auf SUB-159 freigegebenen CI, Fraunces kommt als dritte,
noch enger begrenzte Rolle dazu, ersetzt nichts.
