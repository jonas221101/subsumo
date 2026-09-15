"""Deterministisches Normzitat-Gate.

Ersetzt keinen vollstaendigen Normindex (M2, docs/03-roadmap.md: Import von
gesetze-im-internet.de). Bis der steht, faengt dieses Gate ab, was einem
Collector-Modell besonders leicht unterlaeuft: ein Gesetzeskuerzel, das es
nicht gibt, oder eine Paragraphen-/Artikelnummer ausserhalb des Gesetzes.
Siehe docs/08-ki-redaktion.md, Abschnitt "Was der Reviewer nicht leistet".

Wie das Struktur-Gate (``app.services.content.load_content``) laeuft auch
dieses Gate deterministisch statt als LLM-Aufruf - siehe docs/08-ki-redaktion.md,
Abschnitt "Warum die Formatpruefung nicht dem LLM ueberlassen wird": ein
Sprachmodell darum zu bitten, ein Zitat zu pruefen, ist ein Bitten, kein
Erzwingen. Die Positivliste unten ist bewusst kuratiert (nicht vom Modell
vorgeschlagen) und deckt nur die Gesetze ab, die im bisherigen Content
tatsaechlich vorkommen (siehe ``content/``) - eine unbekannte, aber echte
Abkuerzung wird hier als Fehler gemeldet und braucht eine Erweiterung dieser
Liste per PR, kein stilles Durchwinken.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

# Kuratierte Positivliste: Gesetzeskuerzel -> Zitierweise + plausibler
# Paragraphen-/Artikelbereich. Die Obergrenzen sind grosszuegig (letzte
# bekannte Norm, keine exakte Buchpruefung) - Ziel ist, offensichtlich
# erfundene oder falsch zugeordnete Zitate abzufangen, nicht eine exakte
# Normdatenbank zu ersetzen.


@dataclass(frozen=True)
class Gesetz:
    marker: str  # "§" (Paragraph) oder "Art." (Artikel, z. B. GG)
    max_nummer: int
    min_nummer: int = 1


GESETZE: dict[str, Gesetz] = {
    "BGB": Gesetz(marker="§", max_nummer=2385),
    "StGB": Gesetz(marker="§", max_nummer=358),
    "GG": Gesetz(marker="Art.", max_nummer=146),
    "VwGO": Gesetz(marker="§", max_nummer=195),
    "VwVfG": Gesetz(marker="§", max_nummer=103),
    "StPO": Gesetz(marker="§", max_nummer=477),
    "BVerfGG": Gesetz(marker="§", max_nummer=105),
}

_NUMMER = r"\d+[a-z]?"
_NUMMER_BEREICH = rf"{_NUMMER}(?:-{_NUMMER})?"
# Die Paragraphen-/Artikelnummer(n) vor den Zusatzangaben - ein einzelner
# Bereich ("166-181") oder mehrere kommagetrennte Zitate in einem
# zusammengefassten Zitat ("305c, 307").
_HAUPT_NUMMERN_RE = re.compile(
    rf"^(?P<nummern>{_NUMMER_BEREICH}(?:,\s*{_NUMMER_BEREICH})*)(?:\s+(?P<zusatz>.+))?$"
)

# Roemische Ziffer (1-3999, Standardschreibweise) - fuer Absatzangaben wie
# "Abs. I" statt "Abs. 1", beides gebraeuchlich in Gesetzestexten.
_ROEMISCH = r"(?=[IVXLCDM])M{0,4}(?:CM|CD|D?C{0,3})(?:XC|XL|L?X{0,3})(?:IX|IV|V?I{0,3})"
_ABS_WERT = rf"(?:{_NUMMER}|{_ROEMISCH})(?:,\s*(?:{_NUMMER}|{_ROEMISCH}))*"
_ANDERE_WERT = rf"{_NUMMER}(?:,\s*{_NUMMER})*"
# Zusatzangaben treten immer als Paar aus Schluesselwort + mind. einem Wert
# auf (mehrere durch Komma getrennt moeglich), z. B. "Abs. 1, 2 Var. 1". Ein
# freistehendes "Abs." ohne Wert oder ein Wert ohne Schluesselwort davor ist
# kein gueltiges Zitatformat. "Satz" ist die ausgeschriebene Form von "S." -
# beide Schreibweisen kommen im Content vor.
_ZUSATZ_TEIL = rf"(?:Abs\. {_ABS_WERT}|(?:Nr\.|Var\.|Alt\.|S\.|Satz) {_ANDERE_WERT})"
_ZUSATZ_RE = re.compile(rf"^{_ZUSATZ_TEIL}(?: {_ZUSATZ_TEIL})*$")


@dataclass
class NormPruefung:
    zitat: str
    ok: bool
    grund: str = ""


def pruefe_zitat(zitat: str) -> NormPruefung:
    """Prueft ein einzelnes Zitat wie '§ 242 StGB' oder 'Art. 12 Abs. 1 GG'.

    Drei Dinge werden gecheckt: bekanntes Gesetzeskuerzel, plausible
    Paragraphen-/Artikelnummer, und dass die Zitierweise (§ vs. Art.) zum
    Gesetz passt. Was dazwischen steht (Abs., S./Satz, Nr., Var., Zahlen
    arabisch oder bei Abs. auch roemisch, kommagetrennte Mehrfachzitate) wird
    nur grob auf erwartete Bestandteile geprueft, nicht inhaltlich verifiziert.
    """
    text = (zitat or "").strip()
    tokens = text.split()
    if len(tokens) < 3:
        return NormPruefung(text, False, f"Zitat zu kurz, erwartet z. B. '§ 242 StGB': '{text}'")

    marker, *rest = tokens
    kuerzel = rest.pop()

    if marker not in ("§", "§§", "Art."):
        return NormPruefung(
            text,
            False,
            f"Unbekanntes Zitatformat '{marker}' in '{text}' - erwartet '§', '§§' oder 'Art.'",
        )

    gesetz = GESETZE.get(kuerzel)
    if gesetz is None:
        return NormPruefung(
            text,
            False,
            f"Unbekanntes Gesetzeskuerzel '{kuerzel}' in '{text}' - nicht in der Positivliste",
        )

    if marker == "Art." and gesetz.marker != "Art.":
        return NormPruefung(
            text, False, f"'{kuerzel}' wird mit '§' zitiert, nicht 'Art.' ('{text}')"
        )
    if marker in ("§", "§§") and gesetz.marker != "§":
        return NormPruefung(
            text, False, f"'{kuerzel}' wird mit 'Art.' zitiert, nicht '{marker}' ('{text}')"
        )

    haupt_match = _HAUPT_NUMMERN_RE.match(" ".join(rest))
    if not haupt_match:
        return NormPruefung(
            text, False, f"Fehlende oder ungueltige Paragraphen-/Artikelnummer in '{text}'"
        )

    for nummer_teil in haupt_match.group("nummern").split(","):
        nummer_teil = nummer_teil.strip()
        for teil in nummer_teil.split("-"):
            nummer = int(re.match(r"\d+", teil).group())
            if not (gesetz.min_nummer <= nummer <= gesetz.max_nummer):
                return NormPruefung(
                    text,
                    False,
                    f"{kuerzel} {teil}: ausserhalb des bekannten Bereichs "
                    f"({gesetz.min_nummer}-{gesetz.max_nummer}) in '{text}'",
                )

    zusatz = haupt_match.group("zusatz") or ""
    if zusatz and not _ZUSATZ_RE.match(zusatz):
        return NormPruefung(text, False, f"Unerwartetes Element '{zusatz}' in Zitat '{text}'")

    return NormPruefung(text, True)


def _iter_norm_zitate(draft: dict):
    for card in draft.get("cards") or []:
        for zitat in card.get("norms") or []:
            yield zitat, f"cards[{card.get('slug', '?')}]"
    for schema in draft.get("schemata") or []:
        for zitat in schema.get("norms") or []:
            yield zitat, f"schemata[{schema.get('slug', '?')}]"
    for fall in draft.get("faelle") or []:
        pruefpunkte = (fall.get("expectation") or {}).get("pruefpunkte") or []
        for i, punkt in enumerate(pruefpunkte):
            for zitat in punkt.get("norms") or []:
                yield zitat, f"faelle[{fall.get('slug', '?')}].pruefpunkte[{i}]"


def check_norms(draft: dict) -> list[str]:
    """Prueft alle 'norms:'-Zitate eines Entwurfs. Leere Liste = alles ok."""
    fehler: list[str] = []
    for zitat, wo in _iter_norm_zitate(draft):
        pruefung = pruefe_zitat(zitat)
        if not pruefung.ok:
            fehler.append(f"{wo}: {pruefung.grund}")
    return fehler
