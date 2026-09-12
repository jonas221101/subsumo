"""Analyse des Gutachtenstils - regelbasiert, offline, reproduzierbar.

Loest Challenge 1. Die gesamte juristische Pruefungsleistung haengt an einer
Technik (Obersatz - Definition - Subsumtion - Ergebnis), die in der
Massenuniversitaet niemand individuell korrigiert.

Bewusst *ohne* Sprachmodell: Struktur-Feedback muss sofort, kostenlos,
offline und vor allem reproduzierbar sein. Wer dieselbe Formulierung zweimal
einreicht, muss dieselbe Rueckmeldung bekommen - sonst verliert das Feedback
seine Autoritaet. Die inhaltliche Bewertung kommt getrennt davon in
``evaluator.py`` dazu.

Verfahren:
1. Saetze trennen (juristische Abkuerzungen und Paragraphenzitate geschuetzt)
2. Jeden Satz einem der vier Gutachtenschritte zuordnen
3. Obersaetze auf einen Stack legen, Ergebnisse schliessen sie wieder -
   dadurch wird die *Verschachtelung* der Pruefung korrekt abgebildet
4. Aus offenen Obersaetzen, uebersprungenen Subsumtionen und
   Urteilsstil-Verstoessen einen Score und konkrete Befunde ableiten
"""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass, field
from enum import StrEnum

# --------------------------------------------------------------------------- #
# Satztrennung
# --------------------------------------------------------------------------- #

# Abkuerzungen, deren Punkt kein Satzende ist. Ohne diese Liste zerfaellt
# "§ 433 Abs. 2 S. 1 BGB" in drei Saetze.
_ABBREVIATIONS = [
    "Abs.", "S.", "Nr.", "Alt.", "Var.", "lit.", "Hs.", "Halbs.", "Ziff.", "Art.",
    "i.S.d.", "i.S.v.", "i.V.m.", "i.E.", "i.Ü.", "d.h.", "z.B.", "vgl.", "bzw.",
    "ggf.", "insb.", "u.a.", "sog.", "evtl.", "grds.", "str.", "h.M.", "a.A.",
    "e.A.", "m.M.", "st.Rspr.", "Rspr.", "Lit.", "Az.", "Rn.", "Ls.", "Urt.",
    "Beschl.", "v.", "ff.", "f.", "Nrn.", "Buchst.", "Anm.", "Fn.", "Bd.",
]
_SENTENCE_END = re.compile(r"(?<=[.!?])\s+(?=[A-ZÄÖÜ§„\"(])")


def split_sentences(text: str) -> list[str]:
    """Trennt Saetze, ohne an juristischen Abkuerzungen zu zerbrechen."""
    guarded = text
    for i, abbr in enumerate(_ABBREVIATIONS):
        guarded = guarded.replace(abbr, f"\x00{i}\x00")
    # "§ 823 I 1" oder "Art. 2 I" - ein Punkt zwischen Ziffern ist kein Satzende.
    guarded = re.sub(r"(\d)\.(\s*\d)", "\\1\x01\\2", guarded)

    parts = [p.strip() for p in _SENTENCE_END.split(guarded) if p.strip()]

    restored = []
    for part in parts:
        for i, abbr in enumerate(_ABBREVIATIONS):
            part = part.replace(f"\x00{i}\x00", abbr)
        restored.append(part.replace("\x01", "."))
    return restored


# --------------------------------------------------------------------------- #
# Klassifikation der Gutachtenschritte
# --------------------------------------------------------------------------- #


class Step(StrEnum):
    OBERSATZ = "obersatz"
    DEFINITION = "definition"
    SUBSUMTION = "subsumtion"
    ERGEBNIS = "ergebnis"
    SONSTIGES = "sonstiges"


_OBERSATZ_PATTERNS = [
    r"\bkönnte[nst]?\b",
    r"\bmüsste[nst]?\b",
    r"\bfraglich\s+ist\b",
    r"\bin\s+Betracht\b",
    r"\bdazu\s+müsste\b",
    r"\bzu\s+prüfen\s+ist\b",
    r"\bvoraussetzung\s+(dafür\s+)?(ist|wäre)\b",
    r"\bes\s+müsste\b",
    r"\bdies\s+setzt\s+voraus\b",
    r"\bhätte\s+sich\b.*\bstrafbar\s+gemacht\b",
]

_DEFINITION_PATTERNS = [
    r"\bist\b[^.]{3,}\b(wenn|sofern|soweit)\b",
    r"\bliegt\s+vor,\s+wenn\b",
    r"\bsetzt\s+voraus,\s+dass\b",
    r"\bversteht\s+man\b",
    r"\bist\s+jede[rs]?\b",
    r"\bist\s+jedes\b",
    r"\bwird\s+definiert\s+als\b",
    r"\bbezeichnet\s+man\b",
    r"\berfordert\b",
    r"\bunter\b[^.]{3,}\bist\b[^.]{3,}\bzu\s+verstehen\b",
    # "Ein Angebot ist eine empfangsbeduerftige Willenserklaerung, die ..."
    r"^(ein|eine)\s+[\wäöüß-]+\s+(ist|sind)\b",
    # "Ein Kaufvertrag kommt durch Angebot und Annahme zustande."
    r"^(ein|eine)\s+[\wäöüß-]+\s+kommt\b[^.]{0,80}\bzustande\b",
    r"\bist\s+eine?\s+[\wäöüß-]+,\s+(die|der|das)\b",
]

_SUBSUMTION_PATTERNS = [
    r"\bhier\b",
    r"\bvorliegend\b",
    r"\bim\s+vorliegenden\s+fall\b",
    r"\blaut\s+sachverhalt\b",
    r"\bausweislich\s+des\s+sachverhalts\b",
    r"\bnach\s+dem\s+sachverhalt\b",
    r"\bdies\s+ist\s+der\s+fall\b",
    r"\bso\s+liegt\s+es\b",
    r"\bdaran\s+fehlt\s+es\b",
]

_ERGEBNIS_PATTERNS = [
    r"\bmithin\b",
    r"\bsomit\b",
    r"\bfolglich\b",
    r"\bdemnach\b",
    r"\bim\s+ergebnis\b",
    r"\bergebnis:\b",
    r"\bdamit\s+(ist|steht|besteht|liegt)\b",
    r"\bist\s+(daher|somit|folglich)\s+zu\s+(bejahen|verneinen)\b",
    r"\bder\s+anspruch\s+(besteht|ist\s+begründet)\b",
    r"\bhat\s+sich\b.*\bstrafbar\s+gemacht\b",
]

# Urteilsstil: das Ergebnis steht vorn, die Begruendung folgt mit "da"/"weil".
_URTEILSSTIL_OPENERS = re.compile(r"^\s*(Da|Weil|Nachdem|Aufgrund|Infolge)\s+", re.UNICODE)
_URTEILSSTIL_INLINE = re.compile(
    r"\b(ist|hat|liegt\s+vor|besteht|greift|entfällt)\b[^.]{0,80},\s*(da|weil)\s+",
    re.IGNORECASE,
)

_NORM_RE = re.compile(
    r"§§?\s*\d+[a-z]?"                       # Paragraph
    r"(?:\s*(?:Abs\.|Absatz)?\s*[IVX]+|\s*Abs\.\s*\d+)?"  # Absatz (roemisch/arabisch)
    r"(?:\s*(?:S\.|Satz)\s*\d+)?"
    r"(?:\s*(?:Nr\.|Alt\.|Var\.)\s*\d+)?"
    r"(?:\s+[A-ZÄÖÜ][A-Za-zÄÖÜäöü]{1,9}(?:G|O|B|GB|VO|StGB|GG))?"
)
_GESETZ_RE = re.compile(
    r"\b(BGB|StGB|GG|StPO|ZPO|VwGO|VwVfG|HGB|GmbHG|AktG|ArbGG|BauGB|"
    r"OWiG|UWG|MarkenG|UrhG|PatG|SGB|AO|EStG|GewO|BImSchG|POG|PolG|"
    r"StVO|StVG|VVG|WEG|InsO|GVG|EGBGB|AEUV|EUV|GRCh|EMRK)\b"
)


def _matches_any(text_lower: str, patterns: list[str]) -> bool:
    return any(re.search(p, text_lower, re.IGNORECASE) for p in patterns)


def classify_sentence(sentence: str) -> Step:
    """Ordnet einen Satz einem Gutachtenschritt zu.

    Reihenfolge ist bedeutsam: Die hypothetische Formulierung eines Obersatzes
    ("Fraglich ist, ob hier ...") schlaegt die Subsumtions- und
    Definitionsmarker, die im selben Satz stehen koennen.
    """
    low = sentence.lower()
    if _matches_any(low, _OBERSATZ_PATTERNS):
        return Step.OBERSATZ
    if _matches_any(low, _ERGEBNIS_PATTERNS):
        return Step.ERGEBNIS
    if _matches_any(low, _DEFINITION_PATTERNS):
        return Step.DEFINITION
    if _matches_any(low, _SUBSUMTION_PATTERNS):
        return Step.SUBSUMTION
    return Step.SONSTIGES


def extract_norms(text: str) -> list[str]:
    """Alle Paragraphenzitate in Reihenfolge des Auftretens, dedupliziert."""
    found = [re.sub(r"\s+", " ", m.group(0)).strip() for m in _NORM_RE.finditer(text)]
    seen: dict[str, None] = {}
    for norm in found:
        seen.setdefault(norm, None)
    return list(seen)


# --------------------------------------------------------------------------- #
# Befunde und Bericht
# --------------------------------------------------------------------------- #


class Severity(StrEnum):
    FEHLER = "fehler"
    HINWEIS = "hinweis"
    LOB = "lob"


@dataclass
class Finding:
    severity: Severity
    code: str
    message: str
    hint: str = ""
    sentence_index: int | None = None
    excerpt: str = ""


@dataclass
class GutachtenReport:
    score: int
    steps: list[str]
    counts: dict[str, int]
    findings: list[Finding]
    norms: list[str]
    missing_norms: list[str] = field(default_factory=list)
    words: int = 0
    sentences: int = 0
    avg_sentence_length: float = 0.0
    gutachtenstil_quote: float = 0.0

    def to_dict(self) -> dict:
        data = asdict(self)
        data["findings"] = [
            {**asdict(f), "severity": f.severity.value} for f in self.findings
        ]
        return data


_MAX_PENALTY = {"offener_obersatz": 24, "sprung": 20, "urteilsstil": 30}


def analyze(text: str, *, expected_norms: list[str] | None = None) -> GutachtenReport:
    """Analysiert ein Gutachten und liefert Score plus konkrete Befunde."""
    sentences = split_sentences(text)
    steps = [classify_sentence(s) for s in sentences]
    words = len(re.findall(r"\b[\wÄÖÜäöüß]+\b", text))
    counts = {step.value: sum(1 for s in steps if s is step) for step in Step}

    findings: list[Finding] = []
    penalties: dict[str, int] = dict.fromkeys(_MAX_PENALTY, 0)

    if words < 40:
        return GutachtenReport(
            score=0,
            steps=[s.value for s in steps],
            counts=counts,
            findings=[
                Finding(
                    Severity.HINWEIS,
                    "zu_kurz",
                    "Der Text ist zu kurz fuer eine Strukturanalyse.",
                    "Schreibe mindestens einen vollstaendigen Pruefungspunkt: "
                    "Obersatz, Definition, Subsumtion, Ergebnis.",
                )
            ],
            norms=extract_norms(text),
            words=words,
            sentences=len(sentences),
        )

    # --- Verschachtelte Pruefung ueber einen Obersatz-Stack ------------------ #
    stack: list[dict] = []
    jumps = 0

    def close_block(block: dict) -> None:
        """Schliesst einen Obersatz und traegt ihn zum uebergeordneten hoch."""
        nonlocal jumps
        # Ein vollstaendig geprueftes Unterproblem ist zugleich die Subsumtion
        # des uebergeordneten Obersatzes - sonst wuerde jede verschachtelte
        # Pruefung faelschlich als "Sprung" gemeldet.
        if stack:
            stack[-1]["subsumed"] = True
        if not block["subsumed"] and not block["defined"]:
            jumps += 1
            findings.append(
                Finding(
                    Severity.FEHLER,
                    "sprung_zum_ergebnis",
                    "Zwischen Obersatz und Ergebnis fehlt die Subsumtion.",
                    "Definiere erst das Tatbestandsmerkmal und wende es dann "
                    "ausdruecklich auf den Sachverhalt an ('Hier hat A ...').",
                    sentence_index=block["index"],
                    excerpt=block["text"][:160],
                )
            )

    for idx, (sentence, step) in enumerate(zip(sentences, steps, strict=True)):
        if step is Step.OBERSATZ:
            stack.append({"index": idx, "subsumed": False, "defined": False, "text": sentence})
        elif step in (Step.SUBSUMTION, Step.DEFINITION) and stack:
            key = "subsumed" if step is Step.SUBSUMTION else "defined"
            stack[-1][key] = True
        elif step is Step.ERGEBNIS and stack:
            # Das Schlussergebnis eines Gutachtens beantwortet die Fallfrage und
            # schliesst damit auch alle noch offenen uebergeordneten Obersaetze.
            # Gutachten fassen das regelmaessig zusammen, statt jede Ebene
            # einzeln abzuschliessen - das ist kein Fehler.
            letzter_satz = idx == len(sentences) - 1
            while stack:
                close_block(stack.pop())
                if not letzter_satz:
                    break

    # Was jetzt noch offen ist, wurde tatsaechlich nie beantwortet.
    schwer = leicht = 0
    for block in stack:
        hatte_substanz = block["subsumed"] or block["defined"]
        if hatte_substanz:
            leicht += 1
            findings.append(
                Finding(
                    Severity.HINWEIS,
                    "offener_obersatz",
                    "Dieser Pruefungspunkt wird bearbeitet, aber nicht ausdruecklich "
                    "abgeschlossen.",
                    "Formuliere das Zwischenergebnis ausdruecklich "
                    "('Mithin liegt ein Angebot vor.'). Korrektoren suchen danach.",
                    sentence_index=block["index"],
                    excerpt=block["text"][:160],
                )
            )
        else:
            schwer += 1
            findings.append(
                Finding(
                    Severity.FEHLER,
                    "offener_obersatz",
                    "Dieser Obersatz wird aufgeworfen und danach nie beantwortet.",
                    "Jeder Obersatz braucht Definition, Subsumtion und Ergebnis. "
                    "Offene Pruefungspunkte kosten in der Klausur sicher Punkte.",
                    sentence_index=block["index"],
                    excerpt=block["text"][:160],
                )
            )

    penalties["offener_obersatz"] = min(
        schwer * 12 + leicht * 5, _MAX_PENALTY["offener_obersatz"]
    )
    penalties["sprung"] = min(jumps * 10, _MAX_PENALTY["sprung"])
    unclosed = len(stack)

    # --- Urteilsstil --------------------------------------------------------- #
    urteilsstil = 0
    for idx, sentence in enumerate(sentences):
        opener = _URTEILSSTIL_OPENERS.match(sentence)
        inline = _URTEILSSTIL_INLINE.search(sentence)
        if opener or inline:
            urteilsstil += 1
            findings.append(
                Finding(
                    Severity.FEHLER,
                    "urteilsstil",
                    "Urteilsstil: Das Ergebnis steht vor der Begruendung.",
                    "Im Gutachten wird hypothetisch formuliert: erst 'Fraglich ist, "
                    "ob ...', dann Definition, dann Subsumtion, dann das Ergebnis. "
                    "Nur das Endergebnis darf im Urteilsstil stehen.",
                    sentence_index=idx,
                    excerpt=sentence[:160],
                )
            )
    penalties["urteilsstil"] = min(urteilsstil * 8, _MAX_PENALTY["urteilsstil"])

    # --- Grundbausteine ------------------------------------------------------ #
    score = 100
    if counts[Step.OBERSATZ.value] == 0:
        score -= 40
        findings.append(
            Finding(
                Severity.FEHLER,
                "kein_obersatz",
                "Es gibt keinen erkennbaren Obersatz.",
                "Beginne mit: 'A koennte gegen B einen Anspruch auf ... aus § ... haben.'",
            )
        )
    if counts[Step.DEFINITION.value] == 0:
        score -= 12
        findings.append(
            Finding(
                Severity.HINWEIS,
                "keine_definition",
                "Es wird kein Tatbestandsmerkmal definiert.",
                "Definiere die streitigen Merkmale, bevor du subsumierst - "
                "die Definition ist der Punktelieferant.",
            )
        )
    if counts[Step.SUBSUMTION.value] == 0:
        score -= 15
        findings.append(
            Finding(
                Severity.FEHLER,
                "keine_subsumtion",
                "Der Sachverhalt wird nicht erkennbar unter die Norm subsumiert.",
                "Beziehe dich ausdruecklich auf den Sachverhalt: 'Hier hat A ...', "
                "'Vorliegend ...'. Ohne Sachverhaltsbezug keine Subsumtion.",
            )
        )
    if counts[Step.ERGEBNIS.value] == 0:
        score -= 12
        findings.append(
            Finding(
                Severity.FEHLER,
                "kein_ergebnis",
                "Es fehlt ein abschliessendes Ergebnis.",
                "Schliesse mit 'Mithin hat A gegen B einen Anspruch aus § ...'.",
            )
        )

    score -= sum(penalties.values())

    # --- Normzitate ---------------------------------------------------------- #
    norms = extract_norms(text)
    if not norms:
        score -= 15
        findings.append(
            Finding(
                Severity.FEHLER,
                "keine_norm",
                "Es wird keine Anspruchsgrundlage bzw. Norm zitiert.",
                "Jeder Obersatz nennt die Norm mit Absatz, Satz und Alternative, "
                "z. B. '§ 433 Abs. 2 BGB'.",
            )
        )
    elif not _GESETZ_RE.search(text):
        score -= 5
        findings.append(
            Finding(
                Severity.HINWEIS,
                "gesetz_fehlt",
                "Die Paragraphen werden ohne Gesetzesangabe zitiert.",
                "Nenne das Gesetz mindestens beim ersten Zitat ('§ 433 Abs. 2 BGB').",
            )
        )

    missing_norms: list[str] = []
    if expected_norms:
        normalized = {re.sub(r"\s+", "", n).lower() for n in norms}
        for expected in expected_norms:
            key = re.sub(r"\s+", "", expected).lower()
            if not any(key in n or n in key for n in normalized):
                missing_norms.append(expected)
        if missing_norms:
            score -= min(8 * len(missing_norms), 20)
            findings.append(
                Finding(
                    Severity.HINWEIS,
                    "norm_nicht_geprueft",
                    "Erwartete Normen wurden nicht angesprochen: "
                    + ", ".join(missing_norms),
                    "Pruefe die Anspruchsgrundlagen vollstaendig und in der "
                    "richtigen Reihenfolge (vertraglich - quasivertraglich - "
                    "dinglich - deliktisch).",
                )
            )

    # --- Lesbarkeit ---------------------------------------------------------- #
    long_sentences = [i for i, s in enumerate(sentences) if len(s.split()) > 45]
    if long_sentences:
        score -= min(len(long_sentences) * 2, 8)
        findings.append(
            Finding(
                Severity.HINWEIS,
                "schachtelsatz",
                f"{len(long_sentences)} Satz/Saetze mit mehr als 45 Woertern.",
                "Ein Gedanke pro Satz. Korrektoren lesen unter Zeitdruck.",
                sentence_index=long_sentences[0],
                excerpt=sentences[long_sentences[0]][:160],
            )
        )

    strukturiert = sum(counts[s.value] for s in (
        Step.OBERSATZ, Step.DEFINITION, Step.SUBSUMTION, Step.ERGEBNIS
    ))
    quote = strukturiert / len(sentences) if sentences else 0.0
    if quote >= 0.75 and urteilsstil == 0 and unclosed == 0:
        findings.append(
            Finding(
                Severity.LOB,
                "sauberer_aufbau",
                "Sauberer Gutachtenaufbau: alle Obersaetze sind geschlossen, "
                "kein Urteilsstil.",
            )
        )

    return GutachtenReport(
        score=max(0, min(100, int(round(score)))),
        steps=[s.value for s in steps],
        counts=counts,
        findings=findings,
        norms=norms,
        missing_norms=missing_norms,
        words=words,
        sentences=len(sentences),
        avg_sentence_length=round(words / len(sentences), 1) if sentences else 0.0,
        gutachtenstil_quote=round(quote, 2),
    )
