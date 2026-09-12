"""Gutachten-Trainer: Strukturanalyse und Bewertung gegen den Erwartungshorizont."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.models import Case, Submission
from app.schemas import AnalyzeIn, CaseOut, SubmissionIn
from app.services.evaluator import get_evaluator
from app.services.gutachten import analyze

router = APIRouter(tags=["gutachten"])


@router.post("/gutachten/analyze")
def analyze_text(payload: AnalyzeIn, user: CurrentUser, db: DbSession) -> dict:
    """Sofortiges Struktur- und Stilfeedback - ohne KI, ohne Kosten, ohne Warten.

    Das ist der Endpunkt fuer den Uebungsmodus: Der Nutzer kann jederzeit
    schreiben und bekommt in Millisekunden eine reproduzierbare Rueckmeldung
    zum Gutachtenstil.
    """
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
    case = db.query(Case).filter_by(slug=slug).one_or_none()
    if case is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Fall nicht gefunden")
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
    evaluation = get_evaluator().evaluate(
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
