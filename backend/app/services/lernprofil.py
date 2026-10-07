"""Lernprofil: die Individualisierung als Verhalten, nicht als Anzeige.

Konzept in docs/33-individualisierung.md. Das Profil ist ein JSON-Feld am
Nutzer (``User.lernprofil``), validiert ueber :class:`app.schemas.LernprofilIn`.
Dieses Modul uebersetzt es in Verhalten:

- **Gedaechtnis:** ``sicherheitsniveau`` verschiebt die FSRS-Ziel-Retention je
  Kartentyp (:func:`retention_for`) - "sicher" plant kuerzere Intervalle,
  "kompakt" laengere. Das aendert die Wiederholungslast messbar.
- **Stoff:** ``themen_fokus``/``schwerpunkte`` gewichten neue Karten und den
  Planer hoch, ``themen_pausiert`` nimmt Themen komplett heraus
  (:func:`topic_weight`, :func:`pausierte_themen`).
- **Rhythmus:** ``ruhetage``, ``klausur_wochentag``, ``wochenklausur`` und
  ``neue_karten_pro_tag`` steuern Planer und Kartenstapel.
- **Weg:** Aus Semester, Ziel und Examensdatum folgt eine Persona
  (:func:`persona`), aus ihr und dem Ist-Zustand der naechste Schritt
  (:func:`next_step`) - der Einstiegspunkt je Lernpfad aus docs/13 Abschnitt 2,
  bisher nur beschrieben, hier gebaut.
- **Fehler:** Der haeufigste Strukturfehler wird zum Technik-Tipp
  (:func:`technik_tipp`), der Kategorie-A-Konsequenz aus docs/13 Abschnitt 3.2.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from sqlalchemy.orm import Session

from app.models import Case, Topic, User
from app.schemas import LernprofilIn
from app.services import srs

# Verschiebung der Ziel-Retention je Sicherheitsniveau. +/-0.04 entspricht bei
# FSRS grob einem Drittel weniger bzw. mehr Wiederholungen - spuerbar, aber
# nicht ruinoes (docs/33 Abschnitt 4.3).
RETENTION_OFFSET = {"kompakt": -0.04, "standard": 0.0, "sicher": 0.04}
RETENTION_MIN, RETENTION_MAX = 0.80, 0.97

FOKUS_FAKTOR = 1.5
SCHWERPUNKT_FAKTOR = 1.25

PERSONA_EINSTIEG = "einstieg"  # Lena: erste Semester, Karten und Schemata zuerst
PERSONA_AUFBAU = "aufbau"  # Jonas: Grundlagen sitzen, Faelle und Technik
PERSONA_EXAMEN = "examen"  # Mira: Termin gesetzt, Plan und Klausurrhythmus
PERSONA_WIEDERHOLUNG = "wiederholung"  # nach dem Studium, Referendariat, Auffrischung

PERSONA_LABELS = {
    PERSONA_EINSTIEG: "Einstieg: Karten und Schemata zuerst",
    PERSONA_AUFBAU: "Aufbau: Faelle und Gutachtentechnik",
    PERSONA_EXAMEN: "Examen: Plan und Klausurrhythmus",
    PERSONA_WIEDERHOLUNG: "Wiederholung: Auffrischen nach Schwachstellen",
}

# Technik-Tipps je Strukturfehler-Code (docs/13 Abschnitt 3.2, Kategorie A).
TECHNIK_TIPPS: dict[str, dict[str, str]] = {
    "kein_obersatz": {
        "titel": "Obersatz zuerst",
        "tipp": (
            "Jede Pruefung beginnt mit einem Obersatz im Konjunktiv: 'A koennte gegen B "
            "einen Anspruch auf ... aus § ... haben.' Ohne ihn erkennt der Korrektor die "
            "Methode nicht - das kostet mehr als jeder inhaltliche Fehler."
        ),
    },
    "sprung_zum_ergebnis": {
        "titel": "Subsumtion statt Behauptung",
        "tipp": (
            "Zwischen Definition und Ergebnis fehlt der Schritt, der den Sachverhalt unter "
            "die Definition zieht. Schreibe fuer jedes Merkmal einen Satz, der mit 'Hier ...' "
            "oder 'Vorliegend ...' beginnt."
        ),
    },
    "keine_subsumtion": {
        "titel": "Subsumtion statt Behauptung",
        "tipp": (
            "Definition und Ergebnis stehen da, aber nicht der Weg dazwischen. Nenne die "
            "Tatsache aus dem Sachverhalt, die das Merkmal erfuellt, bevor du das Ergebnis "
            "feststellst."
        ),
    },
    "urteilsstil": {
        "titel": "Gutachten- statt Urteilsstil",
        "tipp": (
            "'Da ..., ist ...' gehoert ins Urteil, nicht ins Gutachten. Im Gutachten steht "
            "erst die Frage (koennte), dann die Pruefung, dann das Ergebnis - nur bei "
            "unproblematischen Punkten darf der Urteilsstil verkuerzen."
        ),
    },
    "offener_obersatz": {
        "titel": "Pruefungspunkte abschliessen",
        "tipp": (
            "Ein aufgeworfener Obersatz braucht einen Ergebnissatz. Lies vor der Abgabe jeden "
            "'koennte'-Satz und pruefe, ob ein 'somit'/'folglich' dazu existiert."
        ),
    },
    "keine_definition": {
        "titel": "Definition vor Subsumtion",
        "tipp": (
            "Ein Tatbestandsmerkmal wird erst definiert, dann subsumiert. Die Definitionskarten "
            "des Themas liefern den Wortlaut - sie sind dafuer da, woertlich zu sitzen."
        ),
    },
    "kein_ergebnis": {
        "titel": "Ergebnissatz formulieren",
        "tipp": (
            "Jede Pruefung endet mit einem klaren Ergebnis im Indikativ: 'A hat gegen B einen "
            "Anspruch aus ...'. Ein Gutachten ohne Ergebnis ist unvollstaendig, egal wie gut "
            "die Pruefung war."
        ),
    },
    "keine_norm": {
        "titel": "Normen zitieren",
        "tipp": (
            "Jede Anspruchsgrundlage und jedes Tatbestandsmerkmal braucht die Norm mit Absatz "
            "und Satz. Die Norm-Karten des Themas sind dafuer da - zieh sie vor."
        ),
    },
    "gesetz_fehlt": {
        "titel": "Gesetz zur Norm",
        "tipp": "'§ 433 Abs. 2' ohne 'BGB' ist unvollstaendig - das Gesetz gehoert zu jedem Zitat.",
    },
    "schachtelsatz": {
        "titel": "Kurze Saetze",
        "tipp": (
            "Ein Gedanke, ein Satz. Lange Schachtelsaetze kosten den Korrektor Zeit und dich "
            "Praezision - teile Saetze mit mehr als zwei Nebensaetzen."
        ),
    },
}


# --------------------------------------------------------------------------- #
# Laden
# --------------------------------------------------------------------------- #


def get_profil(user: User) -> LernprofilIn:
    """Das Lernprofil mit Defaults - tolerant gegen fehlende oder alte Felder."""
    raw = user.lernprofil if isinstance(user.lernprofil, dict) else {}
    try:
        return LernprofilIn.model_validate(raw)
    except ValueError:
        # Ein kaputtes Profil darf nie die Lernschleife blockieren.
        return LernprofilIn()


def ist_eingerichtet(user: User) -> bool:
    return bool(user.lernprofil)


# --------------------------------------------------------------------------- #
# Gedaechtnis
# --------------------------------------------------------------------------- #


def retention_for(profil: LernprofilIn, card_type: str | None) -> float:
    base = srs.DESIRED_RETENTION_BY_TYPE.get(card_type or "", srs.DEFAULT_RETENTION)
    offset = RETENTION_OFFSET.get(profil.sicherheitsniveau, 0.0)
    return max(RETENTION_MIN, min(RETENTION_MAX, base + offset))


# --------------------------------------------------------------------------- #
# Stoff
# --------------------------------------------------------------------------- #


def pausierte_themen(profil: LernprofilIn) -> set[str]:
    return set(profil.themen_pausiert)


def topic_weight(profil: LernprofilIn, topic_slug: str, area: str) -> float:
    """0 = pausiert; > 1 = Fokus oder Schwerpunkt-Rechtsgebiet."""
    if topic_slug in profil.themen_pausiert:
        return 0.0
    weight = 1.0
    if topic_slug in profil.themen_fokus:
        weight *= FOKUS_FAKTOR
    if area in profil.schwerpunkte:
        weight *= SCHWERPUNKT_FAKTOR
    return weight


def eigenes_deck(profil: LernprofilIn, slug: str) -> dict[str, Any] | None:
    for deck in profil.eigene_decks:
        if deck.slug == slug:
            return deck.model_dump()
    return None


# --------------------------------------------------------------------------- #
# Weg
# --------------------------------------------------------------------------- #


def persona(profil: LernprofilIn, user: User) -> str:
    if profil.ziel == "wiederholung":
        return PERSONA_WIEDERHOLUNG
    if profil.ziel == "examen" or user.exam_date is not None:
        return PERSONA_EXAMEN
    if profil.ziel in ("orientierung", "zwischenpruefung"):
        return PERSONA_EINSTIEG
    if profil.semester is not None:
        return PERSONA_EINSTIEG if profil.semester <= 2 else PERSONA_AUFBAU
    return PERSONA_EINSTIEG


@dataclass
class NextStepInput:
    """Alles, was :func:`next_step` braucht - ohne DB-Zugriff, damit die
    Regeln fuer sich testbar sind."""

    eingerichtet: bool
    persona: str
    due_cards: int
    # Kurs-Decks in Studienverlaufsreihenfolge: (slug, title, semester, mastery, cards_due)
    decks: list[dict[str, Any]]
    semester: int | None
    # Schwachstellen-Themen: (topic_slug, title, verfehlte_pruefpunkte)
    schwachstellen: list[dict[str, Any]]
    # Fall je Thema: topic_slug -> (case_slug, title)
    faelle_je_thema: dict[str, tuple[str, str]]
    # Schwaechstes gewichtetes Thema: (slug, title, mastery) oder None
    schwaechstes_thema: tuple[str, str, float] | None
    klausur_heute: bool
    klausur_vorschlag: dict[str, Any] | None


def next_step(inp: NextStepInput) -> dict[str, Any]:
    """Der eine naechste Schritt - Regel fuer Regel, erste passende gewinnt.

    Reihenfolge: Profil vor Rueckstand vor Klausurtag vor Persona-Einstieg.
    """
    if not inp.eingerichtet:
        return _step(
            "profil",
            "Lernprofil einrichten",
            "Semester, Ziel, Schwerpunkte und Rhythmus - drei Minuten, die jede "
            "Empfehlung ab hier passender machen.",
            {"type": "profil"},
        )
    if inp.due_cards > 0:
        return _step(
            "wiederholung",
            f"{inp.due_cards} faellige Karten wiederholen",
            "Wiederholungen zuerst - neuen Stoff aufzunehmen, waehrend Altes verfaellt, "
            "ist der teuerste Fehler.",
            {"type": "review"},
        )
    if inp.klausur_heute and inp.klausur_vorschlag:
        v = inp.klausur_vorschlag
        return _step(
            "klausur",
            f"Klausurtag: {v['title']}",
            v.get("begruendung", ""),
            {"type": "case", "slug": v["slug"], "title": v["title"], "mode": "klausur"},
        )
    if inp.persona == PERSONA_EINSTIEG:
        kandidaten = [
            d
            for d in inp.decks
            if inp.semester is None or (d.get("semester") or 99) <= inp.semester
        ]
        kandidaten = [d for d in kandidaten if not d.get("examenskurs")] or kandidaten
        if kandidaten:
            deck = min(kandidaten, key=lambda d: (d.get("mastery", 0.0), d.get("semester") or 99))
            return _step(
                "deck",
                f"Deck lernen: {deck['title']}",
                "Karten vor Schemata vor Faellen - das Deck mit der geringsten Reife in "
                "deinem Semesterstoff.",
                {"type": "deck", "slug": deck["slug"], "title": deck["title"]},
            )
    if inp.persona in (PERSONA_AUFBAU, PERSONA_EXAMEN, PERSONA_WIEDERHOLUNG) and inp.schwachstellen:
        s = inp.schwachstellen[0]
        fall = inp.faelle_je_thema.get(s["topic_slug"])
        if fall is not None:
            return _step(
                "fall",
                f"Fall zum Schwachpunkt: {fall[1]}",
                f"{s['verfehlte_pruefpunkte']} verfehlte Pruefpunkte zu '{s['title']}' - "
                "ein Fehler im Fall ist die beste Wiederholungskarte.",
                {"type": "case", "slug": fall[0], "title": fall[1], "mode": "uebung"},
            )
        return _step(
            "thema",
            f"Nacharbeiten: {s['title']}",
            f"{s['verfehlte_pruefpunkte']} verfehlte Pruefpunkte - erst die Karten, dann der "
            "naechste Fall.",
            {"type": "topic", "slug": s["topic_slug"], "title": s["title"]},
        )
    if inp.schwaechstes_thema is not None:
        slug, title, mastery = inp.schwaechstes_thema
        fall = inp.faelle_je_thema.get(slug)
        if inp.persona != PERSONA_EINSTIEG and fall is not None and mastery >= 0.5:
            return _step(
                "fall",
                f"Fall bearbeiten: {fall[1]}",
                f"'{title}' ist gewusst ({round(mastery * 100)} % reif), aber noch nicht "
                "angewendet.",
                {"type": "case", "slug": fall[0], "title": fall[1], "mode": "uebung"},
            )
        return _step(
            "thema",
            f"Weiter mit: {title}",
            f"Hoechste Prioritaet nach Relevanz, Fokus und Reife ({round(mastery * 100)} %).",
            {"type": "topic", "slug": slug, "title": title},
        )
    return _step(
        "frei",
        "Nichts faellig, nichts offen",
        "Gut gemacht. Ein Schema rekonstruieren oder einen Fall aus einem Deck waehlen.",
        {"type": "none"},
    )


def _step(kind: str, titel: str, begruendung: str, action: dict[str, Any]) -> dict[str, Any]:
    return {"kind": kind, "titel": titel, "begruendung": begruendung, "action": action}


def faelle_je_thema(db: Session, topic_slugs: set[str]) -> dict[str, tuple[str, str]]:
    """Leichtester Fall je Thema - fuer den Einstieg in die Anwendung."""
    result: dict[str, tuple[str, str]] = {}
    for case in db.query(Case).order_by(Case.difficulty, Case.slug).all():
        if case.topic_slug in topic_slugs and case.topic_slug not in result:
            result[case.topic_slug] = (case.slug, case.title)
    return result


# --------------------------------------------------------------------------- #
# Fehler
# --------------------------------------------------------------------------- #


def technik_tipp(strukturfehler: list[dict[str, Any]]) -> dict[str, Any] | None:
    """Der Tipp zum haeufigsten bekannten Strukturfehler."""
    for eintrag in strukturfehler:
        tipp = TECHNIK_TIPPS.get(str(eintrag.get("code", "")))
        if tipp is not None:
            return {**tipp, "code": eintrag["code"], "anzahl": eintrag.get("anzahl", 0)}
    return None


def validate_topic_refs(
    db: Session,
    profil: LernprofilIn,
    sichtbar: set[str],
    areas: list[str] | None = None,
) -> list[str]:
    """Fachliche Pruefung ueber die Pydantic-Validierung hinaus."""
    fehler: list[str] = []
    if areas is not None:
        for area in profil.schwerpunkte:
            if area not in areas:
                fehler.append(
                    f"schwerpunkte: '{area}' ist kein Fachgebiet deiner Fachrichtung "
                    f"(erlaubt: {', '.join(areas)})"
                )
    bekannt = {t.slug for t in db.query(Topic).all()}
    for feld in ("themen_fokus", "themen_pausiert"):
        for slug in getattr(profil, feld):
            if slug not in bekannt:
                fehler.append(f"{feld}: unbekanntes Thema '{slug}'")
            elif slug not in sichtbar:
                fehler.append(f"{feld}: Thema '{slug}' ist fuer dein Bundesland nicht sichtbar")
    doppelt = set(profil.themen_fokus) & set(profil.themen_pausiert)
    if doppelt:
        fehler.append(f"Thema kann nicht Fokus und pausiert sein: {', '.join(sorted(doppelt))}")
    slugs = [d.slug for d in profil.eigene_decks]
    if len(set(slugs)) != len(slugs):
        fehler.append("eigene_decks: Slugs muessen eindeutig sein")
    for deck in profil.eigene_decks:
        for slug in deck.topic_slugs:
            if slug not in bekannt:
                fehler.append(f"eigene_decks '{deck.slug}': unbekanntes Thema '{slug}'")
    return fehler
