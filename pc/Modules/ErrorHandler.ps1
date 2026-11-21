# ==========================================================
# GamingSuite X
# Error Handler & Logger v1.0
# ==========================================================

. "$PSScriptRoot\Config.ps1"

$script:ErrorLog = [System.Collections.ArrayList]::new()
$script:MaxErrorEntries = 100

function Initialize-ErrorHandler {
    # Ohne $global: wirkt die Zuweisung nur innerhalb dieser Funktion
    # und geht beim Verlassen verloren - daher explizit global setzen.
    $global:ErrorActionPreference = "Continue"
    $global:WarningPreference = "Continue"
}

function Write-GameSuiteError {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$Component,
        [string]$ErrorDetails = ""
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $errorEntry = @{
        Timestamp = $timestamp
        Component = $Component
        Message = $Message
        Details = $ErrorDetails
        Severity = "Error"
    }

    [void]$script:ErrorLog.Add($errorEntry)
    if ($script:ErrorLog.Count -gt $script:MaxErrorEntries) {
        $script:ErrorLog.RemoveAt(0)
    }

    Save-ErrorLog

    Write-Host "[ERROR] [$Component] $Message" -ForegroundColor Red
    if ($ErrorDetails) {
        Write-Host "Details: $ErrorDetails" -ForegroundColor DarkRed
    }
}

function Write-GameSuiteWarning {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$Component
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $warningEntry = @{
        Timestamp = $timestamp
        Component = $Component
        Message = $Message
        Severity = "Warning"
    }

    [void]$script:ErrorLog.Add($warningEntry)
    if ($script:ErrorLog.Count -gt $script:MaxErrorEntries) {
        $script:ErrorLog.RemoveAt(0)
    }

    Write-Host "[WARNING] [$Component] $Message" -ForegroundColor Yellow
}

function Write-GameSuiteInfo {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$Component
    )

    Write-Host "[INFO] [$Component] $Message" -ForegroundColor Cyan
}

function Save-ErrorLog {
    try {
        $logPath = Get-LogPath
        $timestamp = Get-Date -Format "yyyy-MM-dd"
        $logFile = Join-Path $logPath "errors_$timestamp.json"

        $script:ErrorLog | ConvertTo-Json -Depth 8 | Set-Content $logFile -Encoding UTF8 -Force
    }
    catch { }
}

function Get-ErrorLog {
    param(
        [int]$LastEntries = -1
    )

    if ($LastEntries -gt 0 -and $script:ErrorLog.Count -gt $LastEntries) {
        return ,@($script:ErrorLog[-$LastEntries..-1])
    }

    return ,@($script:ErrorLog.ToArray())
}

function Clear-ErrorLog {
    $script:ErrorLog.Clear()
}

function Export-ErrorReport {
    param(
        [Parameter(Mandatory)][string]$FilePath
    )

    try {
        $report = @{
            ExportTime = Get-Date
            TotalErrors = @($script:ErrorLog | Where-Object { $_.Severity -eq "Error" }).Count
            TotalWarnings = @($script:ErrorLog | Where-Object { $_.Severity -eq "Warning" }).Count
            Errors = $script:ErrorLog
        }

        $report | ConvertTo-Json -Depth 8 | Set-Content $FilePath -Encoding UTF8 -Force
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-SafeOperation {
    param(
        [Parameter(Mandatory)][scriptblock]$Operation,
        [Parameter(Mandatory)][string]$Component,
        [string]$OperationName = "Operation"
    )

    try {
        Write-GameSuiteInfo "Starte: $OperationName" $Component
        $result = & $Operation
        Write-GameSuiteInfo "Abgeschlossen: $OperationName" $Component
        return $result
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-GameSuiteError "$OperationName fehlgeschlagen" $Component $errorMsg
        return $null
    }
}

# Initialize on load
Initialize-ErrorHandler
