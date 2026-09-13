# Einmaliges Setup fuer Windows/PowerShell. Findet automatisch eine
# passende Python-Version (>= 3.11, siehe pyproject.toml), baut die venv neu
# auf und installiert alle Abhaengigkeiten - ohne dass "python" auf PATH
# zufaellig auf eine alte Installation zeigen darf (genau das war die
# Ursache, als pip nur fastapi-Versionen bis 0.83.0 fand: die venv war mit
# einem Python 3.6 erstellt worden).
#
# Ausfuehren (PowerShells Skript-Sperre gilt auch fuer dieses Skript - dieser
# Aufruf umgeht sie nur fuer diesen einen Lauf, ohne die Systemeinstellung
# dauerhaft zu aendern):
#
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
# Optional: -Run haengt am Ende direkt "uvicorn app.main:app --reload" an.

param(
    [switch]$Run
)

$ErrorActionPreference = "Stop"
# PowerShell 7.3+ wandelt per Default jeden nichtnull Exit-Code eines
# externen Programms in einen terminierenden Fehler um (respektiert dabei
# $ErrorActionPreference) - das traf hier die Versionssuche unten, die ganz
# bewusst mehrere Aufrufe fehlschlagen laesst, bis die passende Version
# gefunden ist. Ohne diese Zeile bricht das Skript beim ersten Fehlschlag ab,
# obwohl der Code direkt danach genau diesen Fall abfaengt. Auf ausdruecklich
# selbst geprueften Exit-Codes ($LASTEXITCODE) bestehen, nicht auf Powershells
# Automatik.
$PSNativeCommandUseErrorActionPreference = $false

$RequiredMajor = 3
$RequiredMinor = 11

# Liefert ein Hashtable @{ Exe = ...; Arg = ... } fuer den Aufruf einer
# passenden Python-Version, oder $null wenn keine gefunden wurde. Bewusst
# ohne Array-Splatting - zwei feste Faelle (py-Launcher mit Versions-Flag,
# oder blankes "python") sind klarer als generischer Variadic-Code.
#
# Fragt NICHT einzelne Versionen gezielt ab (frueherer Ansatz: 'py -3.15
# --version', 'py -3.14 --version', ... absteigend durchprobieren) - das
# scheiterte real daran, dass der echte Windows-py-Launcher bei einer nicht
# installierten Version seine komplette '-0'-Liste auf stderr ausgibt statt
# einer kurzen Fehlermeldung, was mit obigem PS-7.3-Verhalten das Skript
# abbrach. Stattdessen ein einziger 'py -0'-Aufruf (listet Installiertes,
# schlaegt praktisch nie fehl) und die hoechste passende Version daraus waehlen.
function Find-Python {
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        $listing = & py -0 2>&1
        $available = @()
        foreach ($line in $listing) {
            # Locker gefasst statt ein exaktes Suffix zu verlangen: "py -0"
            # haengt an die Version je nach System z.B. "-64", "-32" oder gar
            # nichts an, gefolgt von Leerzeichen und ggf. "*" beim Default -
            # ein zu strenges Suffix-Muster (vorherige Fassung) erkannte
            # "-3.12-64" gar nicht erst, siehe Testlauf.
            if ("$line" -match '-(\d+)\.(\d+)') {
                $available += [version]"$($Matches[1]).$($Matches[2])"
            }
        }
        $best = $available |
            Where-Object { $_.Major -eq $RequiredMajor -and $_.Minor -ge $RequiredMinor } |
            Sort-Object -Descending |
            Select-Object -First 1
        if ($best) {
            $flag = "-$($best.Major).$($best.Minor)"
            Write-Host "Gefunden ueber 'py $flag' (aus 'py -0')"
            return @{ Exe = "py"; Arg = $flag }
        }
        if ($available) {
            $versions = ($available | Sort-Object -Descending | ForEach-Object { "$_" }) -join ", "
            Write-Host "Ueber 'py -0' gefunden, aber keine Version >= ${RequiredMajor}.${RequiredMinor}: $versions"
        }
    }

    # Fallback: "python" auf PATH, aber Version tatsaechlich pruefen statt
    # blind zu vertrauen - genau das ging beim ersten Versuch schief.
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $versionText = & python --version 2>&1
        if ($versionText -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            if ($major -gt $RequiredMajor -or ($major -eq $RequiredMajor -and $minor -ge $RequiredMinor)) {
                Write-Host "Gefunden auf PATH: $versionText"
                return @{ Exe = "python"; Arg = $null }
            } else {
                Write-Host "Auf PATH gefunden, aber zu alt: $versionText (benoetigt >= $RequiredMajor.$RequiredMinor)"
            }
        }
    }

    return $null
}

function Invoke-Python {
    param($Python, [string[]]$Arguments)
    if ($Python.Arg) {
        & $Python.Exe $Python.Arg @Arguments
    } else {
        & $Python.Exe @Arguments
    }
}

Write-Host "== Subsumo Backend Setup ==" -ForegroundColor Cyan

$python = Find-Python
if (-not $python) {
    Write-Host ""
    Write-Host "Keine Python-Installation >= $RequiredMajor.$RequiredMinor gefunden." -ForegroundColor Red
    Write-Host "Bitte zuerst installieren: https://www.python.org/downloads/"
    Write-Host "Beim Installer unbedingt 'Add python.exe to PATH' aktivieren."
    Write-Host "Danach dieses Skript erneut ausfuehren."
    exit 1
}

if (Test-Path ".venv") {
    Write-Host "Entferne vorhandene .venv (wird neu aufgebaut) ..."
    Remove-Item -Recurse -Force ".venv"
}

Write-Host "Erstelle virtuelle Umgebung ..."
Invoke-Python -Python $python -Arguments @("-m", "venv", ".venv")
if ($LASTEXITCODE -ne 0) {
    Write-Host "Anlegen der venv fehlgeschlagen." -ForegroundColor Red
    exit 1
}

$venvPython = ".\.venv\Scripts\python.exe"

Write-Host "Aktualisiere pip ..."
& $venvPython -m pip install --upgrade pip --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "pip-Upgrade fehlgeschlagen." -ForegroundColor Red
    exit 1
}

Write-Host "Installiere Abhaengigkeiten (requirements-dev.txt) ..."
& $venvPython -m pip install -r requirements-dev.txt
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Installation fehlgeschlagen. Haeufigster Grund: ein Netzwerk-" -ForegroundColor Red
    Write-Host "Proxy/Mirror liefert einen veralteten Paketindex. Versuche von Hand:"
    Write-Host "  $venvPython -m pip install -r requirements-dev.txt --index-url https://pypi.org/simple --no-cache-dir"
    exit 1
}

Write-Host ""
Write-Host "Fertig." -ForegroundColor Green
Write-Host "Tests laufen lassen:  $venvPython -m pytest -q"
Write-Host "Backend starten:      $venvPython -m uvicorn app.main:app --reload"

if ($Run) {
    Write-Host ""
    Write-Host "Starte Backend (Strg+C zum Beenden) ..." -ForegroundColor Cyan
    & $venvPython -m uvicorn app.main:app --reload
}
