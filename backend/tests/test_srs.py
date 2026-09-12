"""Tests fuer den FSRS-Scheduler."""

from datetime import UTC, datetime, timedelta

import pytest

from app.services.srs import (
    DEFAULT_RETENTION,
    CardState,
    Rating,
    State,
    forecast_load,
    interval_for_retention,
    rebuild_from_reviews,
    retrievability,
    review,
)

T0 = datetime(2026, 1, 1, 8, 0, tzinfo=UTC)


def mature(stability: float = 20.0, difficulty: float = 5.0, *, at: datetime = T0) -> CardState:
    """Eine Karte, die den Lernschritt-Modus bereits verlassen hat."""
    return CardState(
        stability=stability,
        difficulty=difficulty,
        due=at,
        last_review=at,
        reps=5,
        state=State.REVIEW,
    )


def test_interval_bei_90_prozent_retention_entspricht_der_stabilitaet():
    # Definitorische Eigenschaft von FSRS: R(t=S) == 0.9
    assert interval_for_retention(10.0, 0.90) == pytest.approx(10.0, rel=1e-6)
    assert interval_for_retention(37.5, 0.90) == pytest.approx(37.5, rel=1e-6)


def test_hoehere_ziel_retention_kuerzt_das_intervall():
    assert interval_for_retention(30.0, 0.95) < interval_for_retention(30.0, 0.90)
    assert interval_for_retention(30.0, 0.85) > interval_for_retention(30.0, 0.90)


def test_retrievability_faellt_monoton_und_liegt_bei_t_gleich_s_bei_09():
    card = mature(stability=10.0)
    assert retrievability(card, T0) == pytest.approx(1.0)
    assert retrievability(card, T0 + timedelta(days=10)) == pytest.approx(0.9, abs=1e-6)
    werte = [retrievability(card, T0 + timedelta(days=d)) for d in range(0, 60, 5)]
    assert all(a > b for a, b in zip(werte, werte[1:], strict=False))


def test_neue_karte_landet_im_lernschritt_und_ist_in_minuten_faellig():
    st = review(CardState(), Rating.GOOD, now=T0)
    assert st.state == State.LEARNING
    assert st.reps == 1
    assert timedelta(0) < st.due - T0 <= timedelta(minutes=30)


def test_neue_karte_mit_easy_ueberspringt_die_lernschritte():
    st = review(CardState(), Rating.EASY, now=T0)
    assert st.state == State.REVIEW
    assert st.due - T0 >= timedelta(days=1)


def test_lernschritte_werden_durchlaufen_bis_zum_tagesrhythmus():
    st = CardState()
    now = T0
    for _ in range(5):
        st = review(st, Rating.GOOD, now=now)
        now = st.due
    assert st.state == State.REVIEW


@pytest.mark.parametrize("rating", [Rating.HARD, Rating.GOOD, Rating.EASY])
def test_erfolgreiche_wiederholung_erhoeht_die_stabilitaet(rating):
    card = mature(stability=20.0)
    st = review(card, rating, now=T0 + timedelta(days=20))
    assert st.stability > card.stability


def test_intervalle_sind_ueber_die_bewertungen_monoton():
    card = mature(stability=20.0)
    at = T0 + timedelta(days=20)
    faellig = {r: review(card, r, now=at).due for r in Rating}
    assert faellig[Rating.AGAIN] < faellig[Rating.HARD]
    assert faellig[Rating.HARD] < faellig[Rating.GOOD] < faellig[Rating.EASY]


def test_again_senkt_stabilitaet_zaehlt_lapse_und_setzt_relearning():
    card = mature(stability=50.0)
    st = review(card, Rating.AGAIN, now=T0 + timedelta(days=50))
    assert st.stability < card.stability
    assert st.lapses == 1
    assert st.state == State.RELEARNING


def test_schwierigkeit_bleibt_im_erlaubten_band():
    st = CardState()
    now = T0
    for i in range(60):
        rating = Rating.AGAIN if i % 2 == 0 else Rating.EASY
        st = review(st, rating, now=now)
        now = max(st.due, now + timedelta(days=1))
        assert 1.0 <= st.difficulty <= 10.0


def test_kartentyp_steuert_die_ziel_retention():
    card = mature(stability=30.0)
    at = T0 + timedelta(days=30)
    definition = review(card, Rating.GOOD, now=at, card_type="definition")  # 0.92
    rechtsprechung = review(card, Rating.GOOD, now=at, card_type="rechtsprechung")  # 0.85
    assert definition.due < rechtsprechung.due


def test_unbekannter_kartentyp_faellt_auf_den_default_zurueck():
    card = mature()
    at = T0 + timedelta(days=20)
    a = review(card, Rating.GOOD, now=at, card_type="gibt-es-nicht")
    b = review(card, Rating.GOOD, now=at, desired_retention=DEFAULT_RETENTION)
    assert a.due == b.due


def test_rebuild_aus_dem_ereignisstrom_ist_reihenfolgeunabhaengig():
    """Der Offline-Sync liefert Reviews verspaetet und unsortiert - das Ergebnis
    muss trotzdem identisch sein."""
    events = [
        (Rating.GOOD, T0),
        (Rating.GOOD, T0 + timedelta(days=1)),
        (Rating.AGAIN, T0 + timedelta(days=4)),
        (Rating.GOOD, T0 + timedelta(days=5)),
        (Rating.EASY, T0 + timedelta(days=20)),
    ]
    vorwaerts = rebuild_from_reviews(events)
    rueckwaerts = rebuild_from_reviews(list(reversed(events)))
    assert vorwaerts == rueckwaerts
    assert vorwaerts.reps == len(events)


def test_forecast_load_verteilt_karten_auf_tagesbuckets():
    states = [
        mature(at=T0),
        CardState(stability=1, difficulty=5, due=T0 + timedelta(hours=5), last_review=T0),
        CardState(stability=1, difficulty=5, due=T0 + timedelta(days=2), last_review=T0),
        CardState(stability=1, difficulty=5, due=T0 + timedelta(days=99), last_review=T0),
    ]
    buckets = forecast_load(states, days=7, now=T0)
    assert buckets[0] == 2  # heute faellig + in 5 Stunden
    assert buckets[2] == 1
    assert sum(buckets) == 3  # die Karte in 99 Tagen faellt aus dem Fenster
