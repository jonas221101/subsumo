# Mitwirken

Dieses Dokument gilt fuer jede Aenderung an `main` — Code, Content und Docs,
egal ob von einem Menschen oder einem Agenten geschrieben. Kein Sonderweg fuer
KI-erzeugte Aenderungen: dieselbe Pruefung wie fuer alles andere.

## Grundregel: main ist immer gruen, niemand pusht direkt

`main` bildet ab, was tatsaechlich funktioniert. Jede Aenderung laeuft ueber
einen kurzlebigen Branch und einen Pull Request — auch fuer den einzigen
Maintainer, auch fuer triviale Fixes. `main` ist per Branch Protection gegen
direkte Pushes gesperrt (siehe unten); es gibt keinen technischen Sonderweg,
nur eine bewusste Ausnahme im Repo-Admin-Bereich fuer echte Notfaelle.

```
main ──●───────●───────●───────●──   (immer deploybar, immer gruen)
        ╲     ╱ ╲     ╱ ╲     ╱
         ●───╱   ●───╱   ●───╱        kurzlebige Branches (moeglichst < 1 Tag)
```

Lang laufende Branches sind ein Kostenfaktor, kein Sicherheitsnetz — sie
laufen auseinander und machen den Merge teurer, nicht sicherer. Lieber
oefter kleine PRs als ein PR mit allem drin.

## Branches

```
feature/<kurzbeschreibung>   neue Funktionalitaet
fix/<kurzbeschreibung>       Bugfix
refactor/<kurzbeschreibung>  Umbau ohne Verhaltensaenderung
docs/<kurzbeschreibung>      nur Dokumentation
chore/<kurzbeschreibung>     Tooling, Dependencies, CI
content/<kurzbeschreibung>   neue oder geaenderte Lerninhalte (content/*.yaml)
```

Von `main` abzweigen, moeglichst innerhalb von 1-3 Tagen mergen, Branch nach
dem Merge loeschen (GitHub macht das per Default-Einstellung automatisch).

## Commits

```
<typ>: <kurze Beschreibung im Imperativ>

<optionaler Body: warum, nicht nur was>
```

Typen: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `content`.

- Ein Commit, ein Anliegen. Formatierung nicht mit Verhaltensaenderung mischen,
  Refactoring nicht mit Feature mischen.
- Die Botschaft erklaert das *Warum* — das *Was* steht im Diff.
- Vor jedem Commit: `git diff --staged` ansehen, insbesondere bei generierten
  Dateien (KI-Redaktion, `flutter create`) nichts Ungewolltes mitschleifen.
- Keine Secrets im Diff (`SUBSUMO_JWT_SECRET`, API-Keys, `.env`).

## Vor jedem PR: die Pruefung, die auch die CI faehrt

Lokal denselben Check laufen lassen, den `.github/workflows/ci.yml` fuer den
jeweils geaenderten Bereich faehrt — das erspart den Rundweg ueber einen
roten CI-Lauf:

```bash
# backend/ geaendert
cd backend
ruff check .
pytest -q

# content/*.yaml geaendert (auch bei KI-Redaktion-generierten Dateien)
cd backend
python scripts/validate_content.py

# app/ geaendert
cd app
flutter analyze
flutter test
```

Kein Gate wird uebersprungen, weil "die Aenderung trivial ist". Trivial und
kaputt schliessen sich nicht aus.

Bei Aenderungen an Screens, Flows oder Komponenten in `app/lib`: vor dem PR
eine Durchsicht mit der Design-Critique-Skill
(`skill://1077519e-0ee1-484a-b163-50fcc3bbcb3d?s=design-critique`) durchfuehren.
Must-fix-Punkte vor der Review-Anfrage beheben oder im PR bewusst begruenden,
warum sie (noch) nicht behoben werden.

## Pull Request

```bash
git checkout -b content/zr-sachenrecht-985
# ... Aenderungen, Commits ...
git push -u origin content/zr-sachenrecht-985
gh pr create --fill
```

- **CI muss grün sein** (drei Jobs: Backend Tests+Lint, Content-Validierung,
  Flutter Analyse+Tests) — das ist die serverseitig erzwungene Voraussetzung
  fuer den Merge, keine Empfehlung.
- Der PR-Body sagt kurz *was* und *warum*; bei Content-PRs reicht ein Verweis
  auf das Thema und ob KI-Redaktion (Bruecken- oder Anthropic-Modus) beteiligt
  war.
- **Squash and merge** ist die Standard-Merge-Strategie — ein PR wird ein
  Commit auf `main`, unabhaengig davon, wie viele Zwischenstaende der Branch
  hatte. Das haelt die Historie auf `main` linear und lesbar.
- Aktuell **kein Pflicht-Review** (Solo-/Kleinprojekt, siehe
  `docs/03-roadmap.md`) — sobald ein zweiter Mitwirkender dazukommt, wird
  `required_approving_review_count` in der Branch-Protection-Regel auf
  mindestens 1 gesetzt.

## Generierte Dateien

- `app/android/`, `app/ios/`, `app/linux/`, `app/macos/`, `app/windows/`,
  `app/web/`, `app/.dart_tool/`, `app/pubspec.lock`: **nicht committen** —
  von `flutter create` / `flutter pub get` bei Bedarf neu erzeugt, siehe
  Wurzel-`.gitignore`.
- `backend/.venv/`, `__pycache__/`, `*.db`: nicht committen.
- KI-Redaktion schreibt nach `content/<gebiet>/<slug>.yaml` — das Ergebnis
  wird wie jede andere Content-Aenderung committed und per PR eingereicht,
  nicht automatisch gemergt (siehe `docs/05-content-pipeline.md`).

## Notfall-Ausnahme

`enforce_admins` ist auf der Branch-Protection-Regel fuer `main` aktiv — auch
Repo-Admins muessen ueber einen PR gehen. Fuer den seltenen echten Notfall
(z. B. Produktionsvorfall, der sofort einen Einzeiler braucht) kann ein
Admin die Regel unter *Settings → Branches* temporaer deaktivieren, den Fix
pushen und die Regel danach sofort wieder aktivieren. Das ist eine bewusste,
protokollierte Ausnahme, kein Standardweg.
