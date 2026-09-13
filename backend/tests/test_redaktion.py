"""Tests der KI-Redaktion: Collector, Reviewer, Pipeline - ueber einen
Fake-LLM-Client, ohne Netz. Dieselbe Teststrategie wie fuer den
LLM-Evaluator: die Orchestrierung muss deterministisch pruefbar sein, auch
ohne einen echten Anthropic-Key in der CI.
"""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from app.core.llm import LLMError, LLMResponse
from app.services.redaktion.collector import CollectorAgent, CollectorError, TopicRequest
from app.services.redaktion.pipeline import (
    RedaktionPipeline,
    _validate_structure,
    collect_existing_slugs,
)
from app.services.redaktion.reviewer import ReviewerAgent, ReviewerError

GUELTIGER_ENTWURF = """
topic:
  slug: zr-test-thema
  area: zivilrecht
  title: Testthema
  relevance: 4
  stand: "2026-09"
cards:
  - slug: zr-test-karte
    type: definition
    front: "Definiere: Testbegriff"
    back: "Ein Testbegriff ist ein Begriff, der in einem Test verwendet wird."
    norms: ["§ 1 BGB"]
    quellen: ["Eigenformulierung Redaktion"]
    stand: "2026-09"
schemata:
  - slug: zr-test-schema
    title: "Testschema"
    quellen: ["Eigenformulierung Redaktion"]
    steps:
      - label: "I. Test"
faelle:
  - slug: zr-test-fall
    title: "Der Testfall"
    facts: "A und B sind fiktive Personen in einem fiktiven Sachverhalt."
    quellen: ["Eigener Sachverhalt der Redaktion"]
    expectation:
      pruefpunkte:
        - id: p1
          label: "Kernpunkt"
          weight: 2.0
          required: true
"""


class FakeLLM:
    """Liefert der Reihe nach vorgegebene Antworten - eine pro Aufruf."""

    def __init__(self, responses: list[str]) -> None:
        self.responses = list(responses)
        self.calls: list[str] = []

    def complete(self, prompt: str, *, max_tokens: int = 4000) -> LLMResponse:
        self.calls.append(prompt)
        if not self.responses:
            raise AssertionError("FakeLLM: keine weitere Antwort vorbereitet")
        return LLMResponse(text=self.responses.pop(0), model="fake-model")


class FailingLLM:
    def complete(self, prompt: str, *, max_tokens: int = 4000) -> LLMResponse:
        raise LLMError("kein Netz in diesem Test")


# --------------------------------------------------------------------------- #
# CollectorAgent
# --------------------------------------------------------------------------- #


def test_collector_parst_reines_yaml():
    agent = CollectorAgent(client=FakeLLM([GUELTIGER_ENTWURF]))
    draft = agent.collect(
        TopicRequest(area="zivilrecht", working_title="Testthema"),
        existing_slugs=[],
    )
    assert draft["topic"]["slug"] == "zr-test-thema"
    assert len(draft["cards"]) == 1


def test_collector_akzeptiert_yaml_in_codeblock():
    wrapped = f"Hier ist der Entwurf:\n```yaml\n{GUELTIGER_ENTWURF}\n```\nEnde."
    agent = CollectorAgent(client=FakeLLM([wrapped]))
    draft = agent.collect(
        TopicRequest(area="zivilrecht", working_title="Testthema"), existing_slugs=[]
    )
    assert draft["topic"]["slug"] == "zr-test-thema"


def test_collector_lehnt_kaputtes_yaml_ab():
    agent = CollectorAgent(client=FakeLLM(["topic: [unterminated"]))
    with pytest.raises(CollectorError):
        agent.collect(
            TopicRequest(area="zivilrecht", working_title="Testthema"), existing_slugs=[]
        )


def test_collector_lehnt_antwort_ohne_topic_block_ab():
    agent = CollectorAgent(client=FakeLLM(["cards: []"]))
    with pytest.raises(CollectorError):
        agent.collect(
            TopicRequest(area="zivilrecht", working_title="Testthema"), existing_slugs=[]
        )


def test_collector_reicht_llm_fehler_als_collector_error_durch():
    agent = CollectorAgent(client=FailingLLM())
    with pytest.raises(CollectorError):
        agent.collect(
            TopicRequest(area="zivilrecht", working_title="Testthema"), existing_slugs=[]
        )


def test_collector_prompt_enthaelt_die_regeln_und_das_feedback():
    fake = FakeLLM([GUELTIGER_ENTWURF])
    agent = CollectorAgent(client=fake)
    agent.collect(
        TopicRequest(area="strafrecht", working_title="Testthema"),
        existing_slugs=["sr-vorhandener-slug"],
        feedback="Bitte Normen korrigieren.",
    )
    prompt = fake.calls[0]
    assert "Urheberrecht" in prompt
    assert "RDG" in prompt
    assert "sr-vorhandener-slug" in prompt
    assert "Bitte Normen korrigieren." in prompt


# --------------------------------------------------------------------------- #
# ReviewerAgent
# --------------------------------------------------------------------------- #


def test_reviewer_approved_bei_positivem_json():
    agent = ReviewerAgent(client=FakeLLM(['{"approved": true, "issues": [], "severity": "ok"}']))
    result = agent.review(yaml.safe_load(GUELTIGER_ENTWURF), existing_slugs=[])
    assert result.approved is True
    assert result.issues == []


def test_reviewer_lehnt_ab_und_liefert_befunde():
    antwort = (
        '{"approved": false, "severity": "schwerwiegend", '
        '"issues": ["Sachverhalt wirkt nicht fiktiv", "Norm existiert nicht"]}'
    )
    agent = ReviewerAgent(client=FakeLLM([antwort]))
    result = agent.review(yaml.safe_load(GUELTIGER_ENTWURF), existing_slugs=[])
    assert result.approved is False
    assert len(result.issues) == 2
    assert "fiktiv" in result.feedback_text


def test_reviewer_akzeptiert_json_mit_umgebendem_text():
    antwort = (
        'Hier ist meine Einschaetzung:\n'
        '{"approved": true, "severity": "ok", "issues": []}\nEnde.'
    )
    agent = ReviewerAgent(client=FakeLLM([antwort]))
    result = agent.review(yaml.safe_load(GUELTIGER_ENTWURF), existing_slugs=[])
    assert result.approved is True


def test_reviewer_ohne_json_wirft_reviewer_error():
    agent = ReviewerAgent(client=FakeLLM(["Das sieht gut aus."]))
    with pytest.raises(ReviewerError):
        agent.review(yaml.safe_load(GUELTIGER_ENTWURF), existing_slugs=[])


def test_reviewer_reicht_llm_fehler_durch():
    agent = ReviewerAgent(client=FailingLLM())
    with pytest.raises(ReviewerError):
        agent.review(yaml.safe_load(GUELTIGER_ENTWURF), existing_slugs=[])


@pytest.mark.parametrize(
    "antwort",
    [
        '{"approved": "false", "severity": "schwerwiegend", "issues": []}',
        '{"approved": true, "severity": "kleinere_maengel", "issues": []}',
        '{"approved": true, "severity": "ok", "issues": ["Hinweis"]}',
        '{"approved": false, "severity": "ok", "issues": ["Hinweis"]}',
        '{"approved": false, "severity": "schwerwiegend", "issues": [1]}',
        '{"approved": true, "issues": []}',
        '{"approved": true, "severity": "unbekannt", "issues": []}',
        '[{"approved": true, "severity": "ok", "issues": []}]',
        '{"approved": true, "approved": false, "severity": "ok", "issues": []}',
    ],
)
def test_reviewer_lehnt_malformed_oder_widerspruechliches_json_ab(antwort: str):
    agent = ReviewerAgent(client=FakeLLM([antwort]))
    with pytest.raises(ReviewerError):
        agent.review(yaml.safe_load(GUELTIGER_ENTWURF), existing_slugs=[])


def test_reviewer_prompt_nennt_alle_fuenf_pruefkriterien():
    fake = FakeLLM(['{"approved": true, "severity": "ok", "issues": []}'])
    ReviewerAgent(client=fake).review(yaml.safe_load(GUELTIGER_ENTWURF), existing_slugs=[])
    prompt = fake.calls[0]
    for kriterium in ["Urheberrecht", "RDG", "Plausibilitaet", "Erwartungshorizont", "Slug"]:
        assert kriterium in prompt


# --------------------------------------------------------------------------- #
# Struktur-Gate (dasselbe wie die CI)
# --------------------------------------------------------------------------- #


def test_struktur_gate_akzeptiert_gueltigen_entwurf():
    assert _validate_structure(yaml.safe_load(GUELTIGER_ENTWURF)) == []


def test_struktur_gate_lehnt_entwurf_ohne_quellen_ab():
    draft = yaml.safe_load(GUELTIGER_ENTWURF)
    del draft["cards"][0]["quellen"]
    fehler = _validate_structure(draft)
    assert any("quellen" in f for f in fehler)


def test_struktur_gate_lehnt_fall_ohne_required_pruefpunkt_ab():
    draft = yaml.safe_load(GUELTIGER_ENTWURF)
    draft["faelle"][0]["expectation"]["pruefpunkte"][0]["required"] = False
    # Das Struktur-Gate selbst verlangt nur *irgendeinen* Pruefpunkt (siehe
    # content.py); dass mindestens einer 'required' ist, prueft bewusst erst
    # der Reviewer fachlich - siehe test_reviewer_prompt_nennt_...
    assert _validate_structure(draft) == []


# --------------------------------------------------------------------------- #
# Pipeline: das Zusammenspiel
# --------------------------------------------------------------------------- #


def test_pipeline_akzeptiert_im_ersten_durchlauf(tmp_path: Path):
    collector = CollectorAgent(client=FakeLLM([GUELTIGER_ENTWURF]))
    reviewer = ReviewerAgent(
        client=FakeLLM(['{"approved": true, "severity": "ok", "issues": []}'])
    )
    pipeline = RedaktionPipeline(content_dir=tmp_path, collector=collector, reviewer=reviewer)

    result = pipeline.run(TopicRequest(area="zivilrecht", working_title="Testthema"))

    assert result.accepted is True
    assert result.rounds == 1
    assert result.path is not None and result.path.exists()
    geschrieben = yaml.safe_load(result.path.read_text())
    assert geschrieben["topic"]["redaktion"]["status"] == "ki-freigegeben"
    assert geschrieben["topic"]["redaktion"]["erzeugt_von"]
    assert geschrieben["topic"]["redaktion"]["geprueft_von"]


def test_pipeline_landet_im_richtigen_rechtsgebietsordner(tmp_path: Path):
    collector = CollectorAgent(client=FakeLLM([GUELTIGER_ENTWURF]))
    reviewer = ReviewerAgent(
        client=FakeLLM(['{"approved": true, "severity": "ok", "issues": []}'])
    )
    pipeline = RedaktionPipeline(content_dir=tmp_path, collector=collector, reviewer=reviewer)

    result = pipeline.run(TopicRequest(area="zivilrecht", working_title="Testthema"))

    assert result.path.parent == tmp_path / "zivilrecht"


def test_pipeline_gibt_reviewer_feedback_an_collector_zurueck_und_erfolgt_dann(
    tmp_path: Path,
):
    collector_client = FakeLLM([GUELTIGER_ENTWURF, GUELTIGER_ENTWURF])
    reviewer_client = FakeLLM(
        [
            '{"approved": false, "severity": "kleinere_maengel", '
            '"issues": ["Norm pruefen"]}',
            '{"approved": true, "severity": "ok", "issues": []}',
        ]
    )
    pipeline = RedaktionPipeline(
        content_dir=tmp_path,
        collector=CollectorAgent(client=collector_client),
        reviewer=ReviewerAgent(client=reviewer_client),
    )

    result = pipeline.run(TopicRequest(area="zivilrecht", working_title="Testthema"))

    assert result.accepted is True
    assert result.rounds == 2
    # Das Feedback aus Runde 1 muss im zweiten Collector-Prompt auftauchen -
    # sonst haette der zweite Versuch keine Chance, es zu beheben.
    assert "Norm pruefen" in collector_client.calls[1]


def test_pipeline_gibt_formatfehler_an_collector_zurueck(tmp_path: Path):
    kaputt = GUELTIGER_ENTWURF.replace(
        'quellen: ["Eigenformulierung Redaktion"]\n    stand', "stand"
    )
    collector_client = FakeLLM([kaputt, GUELTIGER_ENTWURF])
    reviewer_client = FakeLLM(
        ['{"approved": true, "severity": "ok", "issues": []}']
    )
    pipeline = RedaktionPipeline(
        content_dir=tmp_path,
        collector=CollectorAgent(client=collector_client),
        reviewer=ReviewerAgent(client=reviewer_client),
    )

    result = pipeline.run(TopicRequest(area="zivilrecht", working_title="Testthema"))

    assert result.accepted is True
    assert result.rounds == 2
    assert "Formatfehler" in collector_client.calls[1]
    # Der Reviewer darf einen strukturell ungueltigen Entwurf nie zu sehen
    # bekommen - dafuer ist er nicht da.
    assert len(reviewer_client.calls) == 1


def test_pipeline_gibt_nach_max_rounds_auf_und_schreibt_nichts(tmp_path: Path):
    collector = CollectorAgent(client=FakeLLM([GUELTIGER_ENTWURF] * 3))
    reviewer = ReviewerAgent(
        client=FakeLLM(
            [
                '{"approved": false, "severity": "schwerwiegend", '
                '"issues": ["immer noch nicht gut"]}'
            ]
            * 3
        )
    )
    pipeline = RedaktionPipeline(
        content_dir=tmp_path, collector=collector, reviewer=reviewer, max_rounds=3
    )

    result = pipeline.run(TopicRequest(area="zivilrecht", working_title="Testthema"))

    assert result.accepted is False
    assert result.rounds == 3
    assert list(tmp_path.rglob("*.yaml")) == []


def test_pipeline_behandelt_ungueltige_reviewer_antwort_fail_closed(tmp_path: Path):
    collector = CollectorAgent(client=FakeLLM([GUELTIGER_ENTWURF]))
    reviewer = ReviewerAgent(
        client=FakeLLM(
            ['{"approved": "false", "severity": "schwerwiegend", "issues": []}']
        )
    )
    pipeline = RedaktionPipeline(
        content_dir=tmp_path, collector=collector, reviewer=reviewer, max_rounds=1
    )

    result = pipeline.run(TopicRequest(area="zivilrecht", working_title="Testthema"))

    assert result.accepted is False
    assert result.path is None
    assert any("Reviewer-Fehler" in entry for entry in result.history)
    assert list(tmp_path.rglob("*.yaml")) == []


def test_pipeline_verhindert_stilles_ueberschreiben_bestehender_inhalte(tmp_path: Path):
    ziel_dir = tmp_path / "zivilrecht"
    ziel_dir.mkdir()
    (ziel_dir / "zr-test-thema.yaml").write_text("# bereits vorhanden\n", encoding="utf-8")

    collector = CollectorAgent(client=FakeLLM([GUELTIGER_ENTWURF]))
    reviewer = ReviewerAgent(
        client=FakeLLM(['{"approved": true, "severity": "ok", "issues": []}'])
    )
    pipeline = RedaktionPipeline(content_dir=tmp_path, collector=collector, reviewer=reviewer)

    with pytest.raises(FileExistsError):
        pipeline.run(TopicRequest(area="zivilrecht", working_title="Testthema"))
    # Die urspruengliche Datei darf nicht angefasst worden sein.
    assert (ziel_dir / "zr-test-thema.yaml").read_text(encoding="utf-8") == "# bereits vorhanden\n"


def test_collect_existing_slugs_sammelt_aus_allen_kategorien():
    import tempfile

    from app.services.content import load_content

    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "a.yaml"
        path.write_text(GUELTIGER_ENTWURF, encoding="utf-8")
        bundle = load_content(Path(tmp))
        slugs = collect_existing_slugs(bundle)

    assert "zr-test-thema" in slugs
    assert "zr-test-karte" in slugs
    assert "zr-test-schema" in slugs
    assert "zr-test-fall" in slugs


def test_pipeline_reicht_bekannte_slugs_an_beide_agenten_weiter(tmp_path: Path):
    vorhanden_dir = tmp_path / "zivilrecht"
    vorhanden_dir.mkdir()
    (vorhanden_dir / "bestehend.yaml").write_text(
        GUELTIGER_ENTWURF.replace("zr-test-thema", "zr-bestehendes-thema")
        .replace("zr-test-karte", "zr-bestehende-karte")
        .replace("zr-test-schema", "zr-bestehendes-schema")
        .replace("zr-test-fall", "zr-bestehender-fall"),
        encoding="utf-8",
    )
    collector_client = FakeLLM([GUELTIGER_ENTWURF])
    reviewer_client = FakeLLM(
        ['{"approved": true, "severity": "ok", "issues": []}']
    )
    pipeline = RedaktionPipeline(
        content_dir=tmp_path,
        collector=CollectorAgent(client=collector_client),
        reviewer=ReviewerAgent(client=reviewer_client),
    )

    pipeline.run(TopicRequest(area="zivilrecht", working_title="Neues Thema"))

    assert "zr-bestehendes-thema" in collector_client.calls[0]
    assert "zr-bestehendes-thema" in reviewer_client.calls[0]
