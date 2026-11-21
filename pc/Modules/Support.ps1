# ==========================================================
# GamingSuite X
# Support v11.4 - Fehlerbericht fuer GitHub-Issues
# ==========================================================
# Sammelt Systeminfos und Protokolle in einer ZIP-Datei auf dem Desktop.
# Datenschutz: PC-Name, Benutzername und Prozessliste werden entfernt,
# die Handy-PIN wird nie mitgespeichert.

function Remove-GSXPrivateText {
    param([string]$Text)
    if (-not $Text) { return $Text }
    $t = $Text
    foreach ($secret in @($env:COMPUTERNAME, $env:USERNAME, $env:USERDOMAIN)) {
        if ($secret -and $secret.Length -ge 3) { $t = $t -replace [regex]::Escape($secret), '<entfernt>' }
    }
    return $t
}

function New-GSXErrorReport {
    param([string]$UiLog = '')

    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $work = Join-Path $env:TEMP "GamingSuiteX_Bericht_$stamp"
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    function Write-ReportFile([string]$name, [string]$content) {
        [System.IO.File]::WriteAllText((Join-Path $work $name), (Remove-GSXPrivateText $content), (New-Object System.Text.UTF8Encoding($false)))
    }
    function Read-Shared([string]$path) {
        # Auch Dateien lesen, die gerade geoeffnet sind (z. B. das laufende Konsolen-Protokoll)
        try {
            $fs = New-Object System.IO.FileStream($path, 'Open', 'Read', 'ReadWrite')
            $sr = New-Object System.IO.StreamReader($fs)
            $txt = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
            return $txt
        }
        catch { return "" }
    }

    # --- Systeminfos
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("GamingSuite X Fehlerbericht - $(Get-Date -Format s)")
    $lines.Add("Programmversion: $Version")
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $display = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
        $lines.Add("Windows: $($os.Caption) $display (Build $($os.BuildNumber)), Sprache $((Get-Culture).Name)")
    } catch { }
    $lines.Add("PowerShell: $($PSVersionTable.PSVersion)  |  Administrator: $(Test-GSXAdmin)")
    try { $lines.Add("CPU: $((Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim())") } catch { }
    try {
        foreach ($v in @(Get-CimInstance Win32_VideoController)) {
            $lines.Add("GPU: $($v.Name) | Treiber $($v.DriverVersion) vom $(if ($v.DriverDate) { $v.DriverDate.ToString('yyyy-MM-dd') })")
        }
    } catch { }
    try { $lines.Add("RAM: $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)) GB") } catch { }
    try { $m = Get-GSXMonitorInfo; if ($m) { $lines.Add("Monitor: $($m.Width)x$($m.Height) @ $($m.Hz) Hz (max $($m.MaxHz))") } } catch { }
    $lines.Add("Modernes Design aktiv: $script:GSXUiOk $(if ($script:GSXUiError) { "- Fehler: $script:GSXUiError" })")
    $lines.Add("nvidia-smi vorhanden: $([bool](Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue))")
    $lines.Add("PresentMon vorhanden: $(Test-Path -LiteralPath $script:PresentMonExe)")
    $lines.Add("LibreHardwareMonitor laeuft: $([bool](Get-Process LibreHardwareMonitor -ErrorAction SilentlyContinue))")
    $lines.Add("Ryzen X3D (2 CCDs): $(Test-GSXDualCcdX3D)")
    $st = $global:GSXState
    if ($st) {
        $lines.Add("Hintergrund-Messung: letzte Aktualisierung $($st.Updated), Fehler: $($st.LastError)")
        $lines.Add("Handy-Server: laeuft=$($st.PhoneServerRunning), erlaubt=$($st.PhoneEnabled), PIN gesetzt=$([bool]$st.PhonePin), Fehler: $($st.PhoneServerError)")
    }
    Write-ReportFile 'system.txt' ($lines -join "`r`n")

    # --- Aktuelle Messwerte (ohne Prozesse und Rechnernamen)
    try {
        if ($st -and $st.PhoneJson) {
            $snap = $st.PhoneJson | ConvertFrom-Json
            $snap.processes = @()
            $snap.hostname = '<entfernt>'
            Write-ReportFile 'messwerte.json' ($snap | ConvertTo-Json -Depth 8)
        }
    } catch { }

    # --- Optimizer-Status
    try {
        $report = Get-GSXTuningReport | Select-Object Category, Name, Status, Current, Recommended
        Write-ReportFile 'optimizer.txt' (($report | Format-Table -AutoSize | Out-String -Width 300))
    } catch { }

    # --- Spiele-Tuning-Protokoll aus der Oberflaeche
    if ($UiLog) { Write-ReportFile 'spiele_tuning_protokoll.txt' $UiLog }

    # --- Gespeicherte Daten (Messungen, Backups, Einstellungen ohne PIN)
    try { if (Test-Path -LiteralPath $script:GameStateFile) { Write-ReportFile 'games.json' (Read-Shared $script:GameStateFile) } } catch { }
    try { if (Test-Path -LiteralPath $script:TuningBackupFile) { Write-ReportFile 'tuning_backup.json' (Read-Shared $script:TuningBackupFile) } } catch { }
    try {
        $cfg = Get-GamingSuiteConfig | ConvertTo-Json -Depth 8 | ConvertFrom-Json
        if ($cfg.PSObject.Properties['PhonePin']) { $cfg.PhonePin = if ($cfg.PhonePin) { '<gesetzt>' } else { '' } }
        $cfg.FavoriteGames = @()
        Write-ReportFile 'config.json' ($cfg | ConvertTo-Json -Depth 8)
    } catch { }

    # --- PresentMon-Ausgaben der letzten Messungen
    foreach ($f in @(Get-ChildItem -LiteralPath $script:GameDataDir -Filter 'capture_*.txt' -File -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending | Select-Object -First 6)) {
        Write-ReportFile "presentmon_$($f.Name)" (Read-Shared $f.FullName)
    }

    # --- Konsolen-Protokolle (die letzten 2) und Fehlerprotokolle
    foreach ($f in @(Get-ChildItem -LiteralPath (Get-LogPath) -Filter 'console_*.txt' -File -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending | Select-Object -First 2)) {
        Write-ReportFile $f.Name (Read-Shared $f.FullName)
    }
    foreach ($f in @(Get-ChildItem -LiteralPath (Get-LogPath) -Filter 'errors_*.json' -File -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending | Select-Object -First 2)) {
        Write-ReportFile $f.Name (Read-Shared $f.FullName)
    }

    # --- Packen
    $desktop = [Environment]::GetFolderPath('Desktop')
    $zip = Join-Path $desktop "GamingSuiteX_Fehlerbericht_$stamp.zip"
    Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    return $zip
}
