"""Tests fuer den Tool-Spec-v2-Validator (Werkbank, SUB-317).

Siehe docs/27-werkbank-spezifikation.md Abschnitt 3.1.
"""

import copy

from app.services.tool_spec import validate_tool_spec

VALID: dict = {
    "schema": "subsumo.werkbank.tool_spec.v2",
    "tool_id": "4f6f1a2e-8f0a-4a2b-9d3e-6a1c2b3d4e5f",
    "title": "Fällige Karten zählen",
    "description": "Zeigt, wie viele Karten heute fällig sind.",
    "area_scope": "zivilrecht",
    "input_contract": {
        "fields": [
            {"name": "topic", "source": "topic_slug_ref"},
            {"name": "srs_stand", "source": "own_srs_state"},
        ]
    },
    "output_contract": {
        "render_as": "counter",
        "fields": [{"name": "anzahl", "type": "number"}],
    },
    "code": {
        "language": "javascript_es2020",
        "source": "function execute(input) { return { anzahl: 0 }; }",
        "source_sha256": "a" * 64,
    },
    "runtime": "quickjs_sandboxed_v1",
    "resource_limits": {"timeout_ms": 300, "max_output_bytes": 8192},
    "labeling": {"is_suggestion": True, "badge_text": "KI-Vorschlag · ungeprüft"},
    "created_at": "2026-09-25T10:00:00Z",
    "prompt_fingerprint": "abc123",
}


def spec(**overrides) -> dict:
    result = copy.deepcopy(VALID)
    result.update(overrides)
    return result


def test_gueltige_spezifikation_wird_akzeptiert():
    result = validate_tool_spec(VALID)
    assert result.ok, result.errors


def test_freitext_eingabe_wird_abgelehnt():
    bad = spec()
    bad["input_contract"]["fields"][0]["source"] = "freitext"
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("source" in e and "Freitext" in e for e in result.errors)


def test_fehlendes_labeling_wird_abgelehnt():
    bad = spec()
    del bad["labeling"]
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("labeling" in e and "Pflichtfelder fehlen" in e for e in result.errors)


def test_verletzter_output_contract_wird_abgelehnt():
    bad = spec()
    bad["output_contract"]["fields"][0]["type"] = "object"
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("output_contract" in e and "type" in e for e in result.errors)


def test_labeling_is_suggestion_false_wird_abgelehnt():
    bad = spec()
    bad["labeling"]["is_suggestion"] = False
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("is_suggestion" in e for e in result.errors)


def test_labeling_falscher_badge_text_wird_abgelehnt():
    bad = spec()
    bad["labeling"]["badge_text"] = "Von Nutzern erstellt"
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("badge_text" in e for e in result.errors)


def test_unbekanntes_wurzelfeld_wird_abgelehnt():
    bad = spec()
    bad["extra_feld"] = "nicht erlaubt"
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("additionalProperties" in e for e in result.errors)


def test_unbekanntes_area_scope_wird_abgelehnt():
    bad = spec(area_scope="seerecht")
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("area_scope" in e for e in result.errors)


def test_render_as_ausserhalb_der_enum_wird_abgelehnt():
    bad = spec()
    bad["output_contract"]["render_as"] = "raw_html"
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("render_as" in e for e in result.errors)


def test_falsche_code_language_wird_abgelehnt():
    bad = spec()
    bad["code"]["language"] = "python"
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("language" in e for e in result.errors)


def test_ungueltiger_source_sha256_wird_abgelehnt():
    bad = spec()
    bad["code"]["source_sha256"] = "nicht-hex"
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("source_sha256" in e for e in result.errors)


def test_falsches_timeout_wird_abgelehnt():
    bad = spec()
    bad["resource_limits"]["timeout_ms"] = 5000
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("timeout_ms" in e for e in result.errors)


def test_ungueltige_tool_id_wird_abgelehnt():
    bad = spec(tool_id="nicht-uuid")
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("tool_id" in e for e in result.errors)


def test_ungueltiges_created_at_wird_abgelehnt():
    bad = spec(created_at="gestern")
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("created_at" in e for e in result.errors)


def test_zu_viele_input_felder_werden_abgelehnt():
    bad = spec()
    bad["input_contract"]["fields"] = [
        {"name": f"f{i}", "source": "count_int"} for i in range(11)
    ]
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("input_contract.fields" in e and "10" in e for e in result.errors)


def test_fehlendes_pflichtfeld_auf_wurzelebene_wird_abgelehnt():
    bad = spec()
    del bad["runtime"]
    result = validate_tool_spec(bad)
    assert not result.ok
    assert any("runtime" in e and "Pflichtfelder fehlen" in e for e in result.errors)
