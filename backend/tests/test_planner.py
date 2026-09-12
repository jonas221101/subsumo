"""Tests des Lernplaners."""

from datetime import date

import pytest

from app.services.planner import (
    KLAUSUR_WEEKDAY,
    PHASE_GRUNDLAGEN,
    TopicInput,
    generate_plan,
)

START = date(2026, 1, 5)  # Montag


def themen() -> list[TopicInput]:
    return [
        TopicInput("zr-bgb-at", "zivilrecht", "BGB AT", relevance=5),
        TopicInput("zr-schuldrecht-at", "zivilrecht", "Schuldrecht AT", relevance=5),
        TopicInput("zr-sachenrecht", "zivilrecht", "Sachenrecht", relevance=4),
        TopicInput("sr-at", "strafrecht", "Strafrecht AT", relevance=5),
        TopicInput("sr-bt-vermoegen", "strafrecht", "Vermoegensdelikte", relevance=5),
        TopicInput("or-grundrechte", "oeffentliches-recht", "Grundrechte", relevance=5),
        TopicInput("or-verwaltungsrecht-at", "oeffentliches-recht", "VerwR AT", relevance=4),
        TopicInput("or-kommunalrecht", "oeffentliches-recht", "Kommunalrecht", relevance=2),
    ]


def test_examensdatum_muss_in_der_zukunft_liegen():
    with pytest.raises(ValueError):
        generate_plan(themen(), start=START, exam_date=START)


def test_tagesbudget_wird_nie_ueberschritten_ausser_an_klausurtagen():
    plan = generate_plan(themen(), start=START, exam_date=date(2026, 7, 1), daily_minutes=90)
    for day in plan.days:
        if day.is_klausurtag:
            continue
        assert day.total_minutes <= 90, (day.day, day.total_minutes)


def test_alle_themen_kommen_im_plan_vor():
    plan = generate_plan(themen(), start=START, exam_date=date(2026, 7, 1))
    assert plan.uncovered_topics == []


def test_rechtsgebiete_werden_verschraenkt_statt_geblockt():
    plan = generate_plan(themen(), start=START, exam_date=date(2026, 7, 1))
    reihenfolge = [
        b.area
        for d in plan.days
        for b in d.blocks
        if b.kind == "neu" and b.area
    ]
    # Kein Rechtsgebiet darf drei neue Themen am Stueck belegen.
    wechsel = [a for i, a in enumerate(reihenfolge) if i == 0 or a != reihenfolge[i - 1]]
    assert len(wechsel) >= len(set(reihenfolge)) * 2


def test_wiederholungen_haben_vorrang_vor_neuem_stoff():
    plan = generate_plan(
        themen(),
        start=START,
        exam_date=date(2026, 7, 1),
        daily_minutes=90,
        due_forecast=[60] * 30,
        seconds_per_card=20,
    )
    erster = plan.days[0]
    assert erster.blocks[0].kind == "wiederholung"
    # 60 Karten a 20 s = 20 min, passt in die 60-%-Deckelung von 90 min.
    assert erster.blocks[0].minutes == 20
    assert erster.review_backlog == 0


def test_wiederholungen_sind_gedeckelt_und_erzeugen_rueckstand():
    plan = generate_plan(
        themen(),
        start=START,
        exam_date=date(2026, 7, 1),
        daily_minutes=90,
        due_forecast=[250] + [0] * 60,
        seconds_per_card=20,
    )
    erster = plan.days[0]
    # Maximal 60 % von 90 min = 54 min -> 162 Karten, Rest bleibt liegen.
    assert erster.blocks[0].minutes <= 54
    assert 0 < erster.review_backlog < 150
    # Ein moderater Rueckstand darf den Stofffortschritt nicht stoppen.
    assert any(b.kind == "neu" for b in erster.blocks)
    # ... und ist am Folgetag abgearbeitet.
    assert plan.days[1].review_backlog == 0


def test_grosser_rueckstand_stoppt_die_aufnahme_von_neuem_stoff():
    plan = generate_plan(
        themen(),
        start=START,
        exam_date=date(2026, 7, 1),
        daily_minutes=60,
        due_forecast=[2000] + [0] * 60,
        seconds_per_card=20,
    )
    zweiter = plan.days[1]
    assert zweiter.review_backlog > 150
    assert not any(b.kind == "neu" for b in zweiter.blocks)
    assert any("Rueckstand" in b.title for b in zweiter.blocks)


def test_ruhetage_werden_respektiert():
    plan = generate_plan(
        themen(), start=START, exam_date=date(2026, 7, 1), rest_weekdays={6}
    )
    sonntage = [d for d in plan.days if d.day.weekday() == 6]
    assert sonntage
    assert all(d.total_minutes == 0 for d in sonntage)


def test_klausuren_erst_ab_der_vertiefungsphase():
    plan = generate_plan(themen(), start=START, exam_date=date(2026, 12, 1))
    klausurtage = [d for d in plan.days if d.is_klausurtag]
    assert klausurtage, "Ohne Klausuren ist der Plan wertlos"
    assert all(d.day.weekday() == KLAUSUR_WEEKDAY for d in klausurtage)
    assert all(d.phase != PHASE_GRUNDLAGEN for d in klausurtage)
    assert plan.klausur_count == len(klausurtage)


def test_endspurt_enthaelt_volle_fuenf_stunden_klausuren():
    plan = generate_plan(themen(), start=START, exam_date=date(2026, 12, 1))
    endspurt = [d for d in plan.days if d.phase == "endspurt" and d.is_klausurtag]
    assert endspurt
    assert all(b.minutes == 300 for d in endspurt for b in d.blocks if b.kind == "klausur")


def test_horizont_begrenzt_die_planlaenge():
    plan = generate_plan(
        themen(), start=START, exam_date=date(2027, 6, 1), horizon_days=14
    )
    assert len(plan.days) == 14


def test_plan_ist_json_serialisierbar():
    import json

    plan = generate_plan(themen(), start=START, exam_date=date(2026, 4, 1))
    json.dumps(plan.to_dict())
