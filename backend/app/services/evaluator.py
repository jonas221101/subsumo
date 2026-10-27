"""Inhaltliche Bewertung eines Gutachtens gegen einen Erwartungshorizont.

Loest Challenge 4. Zwei Designentscheidungen sind nicht verhandelbar:

* **Bewertung nur gegen einen hinterlegten Erwartungshorizont.** Es gibt keinen
  Endpunkt "bewerte diesen beliebigen Sachverhalt". Das haelt die Bewertung
  nachvollziehbar und die Anwendung ausserhalb des RDG
  (siehe docs/06-recht-compliance.md).
* **Jeder Punktabzug ist auf einen Pruefpunkt zurueckfuehrbar.** Eine Note ohne
  Begruendung ist wertlos; eine KI-Note ohne Begruendung ist schaedlich.

Ohne konfigurierten LLM-Provider laeuft der heuristische Evaluator. Der ist
schwaecher, aber vollstaendig offline, kostenlos und deterministisch - die App
funktioniert also auch ohne KI.
"""

from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from typing import Any, Protocol

from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.core.llm import LLMClient, get_llm_client
from app.models import User
from app.services import limits
from app.services.gutachten import (
    GutachtenReport,
    extract_norms,
    norm_matches,
    split_sentences,
)

# Notenskala der juristischen Staatspruefungen (JurNotSkalV): untere Grenze
# der jeweiligen Notenstufe in Punkten.
NOTENSTUFEN: list[tuple[float, str]] = [
    (16.0, "sehr gut"),
    (13.0, "gut"),
    (10.0, "vollbefriedigend"),
    (7.0, "befriedigend"),
    (4.0, "ausreichend"),
    (1.5, "mangelhaft"),
    (0.0, "ungenügend"),
]


def _de_zahl(x: float) -> str:
    """Deutsche Schreibweise: ``3.5`` -> ``3,5``, ganze Zahlen ohne ``,0``."""
    text = f"{x:.1f}"
    if text.endswith(".0"):
        text = text[:-2]
    return text.replace(".", ",")


def note_fuer_punkte(points: float) -> str:
    for untergrenze, name in NOTENSTUFEN:
        if points >= untergrenze:
            return name
    return "ungenügend"


@dataclass
class Pruefpunkt:
    """Ein Posten des Erwartungshorizonts."""

    id: str
    label: str
    weight: float = 1.0
    keywords: list[str] = field(default_factory=list)
    norms: list[str] = field(default_factory=list)
    required: bool = False
    # Verzahnung mit der Wiederholungskarte (SUB-263, docs/13-lernarchitektur.md
    # Abschnitt 3.2/3.3): wird dieser Pruefpunkt verfehlt, werden die hier
    # referenzierten Karten des einreichenden Nutzers faellig gestellt.
    card_slugs: list[str] = field(default_factory=list)


@dataclass
class PruefpunktResult:
    id: str
    label: str
    weight: float
    hit: bool
    evidence: str = ""
    comment: str = ""


@dataclass
class Evaluation:
    points: float                 # 0-18 (JAP-Skala)
    note: str
    content_ratio: float          # 0..1 gewichtete Trefferquote
    structure_score: int          # 0..100 aus der Strukturanalyse
    checkpoints: list[PruefpunktResult]
    missed_required: list[str]
    summary: str
    engine: str                   # "heuristik" | "llm:<model>"
    # Einzelne, klar formulierte Hinweise zur Deckelung (wichtigster zuerst).
    hinweise: list[str] = field(default_factory=list)
    # Punkte vor den gestaffelten Obergrenzen (nur Heuristik; sonst None).
    points_uncapped: float | None = None
    disclaimer: str = (
        "Lernhilfe, keine Rechtsberatung. Die Bewertung erfolgt gegen den "
        "hinterlegten Erwartungshorizont dieses Übungsfalls."
    )

    def to_dict(self) -> dict:
        data = asdict(self)
        data["points"] = round(self.points, 1)
        return data


def parse_expectation(raw: dict[str, Any] | None) -> list[Pruefpunkt]:
    points = (raw or {}).get("pruefpunkte", [])
    return [
        Pruefpunkt(
            id=str(p.get("id") or f"p{i}"),
            label=str(p.get("label", "")),
            weight=float(p.get("weight", 1.0)),
            # YAML liest ``- 43`` als int; ohne str() stuerzt der Abgleich ab.
            keywords=[str(k) for k in (p.get("keywords") or [])],
            norms=[str(n) for n in (p.get("norms") or [])],
            required=bool(p.get("required", False)),
            card_slugs=[str(c) for c in (p.get("card_slugs") or [])],
        )
        for i, p in enumerate(points)
    ]


def _normalize(text: str) -> str:
    text = text.lower()
    text = text.replace("ä", "a").replace("ö", "o").replace("ü", "u").replace("ß", "ss")
    return re.sub(r"\s+", " ", text)


def _digraph_fold(text: str) -> str:
    """Loest ASCII-Umlaut-Digraphen auf (ae/oe/ue -> a/o/u).

    Zwei Richtungen, ein Fallback: Ein Stichwort in ASCII-Transliteration
    ('ausdruecklich') trifft nach _normalize() keinen Text mit echtem Umlaut
    ('ausdrücklich' -> 'ausdrucklich', Einzelbuchstabe) - und umgekehrt trifft
    ein Stichwort mit echtem Umlaut ('überzeugend' -> 'uberzeugend') keinen
    Nutzertext, der 'ueberzeugend' ohne Umlauttaste getippt hat. Beides wurde
    beim ersten echten End-to-End-Testlauf der KI-Redaktion real beobachtet.

    Deshalb wird diese Faltung auf BEIDE Seiten des Vergleichs angewendet -
    bewusst nur als zweiter, nachrangiger Versuch, nachdem der direkte
    Treffer auf dem unveraenderten Text gescheitert ist. Sie kann seltene
    echte Wortfolgen wie 'neue' -> 'neu' verkuerzen und so einen Treffer
    liefern, der bei genauerem Hinsehen Zufall ist - hinnehmbar fuer einen
    ohnehin heuristischen Fallback-Evaluator (siehe HEURISTIK_MAX_PUNKTE),
    nicht fuer die LLM-Bewertung, die diese Funktion nicht verwendet.
    """
    for digraph, letter in (("ae", "a"), ("oe", "o"), ("ue", "u")):
        text = text.replace(digraph, letter)
    return text


class Evaluator(Protocol):
    def evaluate(
        self, *, text: str, expectation: dict, structure: GutachtenReport
    ) -> Evaluation: ...


# Obergrenze fuer die Heuristik. Ein Stichwortabgleich kann erkennen, *ob* ein
# Pruefpunkt angesprochen wurde - nicht, ob die Argumentation traegt. Ein
# Praedikatsexamen (ab 9 Punkten) vergibt man dafuer nicht, und schon gar kein
# "sehr gut". Eine geschenkte Note zerstoert das Vertrauen in jede spaetere
# Rueckmeldung; die Deckelung wird dem Nutzer ausdruecklich erklaert.
HEURISTIK_MAX_PUNKTE = 11.0


# --------------------------------------------------------------------------- #
# Stichwortabgleich: Wortgrenzen, Negation, Satzkontext
# --------------------------------------------------------------------------- #

# Verneinung *vor* dem Treffer (innerhalb derselben Satzteils, max. 3 Woerter):
# "nicht erforderlich", "keine Enteignung", "ohne Rechtfertigung".
_NEG_VOR = frozenset(
    {
        "nicht", "kein", "keine", "keinen", "keinem", "keiner", "keines", "nie",
        "niemals", "ohne", "weder", "mangels", "fehlende", "fehlenden", "fehlender",
        "fehlendes",
    }
)
# Verneinung *nach* dem Treffer ("Ein Eingriff liegt nicht vor", "Der Angriff
# fehlt", "Die Notwehrlage scheidet aus") - nur mit Praedikat, damit
# "Meinungen und keine Tatsachen" ein Treffer auf "Meinung" bleibt.
_NEG_NACH = re.compile(
    r"\b(?:nicht|kein\w*|nie|niemals)\s+(?:vor|gegeben|erfullt|eroffnet|gewahrt|"
    r"einschlagig|ersichtlich|gedeckt|betroffen|verletzt|gerechtfertigt|zu\s+bejahen|"
    r"anzunehmen|zutreffend|erforderlich|begrundet|wirksam|nachgewiesen|der\s+fall)\b"
    r"|\b(?:fehlt|fehlen|entfallt|entfallen|ausgeschlossen|abzulehnen|zu\s+verneinen|"
    r"verneint|verneinen|mangelt)\b"
    # Plural und Singular: "scheidet/scheiden (hier) aus"
    r"|\bscheid(?:et|en)\s+(?:\w+\s+)?aus\b"
    r"|\bkomm(?:t|en)\s+(?:\w+\s+)?nicht\s+in\s+betracht\b"
    r"|\bbesteh(?:t|en)\s+(?:\w+\s+)?nicht\b"
    r"|\bgreif(?:t|en)\s+(?:\w+\s+)?nicht\b"
    r"|\b(?:ist|sind)\s+(?:\w+\s+)?(?:unzulassig|unbegrundet)\b"
)
# Pruefpunkte, deren Label selbst eine Verneinung/Abgrenzung verlangt: dort ist
# "liegt nicht vor" die *richtige* Antwort und kein Widerspruch.
_LABEL_VERNEINUNG_ERLAUBT = re.compile(
    r"verneint|unbeachtlich|abgrenz|abgelehnt|entfallt|scheidet aus|ausgeschlossen"
    # Label *beginnt* mit der Verneinung ("Keine taetige Reue", "Ergebnis: kein ...");
    # ein "kein" mitten im Label ("...; Kein Raeumungsanspruch") erlaubt sie nicht.
    r"|^(?:[a-z ]{1,30}:\s*)?keine?n?\b"
)
_VERBEN = frozenset(
    "ist sind war waren wird werden wurde wurden hat haben hatte hatten kann kann "
    "konnte koennte muss muesste musste soll liegt liegen lag besteht bestand gilt "
    "gelten greift entfaellt scheidet handelt handelte erfuellt erfolgt steht bleibt "
    "macht fuehrt zeigt ergibt folgt verlangt setzt genuegt reicht bedeutet stellt "
    "hindert begruendet schuetzt verstoesst verstoesst verletzt trifft wollte wusste "
    "besteht".split()
)
_ARTIKEL = frozenset(
    "ein eine einen einem einer eines der die das den dem des dieser diese dieses".split()
)
_PARTIZIP = re.compile(r"\bge[a-z]{3,}(?:t|en)\b")
# Kleingeschriebene Wortformen auf -t/-te/-ten/-en gelten (ausser diesen) als finites Verb.
_KEIN_VERB = frozenset(
    "nicht jetzt bereits zumindest weit erst selbst zuletzt jedoch damit sowie "
    "gerecht oft meist nebst samt statt trotz zudem hingegen entsprechend "
    "bestimmt gemeint gewiss allerdings gegen neben zwischen wegen innen aussen "
    "unten oben hinten vorn".split()
)
_VERB_FORM = re.compile(r"^[a-z]{3,}(?:t|te|ten|en)$")
_PRAEPOSITIONEN = frozenset(
    "in an auf aus bei mit nach von vor zu zur zum zwischen unter uber durch fur gegen "
    "ohne um seit bis am im vom beim ins ans aufs hinter neben wegen trotz gemass "
    "innerhalb ausserhalb als so wie dieselbe derselbe".split()
)
_ADJEKTIV_ENDUNG = ("e", "en", "er", "es", "em")
MIN_SATZ_WOERTER = 6
INHALT_VOLL_SCHWELLE = 0.75
MIN_KURZSATZ_WOERTER = 3
MAX_KOMMA_DICHTE = 0.3
MIN_LISTEN_ABSCHNITTE = 6

_ZAHL_KEYWORD = re.compile(r"\d+[a-z]?")
_PARAGRAPH_TOKEN = re.compile(r"§§?|art\.?|[^\s,]+|,")
_PARAGRAPH_KETTE = frozenset(
    {"abs", "abs.", "absatz", "s.", "satz", "nr.", "alt.", "var.", "und", "bis", "u.", "/", ",",
     "i", "ii", "iii", "iv", "v", "vi", "f.", "ff."}
)


def _kw_muster(kwn: str) -> re.Pattern[str]:
    if _ZAHL_KEYWORD.fullmatch(kwn):
        ende = r"(?![a-z0-9])"
    else:
        ende = r"(?!\d)" if kwn[-1:].isdigit() else ""
    return re.compile(r"(?<![a-z0-9])" + re.escape(kwn) + ende)


def _ist_vollstaendiger_satz(satz: str) -> bool:
    """Heuristik: Satz mit Verb, ausreichend lang und keine Aufzaehlung.

    Stichwortlisten ("Notwehrlage, gegenwaertiger Angriff, erforderlich") sollen
    keine Inhaltspunkte liefern: Ein Treffer zaehlt nur im Satzzusammenhang.
    """
    woerter = re.findall(r"[\wäöüÄÖÜß]+", satz)
    if len(woerter) < MIN_SATZ_WOERTER:
        # Kurze Ergebnissaetze ("Das Vorhaben ist unzulaessig.") sind echte
        # Aussagen: ab drei Woertern mit Satzpunkt, ohne Komma und mit finitem
        # Verb aus der Verbliste (Nutzertest W11).
        return (
            len(woerter) >= MIN_KURZSATZ_WOERTER
            and satz.rstrip().endswith((".", "!"))
            and "," not in satz
            and _hat_listenverb(satz)
        )
    # Zeile ohne Satzschlusszeichen, aber mit Aufzaehlungs-/Zitatmerkmalen
    # ("Antragsbefugnis, § 80 Abs. 5 VwGO, aufschiebende Wirkung"): nur mit
    # echtem finitem Verb aus der Liste ein Satz.
    streng = not satz.rstrip().endswith((".", "!", "?")) and (
        satz.count(",") >= 2 or satz.count("§") >= 2
    )
    if streng and not _hat_listenverb(satz):
        return False
    verb = _hat_listenverb if streng else _hat_verb
    if satz.count(",") / len(woerter) > MAX_KOMMA_DICHTE:
        return False
    # Lange Stichwortketten ("Antragsbefugnis, § 80 Abs. 5 VwGO, Eilbeduerftigkeit, ...")
    # druecken die Kommadichte, weil Normzitate viele "Woerter" haben. Ab sechs
    # Kommaabschnitten zaehlt es nur als Satz, wenn mehr als ein Abschnitt ein Verb traegt.
    abschnitte = [a for a in re.split(r"[,;]", satz) if a.strip()]
    if len(abschnitte) >= MIN_LISTEN_ABSCHNITTE:
        mit_verb = sum(verb(a) for a in abschnitte)
        # Echte Satzgefuege tragen in den meisten Abschnitten ein Verb; eine Stichwortkette
        # mit ein paar "X ist Y"-Stichworten tut das nicht.
        return mit_verb > 1 and mit_verb >= 0.4 * len(abschnitte)
    return verb(satz)


def _hat_listenverb(text: str) -> bool:
    return any(t in _VERBEN for t in re.findall(r"[a-z0-9]+", _normalize(text)))


def _adjektiv_positionen(woerter: list[str]) -> set[int]:
    """Indizes dekliniert gebrauchter Adjektive ("am selben Tag", "die konkrete Gefahr").

    Ein kleingeschriebenes Wort auf -e/-en/-er/-es/-em direkt vor einem
    grossgeschriebenen Nomen und hinter Artikel/Praeposition (oder hinter einem
    weiteren Adjektiv, auch ueber "und"/"oder") ist kein Verb.
    """
    norm = [_normalize(w) for w in woerter]
    adj: set[int] = set()
    for i, w in enumerate(woerter):
        if i == 0 or i + 1 >= len(woerter):
            continue
        if not w[:1].islower() or not woerter[i + 1][:1].isupper():
            continue
        if norm[i] in _VERBEN or not norm[i].endswith(_ADJEKTIV_ENDUNG):
            continue
        prev = norm[i - 1]
        if (
            prev in _ARTIKEL
            or prev in _PRAEPOSITIONEN
            or prev.startswith(("kein", "mein", "sein", "ihr", "unser", "dies", "jen", "jed"))
            or (i - 1) in adj
            or (prev in ("und", "oder") and i >= 2 and (i - 2) in adj)
            or (
                prev in ("und", "oder")
                and i >= 3
                and woerter[i - 2][:1].islower()
                and norm[i - 2].endswith(_ADJEKTIV_ENDUNG)
                and (norm[i - 3] in _ARTIKEL or norm[i - 3] in _PRAEPOSITIONEN)
            )
        ):
            adj.add(i)
    # "die konkrete und unmittelbare Gefahr": das erste Adjektiv steht vor "und"/"oder".
    for i in range(len(woerter) - 3, 0, -1):
        if (
            woerter[i][:1].islower()
            and norm[i] not in _VERBEN
            and norm[i].endswith(_ADJEKTIV_ENDUNG)
            and norm[i + 1] in ("und", "oder")
            and (i + 2) in adj
            and (norm[i - 1] in _ARTIKEL or norm[i - 1] in _PRAEPOSITIONEN)
        ):
            adj.add(i)
    return adj


def _hat_verb(text: str) -> bool:
    norm = _normalize(text)
    tokens = re.findall(r"[a-z0-9]+", norm)
    if any(t in _VERBEN for t in tokens):
        return True
    woerter = re.findall(r"[\wäöüÄÖÜß]+", text)
    adj = _adjektiv_positionen(woerter)
    for i, w in enumerate(woerter):
        if i in adj:
            continue
        n = _normalize(w)
        if re.fullmatch(r"ge[a-z]{3,}(?:t|en)", n):
            return True
        # Kleingeschriebene Formen auf -t/-te/-ten im Originalsatz ("kommt").
        if w[:1].islower() and _VERB_FORM.match(n) and n not in _KEIN_VERB:
            return True
    return False


def _saetze(text: str) -> list[str]:
    """Saetze des Textes; Zeilenumbrueche trennen auch ohne Satzzeichen."""
    result: list[str] = []
    for zeile in re.split(r"\n+", text):
        if zeile.strip():
            result.extend(split_sentences(zeile))
    return result


def _wortende(satz: str, pos: int) -> int:
    while pos < len(satz) and satz[pos].isalnum():
        pos += 1
    return pos


def _verneint(satz: str, start: int, ende: int, *, nach: bool = True) -> bool:
    """Steht der Treffer ``satz[start:ende]`` im Verneinungsfenster?"""
    # "nicht Nichtstoerer, sondern Verhaltensstoerer": die Verneinung gilt nur bis
    # zur Gegenueberstellung, nicht fuer den Teil dahinter.
    vorher = re.split(r"[,;:]|\b(?:sondern|vielmehr|aber)\b", satz[:start])[-1]
    if any(
        t in _NEG_VOR or t.startswith("kein")
        for t in re.findall(r"[a-z0-9]+", vorher)[-3:]
    ):
        return True
    if not nach:
        return False
    # Nach dem Treffer: bis zum Satzteil-Ende. Ein Komma beendet den Satzteil nur,
    # wenn davor ein Verb stand - sonst ist es eine Aufzaehlung ("Ein Erklaerungsirrtum,
    # ein Inhaltsirrtum und ein Motivirrtum liegen nicht vor").
    rest = satz[_wortende(satz, ende):]
    nachher: list[str] = []
    # Aufzaehlung nur, wenn der Treffer ein Substantiv am Satzteil-Anfang ist
    # ("Ein Erklaerungsirrtum, ..."), nicht ein Praedikat ("war auch geboten, ...").
    davor = re.findall(r"[a-z0-9]+", vorher)
    aufzaehlung = not davor or davor[-1] in _ARTIKEL
    for teil in re.split(r"(?<=[;:])|,", rest)[:4]:
        nachher.append(teil)
        verb = any(t in _VERBEN for t in re.findall(r"[a-z0-9]+", teil))
        if verb or teil.endswith((";", ":")) or not aufzaehlung:
            break
    return bool(_NEG_NACH.search(" ".join(" ".join(nachher).split()[:12])))


def _in_paragraphkette(satz: str, start: int) -> bool:
    """Steht die Zahl an ``start`` hinter einem ``§``/``Art.``-Zitat?"""
    vorher = satz[max(0, start - 70):start]
    for token in reversed(_PARAGRAPH_TOKEN.findall(vorher)):
        if token in ("§", "§§") or token.startswith("art"):
            return True
        if token in _PARAGRAPH_KETTE or re.fullmatch(r"\d+[a-z]?", token):
            continue
        return False
    return False


def _vorkommen(satz: str, kwn: str) -> list[tuple[str, int, int]]:
    """Alle Treffer eines normalisierten Stichworts im normalisierten Satz.

    Wortanfang statt Substring ("unbeendeter Versuch" trifft nicht "beendeter
    Versuch"); reine Zahlen nur hinter einem Paragraphen-/Artikelzeichen.
    Erst direkt, dann mit ae/oe/ue-Faltung auf beiden Seiten.
    """
    varianten = [(satz, kwn)]
    gefaltet = (_digraph_fold(satz), _digraph_fold(kwn))
    if gefaltet != varianten[0]:
        varianten.append(gefaltet)
    zahl = bool(_ZAHL_KEYWORD.fullmatch(kwn))
    for text, kw in varianten:
        treffer = []
        for m in _kw_muster(kw).finditer(text):
            if zahl and not _in_paragraphkette(text, m.start()):
                continue
            treffer.append((text, m.start(), m.end()))
        if treffer:
            return treffer
    return []


def _ist_normstichwort(kwn: str) -> bool:
    """Stichwort ist ein reines Normzitat ("§ 242", "art. 14")."""
    return bool(re.match(r"(?:§|art\b)", kwn)) or bool(_ZAHL_KEYWORD.fullmatch(kwn))


def _kw_negation_erwartet(label_n: str, kwn: str) -> bool:
    """Das Stichwort ist selbst verneinend oder steht im Label hinter einer Verneinung."""
    if any(t in _NEG_VOR for t in kwn.split()):
        return True
    return bool(
        re.search(
            r"\b(?:nicht|kein\w*|ohne|nie|weder)\s+(?:\w+\s+){0,2}" + re.escape(kwn), label_n
        )
    )


def _punkte_aus_roh(roh: float) -> float:
    return round(roh * 18 * 2) / 2


def _runde_halb(x: float) -> float:
    return round(x * 2) / 2


class HeuristicEvaluator:
    """Stichwort- und Normabgleich gegen den Erwartungshorizont.

    Bewusst konservativ und gedeckelt: er erkennt, *ob* ein Pruefpunkt
    angesprochen wurde, nicht ob die Argumentation traegt. Das ist ehrlicher
    als eine Scheinnote und als Fallback ohne Netz belastbar.

    Schutz gegen die offensichtlichsten Umgehungen (Test 8, Stresstest):

    * Wortgrenzen und Verneinungserkennung ("nicht erforderlich" ist kein Treffer),
    * Treffer zaehlen nur in vollstaendigen Saetzen (keine Stichwortlisten),
    * gestaffelte Deckel statt harter Klippe: fehlende Kernpunkte, kaputte
      Struktur, Copy-Paste und ein Text zum falschen Fall senken die Obergrenze.
    """

    name = "heuristik"

    def evaluate(
        self, *, text: str, expectation: dict, structure: GutachtenReport
    ) -> Evaluation:
        checkpoints = parse_expectation(expectation)

        # Nur Saetze mit Verb und Satzbau zaehlen als inhaltliche Aussage.
        gesehen: set[str] = set()
        saetze: list[str] = []
        for satz in _saetze(text):
            if not _ist_vollstaendiger_satz(satz):
                continue
            n = _normalize(satz)
            if n not in gesehen:
                gesehen.add(n)
                saetze.append(n)
        saetze_roh = _saetze_roh(text)
        alle_stichworte = [
            kwn
            for cp in checkpoints
            for kwn in (_normalize(k) for k in cp.keywords)
            if kwn and not _ZAHL_KEYWORD.fullmatch(kwn)
        ]

        results: list[PruefpunktResult] = []
        widerspruch: list[tuple[str, str]] = []  # (Label, Stichwort)
        for cp in checkpoints:
            label_n = _normalize(cp.label)
            # "... geprueft": ein Ergebnis wie "Einschraenkungen sind nicht ersichtlich"
            # ist dort richtig; nur die Verneinung *vor* dem Stichwort zaehlt.
            nur_vor = "gepruft" in label_n and "sauber" not in label_n
            verneinung_ok = bool(_LABEL_VERNEINUNG_ERLAUBT.search(label_n))
            hit, evidence, contra = False, "", ""
            norm_treffer = ""
            positive: list[tuple[str, int, int]] = []  # (Stichwort, Satzindex, Position)
            verneint_ab: dict[int, int] = {}  # Satzindex -> frueheste verneinte Position
            for kw in cp.keywords:
                kwn = _normalize(kw)
                if not kwn:
                    continue
                zahl = bool(_ZAHL_KEYWORD.fullmatch(kwn))
                geprueft = not verneinung_ok and not _kw_negation_erwartet(label_n, kwn)
                pos_idx: int | None = None
                pos_start = 0
                neg_idx: list[tuple[int, int]] = []
                for idx, satz in enumerate(saetze):
                    for variante, a, b in _vorkommen(satz, kwn):
                        if geprueft and not zahl and _verneint(
                            variante, a, b, nach=not nur_vor
                        ):
                            neg_idx.append((idx, a))
                        elif pos_idx is None:
                            pos_idx, pos_start = idx, a
                    if pos_idx is not None:
                        break
                if pos_idx is not None:
                    positive.append((kw, pos_idx, pos_start))
                elif neg_idx:
                    for n_idx, n_start in neg_idx:
                        verneint_ab[n_idx] = min(n_start, verneint_ab.get(n_idx, n_start))
                    contra = contra or kw
            for kw, idx, start in positive:
                if _ist_normstichwort(_normalize(kw)):
                    norm_treffer = norm_treffer or kw
                # Steht die Verneinung eines Stichworts im selben Satz VOR dem zweiten
                # Stichwort ("Die Verteidigung war nicht erforderlich, denn A haette Flucht
                # ergreifen muessen"), gilt sie auch dafuer; steht es davor, bleibt es positiv.
                elif start < verneint_ab.get(idx, start + 1) and not hit:
                    hit, evidence = True, kw
            if hit:
                # Ein positiver inhaltlicher Treffer in einem ANDEREN Satz gilt, auch wenn ein
                # weiteres Stichwort desselben Pruefpunkts verneint wurde ("Ein Notstand liegt
                # nicht vor ... die Versammlung ist verboten").
                contra = ""
            elif contra:
                # Kein inhaltliches Stichwort trifft unverneint, eines ist verneint:
                # Widerspruch zum erwarteten Ergebnis. Ein blosses Normzitat als
                # Stichwort ("§ 242") hebt das nicht auf - ein Zitat ist keine Stellung.
                widerspruch.append((cp.label, contra))
            elif norm_treffer:
                hit, evidence = True, norm_treffer
            else:
                for norm in cp.norms:
                    if _norm_fallback_gilt(norm, checkpoints, saetze_roh, alle_stichworte):
                        hit, evidence = True, norm
                        break
            if hit:
                comment = ""
            elif contra:
                comment = (
                    f"Du erwähnst „{contra}“, verneinst es aber. Erwartet wird: {cp.label}."
                )
            else:
                comment = f"Dieser Prüfpunkt wird nicht angesprochen. Erwartet: {cp.label}."
            results.append(
                PruefpunktResult(
                    id=cp.id,
                    label=cp.label,
                    weight=cp.weight,
                    hit=hit,
                    evidence=evidence,
                    comment=comment,
                )
            )

        total_weight = sum(cp.weight for cp in checkpoints) or 1.0
        achieved = sum(cp.weight for cp, r in zip(checkpoints, results, strict=True) if r.hit)
        content_ratio = achieved / total_weight

        required = [cp for cp in checkpoints if cp.required]
        missed_required = [
            cp.label
            for cp, r in zip(checkpoints, results, strict=True)
            if cp.required and not r.hit
        ]
        getroffen = sum(1 for r in results if r.hit)

        # Inhalt zaehlt deutlich schwerer als Form - so bewerten Korrektoren auch.
        raw = 0.72 * content_ratio + 0.28 * (structure.score / 100)
        wrong_case = bool(checkpoints) and getroffen == 0
        if wrong_case:
            # Struktur allein ist kein Verdienst, wenn nichts zum Fall passt.
            raw = 0.0
        points_roh = min(HEURISTIK_MAX_PUNKTE, _punkte_aus_roh(raw))

        # Gestaffelte Obergrenzen: (Grenze, Hinweis). Es zaehlt die niedrigste.
        deckel: list[tuple[float, str]] = []
        if wrong_case:
            deckel.append((
                1.0,
                "Deine Lösung passt offenbar nicht zum Sachverhalt: Kein einziger "
                "Prüfpunkt wurde erkannt.",
            ))
        req_grenze = None
        if missed_required:
            anteil = len(missed_required) / len(required)
            grenze = max(3.5, _runde_halb(HEURISTIK_MAX_PUNKTE - 7.5 * anteil))
            req_grenze = grenze
            deckel.append((grenze, ""))
        if widerspruch:
            grenze = max(3.0, HEURISTIK_MAX_PUNKTE - 2.0 * len(widerspruch))
            deckel.append((
                grenze,
                "Bei "
                + ", ".join(f"„{lab}“ (du schreibst: {kw} verneint)" for lab, kw in widerspruch)
                + " widerspricht deine Formulierung dem erwarteten Ergebnis.",
            ))
        if not wrong_case and content_ratio < INHALT_VOLL_SCHWELLE:
            # Oberhalb von ~2/3 getroffener Pruefpunkte erreichte die Rohskala sonst
            # schon den Deckel - 5 von 8 Punkten zaehlten wie 8 von 8 (Nutzertest W16).
            deckel.append((
                9.0,
                f"Es fehlen noch wesentliche Prüfpunkte ({content_ratio:.0%} gewichtet "
                "angesprochen) - deshalb höchstens 9 Punkte.",
            ))
        if structure.score == 0:
            deckel.append((
                4.0,
                "Ohne erkennbaren Gutachtenaufbau (z. B. Stichwortliste, "
                "Urteilsstil oder zu kurzer Text) sind höchstens 4 Punkte möglich.",
            ))
        elif structure.score < 30:
            deckel.append((
                6.0,
                "Wegen des schwachen Gutachtenaufbaus (z. B. "
                "Urteilsstil statt Gutachtenstil) sind höchstens 6 Punkte möglich.",
            ))
        dup = getattr(structure, "duplicate_ratio", 0.0)
        if dup > 0.5:
            deckel.append((
                3.0,
                f"Der Text besteht zu {dup:.0%} aus wortgleichen Wiederholungen; "
                "wiederholter Text zählt nur einmal.",
            ))
        elif dup > 0.25:
            deckel.append((
                6.0,
                f"{dup:.0%} der Sätze sind wortgleiche Wiederholungen; "
                "wiederholter Text zählt nur einmal.",
            ))

        points = points_roh
        for grenze, _ in deckel:
            points = min(points, grenze)
        points = max(0.0, points)

        # --- Rueckmeldung: wichtigste Einschraenkung zuerst --------------------
        hinweise: list[str] = []
        for grenze, hinweis in deckel:
            if hinweis and (grenze < points_roh or wrong_case):
                hinweise.append(hinweis)
        if missed_required:
            namen = ", ".join(missed_required)
            satz = (
                f"Kernprüfpunkte fehlen: {namen} - nicht erkannt. Falls du sie anders "
                "formuliert hast, kann die automatische Bewertung sie übersehen."
            )
            if req_grenze is not None and req_grenze < points_roh:
                satz += (
                    f" Die Punktzahl ist deshalb auf {_de_zahl(points)} begrenzt "
                    f"(ohne diese Begrenzung: {_de_zahl(points_roh)})."
                )
            hinweise.insert(1 if wrong_case else 0, satz)

        summary = ""
        if points >= HEURISTIK_MAX_PUNKTE:
            summary = (
                "Die automatische Bewertung prüft, ob die erwarteten Prüfungspunkte "
                "angesprochen werden – nicht, wie überzeugend argumentiert wird. "
                f"Deshalb vergibt sie höchstens {_de_zahl(HEURISTIK_MAX_PUNKTE)} Punkte."
            )
        if hinweise:
            summary = (summary + " " if summary else "") + " ".join(hinweise)
        summary += (
            f" Ergebnis: {getroffen} von {len(results)} Prüfpunkten angesprochen "
            f"(gewichtet {content_ratio:.0%}), Aufbau {structure.score}/100 Punkte."
        )
        summary = summary.strip()

        return Evaluation(
            points=points,
            note=note_fuer_punkte(points),
            content_ratio=round(content_ratio, 3),
            structure_score=structure.score,
            checkpoints=results,
            missed_required=missed_required,
            summary=summary,
            engine=self.name,
            hinweise=hinweise,
            points_uncapped=points_roh,
        )


def _norm_fallback_gilt(
    norm: str,
    checkpoints: list[Pruefpunkt],
    saetze_roh: list[str],
    alle_stichworte: list[str],
) -> bool:
    """Trifft ``norm`` allein ueber ein Normzitat - und ist das belastbar?

    Eine Norm, die in mehr als zwei Pruefpunkten des Falls steht, ist kein
    Unterscheidungsmerkmal (z. B. eine Generalnorm). Ausserdem muss der zitierende
    Satz mehr als das Zitat enthalten: ein weiteres inhaltliches Stichwort
    (irgendeines Pruefpunkts) oder ein Verb aus ``_VERBEN``.
    """
    vorkommen = sum(
        1 for cp in checkpoints if any(norm_matches(norm, other) for other in cp.norms)
    )
    if vorkommen > 2:
        return False
    for satz in saetze_roh:
        if not any(norm_matches(norm, seen) for seen in extract_norms(satz)):
            continue
        if _hat_listenverb(satz):
            return True
        satz_n = _normalize(satz)
        if any(_vorkommen(satz_n, kwn) for kwn in alle_stichworte):
            return True
    return False


def _saetze_roh(text: str) -> list[str]:
    """Volle Saetze (unnormalisiert), fuer die Normerkennung im Satzzusammenhang."""
    return [s for s in _saetze(text) if _ist_vollstaendiger_satz(s)]


class LLMEvaluator:
    """Bewertung durch ein Sprachmodell - streng an den Erwartungshorizont gebunden.

    Faellt bei jedem Fehler (kein Key, Timeout, unparsbare Antwort) lautlos auf
    die Heuristik zurueck. Ein Ausfall des Providers darf nie dazu fuehren, dass
    ein Nutzer nach fuenf Stunden Klausur gar kein Feedback bekommt.

    Es wird keine Nutzerkennung uebertragen (Pseudonymisierung, Art. 32 DSGVO).
    """

    def __init__(self, client: LLMClient | None = None) -> None:
        self.settings = get_settings()
        self.fallback = HeuristicEvaluator()
        # Injizierbar fuer Tests (FakeLLMClient) - Produktionscode laesst das
        # weg und bekommt den echten Anthropic-Client ueber get_llm_client().
        self.client = client

    @property
    def name(self) -> str:
        return f"llm:{self.settings.llm_model}"

    def _build_prompt(self, text: str, checkpoints: list[Pruefpunkt]) -> str:
        horizont = "\n".join(
            f"- [{cp.id}] {cp.label} (Gewicht {cp.weight}"
            + (", zwingend" if cp.required else "")
            + (f", Normen: {', '.join(cp.norms)}" if cp.norms else "")
            + ")"
            for cp in checkpoints
        )
        return (
            "Du korrigierst eine juristische Übungsklausur. Bewerte AUSSCHLIESSLICH "
            "anhand des folgenden Erwartungshorizonts. Erfinde keine Prüfpunkte und "
            "keine Normen.\n\n"
            f"ERWARTUNGSHORIZONT:\n{horizont}\n\n"
            f"GUTACHTEN DES PRUEFLINGS:\n{text}\n\n"
            "Antworte ausschliesslich mit JSON nach diesem Schema:\n"
            '{"checkpoints":[{"id":"...","hit":true,"evidence":"wörtliches Zitat aus '
            'dem Gutachten","comment":"knappe Begründung"}],'
            '"summary":"zwei bis vier Saetze Gesamtrueckmeldung"}\n'
            "Regeln: 'hit' nur true, wenn der Prüfpunkt inhaltlich tatsächlich "
            "behandelt wird, nicht bei bloßer Erwähnung. 'evidence' muss wörtlich "
            "im Gutachten stehen."
        )

    def evaluate(
        self, *, text: str, expectation: dict, structure: GutachtenReport
    ) -> Evaluation:
        base = self.fallback.evaluate(text=text, expectation=expectation, structure=structure)
        client = self.client or get_llm_client()
        if not getattr(client, "available", True):
            return base

        checkpoints = parse_expectation(expectation)
        try:
            response = client.complete(self._build_prompt(text, checkpoints), max_tokens=4000)
            parsed = json.loads(re.search(r"\{.*\}", response.text, re.S).group(0))
        except Exception:  # noqa: BLE001 - jeder Fehler fuehrt zum Fallback
            return base

        by_id = {c["id"]: c for c in parsed.get("checkpoints", []) if isinstance(c, dict)}
        results: list[PruefpunktResult] = []
        for cp in checkpoints:
            raw = by_id.get(cp.id, {})
            evidence = str(raw.get("evidence", ""))
            # Schutz gegen halluzinierte Belege: das Zitat muss im Text stehen.
            if evidence and _normalize(evidence) not in _normalize(text):
                evidence = ""
            results.append(
                PruefpunktResult(
                    id=cp.id,
                    label=cp.label,
                    weight=cp.weight,
                    hit=bool(raw.get("hit", False)),
                    evidence=evidence,
                    comment=str(raw.get("comment", "")),
                )
            )

        total_weight = sum(cp.weight for cp in checkpoints) or 1.0
        hits = sum(cp.weight for cp, r in zip(checkpoints, results, strict=True) if r.hit)
        content_ratio = hits / total_weight
        missed_required = [
            cp.label
            for cp, r in zip(checkpoints, results, strict=True)
            if cp.required and not r.hit
        ]
        raw_score = 0.72 * content_ratio + 0.28 * (structure.score / 100)
        points = round(raw_score * 18 * 2) / 2
        if missed_required:
            points = min(points, 3.5)

        return Evaluation(
            points=max(0.0, min(18.0, points)),
            note=note_fuer_punkte(points),
            content_ratio=round(content_ratio, 3),
            structure_score=structure.score,
            checkpoints=results,
            missed_required=missed_required,
            summary=str(parsed.get("summary", base.summary)),
            engine=self.name,
        )


def llm_configured(settings: Settings | None = None) -> bool:
    """Ob ein LLM-Provider grundsaetzlich aktiv ist (unabhaengig von Einwilligung).

    Basis fuer das Feature-Flag in ``GET /v1/public/config`` (SUB-133).
    """
    settings = settings or get_settings()
    return settings.llm_provider == "anthropic" and bool(settings.llm_api_key)


def get_evaluator(
    *, consented: bool = True, db: Session | None = None, user: User | None = None
) -> Evaluator:
    """Waehlt den Evaluator. ``consented=False`` erzwingt die Heuristik.

    Ohne Einwilligung wird ``LLMEvaluator`` gar nicht erst konstruiert - der
    Nutzertext verlaesst das System damit strukturell nicht in Richtung
    Provider, nicht nur durch ein Verhalten, das man auch vergessen koennte
    (SUB-133, Einwilligungs-Gate vor LLM-Versand).

    Kostenbremse (SUB-310): ist entweder das Fair-Use-Limit des Nutzers oder
    das globale Monatsbudget erreicht, wird ebenfalls lautlos auf die
    Heuristik zurueckgefallen - kein Fehler, kein 5xx, der Nutzer merkt nur
    eine andere Korrekturqualitaet (siehe ``app/services/limits.py``). Ohne
    ``db``/``user`` (z. B. der Kalibrierungs-Harness in
    ``scripts/kalibrierung_cli.py``, der ausserhalb eines Requests laeuft)
    greift die Kostenbremse nicht, da es dort keinen abzurechnenden Nutzer
    gibt.
    """
    settings = get_settings()
    if not (llm_configured(settings) and consented):
        return HeuristicEvaluator()
    if db is not None and user is not None:
        now = datetime.now(UTC)
        if limits.llm_user_quota_exceeded(db, user, now=now) or limits.llm_global_budget_exhausted(
            db, settings, now=now
        ):
            return HeuristicEvaluator()
        limits.record_llm_correction_call(db, user, now=now)
    return LLMEvaluator()
