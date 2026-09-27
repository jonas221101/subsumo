"""Examensvorbereitung: Bundesland-Profil, Kurs-Decks, Examensreife, Cockpit.

Konzept in docs/32-examensvorbereitung.md. Drei Entscheidungen, die sich
durch dieses Modul ziehen:

1. **Landesrecht ist nur sichtbar, wo es geprueft wird.** Ein Thema mit
   ``Topic.bundesland`` erscheint nur fuer Nutzer dieses Bundeslands - in
   faelligen Karten, Coverage, Lernplan und Decks (:func:`visible_topic_slugs`).
2. **Die Klausurverteilung des Landes gewichtet die Examensreife.** Wo das
   Strafrecht zwei von sieben Klausuren stellt (NW), wiegt es mehr als bei
   einer von sechs (BY). Ohne Bundesland gilt die Gleichverteilung.
3. **Examensreife ist keine Note.** Sie zerfaellt in benannte Komponenten
   (Wissen, Landesrecht, Anwendung, Technik, Klausurpraxis), die einzeln
   angezeigt werden; der Gesamtwert ist ein gewichteter Mittelwert der
   *verfuegbaren* Komponenten mit offengelegter Formel - "Ehrlichkeit vor
   Motivation" (docs/01-produktvision.md), keine Ampel, kein Konfetti.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.timeutil import as_utc
from app.models import (
    Area,
    Bundesland,
    Card,
    Case,
    Kurs,
    Schema,
    Submission,
    Topic,
    Universitaet,
    User,
    UserCard,
)
from app.services import srs
from app.services.content import landesrecht_topic_slug
from app.services.planner import (
    KLAUSUR_WEEKDAY,
    PHASE_ENDSPURT,
    PHASE_GRUNDLAGEN,
    PHASE_SPLIT,
    PHASE_VERTIEFUNG,
    TopicInput,
)

MATURE_STABILITY_DAYS = 21.0
AREAS = [a.value for a in Area]

# Gewichte der Examensreife-Komponenten (docs/32 Abschnitt 5). Nicht
# verfuegbare Komponenten (z. B. Landesrecht ohne Bundesland) fallen weg,
# die uebrigen Gewichte werden renormiert.
READINESS_WEIGHTS = {
    "wissen": 0.35,
    "landesrecht": 0.10,
    "anwendung": 0.25,
    "technik": 0.15,
    "klausurpraxis": 0.15,
}
# Ein Fall gilt als "bestanden", wenn die beste Abgabe mindestens
# "ausreichend" (4 Punkte, JAP-Skala) erreicht hat.
BESTANDEN_PUNKTE = 4.0
# Klausurpraxis: Ziel ist eine Klausur unter Examensbedingungen pro Woche
# ueber die letzten acht Wochen (Planer: KLAUSUR_WEEKDAY).
KLAUSURPRAXIS_WOCHEN = 8
TECHNIK_FENSTER = 5
# Vorbereitungszeitraum fuer die Phasenrechnung: hoechstens 12 Monate vor
# dem Examen, fruehestens ab Registrierung - stabil ueber Neuberechnungen
# hinweg (behebt den in docs/13 Abschnitt 2.3 benannten Aenderungsbedarf).
VORBEREITUNG_MAX_TAGE = 365


# --------------------------------------------------------------------------- #
# Sichtbarkeit
# --------------------------------------------------------------------------- #


def visible_topics_query(db: Session, user: User):
    """Alle bundesrechtlichen Themen plus das Landesrecht des eigenen Landes."""
    query = db.query(Topic)
    if user.bundesland:
        return query.filter(or_(Topic.bundesland.is_(None), Topic.bundesland == user.bundesland))
    return query.filter(Topic.bundesland.is_(None))


def visible_topic_slugs(db: Session, user: User) -> set[str]:
    return {t.slug for t in visible_topics_query(db, user).all()}


# --------------------------------------------------------------------------- #
# Kartenzustand je Thema
# --------------------------------------------------------------------------- #


@dataclass
class TopicProgress:
    slug: str
    title: str
    area: str
    relevance: int
    bundesland: str | None
    cards_total: int = 0
    cards_started: int = 0
    cards_mature: int = 0
    cards_due: int = 0

    @property
    def mastery(self) -> float:
        return self.cards_mature / self.cards_total if self.cards_total else 0.0

    def to_dict(self) -> dict:
        return {
            "slug": self.slug,
            "title": self.title,
            "area": self.area,
            "relevance": self.relevance,
            "bundesland": self.bundesland,
            "cards_total": self.cards_total,
            "cards_started": self.cards_started,
            "cards_mature": self.cards_mature,
            "cards_due": self.cards_due,
            "mastery": round(self.mastery, 3),
        }


def topic_progress(
    db: Session, user: User, *, now: datetime | None = None
) -> dict[str, TopicProgress]:
    """Kartenreife je sichtbarem Thema - dieselbe Reife-Definition wie
    ``/progress/coverage`` (stability >= 21 Tage und state == review)."""
    now = now or datetime.now(UTC)
    progress: dict[str, TopicProgress] = {}
    for topic in visible_topics_query(db, user).order_by(Topic.area, Topic.position).all():
        progress[topic.slug] = TopicProgress(
            slug=topic.slug,
            title=topic.title,
            area=topic.area,
            relevance=topic.relevance,
            bundesland=topic.bundesland,
        )
    states = {uc.card_id: uc for uc in db.query(UserCard).filter(UserCard.user_id == user.id).all()}
    for card in db.query(Card).all():
        entry = progress.get(card.topic_slug)
        if entry is None:
            continue
        entry.cards_total += 1
        uc = states.get(card.id)
        if uc is None:
            continue
        entry.cards_started += 1
        if uc.stability >= MATURE_STABILITY_DAYS and uc.state == srs.State.REVIEW:
            entry.cards_mature += 1
        due = as_utc(uc.due)
        if (due is not None and due <= now) or uc.content_changed:
            entry.cards_due += 1
    return progress


def topic_inputs(db: Session, user: User) -> list[TopicInput]:
    """Eingabe fuer :func:`app.services.planner.generate_plan` - nur sichtbare Themen."""
    return [
        TopicInput(
            slug=p.slug,
            area=p.area,
            title=p.title,
            relevance=p.relevance,
            mastery=p.mastery,
        )
        for p in topic_progress(db, user).values()
    ]


# --------------------------------------------------------------------------- #
# Bundesland
# --------------------------------------------------------------------------- #


def area_weights(land: Bundesland | None) -> dict[str, float]:
    """Gewicht je Rechtsgebiet aus der Klausurverteilung des Landes."""
    if land is None:
        return {a: 1.0 / len(AREAS) for a in AREAS}
    verteilung = (land.data.get("klausuren") or {}).get("verteilung") or {}
    total = sum(float(verteilung.get(a, 0)) for a in AREAS)
    if total <= 0:
        return {a: 1.0 / len(AREAS) for a in AREAS}
    return {a: float(verteilung.get(a, 0)) / total for a in AREAS}


def bundesland_summary(land: Bundesland) -> dict:
    data = land.data
    return {
        "code": land.code,
        "name": land.name,
        "klausuren": data.get("klausuren", {}),
        "pruefungsamt": data.get("pruefungsamt", {}),
        "pruefstatus": (data.get("redaktion") or {}).get("status", "mensch-freigegeben"),
        "stand": land.stand,
    }


def bundesland_profile(db: Session, land: Bundesland) -> dict:
    """Vollstaendiges Profil inklusive der Landesrecht-Themen dieses Landes."""
    topics = db.query(Topic).filter(Topic.bundesland == land.code).order_by(Topic.slug).all()
    cards_by_topic = Counter(
        c.topic_slug for c in db.query(Card).filter(Card.topic_slug.in_([t.slug for t in topics]))
    )
    return {
        **land.data,
        "pruefstatus": (land.data.get("redaktion") or {}).get("status", "mensch-freigegeben"),
        "gewichtung": area_weights(land),
        "landesrecht_themen": [
            {
                "slug": t.slug,
                "title": t.title,
                "relevance": t.relevance,
                "cards_total": cards_by_topic.get(t.slug, 0),
            }
            for t in topics
        ],
    }


# --------------------------------------------------------------------------- #
# Kurse und Decks
# --------------------------------------------------------------------------- #


def kurs_summary(kurs: Kurs) -> dict:
    data = kurs.data
    return {
        "slug": kurs.slug,
        "title": kurs.title,
        "area": kurs.area,
        "semester_default": data.get("semester_default"),
        "examenskurs": bool(data.get("examenskurs")),
        "beschreibung": data.get("beschreibung", ""),
        "klausurformat": data.get("klausurformat", {}),
        "topic_count": len(data.get("topic_slugs") or []),
        "landesrecht_kategorien": data.get("landesrecht_kategorien") or [],
    }


def deck_topic_slugs(kurs: Kurs, bundesland: str | None) -> list[str]:
    """Themen eines Decks: kanonische Themen plus Landesrecht des Nutzers.

    Landesrecht-Themen werden ueber die Slug-Konvention aufgeloest
    (``content.landesrecht_topic_slug``); ohne Bundesland bleibt das Deck
    bundesrechtlich - das Deck ist dann bewusst unvollstaendig und sagt das
    (``landesrecht_fehlt`` im Ergebnis von :func:`resolve_deck`).
    """
    slugs = list(kurs.data.get("topic_slugs") or [])
    if bundesland:
        for kategorie in kurs.data.get("landesrecht_kategorien") or []:
            slugs.append(landesrecht_topic_slug(bundesland, kategorie))
    return slugs


def resolve_deck(
    db: Session,
    user: User,
    kurs: Kurs,
    *,
    progress: dict[str, TopicProgress] | None = None,
) -> dict:
    """Massgeschneidertes Vorbereitungsdeck fuer einen Nutzer.

    "Massgeschneidert" heisst: die Themenauswahl des Kurses, ergaenzt um das
    Landesrecht des eigenen Bundeslands, mit dem individuellen Kartenzustand,
    den Schemata und Faellen dieser Themen - keine kopierten Karten.
    """
    progress = progress if progress is not None else topic_progress(db, user)
    wanted = deck_topic_slugs(kurs, user.bundesland)
    topics = [progress[s] for s in wanted if s in progress]
    known = {t.slug for t in topics}
    landesrecht_fehlt = [s for s in wanted if s not in known]

    slugs = [t.slug for t in topics]
    schemata = (
        db.query(Schema).filter(Schema.topic_slug.in_(slugs)).order_by(Schema.slug).all()
        if slugs
        else []
    )
    cases = (
        db.query(Case).filter(Case.topic_slug.in_(slugs)).order_by(Case.difficulty, Case.slug).all()
        if slugs
        else []
    )
    cards_total = sum(t.cards_total for t in topics)
    cards_mature = sum(t.cards_mature for t in topics)
    return {
        **kurs_summary(kurs),
        "lernziele": kurs.data.get("lernziele") or [],
        "fehlende_themen": kurs.data.get("fehlende_themen") or [],
        "landesrecht_fehlt": landesrecht_fehlt,
        "topics": [t.to_dict() for t in topics],
        "schemata": [
            {"slug": s.slug, "title": s.title, "topic_slug": s.topic_slug} for s in schemata
        ],
        "cases": [
            {
                "slug": c.slug,
                "title": c.title,
                "topic_slug": c.topic_slug,
                "difficulty": c.difficulty,
                "minutes": c.minutes,
            }
            for c in cases
        ],
        "cards_total": cards_total,
        "cards_mature": cards_mature,
        "cards_started": sum(t.cards_started for t in topics),
        "cards_due": sum(t.cards_due for t in topics),
        "mastery": round(cards_mature / cards_total, 3) if cards_total else 0.0,
    }


def deck_card_topic_slugs(db: Session, user: User, deck_slug: str) -> list[str] | None:
    """Themen-Slugs eines Decks fuer den ``deck``-Filter von ``/cards/due``.

    ``None`` bedeutet: unbekanntes Deck (der Aufrufer antwortet 404).
    """
    kurs = db.query(Kurs).filter_by(slug=deck_slug).one_or_none()
    if kurs is None:
        return None
    return deck_topic_slugs(kurs, user.bundesland)


def university_courses(db: Session, uni: Universitaet | None) -> list[dict]:
    """Kursliste einer Universitaet in Semesterreihenfolge; ohne Universitaet
    der komplette Katalog nach ``semester_default``."""
    kurse = {k.slug: k for k in db.query(Kurs).all()}
    if uni is None:
        return sorted(
            (
                kurs_summary(k) | {"semester": k.data.get("semester_default")}
                for k in kurse.values()
            ),
            key=lambda k: ((k["semester"] or 99), k["slug"]),
        )
    result = []
    for eintrag in uni.data.get("kurse") or []:
        kurs = kurse.get(eintrag.get("kurs"))
        if kurs is None:
            continue
        result.append(
            kurs_summary(kurs)
            | {
                "semester": eintrag.get("semester", kurs.data.get("semester_default")),
                "titel_lokal": eintrag.get("titel_lokal"),
            }
        )
    return sorted(result, key=lambda k: ((k["semester"] or 99), k["slug"]))


# --------------------------------------------------------------------------- #
# Examensreife
# --------------------------------------------------------------------------- #


def _weighted_area_coverage(
    progress: dict[str, TopicProgress], weights: dict[str, float]
) -> tuple[float, dict[str, float]]:
    """Reife je Rechtsgebiet (nach Themenrelevanz), gesamt nach Klausurgewicht."""
    num: dict[str, float] = {}
    den: dict[str, float] = {}
    for p in progress.values():
        if p.bundesland is not None:
            continue  # Landesrecht hat seine eigene Komponente
        num[p.area] = num.get(p.area, 0.0) + p.relevance * p.mastery
        den[p.area] = den.get(p.area, 0.0) + p.relevance
    by_area = {a: (num[a] / den[a] if den.get(a) else 0.0) for a in AREAS}
    total = sum(weights[a] * by_area[a] for a in AREAS)
    return total, by_area


def readiness(
    db: Session,
    user: User,
    *,
    progress: dict[str, TopicProgress],
    land: Bundesland | None,
    now: datetime | None = None,
) -> dict:
    now = now or datetime.now(UTC)
    weights = area_weights(land)
    wissen, by_area = _weighted_area_coverage(progress, weights)

    landesrecht_topics = [p for p in progress.values() if p.bundesland is not None]
    lr_total = sum(p.cards_total for p in landesrecht_topics)
    landesrecht = (
        sum(p.cards_mature for p in landesrecht_topics) / lr_total
        if user.bundesland and lr_total
        else None
    )

    visible = set(progress)
    cases = [c for c in db.query(Case).all() if c.topic_slug in visible]
    submissions = (
        db.query(Submission)
        .filter(Submission.user_id == user.id)
        .order_by(Submission.created_at.desc())
        .all()
    )
    best: dict[int, float] = {}
    for s in submissions:
        if s.points is not None:
            best[s.case_id] = max(best.get(s.case_id, 0.0), s.points)
    bestanden = sum(1 for c in cases if best.get(c.id, 0.0) >= BESTANDEN_PUNKTE)
    anwendung = bestanden / len(cases) if cases else 0.0

    letzte = submissions[:TECHNIK_FENSTER]
    technik = sum(s.structure_score for s in letzte) / (100.0 * len(letzte)) if letzte else None

    fenster_start = now - timedelta(weeks=KLAUSURPRAXIS_WOCHEN)
    klausuren = [
        s
        for s in submissions
        if s.mode == "klausur" and (as_utc(s.created_at) or now) >= fenster_start
    ]
    klausurpraxis = min(1.0, len(klausuren) / KLAUSURPRAXIS_WOCHEN)

    komponenten = {
        "wissen": {
            "label": "Wissen (Kartenreife, nach Klausurgewicht)",
            "value": round(wissen, 3),
            "detail": "Anteil reifer Karten je Rechtsgebiet, gewichtet nach der Klausurverteilung.",
        },
        "landesrecht": {
            "label": "Landesrecht",
            "value": None if landesrecht is None else round(landesrecht, 3),
            "detail": (
                "Reife der Landesrecht-Karten deines Bundeslands."
                if user.bundesland
                else "Ohne Bundesland im Profil nicht messbar."
            ),
        },
        "anwendung": {
            "label": "Anwendung (bestandene Faelle)",
            "value": round(anwendung, 3),
            "detail": (
                f"{bestanden} von {len(cases)} Faellen mit mindestens "
                f"{BESTANDEN_PUNKTE:.0f} Punkten."
            ),
        },
        "technik": {
            "label": "Gutachtentechnik",
            "value": None if technik is None else round(technik, 3),
            "detail": (
                f"Strukturscore der letzten {len(letzte)} Abgaben."
                if letzte
                else "Noch keine Abgabe - Struktur-Feedback im Gutachten-Trainer."
            ),
        },
        "klausurpraxis": {
            "label": "Klausurpraxis",
            "value": round(klausurpraxis, 3),
            "detail": (
                f"{len(klausuren)} Klausur(en) unter Examensbedingungen in den letzten "
                f"{KLAUSURPRAXIS_WOCHEN} Wochen (Ziel: eine pro Woche)."
            ),
        },
    }
    verfuegbar = {k: v["value"] for k, v in komponenten.items() if v["value"] is not None}
    gewicht_summe = sum(READINESS_WEIGHTS[k] for k in verfuegbar)
    gesamt = (
        sum(READINESS_WEIGHTS[k] * v for k, v in verfuegbar.items()) / gewicht_summe
        if gewicht_summe
        else 0.0
    )
    return {
        "gesamt": round(gesamt, 3),
        "formel": " + ".join(
            f"{READINESS_WEIGHTS[k] / gewicht_summe:.2f} x {k}" for k in verfuegbar
        ),
        "komponenten": komponenten,
        "by_area": {
            a: {
                "coverage": round(by_area[a], 3),
                "gewicht": round(weights[a], 3),
                "klausuren": int(
                    ((land.data.get("klausuren") or {}).get("verteilung") or {}).get(a, 0)
                )
                if land
                else None,
            }
            for a in AREAS
        },
    }


# --------------------------------------------------------------------------- #
# Schwachstellen, naechste Klausur, Phase
# --------------------------------------------------------------------------- #


def weak_spots(db: Session, user: User, *, limit: int = 20) -> dict:
    """Aus den letzten Abgaben: verfehlte Pruefpunkte je Thema und die
    haeufigsten Strukturfehler (Fehlertaxonomie docs/13 Abschnitt 3)."""
    submissions = (
        db.query(Submission)
        .filter(Submission.user_id == user.id)
        .order_by(Submission.created_at.desc())
        .limit(limit)
        .all()
    )
    if not submissions:
        return {"themen": [], "strukturfehler": [], "abgaben": 0}
    case_topics = {
        c.id: (c.topic_slug, c.title)
        for c in db.query(Case).filter(Case.id.in_({s.case_id for s in submissions}))
    }
    titles = {t.slug: t.title for t in db.query(Topic).all()}
    verfehlt: Counter[str] = Counter()
    beispiele: dict[str, list[str]] = {}
    strukturfehler: Counter[str] = Counter()
    for s in submissions:
        report = s.report or {}
        topic_slug, _ = case_topics.get(s.case_id, ("", ""))
        for cp in (report.get("evaluation") or {}).get("checkpoints") or []:
            if not cp.get("hit"):
                verfehlt[topic_slug] += 1
                beispiele.setdefault(topic_slug, [])
                if len(beispiele[topic_slug]) < 3 and cp.get("label") not in beispiele[topic_slug]:
                    beispiele[topic_slug].append(cp.get("label", ""))
        for f in (report.get("structure") or {}).get("findings") or []:
            if f.get("severity") == "fehler":
                strukturfehler[f.get("code", "")] += 1
    return {
        "abgaben": len(submissions),
        "themen": [
            {
                "topic_slug": slug,
                "title": titles.get(slug, slug),
                "verfehlte_pruefpunkte": n,
                "beispiele": beispiele.get(slug, []),
            }
            for slug, n in verfehlt.most_common(5)
            if slug
        ],
        "strukturfehler": [
            {"code": code, "anzahl": n} for code, n in strukturfehler.most_common(5) if code
        ],
    }


def next_klausur(
    db: Session,
    user: User,
    *,
    progress: dict[str, TopicProgress],
    readiness_by_area: dict[str, dict],
) -> dict | None:
    """Vorschlag fuer die naechste Klausur unter Examensbedingungen.

    Schwaechstes Rechtsgebiet zuerst (Coverage x Klausurgewicht), darin der
    schwerste noch nicht im Klausurmodus geschriebene Fall.
    """
    geschrieben = {
        s.case_id
        for s in db.query(Submission).filter(
            Submission.user_id == user.id, Submission.mode == "klausur"
        )
    }
    visible = set(progress)
    kandidaten = [
        c
        for c in db.query(Case).filter(Case.difficulty >= 3).all()
        if c.topic_slug in visible and c.id not in geschrieben
    ]
    if not kandidaten:
        kandidaten = [c for c in db.query(Case).all() if c.topic_slug in visible]
    if not kandidaten:
        return None
    # Rechtsgebiet mit dem groessten gewichteten Defizit zuerst.
    rang = {a: (1.0 - v["coverage"]) * v["gewicht"] for a, v in readiness_by_area.items()}
    kandidaten.sort(key=lambda c: (-rang.get(c.area, 0.0), -c.difficulty, c.slug))
    c = kandidaten[0]
    return {
        "slug": c.slug,
        "title": c.title,
        "area": c.area,
        "topic_slug": c.topic_slug,
        "difficulty": c.difficulty,
        "minutes": c.minutes,
        "begruendung": (
            "Schwaechstes Rechtsgebiet nach Klausurgewicht; Fall noch nicht unter "
            "Examensbedingungen geschrieben."
        ),
    }


def next_klausurtag(today: date) -> date:
    delta = (KLAUSUR_WEEKDAY - today.weekday()) % 7
    return today + timedelta(days=delta or 7)


def phase_info(user: User, today: date) -> dict | None:
    """Phase relativ zum *stabilen* Vorbereitungszeitraum, nicht zum Aufrufzeitpunkt."""
    if user.exam_date is None:
        return None
    exam = as_utc(user.exam_date)
    exam_day = exam.date() if exam else None
    if exam_day is None:
        return None
    created = as_utc(user.created_at)
    beginn = max(
        exam_day - timedelta(days=VORBEREITUNG_MAX_TAGE),
        created.date() if created else today,
    )
    beginn = min(beginn, today)
    gesamt = max(1, (exam_day - beginn).days)
    vergangen = max(0, min(gesamt, (today - beginn).days))
    ratio = vergangen / gesamt
    if exam_day <= today:
        phase = PHASE_ENDSPURT
    elif ratio < PHASE_SPLIT[0]:
        phase = PHASE_GRUNDLAGEN
    elif ratio < PHASE_SPLIT[0] + PHASE_SPLIT[1]:
        phase = PHASE_VERTIEFUNG
    else:
        phase = PHASE_ENDSPURT
    g_ende = beginn + timedelta(days=round(gesamt * PHASE_SPLIT[0]))
    v_ende = beginn + timedelta(days=round(gesamt * (PHASE_SPLIT[0] + PHASE_SPLIT[1])))
    return {
        "exam_date": exam_day.isoformat(),
        "tage_bis_examen": (exam_day - today).days,
        "vorbereitungsbeginn": beginn.isoformat(),
        "phase": phase,
        "fortschritt": round(ratio, 3),
        "phasen": [
            {"name": PHASE_GRUNDLAGEN, "von": beginn.isoformat(), "bis": g_ende.isoformat()},
            {"name": PHASE_VERTIEFUNG, "von": g_ende.isoformat(), "bis": v_ende.isoformat()},
            {"name": PHASE_ENDSPURT, "von": v_ende.isoformat(), "bis": exam_day.isoformat()},
        ],
    }


def checkliste(land: Bundesland | None, phase: dict | None) -> list[dict]:
    """Checkliste des Landes, markiert nach 'jetzt dran' anhand der Restzeit."""
    if land is None:
        return []
    tage = phase["tage_bis_examen"] if phase else None
    result = []
    for item in land.data.get("checkliste") or []:
        monate = item.get("monate_vor_examen")
        faellig = tage is not None and monate is not None and tage <= int(monate) * 30
        result.append({**item, "jetzt_dran": faellig})
    return result
