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
    # Schreibweisen mit Leerzeichen, wie sie in Klausuren ueblich sind - laengere
    # zuerst, damit "i. S. d." nicht als "S." geschuetzt und dann zerlegt wird.
    "i. S. d.", "i. S. v.", "i. V. m.", "st. Rspr.", "z. B.", "d. h.", "u. a.",
    "h. M.", "a. A.", "e. A.", "m. M.", "i. E.", "a. F.", "n. F.", "o. g.", "s. o.", "s. u.",
]
_DATUM_TAG = re.compile(
    r"\b(\d{1,2})\.(?=\s+(?:Januar|Februar|März|April|Mai|Juni|Juli|August|September"
    r"|Oktober|November|Dezember)\b)"
)
_SENTENCE_END = re.compile(r"(?<=[.!?])\s+(?=[A-ZÄÖÜ§„\"(])")


def split_sentences(text: str) -> list[str]:
    """Trennt Saetze, ohne an juristischen Abkuerzungen zu zerbrechen."""
    guarded = text
    # Laengste zuerst: sonst zerlegt "S." die Kette "i. S. d." vorab.
    for i, abbr in sorted(enumerate(_ABBREVIATIONS), key=lambda e: -len(e[1])):
        guarded = guarded.replace(abbr, f"\x00{i}\x00")
    # "§ 823 I 1" oder "Art. 2 I" - ein Punkt zwischen Ziffern ist kein Satzende.
    guarded = re.sub(r"(\d)\.(\s*\d)", "\\1\x01\\2", guarded)
    # "am 1. April" - der Punkt nach einer Tageszahl vor einem Monatsnamen ist
    # kein Satzende (Nutzertest 2026-10-15: Fristen in Faellen zerfielen).
    guarded = _DATUM_TAG.sub("\\1\x01", guarded)

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
    # "Eine Misshandlung ist jede Behandlung, die ..." / "spricht man von ..."
    r"\bspricht\s+man\b",
    r"\bgilt\s+(als|dann)\b",
    r"\bwird\s+(dann\s+)?(angenommen|bejaht|verwirklicht|erfüllt),\s+(wenn|sofern|soweit)\b",
    r"\bliegt\s+(dann|immer|stets|nur|bereits)\b[^.]{0,30}\bvor\b",
    r"\bbedeutet\b",
    r"\bdefiniert\b",
    r"\bist\s+(dann|nur|immer|stets)\b[^.]{0,40}\b(wenn|sofern|soweit|gegeben|erfüllt)\b",
    r"\bdarunter\s+(ist|fällt|fallen)\b",
    r"\bunter\b[^.]{3,}\bversteht\b",
    r"\b(erforderlich|maßgeblich|entscheidend)\s+ist\b",
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
    r"\bim\s+(konkreten|vorliegenden|hiesigen)\s+(fall|sachverhalt)\b",
    r"\bim\s+sachverhalt\b",
    r"\bdies\s+(ist|war|trifft)\b[^.]{0,20}\b(der\s+fall|zu|hier|gegeben)\b",
    r"\bdas\s+(ist|war|trifft)\b[^.]{0,20}\b(hier|vorliegend|zu)\b",
    r"\bdemnach\s+hat\b",
    r"\bsachverhalt\b[^.]{0,40}\b(ergibt|zeigt|entnehmen)\b",
]

# Subsumtion in eigenen Worten: ein Beteiligter (Einzelbuchstabe) tut oder erleidet
# etwas im Sachverhalt ("A hat ...", "B erlitt ..."). Gross-/Kleinschreibung zaehlt
# hier, deshalb getrennt vom lower()-Abgleich.
_SUBSUMTION_BETEILIGTER = re.compile(
    r"(?:^|[\s(])[A-Z]\s+(?:hat|hatte|wollte|wusste|handelte|erlitt|schlug|war|ist|"
    r"erklärte|gab|bot|legte|holte|befand|konnte|musste|tat|zeigte|nahm|sagte|"
    r"schrieb|tippte|kannte|wurde)\b"
)

_ERGEBNIS_PATTERNS = [
    r"\bmithin\b",
    r"\bsomit\b",
    r"\bfolglich\b",
    r"\bdemnach\b",
    r"\bim\s+ergebnis\b",
    r"\bergebnis\s*:",
    # "Damit hat K keinen Anspruch ...", "IV. Damit ist die Klage unbegruendet." -
    # am Satzanfang; "damit" als Konjunktion ("damit der Vertrag ...") bleibt aussen vor.
    r"^\W*(?:[ivx]+\.\s*|\d+\.\s*)?damit\s+(?:\w+\s+){0,3}"
    r"(?:hat|haben|ist|sind|steht|besteht|liegt|bleibt|kann|muss|wird)\b",
    # Ausformuliertes Ergebnis ohne Signalwort (OeR/SR); Definitionen ("..., wenn")
    # bleiben aussen vor.
    r"\b(?:ist|sind|war|bleibt)\b[^.;]{0,80}\b(?:rechtswidrig|rechtmäßig|unwirksam|nichtig|"
    r"verfassungswidrig|verfassungsgemäß|unbegründet|unzulässig)\b"
    r"(?![^.]*\b(?:wenn|sofern|soweit|falls)\b)",
    r"\b(?:ist|sind)\s+(?:\w+\s+){0,2}(?:strafbar|begründet)\b(?![^.]*\b(?:wenn|sofern|soweit|falls)\b)",
    r"\bhat\s+(?:\w+\s+){0,2}erfolg\b(?![^.]*\b(?:wenn|sofern|soweit|falls)\b)",
    r"\b(?:kann|darf|muss|hat|ist)\s+(?:\w+\s+)?(?:deshalb|daher|folglich)\b",
    r"\bmacht(?:e|en)?\s+sich\b[^.]{0,80}\bstrafbar\b",
    r"\bstrafbar\s+gemacht\b",
    r"\bdamit\s+(ist|steht|besteht|liegt)\b",
    r"\bist\s+(daher|somit|folglich)\s+zu\s+(bejahen|verneinen)\b",
    r"\bder\s+anspruch\s+(besteht|ist\s+begründet)\b",
    r"\bhat\s+sich\b.*\bstrafbar\s+gemacht\b",
    r"\bzusammenfassend\b",
    r"\b(deshalb|daher|also)\b[^.]{0,60}\b(liegt|ist|sind|besteht|bestand|scheidet|entfällt|"
    r"kann|hat|haben|steht|muss|darf)\b",
    r"\bsomit\w*\b",
    r"\bmithin\w*\b",
    r"\bfolglich\w*\b",
]

# Urteilsstil: das Ergebnis steht vorn, die Begruendung folgt mit "da"/"weil".
_URTEILSSTIL_OPENERS = re.compile(r"^\s*(Da|Weil|Nachdem|Aufgrund|Infolge)\s+", re.UNICODE)
_URTEILSSTIL_INLINE = re.compile(
    r"\b(ist|hat|liegt\s+vor|besteht|greift|entfällt)\b[^.,]{0,70},\s*(da|weil)\s+",
    re.IGNORECASE,
)

# Gesetzeskuerzel hinter einer Norm: mindestens zwei Grossbuchstaben ("BGB", "GO", "BauO",
# "PolG"), optional mit Laenderkuerzel ("GO SH", "BauO NRW", "PolG BW"); reine roemische
# Ziffern ("II") sind Absaetze, kein Gesetz.
_LAENDER = r"(?:SH|NRW|BW|BY|BE|BB|HB|HH|HE|MV|NI|RP|SL|SN|ST|TH|LSA|Bay|Bbg)"
_GESETZ_WORT = (
    r"(?![IVX]+\b)[A-ZÄÖÜ][A-Za-zÄÖÜäöü]*[A-ZÄÖÜ][A-Za-zÄÖÜäöü]*(?:\s+" + _LAENDER + r"\b)?"
)
_GESETZ_IN_NORM = re.compile(r"\s(?:" + _GESETZ_WORT + r")$")

_NORM_RE = re.compile(
    r"§§?\s*\d+(?:\s?[a-z](?![A-Za-zÄÖÜäöü]))?"                       # Paragraph
    r"(?:\s*(?:Abs\.|Absatz)?\s*[IVX]+|\s*Abs\.\s*\d+)?"  # Absatz (roemisch/arabisch)
    r"(?:\s*(?:S\.|Satz)\s*\d+)?"
    r"(?:\s*(?:Nr\.|Alt\.|Var\.)\s*\d+)?"
    r"(?:\s+" + _GESETZ_WORT + r")?"
    r"|"
    # Verfassungs-/Unionsrecht: "Art. 5 Abs. 3 GG", "Art. 12 I GG", "Art. 5 I 1 GG"
    r"\bArt\.?\s*\d+[a-z]?"
    r"(?:\s*(?:Abs\.|Absatz)\s*\d+|\s+[IVX]+\b)?"
    r"(?:\s*(?:S\.|Satz)\s*\d+|\s+\d\b)?"
    r"(?:\s*(?:Nr\.|Alt\.|Var\.)\s*\d+[a-z]?)?"
    r"(?:\s+(?:GG|EMRK|GRCh|EUV|AEUV|WRV|" + _GESETZ_WORT + r")\b)?"
)
_GESETZ_RE = re.compile(
    r"\b(BGB|StGB|GG|StPO|ZPO|VwGO|VwVfG|HGB|GmbHG|AktG|ArbGG|BauGB|"
    r"OWiG|UWG|MarkenG|UrhG|PatG|SGB|AO|EStG|GewO|BImSchG|POG|PolG|"
    r"StVO|StVG|VVG|WEG|InsO|GVG|EGBGB|AEUV|EUV|GRCh|EMRK|GO|BauO|LBO|BayBO|PAG|ASOG|SOG|"
    r"LKrO|KrO|HGO|NBauO|HBauO|BbgBO|BauOBln|SächsBO|ThürBO|BauO|LVwG|LVwVfG)\b"
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
    if _matches_any(low, _SUBSUMTION_PATTERNS) or _SUBSUMTION_BETEILIGTER.search(sentence):
        return Step.SUBSUMTION
    return Step.SONSTIGES


_ROEMISCH = {"I": "1", "II": "2", "III": "3", "IV": "4", "V": "5", "VI": "6"}
_NORM_PARTS_RE = re.compile(
    r"(?P<art>§§?|Art\.?)\s*(?P<num>\d+[a-z]?)"
    r"(?:\s*(?:Abs\.|Absatz)\s*(?P<abs>\d+)|\s+(?P<rom>[IVX]+)\b)?",
    re.IGNORECASE,
)


def norm_parts(norm: str) -> tuple[str, str, str, str] | None:
    """Zerlegt ein Normzitat in (Art/§, Nummer, Absatz, Gesetz) fuer den Abgleich.

    ``"Art. 12 I GG"`` und ``"Art. 12 Abs. 1 GG"`` ergeben dasselbe Tupel.
    Nicht zerlegbare Zitate liefern ``None``.
    """
    # "§ 311 b" und "§ 311b" sind dieselbe Norm.
    norm = re.sub(r"(\d)\s([a-z])(?![A-Za-zÄÖÜäöü])", r"\1\2", norm)
    m = _NORM_PARTS_RE.search(norm)
    if not m:
        return None
    art = "art" if m.group("art").lower().startswith("art") else "§"
    absatz = m.group("abs") or _ROEMISCH.get((m.group("rom") or "").upper(), "")
    gesetze = _GESETZ_RE.findall(norm)
    gesetz = gesetze[-1].lower() if gesetze else ""
    return art, m.group("num").lower(), absatz, gesetz


def norm_matches(expected: str, found: str) -> bool:
    """Ob ein zitiertes Norm ``found`` die erwartete ``expected`` abdeckt.

    Nummer und (falls beide es nennen) Gesetz muessen uebereinstimmen. Ein
    fehlender Absatz beim Studierenden ist unschaedlich: ``§ 223 StGB``
    deckt ``§ 223 Abs. 1 StGB``. Fallback auf den alten Textabgleich fuer
    exotische Zitate.
    """
    e, f = norm_parts(expected), norm_parts(found)
    if e is None or f is None:
        a = re.sub(r"\s+", "", expected).lower()
        b = re.sub(r"\s+", "", found).lower()
        return a in b or b in a
    if e[0] != f[0] or e[1] != f[1]:
        return False
    if e[3] and f[3] and e[3] != f[3]:
        return False
    return True


def collapse_expected_norms(expected: list[str]) -> list[str]:
    """Fasst Alternativen derselben Norm zusammen (``§ 223 StGB`` / ``§ 223 Abs. 1 StGB``).

    Ein Erwartungshorizont fuehrt die gleiche Norm oft in mehreren Schreibweisen
    auf, damit der Abgleich grosszuegig ist. Als *fehlend* darf sie aber nur
    einmal gemeldet werden. Angezeigt wird die kuerzeste Schreibweise.
    """
    groups: dict[tuple, str] = {}
    for norm in expected:
        parts = norm_parts(norm)
        key = (parts[0], parts[1], parts[3]) if parts else (norm,)
        if key not in groups or len(norm) < len(groups[key]):
            groups[key] = norm
    return list(groups.values())


_NORM_LIST_RE = re.compile(
    r"§§\s*(?P<nums>(?:\d+[a-z]?\s*(?:,|und|sowie|u\.|bis)\s*)+\d+[a-z]?)"
    r"(?:\s*(?:Abs\.\s*[\d, ]+|[IVX]+\b))?"
    r"(?:\s+(?P<gesetz>" + _GESETZ_RE.pattern.split("(", 1)[1].rsplit(")", 1)[0] + r"))?"
)


def extract_norms(text: str) -> list[str]:
    """Alle Paragraphenzitate in Reihenfolge des Auftretens, dedupliziert."""
    listen = list(_NORM_LIST_RE.finditer(text))
    found: list[tuple[int, str]] = []
    for m in _NORM_RE.finditer(text):
        if any(l.start() <= m.start() < l.end() for l in listen):  # noqa: E741
            continue
        found.append((m.start(), re.sub(r"\s+", " ", m.group(0)).strip()))
    # "§§ 143, 121 BGB": die Aufzaehlung traegt Gesetz nur einmal am Ende.
    for m in listen:
        gesetz = f" {m.group('gesetz')}" if m.group("gesetz") else ""
        found.extend(
            (m.start(), f"§ {n}{gesetz}") for n in re.findall(r"\d+[a-z]?", m.group("nums"))
        )
    found.sort(key=lambda item: item[0])
    found_norms = [n for _, n in found]
    seen: dict[str, None] = {}
    for norm in found_norms:
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
    # Anteil wortgleich wiederholter Saetze (Copy-Paste), 0..1; nur Saetze ab 4 Woertern.
    duplicate_ratio: float = 0.0

    def to_dict(self) -> dict:
        data = asdict(self)
        data["findings"] = [
            {**asdict(f), "severity": f.severity.value} for f in self.findings
        ]
        return data


def _norm_hinweis(missing: list[str]) -> str:
    """Hinweistext passend zum Rechtsgebiet der fehlenden Normen."""
    text = " ".join(missing)
    if re.search(r"\b(StGB|StPO|OWiG)\b", text):
        return (
            "Prüfe die Strafbarkeit vollständig und in der richtigen Reihenfolge "
            "(Tatbestand - Rechtswidrigkeit - Schuld) und nenne die einschlägigen Normen."
        )
    if re.search(r"\b(GG|VwGO|VwVfG|BauGB|EMRK|GRCh|POG|PolG)\b", text):
        return (
            "Prüfe die einschlägigen Normen vollständig und in der richtigen "
            "Reihenfolge (z. B. Schutzbereich - Eingriff - Rechtfertigung bzw. "
            "Zulässigkeit - Begründetheit)."
        )
    if re.search(r"\b(BGB|HGB|ZPO|GmbHG|AktG)\b", text):
        return (
            "Prüfe die Anspruchsgrundlagen vollständig und in der richtigen "
            "Reihenfolge (vertraglich - quasivertraglich - dinglich - deliktisch)."
        )
    return "Prüfe die einschlägigen Normen vollständig und in der richtigen Reihenfolge."


_MAX_PENALTY = {"offener_obersatz": 24, "sprung": 20, "urteilsstil": 30}


def duplicate_ratio(sentences: list[str]) -> float:
    """Anteil wortgleich wiederholter Saetze (ab 4 Woertern); 0 bei kurzen Texten."""
    normalized = [re.sub(r"\W+", " ", s.lower()).strip() for s in sentences]
    normalized = [n for n in normalized if len(n.split()) >= 4]
    if len(normalized) < 6:
        return 0.0
    return round(1 - len(set(normalized)) / len(normalized), 3)


def _collapse_findings(findings: list[Finding]) -> list[Finding]:
    """Fasst gleiche Befunde (Code + Textstelle) zusammen, statt sie 40-fach zu listen."""
    seen: dict[tuple[str, str], int] = {}
    result: list[Finding] = []
    counts: dict[tuple[str, str], int] = {}
    for f in findings:
        key = (f.code, f.excerpt)
        if not f.excerpt or key not in seen:
            seen[key] = len(result)
            counts[key] = 1
            result.append(f)
        else:
            counts[key] += 1
    for key, idx in seen.items():
        if counts[key] > 1:
            f = result[idx]
            result[idx] = Finding(
                f.severity, f.code, f"{f.message} (×{counts[key]})", f.hint,
                f.sentence_index, f.excerpt,
            )
    return result


_BEISPIELE = {
    "zivilrecht": {
        "obersatz": "A könnte gegen B einen Anspruch auf ... aus § ... haben.",
        "zwischen": "Mithin liegt ein wirksamer Vertrag vor.",
        "ergebnis": "Mithin hat A gegen B einen Anspruch aus § ... bzw. keinen Anspruch.",
        "norm": "'§ 433 Abs. 2 BGB'",
    },
    "strafrecht": {
        "obersatz": "A könnte sich wegen ... nach § ... StGB strafbar gemacht haben.",
        "zwischen": "Mithin ist der Tatbestand des § ... StGB erfüllt.",
        "ergebnis": "A hat sich somit wegen ... nach § ... StGB strafbar gemacht "
        "(bzw. nicht strafbar gemacht).",
        "norm": "'§ 223 Abs. 1 StGB'",
    },
    "oeffentliches-recht": {
        "obersatz": "Die Klage könnte zulässig und begründet sein. / "
        "Die Maßnahme könnte rechtswidrig sein.",
        "zwischen": "Mithin ist die Klage zulässig. / Mithin liegt ein Eingriff in den "
        "Schutzbereich vor.",
        "ergebnis": "Die Maßnahme ist mithin rechtmäßig bzw. rechtswidrig; die Klage "
        "hat (keinen) Erfolg.",
        "norm": "'Art. 5 Abs. 1 S. 1 GG', '§ 80 Abs. 5 VwGO' oder '§ 22 GO SH'",
    },
}
_BEISPIELE_NEUTRAL = {
    "obersatz": "Es könnte ... vorliegen (Fragestellung mit Norm).",
    "zwischen": "Mithin ist das Merkmal erfüllt (bzw. nicht erfüllt).",
    "ergebnis": "Mithin ist ... (Antwort auf die Fallfrage).",
    "norm": "'§ 433 Abs. 2 BGB', '§ 223 Abs. 1 StGB' oder 'Art. 5 Abs. 1 S. 1 GG'",
}


def analyze(
    text: str, *, expected_norms: list[str] | None = None, area: str | None = None
) -> GutachtenReport:
    """Analysiert ein Gutachten und liefert Score plus konkrete Befunde.

    ``area`` (zivilrecht | strafrecht | oeffentliches-recht) waehlt passende
    Formulierungsbeispiele in den Hinweisen; ohne Angabe gelten neutrale.
    """
    bsp = _BEISPIELE.get(area or "", _BEISPIELE_NEUTRAL)
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
                    "Der Text ist zu kurz für eine Strukturanalyse.",
                    "Schreibe mindestens einen vollständigen Prüfungspunkt: "
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
                    "ausdrücklich auf den Sachverhalt an ('Hier hat A ...').",
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
        elif step is Step.SONSTIGES and stack and len(sentence.split()) >= 9:
            # Ein ausformulierter Argumentationssatz ohne Signalphrase ist keine
            # Luecke: Wer in eigenen Worten schreibt ("Der Hieb hat eine Prellung
            # verursacht ..."), springt nicht zum Ergebnis.
            stack[-1]["defined"] = True
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
    unabgeschlossen: list[dict] = []
    for block in stack:
        hatte_substanz = block["subsumed"] or block["defined"]
        if hatte_substanz:
            leicht += 1
            unabgeschlossen.append(block)
        else:
            schwer += 1
            findings.append(
                Finding(
                    Severity.FEHLER,
                    "offener_obersatz",
                    "Dieser Obersatz wird aufgeworfen und danach nie beantwortet.",
                    "Jeder Obersatz braucht Definition, Subsumtion und Ergebnis. "
                    "Offene Prüfungspunkte kosten in der Klausur sicher Punkte.",
                    sentence_index=block["index"],
                    excerpt=block["text"][:160],
                )
            )

    if unabgeschlossen:
        erster = unabgeschlossen[0]
        # Gleichartige Hinweise werden gebuendelt, nicht je Prüfungspunkt wiederholt.
        mehrere = f" (×{len(unabgeschlossen)})" if len(unabgeschlossen) > 1 else ""
        findings.append(
            Finding(
                Severity.HINWEIS,
                "offener_obersatz",
                "Dieser Prüfungspunkt wird bearbeitet, aber nicht ausdrücklich "
                f"abgeschlossen{mehrere}.",
                "Formuliere das Zwischenergebnis ausdrücklich "
                f"(z. B. '{bsp['zwischen']}'). Korrektoren suchen danach.",
                sentence_index=erster["index"],
                excerpt=erster["text"][:160],
            )
        )
    penalties["offener_obersatz"] = min(
        schwer * 12 + leicht * 4, _MAX_PENALTY["offener_obersatz"]
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
                    "Urteilsstil: Das Ergebnis steht vor der Begründung.",
                    "Im Gutachten wird hypothetisch formuliert: erst 'Fraglich ist, "
                    "ob ...', dann Definition, dann Subsumtion, dann das Ergebnis. "
                    "Nur das Endergebnis darf im Urteilsstil stehen.",
                    sentence_index=idx,
                    excerpt=sentence[:160],
                )
            )
    penalties["urteilsstil"] = min(urteilsstil * 10, _MAX_PENALTY["urteilsstil"])

    # --- Grundbausteine ------------------------------------------------------ #
    score = 100
    if counts[Step.OBERSATZ.value] == 0:
        score -= 40
        findings.append(
            Finding(
                Severity.FEHLER,
                "kein_obersatz",
                "Es gibt keinen erkennbaren Obersatz.",
                f"Beginne mit: '{bsp['obersatz']}'",
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
                "Beziehe dich ausdrücklich auf den Sachverhalt: 'Hier hat A ...', "
                "'Vorliegend ...'. Ohne Sachverhaltsbezug keine Subsumtion.",
            )
        )
    if counts[Step.ERGEBNIS.value] == 0:
        score -= 12
        findings.append(
            Finding(
                Severity.FEHLER,
                "kein_ergebnis",
                "Es fehlt ein abschließendes Ergebnis.",
                f"Schließe mit z. B.: '{bsp['ergebnis']}'",
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
                "Es wird keine Norm zitiert.",
                "Jeder Obersatz nennt die Norm mit Absatz, Satz und Alternative, "
                f"z. B. {bsp['norm']}.",
            )
        )
    elif not _GESETZ_RE.search(text) and not any(_GESETZ_IN_NORM.search(n) for n in norms):
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
        for expected in collapse_expected_norms(expected_norms):
            if not any(norm_matches(expected, n) for n in norms):
                missing_norms.append(expected)
        if missing_norms:
            score -= min(8 * len(missing_norms), 20)
            findings.append(
                Finding(
                    Severity.HINWEIS,
                    "norm_nicht_geprueft",
                    "Erwartete Normen wurden nicht angesprochen: "
                    + ", ".join(missing_norms),
                    _norm_hinweis(missing_norms),
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
                "Sauberer Gutachtenaufbau: alle Obersätze sind geschlossen, "
                "kein Urteilsstil.",
            )
        )

    dup = duplicate_ratio(sentences)
    if dup > 0.25:
        score -= 20
        findings.append(
            Finding(
                Severity.FEHLER,
                "wiederholung",
                f"{dup:.0%} der Sätze sind wortgleiche Wiederholungen.",
                "Wiederholter Text zählt nur einmal. Entwickle jeden Prüfungspunkt "
                "einmal vollständig, statt Passagen zu kopieren.",
            )
        )
    findings = _collapse_findings(findings)

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
        duplicate_ratio=dup,
    )
