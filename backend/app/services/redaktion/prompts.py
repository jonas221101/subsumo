"""Prompt-Vorlagen fuer die KI-Redaktion.

Beide Agenten bekommen dasselbe Format-Kontrakt vorgegeben wie in
docs/05-content-pipeline.md beschrieben - der Collector schreibt danach, der
Reviewer prueft danach. Eine Abweichung zwischen Prompt und Doku waere ein
Bug, deshalb steht das Schema hier nur einmal (SCHEMA_BESCHREIBUNG) und wird
in beide Prompts eingesetzt.
"""

from __future__ import annotations

SCHEMA_BESCHREIBUNG = """\
Antworte AUSSCHLIESSLICH mit einem YAML-Dokument nach exakt diesem Schema
(keine Erklaerung davor oder danach, kein Markdown-Codeblock):

topic:
  slug: <kebab-case, eindeutig, z.B. zr-schuldrecht-at-unmoeglichkeit>
  area: {areas}
  title: <Klartext-Titel>
  parent: <slug des Elternthemas, falls vorhanden>
  relevance: <1-5, Pruefungsrelevanz>
  stand: "<YYYY-MM>"

cards:
  - slug: <eindeutig>
    type: {kartentypen}
    front: "<Frage/Vorderseite>"
    back: "<Antwort/Rueckseite, praezise, Definitions-Stil>"
    norms: [{norm_beispiel}]
    einheiten: ["U in V", "I in A"]   # nur bei type: formel (Groesse in SI-Einheit)
    quellen: ["<Gesetz, amtliche Fassung>" | "<eigene Formulierung Redaktion>"]
    stand: "<YYYY-MM>"

schemata:
  - slug: <eindeutig>
    title: "<Prüfungsschema-Titel>"
    norms: ["..."]
    quellen: ["..."]
    steps:
      - label: "I. ..."
        children:
          - label: "1. ..."

faelle:
  - slug: <eindeutig>
    title: "<Fallname>"
    difficulty: <1-5>
    minutes: <Bearbeitungszeit>
    facts: "<vollstaendig FIKTIVER Sachverhalt, keine realen Personen/Firmen/Verfahren>"
    question: "<Fallfrage>"
    quellen: ["Eigener Sachverhalt der Redaktion", ...]
    steps:
      - prompt: "<Teilschritt-Frage>"
        erwartung: "<Kurzantwort>"
    expectation:
      pruefpunkte:
        - id: p1
          label: "<Was muss angesprochen werden>"
          weight: <Zahl>
          required: true|false
          norms: ["..."]
          keywords: ["...", "..."]
"""

REGELN = """\
Verbindliche Regeln:
1. Urheberrecht: Nutze NUR amtliche Werke (Gesetzestexte, amtliche
   Leitsaetze von Gerichtsentscheidungen) oder eigene Formulierungen. Kopiere
   NIEMALS woertliche Passagen aus Lehrbuechern, Kommentaren oder Skripten -
   auch nicht sinngemaess nah am Original. Definitionen selbst formulieren.
2. RDG: 'faelle' sind IMMER vollstaendig fiktiv. Keine realen Namen, Firmen,
   Aktenzeichen oder anhaengigen Verfahren. Kein Bezug zu tatsaechlichen
   Personen, auch nicht "inspiriert von".
3. Jeder Fall braucht mindestens einen Pruefpunkt mit required: true - sonst
   ist die Bewertung nicht aussagekraeftig.
4. Normzitate exakt und ueberpruefbar: § mit Absatz/Satz/Alternative wo
   einschlaegig, Gesetz ausschreiben (BGB, StGB, GG, ...). Erfinde keine
   Paragraphen und keine Rechtsprechung.
5. quellen und stand sind fuer JEDE Karte, JEDES Schema und JEDEN Fall
   Pflicht - ohne sie wird der Inhalt von der CI abgelehnt.
6. Slugs sind projektweit eindeutig. Vermeide Kollisionen mit:
   {existing_slugs}
"""

# Fachrichtungen ausserhalb Jura (docs/34): Regel 2 und 4 werden ersetzt -
# statt RDG und Paragraphen gelten Einheiten, nachrechenbare Zahlen und
# fiktive Vignetten.
REGELN_TECHNIK = """\
Verbindliche Regeln:
1. Urheberrecht: Nur eigene Formulierungen oder gemeinfreies Grundlagenwissen
   (physikalische Gesetze, genormte Definitionen). Keine woertlichen oder nah
   umformulierten Passagen aus Lehrbuechern, Skripten oder Normtexten.
2. Formeln: Jede Karte vom Typ 'formel' traegt die Gleichung auf der
   Rueckseite ('=') und eine 'einheiten'-Liste im Format "Groesse in Einheit"
   mit SI-Einheiten. Keine Paragraphen (§) - 'norms' nennt Gesetze der Physik,
   DIN/VDE/ISO-Normen oder Verfahren, nichts Erfundenes.
3. Aufgaben ('faelle') sind nachrechenbar: Zahlenwerte mit Einheiten im
   Sachverhalt, 'steps' mit Loesungsschritten und Zwischenergebnissen, jeder
   Pruefpunkt mit 'keywords' (Begriffe, Zwischenergebnisse mit Einheit),
   mindestens einer mit required: true.
4. quellen und stand sind fuer JEDE Karte, JEDES Schema und JEDE Aufgabe
   Pflicht - ohne sie wird der Inhalt von der CI abgelehnt.
5. Slugs sind projektweit eindeutig. Vermeide Kollisionen mit:
   {existing_slugs}
"""

REGELN_LEHRAMT = """\
Verbindliche Regeln:
1. Urheberrecht: Nur eigene Formulierungen; KMK-Beschluesse, Schulgesetze und
   Verordnungen sind amtliche Werke und duerfen zitiert werden. Keine
   Passagen aus Lehrbuechern oder Skripten.
2. Fallvignetten ('faelle') sind IMMER fiktiv: keine realen Schulen,
   Lehrkraefte, Schuelerinnen oder Schueler, keine identifizierbaren
   Verfahren. Rechtsgrundlagen ('norms') nur, wenn sie echt sind
   (Schulgesetz des Landes, KMK-Beschluss, GG) - keine erfundenen Paragraphen.
3. Jede Fallvignette hat 'steps' (Analyseschritte) und mindestens einen
   Analysepunkt mit required: true; 'keywords' nennen Fachbegriffe, die in
   einer guten Analyse fallen muessen.
4. quellen und stand sind fuer JEDE Karte, JEDES Planungsraster und JEDE
   Vignette Pflicht - ohne sie wird der Inhalt von der CI abgelehnt.
5. Slugs sind projektweit eindeutig. Vermeide Kollisionen mit:
   {existing_slugs}
"""

JURA_PROFIL = {
    "slug": "jura",
    "name": "Rechtswissenschaft",
    "areas": [
        {"slug": "zivilrecht"},
        {"slug": "strafrecht"},
        {"slug": "oeffentliches-recht"},
    ],
    "kartentypen": {
        "definition": "Definition",
        "schema_step": "Schema",
        "streitstand": "Streitstand",
        "norm": "Norm",
        "rechtsprechung": "Rechtsprechung",
    },
    "begriffe": {"faelle": "Faelle", "schemata": "Pruefungsschemata", "fachgebiet": "Rechtsgebiet"},
    "methodik": {"einheiten_gate": False, "norm_gate": True},
}


def _profil(fach_profil: dict | None) -> dict:
    return fach_profil or JURA_PROFIL


def regeln_fuer(fach_profil: dict | None, existing_slugs: list[str]) -> str:
    profil = _profil(fach_profil)
    slugs = ", ".join(existing_slugs) or "(keine)"
    if profil.get("slug") == "lehramt":
        return REGELN_LEHRAMT.format(existing_slugs=slugs)
    if (profil.get("methodik") or {}).get("einheiten_gate"):
        return REGELN_TECHNIK.format(existing_slugs=slugs)
    return REGELN.format(existing_slugs=slugs)


def schema_fuer(fach_profil: dict | None) -> str:
    profil = _profil(fach_profil)
    areas = " | ".join(a["slug"] for a in profil.get("areas") or [])
    kartentypen = " | ".join(profil.get("kartentypen") or JURA_PROFIL["kartentypen"])
    norm_beispiel = (
        '"§ 123 Abs. 1 BGB"'
        if (profil.get("methodik") or {}).get("norm_gate", profil.get("slug") == "jura")
        else '"Ohmsches Gesetz" | "DIN EN ISO 898-1" | "KMK-Beschluss 2004"'
    )
    return SCHEMA_BESCHREIBUNG.format(
        areas=areas, kartentypen=kartentypen, norm_beispiel=norm_beispiel
    )


def collector_prompt(
    *,
    area: str,
    working_title: str,
    context: str,
    min_cards: int,
    min_schemata: int,
    min_cases: int,
    existing_slugs: list[str],
    feedback: str = "",
    fach_profil: dict | None = None,
) -> str:
    feedback_block = ""
    if feedback:
        feedback_block = (
            "\nDEIN VORHERIGER ENTWURF WURDE ABGELEHNT. Behebe genau diese "
            f"Punkte und liefere eine vollstaendig neue Fassung:\n{feedback}\n"
        )
    profil = _profil(fach_profil)
    begriffe = profil.get("begriffe") or {}
    return f"""\
Du bist die Fachredaktion einer Lern-App fuer {profil.get("name", "Rechtswissenschaft")} \
({begriffe.get("fachgebiet", "Rechtsgebiet")}: {area}).
Erstelle Lerninhalte zum Thema "{working_title}".

Kontext / Einordnung: {context}

Ziel: mindestens {min_cards} Karteikarten, {min_schemata} \
{begriffe.get("schemata", "Pruefungsschema(ta)")}
und {min_cases} {begriffe.get("faelle", "Uebungsfall/-faelle")} - jeweils \
pruefungsrelevant, nicht nur Randwissen.

{regeln_fuer(fach_profil, existing_slugs)}
{feedback_block}
{schema_fuer(fach_profil)}
"""


def reviewer_prompt(
    *, draft_yaml: str, existing_slugs: list[str], fach_profil: dict | None = None
) -> str:
    name = _profil(fach_profil).get("name", "Rechtswissenschaft")
    return f"""\
Du bist die Qualitaetssicherung derselben {name}-Lern-App-Redaktion und pruefst
kritisch - nicht wohlwollend - den Entwurf eines anderen Redaktions-Agenten.
Strukturelle Formatfehler wurden bereits automatisch geprueft; wozu wir DICH
brauchen, ist fachliches und rechtliches Urteilsvermoegen, das eine
Formatpruefung nicht leisten kann:

1. Urheberrecht: Liest sich ein 'back'-Text, ein Schema oder ein Sachverhalt
   wie eine woertliche oder nur leicht umformulierte Uebernahme aus einem
   bekannten Lehrbuch/Kommentar/Skript, statt eigenstaendig formuliert zu
   sein?
2. RDG: Ist jeder Fall zweifelsfrei fiktiv? Jeder Hinweis auf reale Personen,
   Firmen, Aktenzeichen oder ein "das erinnert an den Fall XY" ist ein
   Ablehnungsgrund.
3. Fachliche Plausibilitaet: Wirkt eine Normangabe, eine Definition oder ein
   Pruefungsschritt falsch, veraltet oder erfunden? (Du musst es nicht
   abschliessend wissen - im Zweifel melden statt raten.)
4. Erwartungshorizont: Hat jeder Fall mindestens einen 'required'-Pruefpunkt
   und sind die Pruefpunkte tatsaechlich das, was eine Klausurkorrektur
   verlangen wuerde - nicht triviale Nebensaechlichkeiten?
5. Slug-Kollisionen mit bereits vorhandenen Inhalten:
   {", ".join(existing_slugs) or "(keine)"}

ENTWURF:
{draft_yaml}

Antworte AUSSCHLIESSLICH mit JSON nach diesem Schema, ohne Erklaerung davor
oder danach:
{{"approved": true|false,
  "issues": ["konkreter, umsetzbarer Befund pro Zeile - leer wenn approved"],
  "severity": "ok" | "kleinere_maengel" | "schwerwiegend"}}

'approved' ist nur dann true, wenn ALLE fuenf Punkte unauffaellig sind. Ein
einziger begruendeter Verdacht (z.B. bei Punkt 1 oder 2) reicht fuer
'approved: false' - im Zweifel ablehnen, nicht durchwinken.
"""
