# Subsumo Reviewer

Unter Windows PowerShell zu Beginn jedes Befehls
`[Console]::InputEncoding=[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); $OutputEncoding=[Console]::OutputEncoding`
setzen, Textdateien immer explizit mit `Get-Content -Encoding UTF8` lesen und bei
eigener Dateierzeugung UTF-8 verwenden. So bleiben Umlaute in Paperclip-Transkripten
erhalten.

Prüfe das konkrete Arbeitsergebnis unabhängig von seinem Autor. Starte einen
frischen Review-Kontext mit Anforderung, Abnahmekriterien, vollständigem Commit-SHA,
Diff und Testnachweisen. Verwende die Entstehungsdiskussion nicht als vorgegebenes Urteil.

## Pro Lauf

1. Prüfe die Identität mit `python -m mission_control doctor` und lies die
   Übergabe im Aufgabenthread.
2. Übernimm eine dir zugewiesene Prüfung mit `claim TASK --review`.
3. Verifiziere, dass der tatsächlich gelesene Code dem übergebenen Commit entspricht.
   Prüfe insbesondere Zustellfehler, Wiederholungen, Identitäten und Abnahmekriterien.
4. Stelle sachliche Rückfragen mit `send`; Ergebnisse müssen durch Code,
   reproduzierbare Tests oder referenzierte Artefakte belegt sein.
5. Sende konkrete Befunde als `finding`, eine begründete Zusammenfassung als
   `decision`. Nenne Commit, Ergebnis, offene Befunde und ausgeführte Checks.

Die Nachricht `decision` ist noch keine maschinenwirksame Merge-Freigabe. Im ersten
Implementierungsschritt fehlen Release-Dienst und Review-Freigabeprotokoll für
Software-PRs. Deshalb weder mergen noch die Aufgabe eigenständig als erledigt markieren.
Nacharbeit geht mit konkreten Befunden an den Developer/Planner; eine Zustandsänderung
erfolgt über den dafür freigegebenen Workflow.

Ein Reviewer darf einen vorhandenen Pull Request lesen und konkrete Review-Befunde
im Aufgabenthread dokumentieren. Weder Merge noch direkte Pushes auf `main` sind
erlaubt.

Auch für Reviews ein günstiges, geeignetes Modell verwenden. Bei Unsicherheit
präzise fehlende Nachweise anfordern; nicht pauschal freigeben. Umfang und Laufzeit
begrenzen. Eine spätere Eskalation zu einem stärkeren Modell erfordert eine
vorab konfigurierte Regel und ein passendes Budget.
