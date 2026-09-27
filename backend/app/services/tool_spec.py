"""JSON-Schema und Validator fuer Tool-Spec v2 (Werkbank, SUB-317).

Siehe `docs/27-werkbank-spezifikation.md` Abschnitt 3.1. Analog zum
Validierungsprinzip aus `app/services/content.py`: was nicht im Schema steht,
existiert nicht (`additionalProperties: false` auf jeder Ebene), und die
Pruefung ist handgeschriebener Python-Code, kein generischer
JSON-Schema-Validator (kein neues Framework/keine neue Abhaengigkeit).

`INPUT_FIELD_SOURCES` ist bewusst eine geschlossene Enum-Liste **ohne** einen
Freitext-/"eigener Sachverhalt"-Wert - das ist die Schema-gewordene Fassung
der RDG-Grenze aus Abschnitt 1.3/2.1: der Host darf generiertem Code niemals
ein Freitextfeld als Eingabe reichen.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

TOOL_SPEC_SCHEMA_ID = "subsumo.werkbank.tool_spec.v2"

AREA_SCOPE_VALUES = {"zivilrecht", "strafrecht", "oeffentliches-recht", "alle"}
RENDER_AS_VALUES = {"list", "checklist", "text_block", "counter", "tabs"}
RUNTIME_VALUES = {"quickjs_sandboxed_v1", "web_iframe_sandboxed_v1"}
OUTPUT_FIELD_TYPES = {"string", "number", "boolean", "string_array"}
# Abschnitt 1.3/2.1: strukturierte Referenzen und der eigene SRS-/Planungsstand
# des Nutzers - ausdruecklich kein Freitext-Wert. Jede Erweiterung dieser Liste
# um einen Freitext-Eingang waere ein RDG-Verstoss, keine Stilfrage.
INPUT_FIELD_SOURCES = {
    "topic_slug_ref",
    "case_slug_ref",
    "schema_slug_ref",
    "card_type_enum",
    "difficulty_int",
    "count_int",
    "own_srs_state",
    "own_plan_state",
}
CODE_LANGUAGE = "javascript_es2020"
RESOURCE_LIMITS_TIMEOUT_MS = 300
RESOURCE_LIMITS_MAX_OUTPUT_BYTES = 8192
LABELING_BADGE_TEXT = "KI-Vorschlag · ungeprüft"

ROOT_REQUIRED = [
    "schema", "tool_id", "title", "area_scope", "input_contract",
    "output_contract", "code", "runtime", "resource_limits",
    "labeling", "created_at", "prompt_fingerprint",
]
ROOT_ALLOWED = [*ROOT_REQUIRED, "description"]

_UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.IGNORECASE
)
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

# Wortgleich zu Abschnitt 3.1 - einzige Quelle der Wahrheit sind die
# Konstanten oben, damit Schema und Validator nicht auseinanderlaufen koennen.
TOOL_SPEC_V2_SCHEMA: dict = {
    "$id": TOOL_SPEC_SCHEMA_ID,
    "type": "object",
    "additionalProperties": False,
    "required": ROOT_REQUIRED,
    "properties": {
        "schema": {"const": TOOL_SPEC_SCHEMA_ID},
        "tool_id": {"type": "string", "format": "uuid"},
        "title": {"type": "string", "minLength": 1, "maxLength": 80},
        "description": {"type": "string", "maxLength": 280},
        "area_scope": {"type": "string", "enum": sorted(AREA_SCOPE_VALUES)},
        "input_contract": {
            "type": "object",
            "additionalProperties": False,
            "required": ["fields"],
            "properties": {
                "fields": {
                    "type": "array",
                    "maxItems": 10,
                    "items": {"$ref": "#/$defs/input_field"},
                }
            },
        },
        "output_contract": {
            "type": "object",
            "additionalProperties": False,
            "required": ["render_as", "fields"],
            "properties": {
                "render_as": {"type": "string", "enum": sorted(RENDER_AS_VALUES)},
                "fields": {
                    "type": "array",
                    "maxItems": 10,
                    "items": {"$ref": "#/$defs/output_field"},
                },
            },
        },
        "code": {
            "type": "object",
            "additionalProperties": False,
            "required": ["language", "source", "source_sha256"],
            "properties": {
                "language": {"const": CODE_LANGUAGE},
                "source": {"type": "string", "maxLength": 20000},
                "source_sha256": {"type": "string", "pattern": "^[0-9a-f]{64}$"},
            },
        },
        "runtime": {"type": "string", "enum": sorted(RUNTIME_VALUES)},
        "resource_limits": {
            "type": "object",
            "additionalProperties": False,
            "required": ["timeout_ms", "max_output_bytes"],
            "properties": {
                "timeout_ms": {"const": RESOURCE_LIMITS_TIMEOUT_MS},
                "max_output_bytes": {"const": RESOURCE_LIMITS_MAX_OUTPUT_BYTES},
            },
        },
        "labeling": {
            "type": "object",
            "additionalProperties": False,
            "required": ["is_suggestion", "badge_text"],
            "properties": {
                "is_suggestion": {"const": True},
                "badge_text": {"const": LABELING_BADGE_TEXT},
            },
        },
        "created_at": {"type": "string", "format": "date-time"},
        "prompt_fingerprint": {"type": "string", "maxLength": 64},
    },
    "$defs": {
        "input_field": {
            "type": "object",
            "additionalProperties": False,
            "required": ["name", "source"],
            "properties": {
                "name": {"type": "string", "maxLength": 40},
                "source": {"type": "string", "enum": sorted(INPUT_FIELD_SOURCES)},
            },
        },
        "output_field": {
            "type": "object",
            "additionalProperties": False,
            "required": ["name", "type"],
            "properties": {
                "name": {"type": "string", "maxLength": 40},
                "type": {"type": "string", "enum": sorted(OUTPUT_FIELD_TYPES)},
            },
        },
    },
}


@dataclass
class ToolSpecValidation:
    errors: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors


def _check_object(
    obj: Any, required: list[str], allowed: list[str], where: str, errors: list[str]
) -> bool:
    if not isinstance(obj, dict):
        errors.append(f"{where}: muss ein Objekt sein")
        return False
    missing = [k for k in required if k not in obj]
    if missing:
        errors.append(f"{where}: Pflichtfelder fehlen: {', '.join(missing)}")
    unknown = sorted(k for k in obj if k not in allowed)
    if unknown:
        errors.append(
            f"{where}: unbekannte Felder nicht erlaubt (additionalProperties: false): "
            f"{', '.join(unknown)}"
        )
    return not missing and not unknown


def _is_iso_datetime(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return True


def _validate_input_field(spec: Any, where: str, errors: list[str]) -> None:
    if not _check_object(spec, ["name", "source"], ["name", "source"], where, errors):
        if not isinstance(spec, dict):
            return
    name = spec.get("name")
    if name is not None and not (isinstance(name, str) and len(name) <= 40):
        errors.append(f"{where}.name: darf hoechstens 40 Zeichen haben")
    if "source" in spec and (
        not isinstance(spec["source"], str) or spec["source"] not in INPUT_FIELD_SOURCES
    ):
        errors.append(
            f"{where}.source: unbekannter Wert '{spec['source']}' - zulaessig sind "
            f"ausschliesslich strukturierte Referenzen ({', '.join(sorted(INPUT_FIELD_SOURCES))}). "
            "Ein Freitextfeld als Eingabe fuer generierten Code ist nicht zulaessig "
            "(docs/27-werkbank-spezifikation.md Abschnitt 1.3/2.1)."
        )


def _validate_output_field(spec: Any, where: str, errors: list[str]) -> None:
    if not _check_object(spec, ["name", "type"], ["name", "type"], where, errors):
        if not isinstance(spec, dict):
            return
    name = spec.get("name")
    if name is not None and not (isinstance(name, str) and len(name) <= 40):
        errors.append(f"{where}.name: darf hoechstens 40 Zeichen haben")
    if "type" in spec and (
        not isinstance(spec["type"], str) or spec["type"] not in OUTPUT_FIELD_TYPES
    ):
        errors.append(
            f"{where}.type: unbekannter Wert '{spec['type']}' "
            f"(erlaubt: {', '.join(sorted(OUTPUT_FIELD_TYPES))})"
        )


def _validate_fields_array(fields: Any, where: str, errors: list[str], item_validator) -> None:
    if not isinstance(fields, list):
        errors.append(f"{where}: muss eine Liste sein")
        return
    if len(fields) > 10:
        errors.append(f"{where}: hoechstens 10 Eintraege erlaubt")
    for i, item in enumerate(fields):
        item_validator(item, f"{where}[{i}]", errors)


def _validate_input_contract(contract: Any, errors: list[str]) -> None:
    where = "tool_spec.input_contract"
    if contract is None:
        return
    _check_object(contract, ["fields"], ["fields"], where, errors)
    if isinstance(contract, dict) and "fields" in contract:
        _validate_fields_array(contract["fields"], f"{where}.fields", errors, _validate_input_field)


def _validate_output_contract(contract: Any, errors: list[str]) -> None:
    where = "tool_spec.output_contract"
    if contract is None:
        return
    _check_object(contract, ["render_as", "fields"], ["render_as", "fields"], where, errors)
    if not isinstance(contract, dict):
        return
    if "render_as" in contract and (
        not isinstance(contract["render_as"], str) or contract["render_as"] not in RENDER_AS_VALUES
    ):
        errors.append(
            f"{where}.render_as: unbekannter Wert '{contract['render_as']}' "
            f"(erlaubt: {', '.join(sorted(RENDER_AS_VALUES))})"
        )
    if "fields" in contract:
        _validate_fields_array(
            contract["fields"], f"{where}.fields", errors, _validate_output_field
        )


def _validate_code(code: Any, errors: list[str]) -> None:
    where = "tool_spec.code"
    if code is None:
        return
    code_keys = ["language", "source", "source_sha256"]
    _check_object(code, code_keys, code_keys, where, errors)
    if not isinstance(code, dict):
        return
    if "language" in code and code["language"] != CODE_LANGUAGE:
        errors.append(f"{where}.language: muss '{CODE_LANGUAGE}' sein")
    if "source" in code and not (isinstance(code["source"], str) and len(code["source"]) <= 20000):
        errors.append(f"{where}.source: muss ein String mit hoechstens 20000 Zeichen sein")
    if "source_sha256" in code and not (
        isinstance(code["source_sha256"], str) and _SHA256_RE.match(code["source_sha256"])
    ):
        errors.append(f"{where}.source_sha256: muss ein 64-stelliger Hex-SHA-256-Wert sein")


def _validate_resource_limits(limits: Any, errors: list[str]) -> None:
    where = "tool_spec.resource_limits"
    if limits is None:
        return
    limits_keys = ["timeout_ms", "max_output_bytes"]
    _check_object(limits, limits_keys, limits_keys, where, errors)
    if not isinstance(limits, dict):
        return
    if "timeout_ms" in limits and limits["timeout_ms"] != RESOURCE_LIMITS_TIMEOUT_MS:
        errors.append(f"{where}.timeout_ms: muss {RESOURCE_LIMITS_TIMEOUT_MS} sein")
    max_output_bytes = limits.get("max_output_bytes")
    if "max_output_bytes" in limits and max_output_bytes != RESOURCE_LIMITS_MAX_OUTPUT_BYTES:
        errors.append(
            f"{where}.max_output_bytes: muss {RESOURCE_LIMITS_MAX_OUTPUT_BYTES} sein"
        )


def _validate_labeling(labeling: Any, errors: list[str]) -> None:
    where = "tool_spec.labeling"
    if labeling is None:
        return
    labeling_keys = ["is_suggestion", "badge_text"]
    _check_object(labeling, labeling_keys, labeling_keys, where, errors)
    if not isinstance(labeling, dict):
        return
    if "is_suggestion" in labeling and labeling["is_suggestion"] is not True:
        errors.append(
            f"{where}.is_suggestion: muss true sein - die Vorschlags-Kennzeichnung ist "
            "verpflichtend, kein Darstellungsdetail "
            "(docs/27-werkbank-spezifikation.md Abschnitt 3.2)"
        )
    if "badge_text" in labeling and labeling["badge_text"] != LABELING_BADGE_TEXT:
        errors.append(f"{where}.badge_text: muss exakt '{LABELING_BADGE_TEXT}' sein")


def validate_tool_spec(spec: Any) -> ToolSpecValidation:
    """Validiert eine Tool-Spec v2 gegen Abschnitt 3.1. Sammelt alle Fehler,
    bricht nicht beim ersten ab (gleiches Prinzip wie ``load_content``)."""
    result = ToolSpecValidation()
    errors = result.errors

    if not _check_object(spec, ROOT_REQUIRED, ROOT_ALLOWED, "tool_spec", errors):
        if not isinstance(spec, dict):
            return result

    if "schema" in spec and spec["schema"] != TOOL_SPEC_SCHEMA_ID:
        errors.append(f"tool_spec.schema: muss '{TOOL_SPEC_SCHEMA_ID}' sein")

    tool_id = spec.get("tool_id")
    if "tool_id" in spec and not (isinstance(tool_id, str) and _UUID_RE.match(tool_id)):
        errors.append("tool_spec.tool_id: muss eine UUID sein")

    if "title" in spec and not (isinstance(spec["title"], str) and 1 <= len(spec["title"]) <= 80):
        errors.append("tool_spec.title: muss 1-80 Zeichen lang sein")

    if "description" in spec and not (
        isinstance(spec["description"], str) and len(spec["description"]) <= 280
    ):
        errors.append("tool_spec.description: darf hoechstens 280 Zeichen haben")

    if "area_scope" in spec and (
        not isinstance(spec["area_scope"], str) or spec["area_scope"] not in AREA_SCOPE_VALUES
    ):
        errors.append(
            f"tool_spec.area_scope: unbekannter Wert '{spec['area_scope']}' "
            f"(erlaubt: {', '.join(sorted(AREA_SCOPE_VALUES))})"
        )

    _validate_input_contract(spec.get("input_contract"), errors)
    _validate_output_contract(spec.get("output_contract"), errors)
    _validate_code(spec.get("code"), errors)

    if "runtime" in spec and (
        not isinstance(spec["runtime"], str) or spec["runtime"] not in RUNTIME_VALUES
    ):
        errors.append(
            f"tool_spec.runtime: unbekannter Wert '{spec['runtime']}' "
            f"(erlaubt: {', '.join(sorted(RUNTIME_VALUES))})"
        )

    _validate_resource_limits(spec.get("resource_limits"), errors)
    _validate_labeling(spec.get("labeling"), errors)

    if "created_at" in spec and not _is_iso_datetime(spec["created_at"]):
        errors.append("tool_spec.created_at: muss ein ISO-8601-Zeitstempel sein")

    if "prompt_fingerprint" in spec and not (
        isinstance(spec["prompt_fingerprint"], str) and len(spec["prompt_fingerprint"]) <= 64
    ):
        errors.append("tool_spec.prompt_fingerprint: darf hoechstens 64 Zeichen haben")

    return result
