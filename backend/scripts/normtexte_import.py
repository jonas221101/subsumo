"""Laedt amtliche Gesetzestexte von gesetze-im-internet.de nach ``content/normtexte``.

Aufruf (einmalig bzw. zur Aktualisierung)::

    backend/.venv/bin/python backend/scripts/normtexte_import.py [--only bgb stgb] [--dest DIR]

Pro Gesetz entsteht ``<abk>.json`` mit ``{"§ 433": {"titel": ..., "text": ...}}``
(Grundgesetz etc.: ``"Art. 12"``). Absaetze bleiben als ``(1) ...``-Zeilen
erhalten, Aufzaehlungen stehen eine pro Zeile. Fussnoten/Metadaten werden
verworfen. Die Texte sind amtliche Werke (§ 5 UrhG).
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
import urllib.request
import zipfile
from datetime import date
from pathlib import Path
from xml.etree import ElementTree as ET

BASE_URL = "https://www.gesetze-im-internet.de/{abk}/xml.zip"

# URL-Kuerzel -> Anzeigename des Gesetzes
GESETZE: dict[str, str] = {
    "bgb": "BGB",
    "stgb": "StGB",
    "gg": "GG",
    "stpo": "StPO",
    "zpo": "ZPO",
    "vwgo": "VwGO",
    "vwvfg": "VwVfG",
    "hgb": "HGB",
    "gvg": "GVG",
    "bverfgg": "BVerfGG",
    "bgbeg": "EGBGB",
    "gmbhg": "GmbHG",
    "prodhaftg": "ProdHaftG",
    "stvg": "StVG",
    "kschg": "KSchG",
    "inso": "InsO",
    "bbaug": "BauGB",
    "baunvo": "BauNVO",
    "versammlg": "VersammlG",
    "vwvg": "VwVG",
    "kcang": "KCanG",
    "aktg": "AktG",
    "owig_1968": "OWiG",
}

_NORM_KEY = re.compile(r"^(§|Art)\s")


def _text_of(el: ET.Element) -> str:
    """Flacht ein Inhaltselement zu Text mit Zeilenumbruechen ab."""
    parts: list[str] = []

    def walk(node: ET.Element) -> None:
        tag = node.tag
        if tag == "BR":
            parts.append("\n")
        if tag in ("DT", "P") and parts and not parts[-1].endswith("\n"):
            parts.append("\n")
        if node.text:
            parts.append(node.text)
        for child in node:
            walk(child)
            if child.tag == "DT":
                parts.append(" ")
            elif child.tag in ("DD", "P"):
                parts.append("\n")
            if child.tail:
                parts.append(child.tail)

    walk(el)
    text = "".join(parts)
    text = re.sub(r"[ \t ]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    return re.sub(r"\n{2,}", "\n", text).strip()


def parse_xml(xml_bytes: bytes) -> dict[str, dict[str, str]]:
    """Extrahiert ``{"§ 433": {"titel", "text"}}`` aus einer GII-XML-Datei."""
    root = ET.fromstring(xml_bytes)
    out: dict[str, dict[str, str]] = {}
    # EGBGB & Co. gliedern in "Art 246a" (Gliederungseinheit) mit eigenen "§ 1".
    art_ctx = ""
    art_titel = ""
    for norm in root.iter("norm"):
        meta = norm.find("metadaten")
        if meta is None:
            continue
        enbez = (meta.findtext("enbez") or "").strip()
        content = norm.find("textdaten/text/Content")
        text = _text_of(content) if content is not None else ""
        gl = meta.find("gliederungseinheit")
        if gl is not None:
            bez = (gl.findtext("gliederungsbez") or "").strip()
            if bez.startswith("Art"):
                art_ctx = re.sub(r"^Art\s*", "Art. ", bez)
                art_titel = (gl.findtext("gliederungstitel") or "").strip()
            else:
                art_ctx = ""
        if not enbez:
            # Artikel ohne eigene Paragraphen (z. B. EGBGB Art. 2): Text steht an der Gliederung
            if gl is not None and art_ctx and text:
                out[art_ctx] = {"titel": art_titel, "text": text}
            continue
        if not _NORM_KEY.match(enbez):
            continue  # Anlagen, Eingangsformel
        key = re.sub(r"^Art\s", "Art. ", enbez)
        if art_ctx and key.startswith("§") and not key.startswith(art_ctx):
            key = f"{art_ctx} {key}"
        titel = _text_of(meta.find("titel")) if meta.find("titel") is not None else ""
        if not text or text in ("-", "(weggefallen)"):
            continue
        out[key] = {"titel": titel, "text": text}
    return out


def fetch(abk: str) -> bytes:
    req = urllib.request.Request(
        BASE_URL.format(abk=abk), headers={"User-Agent": "subsumo-normtexte-import/1.0"}
    )
    with urllib.request.urlopen(req, timeout=60) as resp:  # noqa: S310 - feste https-URL
        data = resp.read()
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        names = [n for n in zf.namelist() if n.lower().endswith(".xml")]
        return zf.read(names[0])


def main(argv: list[str] | None = None) -> int:
    default_dest = Path(__file__).resolve().parents[2] / "content" / "normtexte"
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--only", nargs="*", help="nur diese URL-Kuerzel")
    ap.add_argument("--dest", type=Path, default=default_dest)
    args = ap.parse_args(argv)
    args.dest.mkdir(parents=True, exist_ok=True)
    failed = 0
    index_path = args.dest / "index.json"
    index: dict[str, dict] = {}
    if index_path.exists():
        index = json.loads(index_path.read_text(encoding="utf-8")).get("gesetze", {})
    for abk, name in GESETZE.items():
        if args.only and abk not in args.only:
            continue
        try:
            norms = parse_xml(fetch(abk))
        except Exception as exc:  # noqa: BLE001 - Einzelfehler soll Rest nicht stoppen
            print(f"FEHLER {abk}: {exc}", file=sys.stderr)
            failed += 1
            continue
        path = args.dest / f"{abk}.json"
        path.write_text(
            json.dumps(norms, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
        )
        index[abk] = {"gesetz": name, "normen": len(norms), "bytes": path.stat().st_size}
        print(f"{abk}: {len(norms)} Normen, {path.stat().st_size // 1024} KiB")
    if index:
        index_path.write_text(
            json.dumps(
                {"abgerufen": date.today().isoformat(), "gesetze": index},
                ensure_ascii=False, indent=1,
            ),
            encoding="utf-8",
        )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
