# ==========================================================
# GamingSuite X v11.2 - ULTIMATE EDITION
# ==========================================================

Clear-Host

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "Einige Funktionen benoetigen Administrator-Rechte (Optimizer, Firewall-Regel fuer das Handy)."
    Start-Sleep 2
}

$Version = "11.4"

# Konsolen-Protokoll (fuer Fehlerberichte), die letzten 10 behalten
$consoleLogDir = Join-Path $env:APPDATA "GamingSuiteX\logs"
try {
    if (-not (Test-Path -LiteralPath $consoleLogDir)) { New-Item -ItemType Directory -Path $consoleLogDir -Force | Out-Null }
    Get-ChildItem -LiteralPath $consoleLogDir -Filter 'console_*.txt' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip 9 | Remove-Item -Force -ErrorAction SilentlyContinue
    Start-Transcript -Path (Join-Path $consoleLogDir "console_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt") -ErrorAction Stop | Out-Null
    $transcriptOn = $true
}
catch { $transcriptOn = $false }
$BasePath = $PSScriptRoot
$ModulePath = Join-Path $BasePath "Modules"

Write-Host ""
Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     GAMINGSUITE X v$Version                 ║" -ForegroundColor Cyan
Write-Host "║     Ultimate Gaming Dashboard             ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ----------------------------------------------------------
# Module laden (Reihenfolge ist wichtig!)
# ----------------------------------------------------------
# Version 10 hatte nur noch UI.ps1 geladen - dadurch fehlten
# Hardware, Gaming Center, Optimizer, Storage usw.

$modules = @(
    "Config.ps1",
    "ErrorHandler.ps1",
    "Logger.ps1",
    "Hardware.ps1",
    "HardwareManager.ps1",
    "GamingCenter.ps1",
    "Optimizer.ps1",
    "StorageManager.ps1",   # nach Optimizer: dessen Clear-CacheFiles (mit FreedMB) soll gelten
    "BackgroundMonitor.ps1",
    "PhoneServer.ps1",
    "SystemTuning.ps1",
    "GameTuning.ps1",
    "Support.ps1",
    "UIControls.ps1",
    "UI.ps1"
)

$missing = @()
foreach ($module in $modules + @("PhoneData.ps1")) {
    if (-not (Test-Path -LiteralPath (Join-Path $ModulePath $module))) { $missing += $module }
}
if ($missing.Count -gt 0) {
    Write-Host "Folgende Dateien fehlen im Ordner 'Modules':" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Read-Host "Enter druecken zum Beenden"
    exit 1
}

foreach ($module in $modules) {
    try {
        . (Join-Path $ModulePath $module)
        Write-Host "  [OK] $module" -ForegroundColor Green
    }
    catch {
        Write-Host "  [FEHLER] $module : $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Enter druecken zum Beenden"
        exit 1
    }
}

# ----------------------------------------------------------
# Hinweis beim ersten Start (einmalig bestaetigen)
# ----------------------------------------------------------

if (-not (Get-GamingSuiteConfigValue -Key 'DisclaimerAccepted' -Default $false)) {
    $text = "GamingSuite X ist ein kostenloses Hobby-Projekt OHNE GEWAEHR.`n`n" +
            "- Der Optimizer aendert Windows-Einstellungen (Energie, Registry, Netzwerk).`n" +
            "  Vor jeder Aenderung wird ein Backup angelegt, 'Alles zuruecksetzen' stellt den Originalzustand wieder her.`n" +
            "- Fuer Spiele-Einstellungsdateien wird ebenfalls eine Sicherung angelegt.`n" +
            "- Zur FPS-Messung wird einmalig Intel PresentMon (kostenlos, GitHub) heruntergeladen.`n" +
            "- Es werden KEINE Daten ins Internet gesendet. Der Handy-Zugriff funktioniert nur im eigenen WLAN`n" +
            "  und laesst sich unter 'Settings' abschalten oder mit einer PIN schuetzen.`n`n" +
            "Im Zweifel vorher einen Windows-Wiederherstellungspunkt anlegen.`n`n" +
            "Verstanden und fortfahren?"
    $answer = [System.Windows.Forms.MessageBox]::Show($text, "GamingSuite X - Hinweis", 'YesNo', 'Information')
    if ($answer -ne 'Yes') { exit 0 }
    [void](Update-GamingSuiteConfigValue -Key 'DisclaimerAccepted' -Value $true)
}

# ----------------------------------------------------------
# Hintergrund-Dienste starten
# ----------------------------------------------------------

Start-HardwareMonitor -IntervalSeconds 2
Write-Host "  [OK] Hardware-Messung laeuft im Hintergrund" -ForegroundColor Green

# Handy-/Browser-Zugriff aus den Einstellungen
$global:GSXState.PhoneEnabled = [bool](Get-GamingSuiteConfigValue -Key 'PhoneAccessEnabled' -Default $true)
$global:GSXState.PhonePin = [string](Get-GamingSuiteConfigValue -Key 'PhonePin' -Default '')

Start-PhoneServer
$addresses = @(Get-PhoneServerAddresses)
Write-Host "  [OK] Handy-Server gestartet" -ForegroundColor Green
if ($addresses.Count -gt 0) {
    Write-Host "       Adresse fuer die App: $(($addresses | ForEach-Object { "$($_):47801" }) -join ', ')" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Alle Module geladen!" -ForegroundColor Green
Write-Host "Starte GamingSuite X v$Version ..." -ForegroundColor Cyan
Write-Host ""

try {
    Start-GamingSuiteUI
}
finally {
    Write-Host "Beende Hintergrund-Dienste ..." -ForegroundColor DarkGray
    Stop-GamingSuiteBackground
    Save-PerformanceLog
    if ($transcriptOn) { try { Stop-Transcript | Out-Null } catch { } }
}
