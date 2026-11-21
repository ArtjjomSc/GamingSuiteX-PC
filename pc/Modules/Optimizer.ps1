# ==========================================================
# GamingSuite X
# System Optimizer v1.0
# ==========================================================

. "$PSScriptRoot\Config.ps1"

function Get-OptimizationStatus {
    param()
    
    $status = @{
        TempFiles = 0
        CacheFiles = 0
        UnusedSoftware = @()
        PowerSettings = "Unbekannt"
        GameMode = $false
        Recommendations = @()
    }
    
    # Temp-Dateien
    try {
        $tempPath = $env:TEMP
        $status.TempFiles = @(Get-ChildItem -Path $tempPath -Recurse -File -ErrorAction SilentlyContinue).Count
    }
    catch { }
    
    # Cache-Dateien (LocalAppData)
    try {
        $cachePath = Join-Path $env:LOCALAPPDATA "Temp"
        $status.CacheFiles = @(Get-ChildItem -Path $cachePath -Recurse -File -ErrorAction SilentlyContinue).Count
    }
    catch { }
    
    # Power-Plan
    try {
        $powerPlan = (Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan -Filter "IsActive=true" -ErrorAction SilentlyContinue).ElementName
        $status.PowerSettings = $powerPlan
    }
    catch { }
    
    # Game-Modus (Windows 11)
    try {
        $gameMode = (Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name AutoGameModeEnabled -ErrorAction SilentlyContinue).AutoGameModeEnabled -eq 1
        $status.GameMode = $gameMode
    }
    catch { }
    
    # Recommendations
    if ($status.TempFiles -gt 100) {
        $status.Recommendations += "Temp-Ordner: $($status.TempFiles) Dateien - Cleanup empfohlen"
    }
    
    if ($status.CacheFiles -gt 500) {
        $status.Recommendations += "Cache-Ordner: $($status.CacheFiles) Dateien - Cleanup empfohlen"
    }
    
    if ($status.PowerSettings -ne "Hochleistung") {
        $status.Recommendations += "Power-Plan: Wechseln zu Hochleistung fuer besseres Gaming"
    }
    
    if (-not $status.GameMode) {
        $status.Recommendations += "Game-Modus nicht aktiviert - fuer bessere Gaming-Performance aktivieren"
    }
    
    return [PSCustomObject]$status
}

function Clear-TempFiles {
    param()
    
    $removedCount = 0
    $errors = 0
    # Nur Dateien, die aelter als 1 Tag sind - laufende Installationen
    # und Programme brauchen ihre aktuellen Temp-Dateien noch.
    $cutoff = (Get-Date).AddDays(-1)
    
    try {
        $tempPath = $env:TEMP
        $files = Get-ChildItem -Path $tempPath -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }
        
        foreach ($file in $files) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                $removedCount++
            }
            catch {
                $errors++
            }
        }
    }
    catch { }
    
    return @{
        Removed = $removedCount
        Errors = $errors
    }
}

function Clear-CacheFiles {
    param()
    
    $removedCount = 0
    $errors = 0
    
    try {
        $cachePath = Join-Path $env:LOCALAPPDATA "Temp"
        $files = Get-ChildItem -Path $cachePath -Recurse -File -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                $removedCount++
            }
            catch {
                $errors++
            }
        }
    }
    catch { }
    
    return @{
        Removed = $removedCount
        Errors = $errors
    }
}

function Set-PowerPlanToHigh {
    param()
    
    try {
        $powerPlans = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan -ErrorAction SilentlyContinue
        $highPerf = $powerPlans | Where-Object { $_.ElementName -like "*chstleistung*" -or $_.ElementName -like "*High Performance*" } | Select-Object -First 1
        
        if ($highPerf) {
            Invoke-CimMethod -InputObject $highPerf -MethodName Activate | Out-Null
            return $true
        }
    }
    catch { }
    
    return $false
}

function Enable-GameMode {
    param()
    
    try {
        $regPath = "HKCU:\Software\Microsoft\GameBar"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "AutoGameModeEnabled" -Value 1 -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Disable-UnnecessaryServices {
    param()
    
    # Nur nicht-kritische Services, die Gaming beeinflussen
    $servicesDisable = @(
        "DiagTrack",              # Diagnostics Tracking Service
        "dmwappushservice",       # dmwappushservice
        "Spooler",                # Print Spooler
        "WMPNetworkSvc",          # Windows Media Player Network Sharing Service
        "WSearch"                 # Windows Search (optional)
    )
    
    $disabled = @()
    $errors = @()
    
    foreach ($service in $servicesDisable) {
        try {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq "Running") {
                Stop-Service -Name $service -Force -ErrorAction Stop
                Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
                $disabled += $service
            }
        }
        catch {
            $errors += $service
        }
    }
    
    return @{
        Disabled = $disabled
        Errors = $errors
    }
}

function Get-StorageAnalysis {
    param()
    
    $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    $analysis = @()
    
    foreach ($drive in $drives) {
        $largeFiles = @()
        $largeDir = ""
        $maxSize = 0
        
        try {
            $items = Get-ChildItem -Path "$($drive.DeviceID)\" -ErrorAction SilentlyContinue -Force |
                Where-Object { -not $_.PSIsContainer } |
                Sort-Object Length -Descending |
                Select-Object -First 5
            
            foreach ($item in $items) {
                if ($item.Length -gt $maxSize) {
                    $maxSize = $item.Length
                }
                $largeFiles += @{
                    Name = $item.Name
                    Size = [math]::Round($item.Length / 1MB, 2)
                }
            }
        }
        catch { }
        
        $analysis += [PSCustomObject]@{
            Drive = $drive.DeviceID
            Used = [math]::Round(($drive.Size - $drive.FreeSpace) / 1GB, 2)
            Free = [math]::Round($drive.FreeSpace / 1GB, 2)
            LargeFiles = $largeFiles
        }
    }
    
    return $analysis
}
