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


def lookup(z: Zitat) -> dict | None:
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
    }
