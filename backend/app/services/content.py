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

from app.models import Area, Card, CardType, Case, Schema, Topic, UserCard

VALID_AREAS = {a.value for a in Area}
VALID_CARD_TYPES = {t.value for t in CardType}
# Ab diesem Alter meldet die CI einen Inhalt zur redaktionellen Pruefung.
STALE_AFTER_MONTHS = 18
# Status-Werte des optionalen ``topic.redaktion``-Blocks (KI-Redaktion,
# siehe docs/08-ki-redaktion.md). Fehlt der Block, gilt ein Inhalt als
# regulaer redigiert (M0-Bestand vor der KI-Redaktion).
VALID_REDAKTION_STATUS = {"ki-freigegeben", "mensch-freigegeben", "in-pruefung"}


@dataclass
class ContentBundle:
    topics: list[dict] = field(default_factory=list)
    cards: list[dict] = field(default_factory=list)
    schemata: list[dict] = field(default_factory=list)
    cases: list[dict] = field(default_factory=list)
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

        topic = data.get("topic") or {}
        if not _require(topic, ["slug", "area", "title"], f"{rel} topic", bundle.errors):
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

    return bundle


def seed(db: Session, bundle: ContentBundle) -> dict[str, int]:
    """Schreibt das Bundle idempotent in die Datenbank (Upsert ueber ``slug``)."""
    stats = {"topics": 0, "cards": 0, "schemata": 0, "cases": 0, "changed_cards": 0}

    for t in bundle.topics:
        row = db.query(Topic).filter_by(slug=t["slug"]).one_or_none() or Topic(slug=t["slug"])
        row.area, row.title = t["area"], t["title"]
        row.parent_slug = t.get("parent")
        row.relevance = int(t.get("relevance", 3))
        row.position = int(t.get("position", 0))
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

    db.commit()
    return stats
