# ==========================================================
# GamingSuite X
# Configuration Manager v1.0
# ==========================================================

$script:ConfigPath = Join-Path $env:APPDATA "GamingSuiteX"
$script:ConfigFile = Join-Path $script:ConfigPath "config.json"
$script:LogPath = Join-Path $script:ConfigPath "logs"

function Get-InitialConfig {
    # Liefert die Standard-Konfiguration. Wird sowohl beim Erst-Setup
    # als auch als Fallback verwendet, falls config.json beschaedigt ist.
    return @{
        Theme = "Dark"
        UpdateInterval = 5
        EnablePerformanceLogging = $true
        EnableNotifications = $true
        FavoriteGames = @()
        GameFilters = @{
            ShowInstalled = $true
            ShowRecent = $true
        }
        UISettings = @{
            WindowWidth = 1400
            WindowHeight = 850
        }
        OptimizerSettings = @{
            AutoCleanTemp = $false
            AutoOptimizePower = $false
            EnableGameMode = $true
        }
    }
}

function Initialize-GamingSuiteConfig {
    if (-not (Test-Path $script:ConfigPath)) {
        New-Item -ItemType Directory -Path $script:ConfigPath -Force | Out-Null
    }
    if (-not (Test-Path $script:LogPath)) {
        New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
    }

    if (-not (Test-Path $script:ConfigFile)) {
        $defaultConfig = Get-InitialConfig
        $defaultConfig | ConvertTo-Json -Depth 8 | Set-Content $script:ConfigFile -Encoding UTF8
        return $defaultConfig
    }

    try {
        $config = Get-Content $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Warning "Config-Datei beschaedigt. Standard-Config wird verwendet."
        $defaultConfig = Get-InitialConfig
        try {
            # Beschaedigte Datei durch eine gueltige Standard-Config ersetzen,
            # damit der Fehler nicht bei jedem Start erneut auftritt.
            $defaultConfig | ConvertTo-Json -Depth 8 | Set-Content $script:ConfigFile -Encoding UTF8 -Force
        }
        catch {
            Write-Warning "Standard-Config konnte nicht gespeichert werden: $_"
        }
        return $defaultConfig
    }
}

function Get-GamingSuiteConfig {
    if (-not (Test-Path $script:ConfigFile)) {
        return Initialize-GamingSuiteConfig
    }

    try {
        Get-Content $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Initialize-GamingSuiteConfig
    }
}

function Set-GamingSuiteConfig {
    param([Parameter(Mandatory)][object]$Config)

    try {
        $Config | ConvertTo-Json -Depth 8 | Set-Content $script:ConfigFile -Encoding UTF8 -Force
        return $true
    }
    catch {
        Write-Warning "Fehler beim Speichern der Config: $_"
        return $false
    }
}

function Update-GamingSuiteConfigValue {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)]$Value
    )

    $config = Get-GamingSuiteConfig

    $keys = $Key -split '\.'
    $current = $config

    for ($i = 0; $i -lt $keys.Count - 1; $i++) {
        if (-not $current.PSObject.Properties[$keys[$i]]) {
            $current | Add-Member -NotePropertyName $keys[$i] -NotePropertyValue @{}
        }
        $current = $current.($keys[$i])
    }

    $lastKey = $keys[-1]
    $current | Add-Member -NotePropertyName $lastKey -NotePropertyValue $Value -Force

    Set-GamingSuiteConfig $config
}

function Get-GamingSuiteConfigValue {
    param(
        [Parameter(Mandatory)][string]$Key,
        $Default = $null
    )

    $config = Get-GamingSuiteConfig
    $keys = $Key -split '\.'
    $current = $config

    foreach ($k in $keys) {
        if ($current.PSObject.Properties[$k]) {
            $current = $current.$k
        }
        else {
            return $Default
        }
    }

    return $current
}

function Add-FavoriteGame {
    param(
        [Parameter(Mandatory)][object]$Game
    )

    $config = Get-GamingSuiteConfig

    $current = @()
    if ($config.FavoriteGames) {
        $current = @($config.FavoriteGames)
    }

    $existing = $current | Where-Object { $_.AppId -eq $Game.AppId }
    if (-not $existing) {
        $config.FavoriteGames = @($current + $Game)
        Set-GamingSuiteConfig $config
        return $true
    }
    return $false
}

function Remove-FavoriteGame {
    param([Parameter(Mandatory)][string]$AppId)

    $config = Get-GamingSuiteConfig
    if ($config.FavoriteGames) {
        $config.FavoriteGames = @($config.FavoriteGames | Where-Object { $_.AppId -ne $AppId })
        Set-GamingSuiteConfig $config
    }
}

function Get-FavoriteGames {
    $config = Get-GamingSuiteConfig
    if (-not $config.FavoriteGames) {
        return @()
    }
    return @($config.FavoriteGames)
}

function Get-ConfigPath {
    return $script:ConfigPath
}

function Get-LogPath {
    return $script:LogPath
}

# Initialisierung beim Laden
Initialize-GamingSuiteConfig | Out-Null
