# Normtexte

Gesetzestexte fuer die Funktion "Antippen einer Normangabe zeigt den Wortlaut"
(`GET /v1/normen?zitat=...`, Service `backend/app/services/normen.py`).

- Quelle: <https://www.gesetze-im-internet.de/> (Bundesministerium der Justiz),
  XML-Download je Gesetz (`/<abk>/xml.zip`).
- Rechtsstatus: Gesetzestexte sind amtliche Werke und nach § 5 UrhG gemeinfrei.
- Abrufdatum: 2026-10-15 (Stand der Quelle: Builddatum 2026-09-26, siehe `index.json`).
- Erzeugt mit `backend/scripts/normtexte_import.py` (alle Gesetze) bzw.
  `--only bgb stgb` (einzelne). Das Skript schreibt nur Normtexte
  (`{"§ 433": {"titel", "text"}}`, Grundgesetz `"Art. 12"`, EGBGB
  `"Art. 246a § 1"`), keine Fussnoten oder Metadaten. Absaetze stehen als
  `(1) ...`-Zeilen, Aufzaehlungen eine pro Zeile.
- Nicht enthalten: Landesrecht und EU-Recht (AEUV/EUV liegen nicht bei gii).
  Die API antwortet dort mit 404 und einem Link auf gesetze-im-internet.de.
- Aktualisieren: Skript erneut ausfuehren, JSON-Dateien und `index.json`
  committen. Die Gesetze aendern sich; der Abruf ist keine Rechtsberatung und
  ersetzt nicht die amtliche Fassung.
