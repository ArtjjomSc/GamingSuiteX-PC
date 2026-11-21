# ==========================================================
# GamingSuite X
# Storage Manager v1.0
# ==========================================================

function Get-StorageInfo {
    param()

    $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    $storageInfo = @()

    foreach ($drive in $drives) {
        if (-not $drive.Size -or $drive.Size -le 0) { continue }
        $info = [PSCustomObject]@{
            Drive = $drive.DeviceID
            Label = $drive.VolumeName
            Total = [math]::Round($drive.Size / 1GB, 2)
            Used = [math]::Round(($drive.Size - $drive.FreeSpace) / 1GB, 2)
            Free = [math]::Round($drive.FreeSpace / 1GB, 2)
            Percent = [math]::Round((($drive.Size - $drive.FreeSpace) / $drive.Size) * 100, 1)
        }
        $storageInfo += $info
    }

    return ,@($storageInfo)
}

function Find-LargeFiles {
    param(
        [string]$Path = $env:USERPROFILE,
        [int]$MinSizeMB = 500
    )

    $largeFiles = @()

    try {
        Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt ($MinSizeMB * 1MB) } |
        ForEach-Object {
            $largeFiles += [PSCustomObject]@{
                Path = $_.FullName
                Size = [math]::Round($_.Length / 1MB, 2)
                SizeGB = [math]::Round($_.Length / 1GB, 3)
                Created = $_.CreationTime
                Modified = $_.LastWriteTime
            }
        }
    }
    catch { }

    return ,@($largeFiles | Sort-Object -Property Size -Descending)
}

function Get-FolderSize {
    param(
        [Parameter(Mandatory)][string]$FolderPath
    )

    try {
        $size = (Get-ChildItem -Path $FolderPath -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum

        return [PSCustomObject]@{
            Path = $FolderPath
            SizeMB = [math]::Round($size / 1MB, 2)
            SizeGB = [math]::Round($size / 1GB, 3)
        }
    }
    catch {
        return $null
    }
}

function Get-UninstalledSoftwareSize {
    param()

    # Groesse aus der Windows-Registry (EstimatedSize, KB) - schnell.
    # Vorher wurde jeder Programmordner komplett durchgezaehlt (Minuten).
    $softwareInfo = @()
    $uninstallPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $uninstallPaths) {
        if (-not (Test-Path $path)) { continue }
        foreach ($key in (Get-ChildItem -Path $path -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
            if (-not $p.DisplayName -or -not $p.EstimatedSize) { continue }
            if ($p.SystemComponent -eq 1) { continue }
            $softwareInfo += [PSCustomObject]@{
                Name = $p.DisplayName
                Path = $p.InstallLocation
                SizeMB = [math]::Round($p.EstimatedSize / 1024, 2)
            }
        }
    }

    return $softwareInfo |
        Sort-Object -Property Name -Unique |
        Sort-Object -Property SizeMB -Descending |
        Select-Object -First 20
}

function Get-DuplicateFiles {
    param(
        [string]$Path = $env:USERPROFILE,
        [int]$MinSizeMB = 10
    )

    $duplicates = @()

    try {
        # Nur Dateien gleicher Groesse koennen identisch sein -> nur diese hashen.
        # (Vorher wurde JEDE Datei ueber 10 MB gehasht - das dauerte ewig.)
        $groups = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt ($MinSizeMB * 1MB) } |
            Group-Object Length |
            Where-Object { $_.Count -gt 1 }

        foreach ($group in $groups) {
            $byHash = @{}
            foreach ($file in $group.Group) {
                $hash = (Get-FileHash -Path $file.FullName -Algorithm MD5 -ErrorAction SilentlyContinue).Hash
                if (-not $hash) { continue }
                if ($byHash.ContainsKey($hash)) {
                    $duplicates += [PSCustomObject]@{
                        Original = $byHash[$hash].FullName
                        Duplicate = $file.FullName
                        Size = [math]::Round($file.Length / 1MB, 2)
                        Hash = $hash
                    }
                }
                else {
                    $byHash[$hash] = $file
                }
            }
        }
    }
    catch { }

    return ,@($duplicates | Sort-Object Size -Descending)
}

function Get-CacheDirectories {
    param()

    $cacheLocations = @(
        @{ Name = "Windows Temp"; Path = $env:TEMP }
        @{ Name = "AppData Temp"; Path = Join-Path $env:LOCALAPPDATA "Temp" }
        @{ Name = "Browser Cache"; Path = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Cache" }
        # Prefetch und Windows-Update-Downloads bewusst NICHT: Prefetch beschleunigt
        # Programmstarts, und laufende Updates koennen sonst kaputtgehen.
    )

    $cacheInfo = @()

    foreach ($location in $cacheLocations) {
        try {
            if (Test-Path $location.Path) {
                $size = (Get-ChildItem -Path $location.Path -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum

                $cacheInfo += [PSCustomObject]@{
                    Name = $location.Name
                    Path = $location.Path
                    SizeMB = [math]::Round($size / 1MB, 2)
                }
            }
        }
        catch { }
    }

    return ,@($cacheInfo | Sort-Object -Property SizeMB -Descending)
}

function Clear-CacheFiles {
    param()

    $removedCount = 0
    $errors = 0
    $freedMB = 0

    try {
        $cutoff = (Get-Date).AddDays(-1)   # nur Dateien aelter als 1 Tag
        $caches = Get-CacheDirectories
        foreach ($cache in $caches) {
            $files = Get-ChildItem -Path $cache.Path -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoff }
            foreach ($file in $files) {
                try {
                    $sizeMB = [math]::Round($file.Length / 1MB, 2)
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    $removedCount++
                    $freedMB += $sizeMB
                }
                catch {
                    $errors++
                }
            }
        }
    }
    catch { }

    return @{
        Removed = $removedCount
        Errors = $errors
        FreedMB = [math]::Round($freedMB, 2)
    }
}

function Clear-Recycle {
    param()

    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        return $true
    }
    catch {
        # Leerer Papierkorb meldet unter Umstaenden einen Fehler - dann ist er trotzdem leer
        if ("$($_.Exception.Message)" -match 'leer|empty|nicht gefunden|cannot find') { return $true }
        return $false
    }
}
