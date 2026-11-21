# ==========================================================
# GamingSuite X
# Performance Logger v1.0
# ==========================================================

. "$PSScriptRoot\Config.ps1"

$script:PerformanceHistory = @{
    CPU = [System.Collections.ArrayList]::new()
    GPU = [System.Collections.ArrayList]::new()
    RAM = [System.Collections.ArrayList]::new()
    Network = [System.Collections.ArrayList]::new()
}

$script:MaxHistoryEntries = 500

function Add-PerformanceLog {
    param(
        [Parameter(Mandatory)][object]$HardwareSnapshot
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        # CPU
        if ($HardwareSnapshot.CPU) {
            $cpuEntry = @{
                Timestamp = $timestamp
                Load = [double]$HardwareSnapshot.CPU.Load
                Temperature = $HardwareSnapshot.CPU.Temperature
            }
            [void]$script:PerformanceHistory.CPU.Add($cpuEntry)
            if ($script:PerformanceHistory.CPU.Count -gt $script:MaxHistoryEntries) {
                $script:PerformanceHistory.CPU.RemoveAt(0)
            }
        }

        # GPU
        if ($HardwareSnapshot.GPU -and $null -ne $HardwareSnapshot.GPU.Usage) {
            $gpuEntry = @{
                Timestamp = $timestamp
                Usage = [double]$HardwareSnapshot.GPU.Usage
                VRAMUsed = [double]$HardwareSnapshot.GPU.VRAMUsed
                Temperature = $HardwareSnapshot.GPU.Temperature
            }
            [void]$script:PerformanceHistory.GPU.Add($gpuEntry)
            if ($script:PerformanceHistory.GPU.Count -gt $script:MaxHistoryEntries) {
                $script:PerformanceHistory.GPU.RemoveAt(0)
            }
        }

        # RAM
        if ($HardwareSnapshot.RAM) {
            $ramEntry = @{
                Timestamp = $timestamp
                Percent = [double]$HardwareSnapshot.RAM.Percent
                Used = [double]$HardwareSnapshot.RAM.Used
            }
            [void]$script:PerformanceHistory.RAM.Add($ramEntry)
            if ($script:PerformanceHistory.RAM.Count -gt $script:MaxHistoryEntries) {
                $script:PerformanceHistory.RAM.RemoveAt(0)
            }
        }

        # Network
        if ($HardwareSnapshot.Network) {
            $netEntry = @{
                Timestamp = $timestamp
                Download = [double]$HardwareSnapshot.Network.Download
                Upload = [double]$HardwareSnapshot.Network.Upload
            }
            [void]$script:PerformanceHistory.Network.Add($netEntry)
            if ($script:PerformanceHistory.Network.Count -gt $script:MaxHistoryEntries) {
                $script:PerformanceHistory.Network.RemoveAt(0)
            }
        }

        # Speichere periodisch zu Datei
        if ($script:PerformanceHistory.CPU.Count % 50 -eq 0) {
            Save-PerformanceLog
        }
    }
    catch {
        Write-Debug "Fehler beim Logging: $_"
    }
}

function Save-PerformanceLog {
    try {
        $logPath = Get-LogPath
        $timestamp = Get-Date -Format "yyyy-MM-dd"
        $logFile = Join-Path $logPath "performance_$timestamp.json"

        $export = @{
            ExportDate = Get-Date -Format "o"
            CPU = $script:PerformanceHistory.CPU
            GPU = $script:PerformanceHistory.GPU
            RAM = $script:PerformanceHistory.RAM
            Network = $script:PerformanceHistory.Network
        }

        $export | ConvertTo-Json -Depth 8 | Set-Content $logFile -Encoding UTF8 -Force
    }
    catch {
        Write-Debug "Fehler beim Speichern des Logs: $_"
    }
}

function Get-PerformanceHistory {
    param(
        [ValidateSet("CPU", "GPU", "RAM", "Network")]
        [string]$Component = "CPU",
        [int]$LastEntries = -1
    )

    $history = $script:PerformanceHistory[$Component]

    if ($LastEntries -gt 0 -and $history.Count -gt $LastEntries) {
        return ,@($history[-$LastEntries..-1])
    }

    return ,@($history.ToArray())
}

function Get-PerformanceStats {
    param(
        [ValidateSet("CPU", "GPU", "RAM", "Network")]
        [string]$Component = "CPU"
    )

    $history = Get-PerformanceHistory $Component

    if ($history.Count -eq 0) {
        return $null
    }

    $values = @()
    switch ($Component) {
        "CPU" { $values = $history | ForEach-Object { $_.Load } }
        "GPU" { $values = $history | ForEach-Object { $_.Usage } }
        "RAM" { $values = $history | ForEach-Object { $_.Percent } }
        "Network" { $values = $history | ForEach-Object { $_.Download } }
    }

    if ($values.Count -eq 0) {
        return $null
    }

    return [PSCustomObject]@{
        Component = $Component
        Current = $values[-1]
        Average = [math]::Round(($values | Measure-Object -Average).Average, 2)
        Max = [math]::Round(($values | Measure-Object -Maximum).Maximum, 2)
        Min = [math]::Round(($values | Measure-Object -Minimum).Minimum, 2)
        Count = $values.Count
    }
}

function Clear-PerformanceHistory {
    $script:PerformanceHistory.CPU.Clear()
    $script:PerformanceHistory.GPU.Clear()
    $script:PerformanceHistory.RAM.Clear()
    $script:PerformanceHistory.Network.Clear()
}

function Export-PerformanceReport {
    param(
        [Parameter(Mandatory)][string]$FilePath
    )

    try {
        $stats = @{
            ExportTime = Get-Date
            CPU = Get-PerformanceStats "CPU"
            GPU = Get-PerformanceStats "GPU"
            RAM = Get-PerformanceStats "RAM"
            Network = Get-PerformanceStats "Network"
        }

        $stats | ConvertTo-Json -Depth 8 | Set-Content $FilePath -Encoding UTF8
        return $true
    }
    catch {
        return $false
    }
}
