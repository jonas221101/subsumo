"""Slug-Katalog fuer den Werkbank-Generierungskontext (Ticket 1, SUB-366).

Siehe docs/27-werkbank-spezifikation.md Abschnitt 4.2: der Systemprompt der
Stufe 2 (Generierungsaufruf) erhaelt eine vom Server vorab geladene, auf das
vom Nutzer genannte Rechtsgebiet begrenzte Liste gueltiger `topic_slug`-/
`schema_slug`-Werte - nicht den gesamten Content-Bestand, damit
Kontextgroesse und Halluzinationsflaeche klein bleiben.

Das ist ein anderer Zweck als das statische `input_field.source`-Enum aus
Abschnitt 3.1: jenes steht bereits vollstaendig im Tool-Spec-v2-JSON-Schema
(`app/services/tool_spec.py`, SUB-317) und braucht keinen eigenen Endpunkt.
Dieses Modul liefert stattdessen die konkreten Slug-*Werte* eines
Rechtsgebiets, die das Modell im generierten Tool referenzieren darf.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from sqlalchemy.orm import Session

from app.models import Area, Schema, Topic

SLUG_CATALOG_SCHEMA_ID = "subsumo.werkbank.slug_catalog.v1"

# Die drei realen Rechtsgebiete, gegen die Topic.area/Schema.area gefuellt
# sind. Bewusst *nicht* das AREA_SCOPE_VALUES aus tool_spec.py: dort
# bezeichnet "alle" die Reichweite eines fertigen Werkzeugs, hier geht es um
# das eine Rechtsgebiet, das der Nutzer fuer die Generierung genannt hat -
# "alle" ist dafuer keine gueltige Eingabe.
VALID_AREAS = {a.value for a in Area}

# Abschnitt 4.2: Kontextgroesse fuer den Generierungsprompt klein halten -
# auch innerhalb eines Rechtsgebiets nicht unbegrenzt mitwachsen lassen.
MAX_SLUGS_PER_KIND = 60


class UnknownAreaError(ValueError):
    """Rechtsgebiet ist leer oder keines der bekannten drei Rechtsgebiete."""


@dataclass(frozen=True)
class SlugCatalog:
    schema: str
    area: str
    topic_slugs: list[str] = field(default_factory=list)
    schema_slugs: list[str] = field(default_factory=list)

    def as_dict(self) -> dict:
        return {
            "schema": self.schema,
            "area": self.area,
            "topic_slugs": self.topic_slugs,
            "schema_slugs": self.schema_slugs,
        }


def build_slug_catalog(db: Session, area: str) -> SlugCatalog:
    """Liefert die auf ``area`` begrenzte Slug-Liste fuer Stufe 2 (Abschnitt 4.2).

    Wirft ``UnknownAreaError`` bei leerem oder unbekanntem Rechtsgebiet -
    Kriterium 3 aus SUB-366: kein stiller Fallback auf die Vollliste.
    """
    if not area or area not in VALID_AREAS:
        raise UnknownAreaError(
            f"Unbekanntes Rechtsgebiet '{area}' (erlaubt: {', '.join(sorted(VALID_AREAS))})"
        )
    topic_slugs = [
        row[0]
        for row in db.query(Topic.slug)
        .filter(Topic.area == area)
        .order_by(Topic.relevance.desc(), Topic.position, Topic.slug)
        .limit(MAX_SLUGS_PER_KIND)
        .all()
    ]
    schema_slugs = [
        row[0]
        for row in db.query(Schema.slug)
        .filter(Schema.area == area)
        .order_by(Schema.slug)
        .limit(MAX_SLUGS_PER_KIND)
        .all()
    ]
    return SlugCatalog(
        schema=SLUG_CATALOG_SCHEMA_ID,
        area=area,
        topic_slugs=topic_slugs,
        schema_slugs=schema_slugs,
    )
