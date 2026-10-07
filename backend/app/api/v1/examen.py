"""Examen-Reiter: Bundesland-Profile, Universitaeten, Kurs-Decks, Cockpit.

Konzept: docs/32-examensvorbereitung.md. Die Listen-Endpunkte sind wie
``/content/*`` oeffentlich (Onboarding vor dem Login, Landing-Page); Decks
und Cockpit brauchen den Nutzer, weil sie seinen Kartenzustand und sein
Bundesland einrechnen.
"""

from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import APIRouter, HTTPException, Query, status

from app.api.deps import CurrentUser, DbSession
from app.config import get_settings
from app.core.timeutil import as_utc
from app.models import DEFAULT_FACHRICHTUNG, Bundesland, Fachrichtung, Kurs, Universitaet, UserCard
from app.services import examen, lernprofil, srs
from app.services.content import bundesland_key
from app.services.planner import generate_plan

router = APIRouter(prefix="/examen", tags=["examen"])


@router.get("/fachrichtungen")
def fachrichtungen(db: DbSession) -> list[dict]:
    """Alle Fachrichtungen (docs/34) mit Fachgebieten, Begriffen und Methodik."""
    return [
        examen.fachrichtung_info(db, f.slug)
        for f in db.query(Fachrichtung).order_by(Fachrichtung.slug).all()
    ]


@router.get("/bundeslaender")
def bundeslaender(db: DbSession, fachrichtung: str = DEFAULT_FACHRICHTUNG) -> list[dict]:
    """Alle Laender mit Klausurstruktur je Fachrichtung - fuer die Auswahl im Profil."""
    return [
        examen.bundesland_summary(land)
        for land in db.query(Bundesland)
        .filter(Bundesland.fachrichtung == fachrichtung)
        .order_by(Bundesland.name)
        .all()
    ]


@router.get("/bundeslaender/{code}")
def bundesland(code: str, db: DbSession, fachrichtung: str = DEFAULT_FACHRICHTUNG) -> dict:
    land = db.get(Bundesland, bundesland_key(fachrichtung, code))
    if land is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bundesland nicht gefunden")
    return examen.bundesland_profile(db, land)


@router.get("/universitaeten")
def universitaeten(
    db: DbSession, bundesland: str | None = None, fachrichtung: str | None = None
) -> list[dict]:
    query = db.query(Universitaet)
    if bundesland:
        query = query.filter(Universitaet.bundesland == bundesland.upper())
    return [
        {
            "slug": u.slug,
            "name": u.name,
            "kurzname": u.data.get("kurzname", u.name),
            "stadt": u.data.get("stadt", ""),
            "bundesland": u.bundesland,
            "traegerschaft": u.data.get("traegerschaft", "staatlich"),
            "fachrichtungen": u.data.get("fachrichtungen") or [DEFAULT_FACHRICHTUNG],
        }
        for u in query.order_by(Universitaet.bundesland, Universitaet.name).all()
        if fachrichtung is None
        or fachrichtung in (u.data.get("fachrichtungen") or [DEFAULT_FACHRICHTUNG])
    ]


@router.get("/universitaeten/{slug}")
def universitaet(slug: str, db: DbSession) -> dict:
    uni = db.query(Universitaet).filter_by(slug=slug).one_or_none()
    if uni is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Universitaet nicht gefunden")
    land = db.get(Bundesland, bundesland_key(DEFAULT_FACHRICHTUNG, uni.bundesland))
    angebot = uni.data.get("fachrichtungen") or [DEFAULT_FACHRICHTUNG]
    return {
        **uni.data,
        "pruefstatus": (uni.data.get("redaktion") or {}).get("status", "mensch-freigegeben"),
        "bundesland_name": land.name if land else uni.bundesland,
        "kurse": [kurs for fach in angebot for kurs in examen.university_courses(db, uni, fach)],
    }


@router.get("/kurse")
def kurse(db: DbSession, fachrichtung: str = DEFAULT_FACHRICHTUNG) -> list[dict]:
    """Kanonischer Kurskatalog je Fachrichtung (docs/32 Abschnitt 3.3, docs/34)."""
    return examen.university_courses(db, None, fachrichtung)


@router.get("/kurse/{slug}/deck")
def kurs_deck(slug: str, user: CurrentUser, db: DbSession) -> dict:
    """Vorbereitungsdeck eines Kurses, zugeschnitten auf Bundesland und Kartenzustand."""
    kurs = db.query(Kurs).filter_by(slug=slug).one_or_none()
    if kurs is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Kurs nicht gefunden")
    return examen.resolve_deck(db, user, kurs)


@router.get("/cockpit")
def cockpit(
    user: CurrentUser,
    db: DbSession,
    plan_days: int = Query(default=7, ge=1, le=30),
) -> dict:
    """Alles, was der Examen-Reiter auf einen Blick braucht.

    Profil, Countdown und Phase, Examensreife mit Komponenten, das Profil des
    Bundeslands, die Kurs-Decks der Universitaet, das Landesrecht-Deck,
    Schwachstellen aus den letzten Abgaben, der Klausurvorschlag fuer den
    naechsten Klausurtag und - bei gesetztem Examensdatum - die naechsten
    Plantage.
    """
    now = datetime.now(UTC)
    today = date.today()
    fach_slug = examen.user_fachrichtung(user)
    fach = examen.fachrichtung_info(db, fach_slug)
    areas = [a["slug"] for a in fach["areas"]]
    land = examen.bundesland_for(db, user)
    uni = (
        db.query(Universitaet).filter_by(slug=user.universitaet_slug).one_or_none()
        if user.universitaet_slug
        else None
    )
    profil = lernprofil.get_profil(user)
    progress = examen.topic_progress(db, user, now=now)
    reife = examen.readiness(
        db, user, progress=progress, land=land, now=now, areas=areas, fachrichtung=fach
    )
    phase = examen.phase_info(user, today)

    decks = [
        examen.resolve_deck(db, user, kurs, progress=progress)
        for kurs in _kurse_in_reihenfolge(db, uni, fach_slug)
    ]
    eigene_decks = [
        examen.resolve_eigenes_deck(db, user, d.model_dump(), progress=progress)
        for d in profil.eigene_decks
    ]
    landesrecht = [p.to_dict() for p in progress.values() if p.bundesland is not None]
    schwachstellen = examen.weak_spots(db, user)
    schwachstellen["technik_tipp"] = lernprofil.technik_tipp(schwachstellen["strukturfehler"])
    klausur_vorschlag = examen.next_klausur(
        db, user, progress=progress, readiness_by_area=reife["by_area"]
    )
    persona = lernprofil.persona(profil, user)
    pausiert = lernprofil.pausierte_themen(profil)
    naechster_schritt = lernprofil.next_step(
        lernprofil.NextStepInput(
            eingerichtet=lernprofil.ist_eingerichtet(user),
            persona=persona,
            due_cards=sum(p.cards_due for p in progress.values() if p.slug not in pausiert),
            decks=[
                {
                    "slug": d["slug"],
                    "title": d["title"],
                    "semester": d.get("semester_default"),
                    "mastery": d.get("mastery", 0.0),
                    "examenskurs": d.get("examenskurs", False),
                }
                for d in decks
            ],
            semester=profil.semester,
            schwachstellen=schwachstellen["themen"],
            faelle_je_thema=lernprofil.faelle_je_thema(db, set(progress) - pausiert),
            schwaechstes_thema=examen.schwaechstes_thema(progress, profil),
            klausur_heute=profil.wochenklausur
            and examen.ist_klausurtag(today, profil.klausur_wochentag),
            klausur_vorschlag=klausur_vorschlag,
        )
    )

    plan_days_out: list[dict] = []
    if user.exam_date is not None and phase and phase["tage_bis_examen"] > 0:
        settings = get_settings()
        exam_day = date.fromisoformat(phase["exam_date"])
        states = db.query(UserCard).filter(UserCard.user_id == user.id).all()
        forecast = srs.forecast_load(
            [
                srs.CardState(
                    stability=uc.stability,
                    difficulty=uc.difficulty,
                    due=as_utc(uc.due),
                    last_review=as_utc(uc.last_review),
                    reps=uc.reps,
                    lapses=uc.lapses,
                    state=uc.state,
                )
                for uc in states
            ],
            days=min(plan_days, 400),
            now=now,
        )
        plan = generate_plan(
            examen.topic_inputs(db, user),
            start=today,
            exam_date=exam_day,
            daily_minutes=user.daily_minutes or settings.default_daily_minutes,
            due_forecast=forecast,
            seconds_per_card=settings.seconds_per_card,
            rest_weekdays=set(profil.ruhetage),
            horizon_days=plan_days,
            klausur_weekday=profil.klausur_wochentag,
            klausuren=profil.wochenklausur,
        )
        plan_days_out = plan.to_dict()["days"]

    return {
        "profil": {
            "bundesland": examen.bundesland_summary(land) if land else None,
            "universitaet": (
                {
                    "slug": uni.slug,
                    "name": uni.name,
                    "kurzname": uni.data.get("kurzname", uni.name),
                }
                if uni
                else None
            ),
            "exam_date": phase["exam_date"] if phase else None,
            "daily_minutes": user.daily_minutes,
            "vollstaendig": bool(land and user.exam_date),
        },
        "fachrichtung": fach,
        "lernprofil": {
            **profil.model_dump(),
            "eingerichtet": lernprofil.ist_eingerichtet(user),
            "persona": persona,
            "persona_label": lernprofil.PERSONA_LABELS.get(persona, persona),
        },
        "naechster_schritt": naechster_schritt,
        "semesterstoff": examen.semesterstoff(decks, profil.semester),
        "themen": [
            {"slug": p.slug, "title": p.title, "area": p.area, "bundesland": p.bundesland}
            for p in progress.values()
        ],
        "phase": phase,
        "examensreife": reife,
        "bundesland": examen.bundesland_profile(db, land) if land else None,
        "kurs_decks": decks,
        "eigene_decks": eigene_decks,
        "landesrecht_deck": {
            "topics": landesrecht,
            "cards_total": sum(t["cards_total"] for t in landesrecht),
            "cards_mature": sum(t["cards_mature"] for t in landesrecht),
            "cards_due": sum(t["cards_due"] for t in landesrecht),
        },
        "schwachstellen": schwachstellen,
        "naechste_klausur": {
            "datum": examen.next_klausurtag(today, profil.klausur_wochentag).isoformat(),
            "heute": profil.wochenklausur
            and examen.ist_klausurtag(today, profil.klausur_wochentag),
            "aktiv": profil.wochenklausur,
            "vorschlag": klausur_vorschlag,
        },
        "checkliste": examen.checkliste(land, phase),
        "plan": plan_days_out,
    }


def _kurse_in_reihenfolge(
    db: DbSession, uni: Universitaet | None, fachrichtung: str = DEFAULT_FACHRICHTUNG
) -> list[Kurs]:
    kurse = {k.slug: k for k in db.query(Kurs).filter(Kurs.fachrichtung == fachrichtung).all()}
    if uni is None:
        return sorted(kurse.values(), key=lambda k: (k.data.get("semester_default") or 99, k.slug))
    ordered: list[Kurs] = []
    for eintrag in uni.data.get("kurse") or []:
        kurs = kurse.get(eintrag.get("kurs"))
        if kurs is not None and kurs not in ordered:
            ordered.append(kurs)
    return ordered
