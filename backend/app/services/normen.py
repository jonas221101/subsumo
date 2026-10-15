"""Gesetzestexte zu Normzitaten (``content/normtexte/<abk>.json``).

Die Daten stammen von gesetze-im-internet.de (siehe ``content/normtexte/README.md``)
und werden pro Gesetz erst beim ersten Zugriff geladen und im Prozess gehalten.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from app.config import get_settings

GII_BASE = "https://www.gesetze-im-internet.de/"

# Zitier-Kuerzel (klein) -> (Dateikuerzel/URL-Pfad bei gii, Anzeigename)
GESETZE: dict[str, tuple[str, str]] = {
    "bgb": ("bgb", "BGB"),
    "stgb": ("stgb", "StGB"),
    "gg": ("gg", "GG"),
    "stpo": ("stpo", "StPO"),
    "zpo": ("zpo", "ZPO"),
    "vwgo": ("vwgo", "VwGO"),
    "vwvfg": ("vwvfg", "VwVfG"),
    "hgb": ("hgb", "HGB"),
    "gvg": ("gvg", "GVG"),
    "bverfgg": ("bverfgg", "BVerfGG"),
    "egbgb": ("bgbeg", "EGBGB"),
    "gmbhg": ("gmbhg", "GmbHG"),
    "prodhaftg": ("prodhaftg", "ProdHaftG"),
    "stvg": ("stvg", "StVG"),
    "kschg": ("kschg", "KSchG"),
    "inso": ("inso", "InsO"),
    "baugb": ("bbaug", "BauGB"),
    "baunvo": ("baunvo", "BauNVO"),
    "versammlg": ("versammlg", "VersammlG"),
    "versg": ("versammlg", "VersammlG"),
    "vwvg": ("vwvg", "VwVG"),
    "kcang": ("kcang", "KCanG"),
    "aktg": ("aktg", "AktG"),
    "owig": ("owig_1968", "OWiG"),
}

_ROEMISCH = {"I": "1", "II": "2", "III": "3", "IV": "4", "V": "5", "VI": "6", "VII": "7"}

_NORM_RE = re.compile(
    r"(?P<art>§§?|Art\.?)\s*(?P<num>\d+[a-z]?)"
    # EGBGB: "Art. 246a § 1 Abs. 2"
    r"(?:\s*§\s*(?P<num2>\d+[a-z]?))?"
    r"(?:\s*(?:Abs\.|Absatz)\s*(?P<abs>\d+[a-z]?)|\s+(?P<rom>[IVX]{1,4})\b(?!\.))?"
    r"(?:\s*(?:S\.|Satz)\s*(?P<satz>\d+)|\s+(?P<satz2>\d)\b)?",
    re.IGNORECASE,
)
_WORT_RE = re.compile(r"[A-Za-zÄÖÜäöü]+")


@dataclass(frozen=True)
class Zitat:
    """Erste Norm eines Zitats, zerlegt."""

    art: str  # "§" oder "Art."
    nummer: str  # "433", "246a"
    nummer2: str  # nur EGBGB-Form "Art. 246a § 1"
    absatz: str
    satz: str
    gesetz_key: str  # Schluessel in GESETZE oder "" falls kein bekanntes Gesetz
    gesetz_text: str  # im Zitat genanntes Gesetz (oder "")

    @property
    def norm_key(self) -> str:
        key = f"{self.art} {self.nummer}"
        return f"{key} § {self.nummer2}" if self.nummer2 else key


def parse_zitat(zitat: str) -> Zitat | None:
    """Zerlegt ``"§§ 280 Abs. 1, 283 BGB"`` o. ae. in die erste Norm samt Gesetz.

    Das Gesetz ist das letzte bekannte Kuerzel im Zitat; ``None`` nur, wenn gar
    keine Normnummer erkennbar ist.
    """
    zitat = re.sub(r"\s+", " ", zitat).strip()
    m = _NORM_RE.search(zitat)
    if not m:
        return None
    art = "Art." if m.group("art").lower().startswith("art") else "§"
    absatz = m.group("abs") or _ROEMISCH.get((m.group("rom") or "").upper(), "")
    satz = m.group("satz") or m.group("satz2") or ""
    gesetz_key = ""
    gesetz_text = ""
    for wort in _WORT_RE.findall(zitat[m.end() :] or ""):
        if wort.lower() in GESETZE:
            gesetz_key, gesetz_text = wort.lower(), wort
    if not gesetz_key:  # Gesetz steht ausnahmsweise vor der Norm ("GG Art. 12")
        for wort in _WORT_RE.findall(zitat[: m.start()]):
            if wort.lower() in GESETZE:
                gesetz_key, gesetz_text = wort.lower(), wort
    if not gesetz_key:
        # letztes grossgeschriebenes Kuerzel merken, z. B. "LStVG" (Landesrecht)
        tail = [w for w in _WORT_RE.findall(zitat[m.end() :]) if w[:1].isupper() and len(w) > 1]
        gesetz_text = tail[-1] if tail else ""
    return Zitat(
        art=art,
        nummer=m.group("num").lower(),
        nummer2=(m.group("num2") or "").lower(),
        absatz=absatz,
        satz=satz,
        gesetz_key=gesetz_key,
        gesetz_text=gesetz_text,
    )


def normtexte_dir() -> Path:
    return get_settings().content_dir / "normtexte"


@lru_cache(maxsize=64)
def _load(dirpath: str, datei: str) -> dict[str, dict[str, str]]:
    path = Path(dirpath) / f"{datei}.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def clear_cache() -> None:
    _load.cache_clear()


def quelle_url(z: Zitat | None) -> str:
    """Direktlink zur Norm bei gii, sonst Gesetzesseite bzw. Startseite."""
    if z is None or not z.gesetz_key:
        return GII_BASE
    datei = GESETZE[z.gesetz_key][0]
    if z.nummer2:
        return f"{GII_BASE}{datei}/"
    if z.art == "§":
        return f"{GII_BASE}{datei}/__{z.nummer}.html"
    return f"{GII_BASE}{datei}/art_{z.nummer}.html"


# --------------------------------------------------------------------------- #
# Herkunft nicht erfasster Normen: Unionsrecht, Landesrecht
# --------------------------------------------------------------------------- #

EURLEX_BASE = "https://eur-lex.europa.eu/legal-content/DE/TXT/?uri="
# Kuerzel (klein) -> (Anzeigename, Meldung, Quell-URL)
EU_RECHT: dict[str, tuple[str, str, str]] = {
    "aeuv": ("AEUV", "Unionsrecht – Text bei EUR-Lex", EURLEX_BASE + "CELEX:12016E/TXT"),
    "euv": ("EUV", "Unionsrecht – Text bei EUR-Lex", EURLEX_BASE + "CELEX:12016M/TXT"),
    "grch": ("GRCh", "Unionsrecht – Text bei EUR-Lex", EURLEX_BASE + "CELEX:12016P/TXT"),
    "eugrch": ("GRCh", "Unionsrecht – Text bei EUR-Lex", EURLEX_BASE + "CELEX:12016P/TXT"),
    # Die EMRK ist Europaratsrecht, kein Unionsrecht und nicht bei EUR-Lex.
    "emrk": (
        "EMRK",
        "Europarecht (EMRK) – Text beim Europarat",
        "https://www.echr.coe.int",
    ),
}

# Land -> (Anzeigename, Portal)
LANDESPORTALE: dict[str, tuple[str, str]] = {
    "BW": ("Baden-Württemberg", "https://www.landesrecht-bw.de"),
    "BY": ("Bayern", "https://www.gesetze-bayern.de"),
    "BE": ("Berlin", "https://gesetze.berlin.de"),
    "BB": ("Brandenburg", "https://bravors.brandenburg.de"),
    "HB": ("Bremen", "https://www.transparenz.bremen.de"),
    "HH": ("Hamburg", "https://www.landesrecht-hamburg.de"),
    "HE": ("Hessen", "https://www.rv.hessenrecht.hessen.de"),
    "MV": ("Mecklenburg-Vorpommern", "https://www.landesrecht-mv.de"),
    "NI": ("Niedersachsen", "https://voris.wolterskluwer-online.de"),
    "NW": ("Nordrhein-Westfalen", "https://recht.nrw.de"),
    "RP": ("Rheinland-Pfalz", "https://landesrecht.rlp.de"),
    "SL": ("Saarland", "https://recht.saarland.de"),
    "SN": ("Sachsen", "https://www.revosax.sachsen.de"),
    "ST": ("Sachsen-Anhalt", "https://www.landesrecht.sachsen-anhalt.de"),
    "SH": ("Schleswig-Holstein", "https://www.gesetze-rechtsprechung.sh.juris.de"),
    "TH": ("Thüringen", "https://landesrecht.thueringen.de"),
}
# Laenderkuerzel im Zitat (exakt, Grossschreibung) -> Land
_LAND_SUFFIX = {
    "NRW": "NW", "BW": "BW", "BY": "BY", "BE": "BE", "Bln": "BE", "Bbg": "BB",
    "BB": "BB", "HB": "HB", "HH": "HH", "HE": "HE", "MV": "MV", "NI": "NI",
    "RP": "RP", "SL": "SL", "SN": "SN", "ST": "ST", "LSA": "ST", "TH": "TH", "SH": "SH",
}
# Landesgesetze, die ohne Laenderzusatz eindeutig sind (klein)
_LAND_GESETZ = {
    "baybo": "BY", "pag": "BY", "baygo": "BY", "lstvg": "BY", "baylkro": "BY",
    "bayvwvfg": "BY", "bayverf": "BY",
    "hsog": "HE", "hgo": "HE", "hbo": "HE",
    "npog": "NI", "nkomvg": "NI", "nbauo": "NI",
    "asog": "BE", "bauobln": "BE",
    "bbgbo": "BB", "hbauo": "HH", "sächsbo": "SN", "thürbo": "TH", "lvwg": "SH",
}


def herkunft(zitat: str) -> dict | None:
    """Erkennt Unionsrecht bzw. Landesrecht in einem Zitat (sonst ``None``).

    Liefert ``kategorie`` (``"eu"``/``"landesrecht"``), ``message`` und ``quelle_url``
    (bei unbekanntem Land ``None``).
    """
    woerter = re.findall(r"[A-Za-zÄÖÜäöü]+", zitat)
    for w in woerter:
        eu = EU_RECHT.get(w.lower())
        if eu:
            return {"kategorie": "eu", "gesetz": eu[0], "message": eu[1], "quelle_url": eu[2]}
    land = ""
    for w in woerter:
        land = _LAND_GESETZ.get(w.lower(), land)
    for w in woerter:
        if w in _LAND_SUFFIX:  # exakt (Grossschreibung), "Bay" via Sonderfall
            land = _LAND_SUFFIX[w]
    if "Bay" in woerter:
        land = "BY"
    if land:
        name, url = LANDESPORTALE[land]
        return {
            "kategorie": "landesrecht",
            "land": name,
            "message": f"Landesrecht {name} – Text im Landesrechtsportal",
            "quelle_url": url,
        }
    # Landesrechtlich erkennbar nur am Zusatz ohne bekanntes Land -> generisch
    if re.search(r"\b(?:GO|BauO|PolG|OBG|LBO|SOG|GemO|KrO|LKrO|LVwG)\b", zitat):
        return {
            "kategorie": "landesrecht",
            "land": None,
            "message": "Landesrecht – Text im Landesrechtsportal des jeweiligen Landes",
            "quelle_url": None,
            "portale": [{"land": n, "url": u} for n, u in LANDESPORTALE.values()],
        }
    return None


_WEITERE_SEG_RE = re.compile(
    r"^(?:§\s*)?(\d+[a-z]?)(?:\s*(?:Abs\.|Absatz)\s*\d+[a-z]?)?(?:\s*(?:S\.|Satz)\s*\d+)?"
    r"(?:\s+[A-Za-zÄÖÜäöü]+(?:\s+[A-Z]{2,3})?)?$"
)


def weitere_normen(zitat: str, z: Zitat) -> list[str]:
    """Weitere Normen eines Mehrfachzitats (``"§§ 214, 215 BauGB"`` -> ``["§ 215 BauGB"]``)."""
    zitat = re.sub(r"\s+", " ", zitat).strip()
    if z.art != "§" or "§§" not in zitat:
        return []
    m = _NORM_RE.search(zitat)
    if not m:
        return []
    rest = zitat[m.end():]
    if not rest.startswith((",", " und", " sowie", " u.")):
        return []
    try:
        zuletzt = int(re.match(r"\d+", z.nummer).group())  # type: ignore[union-attr]
    except AttributeError:
        return []
    out: list[str] = []
    for seg in re.split(r"\s*(?:,|\bund\b|\bsowie\b|\bu\.)\s*", rest):
        seg = seg.strip()
        sm = _WEITERE_SEG_RE.match(seg) if seg else None
        if not sm:
            continue
        nummer = sm.group(1)
        zahl = int(re.match(r"\d+", nummer).group())  # type: ignore[union-attr]
        if zahl <= zuletzt:  # "Abs. 1 und 2": eine Absatznummer, keine Norm
            continue
        zuletzt = zahl
        out.append(f"§ {nummer}" + (f" {z.gesetz_text}" if z.gesetz_text else ""))
    return out


def lookup(z: Zitat, zitat: str = "") -> dict | None:
    """Normtext zum Zitat oder ``None`` (Landesrecht / nicht erfasst)."""
    if not z.gesetz_key:
        return None
    datei, anzeige = GESETZE[z.gesetz_key]
    eintrag = _load(str(normtexte_dir()), datei).get(z.norm_key)
    if eintrag is None:
        return None
    return {
        "gesetz": anzeige,
        "norm": z.norm_key,
        "titel": eintrag.get("titel", ""),
        "text": eintrag["text"],
        "absatz": z.absatz or None,
        "satz": z.satz or None,
        "quelle_url": quelle_url(z),
        "weitere": weitere_normen(zitat, z) if zitat else [],
    }
