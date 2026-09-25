"""Gutachten-Trainer: Strukturanalyse und Bewertung gegen den Erwartungshorizont."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.config import get_settings
from app.models import Card, CardStateEnum, Case, Submission, UserCard
from app.schemas import AnalyzeIn, CaseOut, SubmissionIn
from app.services import limits
from app.services.evaluator import Evaluation, get_evaluator, parse_expectation
from app.services.gutachten import analyze

router = APIRouter(tags=["gutachten"])


def _stelle_verknuepfte_karten_faellig(
    db: DbSession, *, user_id: int, case: Case, evaluation: Evaluation
) -> None:
    """Verzahnung Pruefpunkt -> Wiederholungskarte (SUB-263).

    Fuer jeden verfehlten Pruefpunkt mit ``card_slugs`` werden die
    referenzierten Karten des Nutzers faellig gestellt; bei einem verfehlten
    Pflichtpruefpunkt zusaetzlich auf ``relearning`` zurueckgesetzt. Nur
    bestehende UserCard-Zeilen werden aktualisiert - eine Karte, die der
    Nutzer noch nie gelernt hat, wird dadurch nicht neu angelegt, sondern
    bleibt bis zum ersten regulaeren Lernen unberuehrt.
    """
    checkpoints = parse_expectation(case.expectation or {})
    results_by_id = {r.id: r for r in evaluation.checkpoints}

    due_slugs: set[str] = set()
    relearning_slugs: set[str] = set()
    for cp in checkpoints:
        if not cp.card_slugs:
            continue
        result = results_by_id.get(cp.id)
        if result is None or result.hit:
            continue
        due_slugs.update(cp.card_slugs)
        if cp.required:
            relearning_slugs.update(cp.card_slugs)

    if not due_slugs:
        return

    now = datetime.now(UTC)
    slug_to_id = dict(db.query(Card.slug, Card.id).filter(Card.slug.in_(due_slugs)).all())

    plain_due_ids = [slug_to_id[s] for s in due_slugs - relearning_slugs if s in slug_to_id]
    if plain_due_ids:
        db.query(UserCard).filter(
            UserCard.user_id == user_id, UserCard.card_id.in_(plain_due_ids)
        ).update({"due": now}, synchronize_session=False)

    relearning_ids = [slug_to_id[s] for s in relearning_slugs if s in slug_to_id]
    if relearning_ids:
        db.query(UserCard).filter(
            UserCard.user_id == user_id, UserCard.card_id.in_(relearning_ids)
        ).update({"due": now, "state": CardStateEnum.RELEARNING.value}, synchronize_session=False)


@router.post("/gutachten/analyze")
def analyze_text(payload: AnalyzeIn, user: CurrentUser, db: DbSession) -> dict:
    """Sofortiges Struktur- und Stilfeedback - ohne KI, ohne Kosten, ohne Warten.

    Das ist der Endpunkt fuer den Uebungsmodus: Der Nutzer kann jederzeit
    schreiben und bekommt in Millisekunden eine reproduzierbare Rueckmeldung
    zum Gutachtenstil.

    Free-Tier-Limit (docs/20 B2): max. 3 Aufrufe/Woche, serverseitig gezaehlt.
    """
    settings = get_settings()
    if limits.is_free_tier(user, settings):
        limits.enforce_analyze_quota(db, user, now=datetime.now(UTC))

    expected: list[str] = []
    if payload.case_slug:
        case = db.query(Case).filter_by(slug=payload.case_slug).one_or_none()
        if case is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Fall nicht gefunden")
        for pruefpunkt in (case.expectation or {}).get("pruefpunkte", []):
            expected.extend(pruefpunkt.get("norms", []))
    return analyze(payload.text, expected_norms=expected or None).to_dict()


@router.get("/cases/{slug}", response_model=CaseOut)
def get_case(slug: str, user: CurrentUser, db: DbSession) -> Case:
    """Free-Tier-Limit (docs/20 B2): ab dem dritten unterschiedlichen Fall 403."""
    case = db.query(Case).filter_by(slug=slug).one_or_none()
    if case is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Fall nicht gefunden")
    settings = get_settings()
    if limits.is_free_tier(user, settings):
        limits.enforce_case_access(db, user, case)
    return case


@router.post("/cases/{slug}/submit", status_code=status.HTTP_201_CREATED)
def submit_case(slug: str, payload: SubmissionIn, user: CurrentUser, db: DbSession) -> dict:
    """Gutachten abgeben und vollstaendig bewerten lassen.

    Die Bewertung erfolgt ausschliesslich gegen den hinterlegten
    Erwartungshorizont dieses Uebungsfalls. Einen Endpunkt fuer beliebige
    Sachverhalte gibt es bewusst nicht (siehe docs/06-recht-compliance.md).
    """
    case = db.query(Case).filter_by(slug=slug).one_or_none()
    if case is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Fall nicht gefunden")

    expected_norms: list[str] = []
    for pruefpunkt in (case.expectation or {}).get("pruefpunkte", []):
        expected_norms.extend(pruefpunkt.get("norms", []))

    structure = analyze(payload.text, expected_norms=expected_norms or None)
    # Ohne Einwilligung (SUB-133) laeuft ausschliesslich die Heuristik - die
    # Abgabe wird deshalb nie abgelehnt, nur der Evaluator umgeschaltet. Das
    # Ergebnis-Feld "engine" macht sichtbar, welcher Evaluator gelaufen ist.
    evaluator = get_evaluator(
        consented=user.ai_review_consent_at is not None, db=db, user=user
    )
    evaluation = evaluator.evaluate(
        text=payload.text, expectation=case.expectation or {}, structure=structure
    )

    report = {"structure": structure.to_dict(), "evaluation": evaluation.to_dict()}
    submission = Submission(
        user_id=user.id,
        case_id=case.id,
        text=payload.text,
        mode=payload.mode,
        duration_s=payload.duration_s,
        structure_score=structure.score,
        points=evaluation.points,
        report=report,
    )
    db.add(submission)
    _stelle_verknuepfte_karten_faellig(db, user_id=user.id, case=case, evaluation=evaluation)
    db.commit()

    return {
        "submission_id": submission.id,
        "case_slug": case.slug,
        **report,
        # Erst nach der Abgabe: Musterloesung und Erwartungshorizont.
        "expectation": case.expectation,
        "steps": case.steps,
    }


@router.get("/submissions")
def list_submissions(user: CurrentUser, db: DbSession, limit: int = 20) -> list[dict]:
    rows = (
        db.query(Submission)
        .filter_by(user_id=user.id)
        .order_by(Submission.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": s.id,
            "case_id": s.case_id,
            "mode": s.mode,
            "duration_s": s.duration_s,
            "structure_score": s.structure_score,
            "points": s.points,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        }
        for s in rows
    ]
