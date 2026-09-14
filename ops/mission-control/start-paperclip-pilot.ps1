[CmdletBinding()]
param(
    [switch]$Reset
)

$ErrorActionPreference = "Stop"

# Keep the control plane separate from both the learner-facing backend and a
# developer's regular Paperclip instance. Upgrade only by changing this pin
# and repeating the acceptance run in README.md.
$paperclipVersion = "2026.831.1"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$stateDir = Join-Path $repoRoot "work\\mission-control\\paperclip"
$homeDir = Join-Path $stateDir "home"
$environmentFile = Join-Path $stateDir "pilot.env"

if ($Reset) {
    if (-not (Test-Path -LiteralPath $stateDir)) {
        Write-Host "Kein Pilotzustand vorhanden: $stateDir"
        return
    }
    $confirmation = Read-Host "Pilotzustand inklusive Aufgaben und Schluessel wirklich loeschen? (yes)"
    if ($confirmation -ne "yes") {
        Write-Host "Abgebrochen."
        return
    }
    Remove-Item -LiteralPath $stateDir -Recurse -Force
    Write-Host "Pilotzustand entfernt."
    return
}

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$environmentLines = [string[]]@(
    "PAPERCLIP_HOME=$homeDir"
)
[System.IO.File]::WriteAllLines(
    $environmentFile,
    $environmentLines,
    (New-Object System.Text.UTF8Encoding($false))
)

Get-Content -LiteralPath $environmentFile | ForEach-Object {
    $name, $value = $_ -split "=", 2
    if ($name -and $null -ne $value) {
        Set-Item -Path "Env:$name" -Value $value
    }
}

$npx = Get-Command npx.cmd -ErrorAction Stop
& $npx.Source --yes "paperclipai@$paperclipVersion" onboard --yes
if ($LASTEXITCODE -ne 0) {
    throw "Paperclip-Onboarding fehlgeschlagen (Exit-Code $LASTEXITCODE)."
}

Write-Host "Paperclip-Pilot $paperclipVersion ist vorbereitet."
Write-Host "Die gestartete Instanz meldet ihre konkrete Loopback-Adresse im Startprotokoll."
Write-Host "Dann Company, Projekt sowie Planner-, Developer- und Reviewer-Agenten anlegen."
