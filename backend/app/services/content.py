"""Laden, Validieren und Seeden der Lerninhalte.

Loest Challenge 10: Inhalte liegen als YAML im Git, nicht in der Datenbank.
Die Datenbank ist ein Cache. Fachliche Aenderungen laufen als Pull Request mit
Review, die CI validiert das Format und meldet veraltete Inhalte.

Jeder Inhalt traegt ``stand`` und ``quellen`` als Pflichtfelder - ohne Quelle
wird nichts veroeffentlicht (urheberrechtliche Nachvollziehbarkeit, siehe
docs/06-recht-compliance.md).
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import Any

import yaml
from sqlalchemy.orm import Session

from app.models import (
    Area,
    Bundesland,
    Card,
    CardType,
    Case,
    Kurs,
    Schema,
    Topic,
    Universitaet,
    UserCard,
)

VALID_AREAS = {a.value for a in Area}
VALID_CARD_TYPES = {t.value for t in CardType}
# Ab diesem Alter meldet die CI einen Inhalt zur redaktionellen Pruefung.
STALE_AFTER_MONTHS = 18
# Status-Werte des optionalen ``topic.redaktion``-Blocks (KI-Redaktion,
# siehe docs/08-ki-redaktion.md). Fehlt der Block, gilt ein Inhalt als
# regulaer redigiert (M0-Bestand vor der KI-Redaktion).
VALID_REDAKTION_STATUS = {"ki-freigegeben", "mensch-freigegeben", "in-pruefung"}

# Die 16 Laender, amtliche Kuerzel. Ein Bundesland-Profil, ein Landesrecht-
# Thema oder ein Nutzerprofil darf nur eines davon tragen
# (docs/32-examensvorbereitung.md).
BUNDESLAND_CODES = {
    "BW", "BY", "BE", "BB", "HB", "HH", "HE", "MV",
    "NI", "NW", "RP", "SL", "SN", "ST", "SH", "TH",
}  # fmt: skip

# Landesrecht-Kategorien, ueber die ein Kurs bundeslandspezifische Themen
# einbindet. Konvention fuer den Topic-Slug: ``<code klein>-<kategorie>``,
# z. B. ``by-polizei-ordnungsrecht``. Der Loader prueft die Konvention.
LANDESRECHT_KATEGORIEN = {"polizei-ordnungsrecht", "landesrecht-allgemein"}


@dataclass
class ContentBundle:
    topics: list[dict] = field(default_factory=list)
    cards: list[dict] = field(default_factory=list)
    schemata: list[dict] = field(default_factory=list)
    cases: list[dict] = field(default_factory=list)
    bundeslaender: list[dict] = field(default_factory=list)
    universitaeten: list[dict] = field(default_factory=list)
    kurse: list[dict] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors


def content_hash(*parts: str) -> str:
    digest = hashlib.sha256()
    for part in parts:
        digest.update(part.encode("utf-8"))
        digest.update(b"\x1f")
    return digest.hexdigest()[:32]


def _require(obj: dict, keys: list[str], where: str, errors: list[str]) -> bool:
    missing = [k for k in keys if not obj.get(k)]
    if missing:
        errors.append(f"{where}: Pflichtfelder fehlen: {', '.join(missing)}")
        return False
    return True


def _check_stand(value: Any, where: str, warnings: list[str], errors: list[str]) -> str:
    text = str(value or "").strip()
    if not text:
        errors.append(f"{where}: 'stand' fehlt (Datum der letzten fachlichen Pruefung)")
        return ""
    try:
        parsed = datetime.strptime(text if len(text) > 7 else text + "-01", "%Y-%m-%d").date()
    except ValueError:
        errors.append(f"{where}: 'stand' muss YYYY-MM oder YYYY-MM-TT sein, ist '{text}'")
        return text
    months = (date.today().year - parsed.year) * 12 + (date.today().month - parsed.month)
    if months > STALE_AFTER_MONTHS:
        warnings.append(f"{where}: Inhalt ist {months} Monate alt - redaktionell pruefen")
    return text


def load_content(content_dir: Path) -> ContentBundle:
    """Liest alle YAML-Dateien unterhalb von ``content_dir`` und validiert sie."""
    bundle = ContentBundle()
    if not content_dir.exists():
        bundle.errors.append(f"Content-Verzeichnis nicht gefunden: {content_dir}")
        return bundle

    slugs: dict[str, str] = {}
    # (where, card_slug) je referenziertem Pruefpunkt.card_slugs - erst nach der
    # kompletten Dateischleife geprueft, da eine Karte aus einer alphabetisch
    # spaeter sortierten Datei zum Zeitpunkt der Fall-Validierung noch nicht in
    # ``bundle.cards`` steht.
    card_slug_refs: list[tuple[str, str]] = []
    for path in sorted(content_dir.rglob("*.y*ml")):
        rel = path.relative_to(content_dir)
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except yaml.YAMLError as exc:
            bundle.errors.append(f"{rel}: YAML nicht lesbar - {exc}")
            continue
        if not isinstance(data, dict):
            bundle.errors.append(f"{rel}: Datei muss ein Mapping auf oberster Ebene sein")
            continue

        if "topic" not in data:
            _load_examen_file(data, str(rel), bundle)
            continue

        topic = data.get("topic") or {}
        if not _require(topic, ["slug", "area", "title"], f"{rel} topic", bundle.errors):
            continue
        land = topic.get("bundesland")
        if land is not None and land not in BUNDESLAND_CODES:
            bundle.errors.append(
                f"{rel} topic: unbekanntes Bundesland '{land}' "
                f"(erlaubt: {', '.join(sorted(BUNDESLAND_CODES))})"
            )
            continue
        if topic["area"] not in VALID_AREAS:
            bundle.errors.append(
                f"{rel} topic: unbekanntes Rechtsgebiet '{topic['area']}' "
                f"(erlaubt: {', '.join(sorted(VALID_AREAS))})"
            )
            continue
        topic.setdefault("relevance", 3)
        if not 1 <= int(topic["relevance"]) <= 5:
            bundle.errors.append(f"{rel} topic: 'relevance' muss zwischen 1 und 5 liegen")
        redaktion = topic.get("redaktion")
        if redaktion is not None:
            status = redaktion.get("status") if isinstance(redaktion, dict) else None
            if status not in VALID_REDAKTION_STATUS:
                bundle.errors.append(
                    f"{rel} topic.redaktion: 'status' fehlt oder unbekannt "
                    f"(erlaubt: {', '.join(sorted(VALID_REDAKTION_STATUS))})"
                )
            elif status == "in-pruefung":
                bundle.warnings.append(
                    f"{rel} topic: Status 'in-pruefung' - noch nicht fuer Nutzer freigegeben"
                )
        bundle.topics.append(topic)

        def register(slug: str, where: str) -> bool:
            if slug in slugs:
                bundle.errors.append(f"{where}: slug '{slug}' bereits vergeben in {slugs[slug]}")
                return False
            slugs[slug] = where
            return True

        for i, card in enumerate(data.get("cards") or []):
            where = f"{rel} cards[{i}]"
            if not _require(card, ["slug", "front", "back", "quellen"], where, bundle.errors):
                continue
            if card.get("type", "definition") not in VALID_CARD_TYPES:
                bundle.errors.append(f"{where}: unbekannter Kartentyp '{card.get('type')}'")
                continue
            card["stand"] = _check_stand(
                card.get("stand", topic.get("stand")), where, bundle.warnings, bundle.errors
            )
            if not register(card["slug"], where):
                continue
            card["topic_slug"] = topic["slug"]
            bundle.cards.append(card)

        for i, schema in enumerate(data.get("schemata") or []):
            where = f"{rel} schemata[{i}]"
            if not _require(schema, ["slug", "title", "steps", "quellen"], where, bundle.errors):
                continue
            schema["stand"] = _check_stand(
                schema.get("stand", topic.get("stand")), where, bundle.warnings, bundle.errors
            )
            if not register(schema["slug"], where):
                continue
            schema["topic_slug"] = topic["slug"]
            schema["area"] = topic["area"]
            bundle.schemata.append(schema)

        for i, case in enumerate(data.get("faelle") or []):
            where = f"{rel} faelle[{i}]"
            if not _require(
                case, ["slug", "title", "facts", "expectation", "quellen"], where, bundle.errors
            ):
                continue
            pruefpunkte = (case.get("expectation") or {}).get("pruefpunkte") or []
            if not pruefpunkte:
                bundle.errors.append(
                    f"{where}: 'expectation.pruefpunkte' ist leer - ohne "
                    "Erwartungshorizont darf ein Fall nicht bewertet werden"
                )
                continue
            ids = [p.get("id") for p in pruefpunkte]
            if len(set(ids)) != len(ids):
                bundle.errors.append(f"{where}: Pruefpunkt-IDs sind nicht eindeutig")
            for p in pruefpunkte:
                for card_slug in p.get("card_slugs") or []:
                    card_slug_refs.append((where, card_slug))
            case["stand"] = _check_stand(
                case.get("stand", topic.get("stand")), where, bundle.warnings, bundle.errors
            )
            if not register(case["slug"], where):
                continue
            case["topic_slug"] = topic["slug"]
            case["area"] = topic["area"]
            bundle.cases.append(case)

    card_slugs_available = {c["slug"] for c in bundle.cards}
    for where, card_slug in card_slug_refs:
        if card_slug not in card_slugs_available:
            bundle.errors.append(
                f"{where}: card_slugs verweist auf unbekannten Card-Slug '{card_slug}'"
            )

    _cross_check_examen(bundle)
    return bundle


# --------------------------------------------------------------------------- #
# Examensvorbereitung: Bundesland-Profile, Universitaeten, Kurse
# (docs/32-examensvorbereitung.md, Abschnitt 3)
# --------------------------------------------------------------------------- #


def _check_redaktion(obj: dict, where: str, bundle: ContentBundle) -> None:
    redaktion = obj.get("redaktion")
    if redaktion is None:
        return
    status = redaktion.get("status") if isinstance(redaktion, dict) else None
    if status not in VALID_REDAKTION_STATUS:
        bundle.errors.append(
            f"{where} redaktion: 'status' fehlt oder unbekannt "
            f"(erlaubt: {', '.join(sorted(VALID_REDAKTION_STATUS))})"
        )
    elif status == "in-pruefung":
        bundle.warnings.append(
            f"{where}: Status 'in-pruefung' - Angaben vor Nutzung redaktionell pruefen"
        )


def _load_examen_file(data: dict, rel: str, bundle: ContentBundle) -> None:
    """Parst eine Datei mit ``bundesland``, ``universitaet`` oder ``kurs``."""
    if "bundesland" in data:
        _load_bundesland(data["bundesland"] or {}, f"{rel} bundesland", bundle)
    elif "universitaet" in data:
        _load_universitaet(data["universitaet"] or {}, f"{rel} universitaet", bundle)
    elif "kurs" in data:
        _load_kurs(data["kurs"] or {}, f"{rel} kurs", bundle)
    else:
        bundle.errors.append(
            f"{rel}: oberste Ebene muss 'topic', 'bundesland', 'universitaet' oder 'kurs' sein"
        )


def _load_bundesland(land: dict, where: str, bundle: ContentBundle) -> None:
    if not _require(land, ["code", "name", "quellen", "klausuren"], where, bundle.errors):
        return
    code = str(land["code"])
    if code not in BUNDESLAND_CODES:
        bundle.errors.append(f"{where}: unbekanntes Bundesland-Kuerzel '{code}'")
        return
    if any(b["code"] == code for b in bundle.bundeslaender):
        bundle.errors.append(f"{where}: Profil fuer '{code}' bereits vorhanden")
        return
    land["stand"] = _check_stand(land.get("stand"), where, bundle.warnings, bundle.errors)
    _check_redaktion(land, where, bundle)

    klausuren = land["klausuren"]
    verteilung = klausuren.get("verteilung") if isinstance(klausuren, dict) else None
    anzahl = klausuren.get("anzahl") if isinstance(klausuren, dict) else None
    if not isinstance(verteilung, dict) or not isinstance(anzahl, int):
        bundle.errors.append(f"{where}: 'klausuren' braucht 'anzahl' (int) und 'verteilung'")
        return
    unbekannt = set(verteilung) - VALID_AREAS
    if unbekannt:
        bundle.errors.append(
            f"{where}: klausuren.verteilung mit unbekanntem Rechtsgebiet "
            f"{', '.join(sorted(unbekannt))}"
        )
    if sum(int(v) for v in verteilung.values()) != anzahl:
        bundle.errors.append(
            f"{where}: klausuren.verteilung ({sum(verteilung.values())}) "
            f"ergibt nicht klausuren.anzahl ({anzahl})"
        )
    bundle.bundeslaender.append(land)


def _load_universitaet(uni: dict, where: str, bundle: ContentBundle) -> None:
    if not _require(uni, ["slug", "name", "bundesland", "quellen", "kurse"], where, bundle.errors):
        return
    if uni["bundesland"] not in BUNDESLAND_CODES:
        bundle.errors.append(f"{where}: unbekanntes Bundesland '{uni['bundesland']}'")
        return
    if any(u["slug"] == uni["slug"] for u in bundle.universitaeten):
        bundle.errors.append(f"{where}: slug '{uni['slug']}' bereits vergeben")
        return
    uni["stand"] = _check_stand(uni.get("stand"), where, bundle.warnings, bundle.errors)
    _check_redaktion(uni, where, bundle)
    for i, eintrag in enumerate(uni["kurse"]):
        if not isinstance(eintrag, dict) or not eintrag.get("kurs"):
            bundle.errors.append(f"{where} kurse[{i}]: 'kurs' (Slug) fehlt")
    bundle.universitaeten.append(uni)


def _load_kurs(kurs: dict, where: str, bundle: ContentBundle) -> None:
    if not _require(kurs, ["slug", "title", "area", "quellen"], where, bundle.errors):
        return
    if kurs["area"] not in VALID_AREAS:
        bundle.errors.append(f"{where}: unbekanntes Rechtsgebiet '{kurs['area']}'")
        return
    if any(k["slug"] == kurs["slug"] for k in bundle.kurse):
        bundle.errors.append(f"{where}: slug '{kurs['slug']}' bereits vergeben")
        return
    kurs["stand"] = _check_stand(kurs.get("stand"), where, bundle.warnings, bundle.errors)
    _check_redaktion(kurs, where, bundle)
    kurs.setdefault("topic_slugs", [])
    kurs.setdefault("landesrecht_kategorien", [])
    if not kurs["topic_slugs"] and not kurs["landesrecht_kategorien"]:
        bundle.errors.append(
            f"{where}: ein Kurs braucht 'topic_slugs' oder 'landesrecht_kategorien' - "
            "ein leeres Deck ist kein Vorbereitungsdeck"
        )
    for kategorie in kurs["landesrecht_kategorien"]:
        if kategorie not in LANDESRECHT_KATEGORIEN:
            bundle.errors.append(
                f"{where}: unbekannte Landesrecht-Kategorie '{kategorie}' "
                f"(erlaubt: {', '.join(sorted(LANDESRECHT_KATEGORIEN))})"
            )
    bundle.kurse.append(kurs)


def landesrecht_topic_slug(code: str, kategorie: str) -> str:
    """Slug-Konvention fuer Landesrecht-Themen: ``by-polizei-ordnungsrecht``."""
    return f"{code.lower()}-{kategorie}"


def _cross_check_examen(bundle: ContentBundle) -> None:
    """Querverweise, die erst nach der kompletten Dateischleife pruefbar sind."""
    topic_slugs = {t["slug"] for t in bundle.topics}
    kurs_slugs = {k["slug"] for k in bundle.kurse}
    land_codes = {b["code"] for b in bundle.bundeslaender}

    for topic in bundle.topics:
        land = topic.get("bundesland")
        if land is not None and land not in land_codes:
            bundle.warnings.append(
                f"topic '{topic['slug']}': Landesrecht fuer '{land}' ohne Bundesland-Profil"
            )

    for kurs in bundle.kurse:
        for slug in kurs["topic_slugs"]:
            if slug not in topic_slugs:
                bundle.errors.append(
                    f"kurs '{kurs['slug']}': topic_slugs verweist auf unbekanntes Thema '{slug}'"
                )
        for kategorie in kurs["landesrecht_kategorien"]:
            fehlend = [
                code
                for code in sorted(land_codes)
                if landesrecht_topic_slug(code, kategorie) not in topic_slugs
            ]
            if fehlend:
                bundle.warnings.append(
                    f"kurs '{kurs['slug']}': Landesrecht-Kategorie '{kategorie}' ohne Thema "
                    f"fuer {', '.join(fehlend)}"
                )

    for uni in bundle.universitaeten:
        if uni["bundesland"] not in land_codes:
            bundle.errors.append(
                f"universitaet '{uni['slug']}': kein Profil fuer Bundesland '{uni['bundesland']}'"
            )
        for eintrag in uni["kurse"]:
            slug = eintrag.get("kurs") if isinstance(eintrag, dict) else None
            if slug and slug not in kurs_slugs:
                bundle.errors.append(f"universitaet '{uni['slug']}': unbekannter Kurs '{slug}'")


def seed(db: Session, bundle: ContentBundle) -> dict[str, int]:
    """Schreibt das Bundle idempotent in die Datenbank (Upsert ueber ``slug``)."""
    stats = {
        "topics": 0,
        "cards": 0,
        "schemata": 0,
        "cases": 0,
        "changed_cards": 0,
        "bundeslaender": 0,
        "universitaeten": 0,
        "kurse": 0,
    }

    for t in bundle.topics:
        row = db.query(Topic).filter_by(slug=t["slug"]).one_or_none() or Topic(slug=t["slug"])
        row.area, row.title = t["area"], t["title"]
        row.parent_slug = t.get("parent")
        row.relevance = int(t.get("relevance", 3))
        row.position = int(t.get("position", 0))
        row.bundesland = t.get("bundesland")
        db.add(row)
        stats["topics"] += 1

    for c in bundle.cards:
        digest = content_hash(c["front"], c["back"])
        row = db.query(Card).filter_by(slug=c["slug"]).one_or_none()
        if row is None:
            row = Card(slug=c["slug"])
        elif row.content_hash and row.content_hash != digest:
            # Inhalt hat sich geaendert: Nutzerkarten werden markiert, nicht
            # zurueckgesetzt. Der Lernfortschritt bleibt erhalten, die Karte
            # wird dem Nutzer einmalig mit Hinweis erneut vorgelegt.
            db.query(UserCard).filter_by(card_id=row.id).update(
                {"content_changed": True}, synchronize_session=False
            )
            stats["changed_cards"] += 1
        row.topic_slug = c["topic_slug"]
        row.type = c.get("type", "definition")
        row.front, row.back = c["front"], c["back"]
        row.norms = list(c.get("norms", []))
        row.sources = list(c.get("quellen", []))
        row.stand = c.get("stand", "")
        row.content_hash = digest
        db.add(row)
        stats["cards"] += 1

    for s in bundle.schemata:
        row = db.query(Schema).filter_by(slug=s["slug"]).one_or_none() or Schema(slug=s["slug"])
        row.topic_slug, row.area, row.title = s["topic_slug"], s["area"], s["title"]
        row.norms = list(s.get("norms", []))
        row.steps = s["steps"]
        row.sources = list(s.get("quellen", []))
        row.stand = s.get("stand", "")
        db.add(row)
        stats["schemata"] += 1

    for f in bundle.cases:
        row = db.query(Case).filter_by(slug=f["slug"]).one_or_none() or Case(slug=f["slug"])
        row.topic_slug, row.area, row.title = f["topic_slug"], f["area"], f["title"]
        row.difficulty = int(f.get("difficulty", 2))
        row.minutes = int(f.get("minutes", 60))
        row.facts = f["facts"]
        row.question = f.get("question", "")
        row.steps = f.get("steps", [])
        row.expectation = f["expectation"]
        row.sources = list(f.get("quellen", []))
        row.stand = f.get("stand", "")
        db.add(row)
        stats["cases"] += 1

    for land in bundle.bundeslaender:
        row = db.get(Bundesland, land["code"]) or Bundesland(code=land["code"])
        row.name = land["name"]
        row.stand = land.get("stand", "")
        row.data = _json_safe(land)
        db.add(row)
        stats["bundeslaender"] += 1

    for uni in bundle.universitaeten:
        row = db.query(Universitaet).filter_by(slug=uni["slug"]).one_or_none() or Universitaet(
            slug=uni["slug"]
        )
        row.name = uni["name"]
        row.bundesland = uni["bundesland"]
        row.stand = uni.get("stand", "")
        row.data = _json_safe(uni)
        db.add(row)
        stats["universitaeten"] += 1

    for kurs in bundle.kurse:
        row = db.query(Kurs).filter_by(slug=kurs["slug"]).one_or_none() or Kurs(slug=kurs["slug"])
        row.title = kurs["title"]
        row.area = kurs["area"]
        row.stand = kurs.get("stand", "")
        row.data = _json_safe(kurs)
        db.add(row)
        stats["kurse"] += 1

    db.commit()
    return stats


def _json_safe(value: Any) -> Any:
    """YAML liefert date-Objekte fuer unquoted Datumsangaben - JSON-Spalten nicht."""
    if isinstance(value, dict):
        return {str(k): _json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_json_safe(v) for v in value]
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value
