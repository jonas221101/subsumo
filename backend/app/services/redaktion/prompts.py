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
  area: zivilrecht | strafrecht | oeffentliches-recht
  title: <Klartext-Titel>
  parent: <slug des Elternthemas, falls vorhanden>
  relevance: <1-5, Pruefungsrelevanz>
  stand: "<YYYY-MM>"

cards:
  - slug: <eindeutig>
    type: definition | schema_step | streitstand | norm | rechtsprechung
    front: "<Frage/Vorderseite>"
    back: "<Antwort/Rueckseite, praezise, Definitions-Stil>"
    norms: ["§ 123 Abs. 1 BGB"]
    quellen: ["<Gesetz, amtliche Fassung>" | "<eigene Formulierung Redaktion>"]
    stand: "<YYYY-MM>"

schemata:
  - slug: <eindeutig>
    title: "<Pruefungsschema-Titel>"
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
) -> str:
    feedback_block = ""
    if feedback:
        feedback_block = (
            "\nDEIN VORHERIGER ENTWURF WURDE ABGELEHNT. Behebe genau diese "
            f"Punkte und liefere eine vollstaendig neue Fassung:\n{feedback}\n"
        )
    return f"""\
Du bist die Fachredaktion einer Jura-Lern-App (Rechtsgebiet: {area}).
Erstelle Lerninhalte zum Thema "{working_title}".

Kontext / Einordnung: {context}

Ziel: mindestens {min_cards} Karteikarten, {min_schemata} Pruefungsschema(ta)
und {min_cases} Uebungsfall/-faelle - jeweils examensrelevant, nicht nur
Randwissen.

{REGELN.format(existing_slugs=", ".join(existing_slugs) or "(keine)")}
{feedback_block}
{SCHEMA_BESCHREIBUNG}
"""


def reviewer_prompt(*, draft_yaml: str, existing_slugs: list[str]) -> str:
    return f"""\
Du bist die Qualitaetssicherung derselben Jura-Lern-App-Redaktion und pruefst
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
