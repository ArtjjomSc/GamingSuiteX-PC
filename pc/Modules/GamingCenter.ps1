## ==========================================================
# GamingSuite X v8.1 Stable
# Gaming Center
# Steam Integration Module
# ==========================================================

# HINWEIS: Set-StrictMode und $ErrorActionPreference='Stop' wurden hier
# entfernt. Da dieses Modul per Dot-Sourcing eingebunden wird, hätten
# beide Einstellungen global fuer die gesamte restliche Anwendung
# gegolten (inkl. Optimizer.ps1, StorageManager.ps1, UI.ps1) und dort
# ungeschuetzte Property-Zugriffe (z.B. $config.FavoriteGames) zum
# Absturz bringen koennen. Alle Cmdlet-Aufrufe in diesem Modul setzen
# -ErrorAction bereits explizit, die globalen Einstellungen wurden also
# nicht benoetigt.

# ----------------------------------------------------------
# Script Cache
# ----------------------------------------------------------

$script:GamingLibrary = @()
$script:GamingLibraryLastUpdate = $null

# ----------------------------------------------------------
# Logging
# ----------------------------------------------------------

function Write-GamingCenterLog {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {

        Write-Log -Message $Message -Level $Level

    }
    else {

        Write-Verbose "[$Level] $Message"

    }

}

# ----------------------------------------------------------
# Steam Library Detection
# ----------------------------------------------------------

function Get-SteamLibraryPaths {

    [CmdletBinding()]
    param()

    $paths = [System.Collections.Generic.List[string]]::new()

    $steamPath = $null

    try {

        $steamPath = (
            Get-ItemProperty `
                "HKCU:\Software\Valve\Steam" `
                -ErrorAction Stop
        ).SteamPath

    }
    catch {

        $defaultPath = Join-Path ${env:ProgramFiles(x86)} "Steam"

        if (Test-Path -LiteralPath $defaultPath) {

            $steamPath = $defaultPath

            Write-GamingCenterLog `
                "Steam wurde im Standardpfad gefunden."

        }

    }

    if ([string]::IsNullOrWhiteSpace($steamPath)) {

        Write-GamingCenterLog `
            "Steam wurde nicht gefunden." `
            "WARN"

        return @()

    }

    if (-not (Test-Path -LiteralPath $steamPath)) {

        Write-GamingCenterLog `
            "Steam-Verzeichnis existiert nicht." `
            "WARN"

        return @()

    }

    $paths.Add($steamPath)

    $libraryFile = Join-Path `
        $steamPath `
        "steamapps\libraryfolders.vdf"

    if (-not (Test-Path -LiteralPath $libraryFile)) {

        Write-GamingCenterLog `
            "libraryfolders.vdf wurde nicht gefunden."

        return $paths

    }

    try {

        $content = Get-Content `
            -LiteralPath $libraryFile `
            -Raw `
            -Encoding UTF8

    }
    catch {

        Write-GamingCenterLog `
            "libraryfolders.vdf konnte nicht gelesen werden." `
            "ERROR"

        return $paths

    }

    $matches = [regex]::Matches(
        $content,
        '"path"\s+"([^"\r\n]+)"'
    )

    foreach ($match in $matches) {

        $path = $match.Groups[1].Value -replace '\\\\','\'

        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        if ($paths.Contains($path)) {
            continue
        }

        $paths.Add($path)

    }

    Write-GamingCenterLog `
        "Steam-Bibliotheken gefunden: $($paths.Count)"

    return $paths

}
# ----------------------------------------------------------
# Steam Game Detection
# ----------------------------------------------------------

function Get-SteamGames {

    [CmdletBinding()]
    param()

    Write-GamingCenterLog "Suche installierte Steam-Spiele..."

    $games = [System.Collections.Generic.List[object]]::new()

    $appIdRegex = [regex]'"appid"\s+"(\d+)"'
    $nameRegex  = [regex]'"name"\s+"([^"]+)"'

    foreach ($libraryPath in Get-SteamLibraryPaths) {

        $steamApps = Join-Path $libraryPath "steamapps"

        if (-not (Test-Path -LiteralPath $steamApps)) {
            continue
        }

        Get-ChildItem `
            -LiteralPath $steamApps `
            -Filter "appmanifest_*.acf" `
            -File `
            -ErrorAction SilentlyContinue |

        ForEach-Object {

            try {

                $content = Get-Content `
                    -LiteralPath $_.FullName `
                    -Raw `
                    -Encoding UTF8 `
                    -ErrorAction Stop

                $appId = $appIdRegex.Match($content).Groups[1].Value
                $name  = $nameRegex.Match($content).Groups[1].Value

                if ([string]::IsNullOrWhiteSpace($appId)) {
                    return
                }

                if ([string]::IsNullOrWhiteSpace($name)) {
                    return
                }

                $games.Add([PSCustomObject]@{

                    Name            = $name
                    AppId           = $appId
                    Platform        = "Steam"

                    LaunchUri       = "steam://rungameid/$appId"

                    InstallPath     = $libraryPath

                    Installed       = $true

                    Favorite        = $false

                    Hidden          = $false

                    Executable      = $null

                    Icon            = $null

                    LastPlayed      = $null

                })

            }
            catch {

                Write-GamingCenterLog `
                    "Beschädigte Steam-Datei: $($_.Name)" `
                    "WARN"

            }

        }

    }

    $result = $games |
        Sort-Object Platform,Name -Unique

    Write-GamingCenterLog "$($result.Count) Steam-Spiele gefunden."

    return $result

}

# ----------------------------------------------------------
# Library Update
# ----------------------------------------------------------

function Update-GamingCenter {

    Write-GamingCenterLog "Aktualisiere Spielebibliothek..."

    try {

        $script:GamingLibrary = Get-SteamGames

        $script:GamingLibraryLastUpdate = Get-Date

        Write-GamingCenterLog `
            "GamingCenter erfolgreich aktualisiert."

        return $script:GamingLibrary

    }
    catch {

        Write-GamingCenterLog `
            $_.Exception.Message `
            "ERROR"

        return @()

    }

}

# ----------------------------------------------------------
# Cached Library
# ----------------------------------------------------------

function Get-GamingLibrary {

    # Nur beim allerersten Aufruf scannen. Vorher wurde bei 0 gefundenen
    # Spielen bei JEDEM Aufruf neu gescannt (leere Liste = "nicht geladen").
    if ($null -eq $script:GamingLibraryLastUpdate) {

        Update-GamingCenter | Out-Null

    }

    return $script:GamingLibrary

}

# ----------------------------------------------------------
# Force Refresh
# ----------------------------------------------------------

function Refresh-GamingLibrary {

    Write-GamingCenterLog "Cache wird geleert..."

    $script:GamingLibrary = @()

    Update-GamingCenter

}

# ----------------------------------------------------------
# Search
# ----------------------------------------------------------

function Find-GamingSuiteGame {

    [CmdletBinding()]
    param(

        [Parameter(Mandatory)]
        [string]$Name

    )

    Get-GamingLibrary |
        Where-Object {
            $_.Name -like "*$Name*"
        } |
        Sort-Object Name

}
# ----------------------------------------------------------
# Start Game
# ----------------------------------------------------------

function Start-GamingSuiteGame {

    [CmdletBinding()]
    param(

        [Parameter(Mandatory)]
        [pscustomobject]$Game

    )

    if ($null -eq $Game) {
        throw "Kein Spielobjekt übergeben."
    }

    if ([string]::IsNullOrWhiteSpace($Game.LaunchUri)) {
        throw "LaunchUri fehlt."
    }

    Write-GamingCenterLog "Starte Spiel: $($Game.Name)"

    try {

        Start-Process `
            -FilePath $Game.LaunchUri `
            -ErrorAction Stop

    }
    catch {

        Write-GamingCenterLog `
            "Spiel konnte nicht gestartet werden: $($_.Exception.Message)" `
            "ERROR"

        throw

    }

}

# ----------------------------------------------------------
# Launcher Support (Vorbereitung)
# ----------------------------------------------------------

function Get-EpicGames {

    Write-GamingCenterLog "Epic Games Launcher wird derzeit noch nicht unterstützt."
    return @()

}

function Get-GOGGames {

    Write-GamingCenterLog "GOG Galaxy wird derzeit noch nicht unterstützt."
    return @()

}

function Get-EAGames {

    Write-GamingCenterLog "EA App wird derzeit noch nicht unterstützt."
    return @()

}

function Get-UbisoftGames {

    Write-GamingCenterLog "Ubisoft Connect wird derzeit noch nicht unterstützt."
    return @()

}

function Get-BattleNetGames {

    Write-GamingCenterLog "Battle.net wird derzeit noch nicht unterstützt."
    return @()

}

function Get-XboxGames {

    Write-GamingCenterLog "Xbox App wird derzeit noch nicht unterstützt."
    return @()

}

# ----------------------------------------------------------
# Statistics
# ----------------------------------------------------------

function Get-GamingCenterStatistics {

    $library = Get-GamingLibrary

    [PSCustomObject]@{

        TotalGames = $library.Count

        SteamGames = ($library | Where-Object Platform -eq "Steam").Count

        LastUpdate = $script:GamingLibraryLastUpdate

    }

}

# ----------------------------------------------------------
# Module Initialisierung
# ----------------------------------------------------------

Write-GamingCenterLog "GamingCenter Modul erfolgreich geladen."