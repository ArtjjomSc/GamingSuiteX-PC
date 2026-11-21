# ==========================================================
# GamingSuite X
# System Tuning v10.1 - Hardware-Diagnose & Gaming-Optimierung
# ==========================================================
# Prueft alle wichtigen Einstellungen fuer Leistung und Latenz,
# zeigt BIOS/Treiber/Hardware-Infos und optimiert per Klick.
# Vor jeder Aenderung wird der Originalzustand gesichert
# (%APPDATA%\GamingSuiteX\tuning_backup.json) -> "Zuruecksetzen".

$script:TuningBackupFile = Join-Path (Get-ConfigPath) "tuning_backup.json"

$script:GUID_ULTIMATE   = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$script:GUID_HIGHPERF   = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$script:GUID_SUB_CPU    = '54533251-82be-4824-96c1-47b60b740d00'
$script:GUID_CPU_MIN    = '893dee8e-2bef-41e0-89c6-b55d0929964c'
$script:GUID_CORE_PARK  = '0cc5b647-c1df-4637-891a-dec35c318583'

$script:MMCSS_PROFILE = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$script:MMCSS_GAMES   = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
$script:HVCI_KEY      = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'

# ----------------------------------------------------------
# Hilfsfunktionen
# ----------------------------------------------------------

function Test-GSXAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-GSXRegValue {
    param([string]$Path, [string]$Name)
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.GetValueNames() -contains $Name) { return $item.GetValue($Name) }
    }
    catch { }
    return $null
}

function Set-GSXRegValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }
    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
}

function Get-GSXActivePowerScheme {
    $out = (powercfg /getactivescheme 2>$null) -join ' '
    if ($out -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s+\((.+)\)') {
        return [PSCustomObject]@{ Guid = $Matches[1].ToLower(); Name = $Matches[2].Trim() }
    }
    return $null
}

function Get-GSXPowerIndexAC {
    param([string]$Scheme, [string]$Sub, [string]$Setting)
    $out = (powercfg /query $Scheme $Sub $Setting 2>$null) -join "`n"
    $hex = [regex]::Matches($out, '0x[0-9a-fA-F]{8}')
    # Reihenfolge: Minimum, Maximum, Schrittweite, AC-Wert, DC-Wert
    if ($hex.Count -ge 2) {
        return [Convert]::ToInt32($hex[$hex.Count - 2].Value.Substring(2), 16)
    }
    return $null
}

function Get-GSXNvidiaSmi {
    $cmd = Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if (Test-Path "C:\Windows\System32\nvidia-smi.exe") { return "C:\Windows\System32\nvidia-smi.exe" }
    return $null
}

function Get-GSXActiveTcpInterfaces {
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
    $result = @()
    foreach ($key in (Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue)) {
        $p = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
        $ips = @(@($p.DhcpIPAddress) + @($p.IPAddress) | Where-Object { $_ -and $_ -ne '0.0.0.0' })
        if ($ips.Count -gt 0) { $result += $key.PSPath }
    }
    return $result
}

function Set-GSXMouseLive {
    param([int]$Threshold1, [int]$Threshold2, [int]$Speed)
    try {
        if (-not ('GSXNative' -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class GSXNative {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, int[] pvParam, uint fWinIni);
}
"@
        }
        # SPI_SETMOUSE = 0x0004, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 3
        [void][GSXNative]::SystemParametersInfo(0x0004, 0, [int[]]@($Threshold1, $Threshold2, $Speed), 3)
    }
    catch { }
}

# ----------------------------------------------------------
# Backup / Zuruecksetzen
# ----------------------------------------------------------

function Initialize-GSXTuningBackup {
    $script:TuningBackup = @{ Registry = @{}; PowerScheme = $null; PowerIndex = @{} }
    if (-not (Test-Path -LiteralPath $script:TuningBackupFile)) { return }
    try {
        $data = Get-Content -LiteralPath $script:TuningBackupFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($e in @($data.Registry)) {
            if ($e) { $script:TuningBackup.Registry["$($e.Path)|$($e.Name)"] = $e }
        }
        foreach ($e in @($data.PowerIndex)) {
            if ($e) { $script:TuningBackup.PowerIndex["$($e.Scheme)|$($e.Sub)|$($e.Setting)"] = $e }
        }
        $script:TuningBackup.PowerScheme = $data.PowerScheme
    }
    catch {
        Write-Warning "Tuning-Backup konnte nicht gelesen werden: $_"
    }
}

function Save-GSXTuningBackup {
    $out = [ordered]@{
        Created     = (Get-Date).ToString('s')
        PowerScheme = $script:TuningBackup.PowerScheme
        Registry    = @($script:TuningBackup.Registry.Values)
        PowerIndex  = @($script:TuningBackup.PowerIndex.Values)
    }
    $out | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:TuningBackupFile -Encoding UTF8
}

function Test-GSXTuningBackup {
    return ($script:TuningBackup.Registry.Count -gt 0 -or
            $script:TuningBackup.PowerIndex.Count -gt 0 -or
            $script:TuningBackup.PowerScheme)
}

function Backup-GSXRegValue {
    param([string]$Path, [string]$Name)
    $key = "$Path|$Name"
    if ($script:TuningBackup.Registry.ContainsKey($key)) { return }   # Original nur einmal sichern

    $existed = $false; $value = $null; $type = $null
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.GetValueNames() -contains $Name) {
            $existed = $true
            $value = $item.GetValue($Name)
            $type = $item.GetValueKind($Name).ToString()
        }
    }
    catch { }

    $script:TuningBackup.Registry[$key] = [PSCustomObject]@{
        Path = $Path; Name = $Name; Existed = $existed; Value = $value; Type = $type
    }
}

function Set-GSXTunedValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    Backup-GSXRegValue -Path $Path -Name $Name
    Set-GSXRegValue -Path $Path -Name $Name -Value $Value -Type $Type
}

function Backup-GSXPowerIndex {
    param([string]$Scheme, [string]$Sub, [string]$Setting)
    $key = "$Scheme|$Sub|$Setting"
    if ($script:TuningBackup.PowerIndex.ContainsKey($key)) { return }
    $ac = Get-GSXPowerIndexAC -Scheme $Scheme -Sub $Sub -Setting $Setting
    if ($null -eq $ac) { return }
    $script:TuningBackup.PowerIndex[$key] = [PSCustomObject]@{
        Scheme = $Scheme; Sub = $Sub; Setting = $Setting; AC = $ac
    }
}

function Restore-GSXTuning {
    $messages = @()

    foreach ($e in @($script:TuningBackup.Registry.Values)) {
        try {
            if ($e.Existed) {
                $type = if ($e.Type) { $e.Type } else { 'DWord' }
                Set-GSXRegValue -Path $e.Path -Name $e.Name -Value $e.Value -Type $type
            }
            else {
                Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue
            }
        }
        catch { $messages += "Fehler bei $($e.Name): $($_.Exception.Message)" }
    }

    foreach ($e in @($script:TuningBackup.PowerIndex.Values)) {
        powercfg /setacvalueindex $e.Scheme $e.Sub $e.Setting $e.AC 2>$null | Out-Null
    }

    if ($script:TuningBackup.PowerScheme) {
        powercfg /setactive $script:TuningBackup.PowerScheme 2>$null | Out-Null
    }
    else {
        powercfg /setactive SCHEME_CURRENT 2>$null | Out-Null
    }

    # Mauswerte sofort uebernehmen
    $t1 = Get-GSXRegValue 'HKCU:\Control Panel\Mouse' 'MouseThreshold1'
    $t2 = Get-GSXRegValue 'HKCU:\Control Panel\Mouse' 'MouseThreshold2'
    $sp = Get-GSXRegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed'
    if ($null -ne $sp) { Set-GSXMouseLive -Threshold1 ([int]"$t1") -Threshold2 ([int]"$t2") -Speed ([int]"$sp") }

    Remove-Item -LiteralPath $script:TuningBackupFile -Force -ErrorAction SilentlyContinue
    Initialize-GSXTuningBackup

    return [PSCustomObject]@{ Errors = $messages }
}

# ----------------------------------------------------------
# Optimierbare Einstellungen
# ----------------------------------------------------------
# Check  -> @{ Ok = $true/$false/$null; Current = "Text" }
# Apply  -> aendert die Einstellung (mit Backup)

$script:TuningDefinitions = @(

    @{
        Id = 'powerplan'; Category = 'Energie'; Name = 'Energiesparplan Hoechstleistung / Ultimativ'
        Recommended = 'Ultimative Leistung'; OneClick = $true; Restart = $false
        Check = {
            $a = Get-GSXActivePowerScheme
            if (-not $a) { return @{ Ok = $null; Current = 'unbekannt' } }
            $ok = ($a.Guid -eq $script:GUID_ULTIMATE -or $a.Guid -eq $script:GUID_HIGHPERF -or
                   $a.Name -match 'Ultimat|chstleistung|High performance')
            @{ Ok = $ok; Current = $a.Name }
        }
        Apply = {
            $active = Get-GSXActivePowerScheme
            if (-not $script:TuningBackup.PowerScheme -and $active) {
                $script:TuningBackup.PowerScheme = $active.Guid
            }
            $list = (powercfg /list 2>$null) -join "`n"
            $guid = $null
            foreach ($m in [regex]::Matches($list, '([0-9a-fA-F-]{36})\s+\(([^)]+)\)')) {
                if ($m.Groups[2].Value -match 'Ultimat') { $guid = $m.Groups[1].Value; break }
            }
            if (-not $guid) {
                $dup = (powercfg -duplicatescheme $script:GUID_ULTIMATE 2>$null) -join ' '
                if ($dup -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
                    $guid = $Matches[1]
                }
            }
            if (-not $guid) { $guid = $script:GUID_HIGHPERF }
            powercfg /setactive $guid 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Energiesparplan konnte nicht aktiviert werden." }
        }
    }

    @{
        Id = 'cpupark'; Category = 'CPU'; Name = 'CPU-Mindestleistung 100 % / kein Core-Parking'
        Recommended = 'Min. 100 %, alle Kerne aktiv'; OneClick = $true; Restart = $false
        Check = {
            $a = Get-GSXActivePowerScheme
            if (-not $a) { return @{ Ok = $null; Current = 'unbekannt' } }
            $min = Get-GSXPowerIndexAC $a.Guid $script:GUID_SUB_CPU $script:GUID_CPU_MIN
            $park = Get-GSXPowerIndexAC $a.Guid $script:GUID_SUB_CPU $script:GUID_CORE_PARK
            if ($null -eq $min) { return @{ Ok = $null; Current = 'nicht lesbar' } }
            $text = "Min. $min %"
            if ($null -ne $park) { $text += " · Kerne min. $park %" }
            @{ Ok = ($min -ge 100 -and ($null -eq $park -or $park -ge 100)); Current = $text }
        }
        Apply = {
            $a = Get-GSXActivePowerScheme
            if (-not $a) { throw "Aktiver Energiesparplan nicht lesbar." }
            foreach ($setting in @($script:GUID_CPU_MIN, $script:GUID_CORE_PARK)) {
                Backup-GSXPowerIndex -Scheme $a.Guid -Sub $script:GUID_SUB_CPU -Setting $setting
                powercfg /setacvalueindex $a.Guid $script:GUID_SUB_CPU $setting 100 2>$null | Out-Null
            }
            powercfg /setactive $a.Guid 2>$null | Out-Null
        }
    }

    @{
        Id = 'throttling'; Category = 'CPU'; Name = 'Windows Power Throttling aus'
        Recommended = 'Aus (vor allem bei Intel 12. Gen+ mit P/E-Kernen)'; OneClick = $true; Restart = $true
        Check = {
            $v = Get-GSXRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff'
            @{ Ok = ($v -eq 1); Current = if ($v -eq 1) { 'Aus' } else { 'An (Standard)' } }
        }
        Apply = {
            Set-GSXTunedValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
        }
    }

    @{
        Id = 'gamemode'; Category = 'Windows'; Name = 'Windows-Spielmodus'
        Recommended = 'An'; OneClick = $true; Restart = $false
        Check = {
            $v = Get-GSXRegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'
            # Fehlt der Wert, ist der Spielmodus unter Windows 10/11 standardmaessig an.
            $on = ($null -eq $v -or $v -eq 1)
            @{ Ok = $on; Current = if ($on) { 'An' } else { 'Aus' } }
        }
        Apply = {
            Set-GSXTunedValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
            Set-GSXTunedValue 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
        }
    }

    @{
        Id = 'hags'; Category = 'GPU'; Name = 'Hardwarebeschleunigte GPU-Planung (HAGS)'
        Recommended = 'An (wichtig fuer DLSS Frame Generation)'; OneClick = $true; Restart = $true
        Check = {
            $v = Get-GSXRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
            @{ Ok = ($v -eq 2); Current = if ($v -eq 2) { 'An' } elseif ($v -eq 1) { 'Aus' } else { 'Standard (aus)' } }
        }
        Apply = {
            Set-GSXTunedValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
        }
    }

    @{
        Id = 'gamedvr'; Category = 'Windows'; Name = 'Xbox Game DVR / Hintergrundaufnahme'
        Recommended = 'Aus'; OneClick = $true; Restart = $false
        Check = {
            $dvr = Get-GSXRegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
            $cap = Get-GSXRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
            $off = ($dvr -eq 0 -and $cap -eq 0)
            @{ Ok = $off; Current = if ($off) { 'Aus' } else { 'An' } }
        }
        Apply = {
            Set-GSXTunedValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
            Set-GSXTunedValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
        }
    }

    @{
        Id = 'mouse'; Category = 'Eingabe'; Name = 'Mausbeschleunigung (Zeigerbeschleunigung)'
        Recommended = 'Optional: Aus fuer 1:1-Zielen (Geschmackssache)'; OneClick = $false; Restart = $false
        Check = {
            $v = Get-GSXRegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed'
            $off = ("$v" -eq '0')
            @{ Ok = $off; Current = if ($off) { 'Aus' } else { 'An' } }
        }
        Apply = {
            Set-GSXTunedValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
            Set-GSXTunedValue 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
            Set-GSXTunedValue 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
            Set-GSXMouseLive -Threshold1 0 -Threshold2 0 -Speed 0
        }
    }

    @{
        Id = 'mmcss'; Category = 'Latenz'; Name = 'Spiele-Prioritaet (MMCSS)'
        Recommended = 'Hohe Prioritaet fuer Spiele'; OneClick = $true; Restart = $true
        Check = {
            $resp = Get-GSXRegValue $script:MMCSS_PROFILE 'SystemResponsiveness'
            $prio = Get-GSXRegValue $script:MMCSS_GAMES 'Priority'
            $gpu  = Get-GSXRegValue $script:MMCSS_GAMES 'GPU Priority'
            $ok = ($null -ne $resp -and $resp -le 10 -and $prio -eq 6 -and $gpu -eq 8)
            @{ Ok = $ok; Current = "Reserve $resp % · Prioritaet $prio · GPU $gpu" }
        }
        Apply = {
            Set-GSXTunedValue $script:MMCSS_PROFILE 'SystemResponsiveness' 10
            Set-GSXTunedValue $script:MMCSS_GAMES 'GPU Priority' 8
            Set-GSXTunedValue $script:MMCSS_GAMES 'Priority' 6
            Set-GSXTunedValue $script:MMCSS_GAMES 'Scheduling Category' 'High' 'String'
            Set-GSXTunedValue $script:MMCSS_GAMES 'SFIO Priority' 'High' 'String'
        }
    }

    @{
        Id = 'netthrottle'; Category = 'Latenz'; Name = 'Netzwerk-Drosselung (Network Throttling)'
        Recommended = 'Optional: Aus (Wirkung je nach System gering)'; OneClick = $false; Restart = $true
        Check = {
            $v = Get-GSXRegValue $script:MMCSS_PROFILE 'NetworkThrottlingIndex'
            $off = ($v -eq -1)
            @{ Ok = $off; Current = if ($off) { 'Aus' } elseif ($null -eq $v) { 'An (Standard)' } else { "An ($v)" } }
        }
        Apply = {
            Set-GSXTunedValue $script:MMCSS_PROFILE 'NetworkThrottlingIndex' ([int]-1)
        }
    }

    @{
        Id = 'nagle'; Category = 'Latenz'; Name = 'Nagle-Algorithmus (TCP-Verzoegerung)'
        Recommended = 'Optional: Aus (hilft v. a. aelteren Spielen)'; OneClick = $false; Restart = $true
        Check = {
            $ifaces = @(Get-GSXActiveTcpInterfaces)
            if ($ifaces.Count -eq 0) { return @{ Ok = $null; Current = 'keine aktive Verbindung' } }
            $done = @($ifaces | Where-Object {
                (Get-GSXRegValue $_ 'TcpAckFrequency') -eq 1 -and (Get-GSXRegValue $_ 'TCPNoDelay') -eq 1
            })
            @{ Ok = ($done.Count -eq $ifaces.Count); Current = "$($done.Count) von $($ifaces.Count) Adaptern optimiert" }
        }
        Apply = {
            foreach ($i in @(Get-GSXActiveTcpInterfaces)) {
                Set-GSXTunedValue $i 'TcpAckFrequency' 1
                Set-GSXTunedValue $i 'TCPNoDelay' 1
            }
        }
    }

    @{
        Id = 'hvci'; Category = 'Sicherheit'; Name = 'Speicher-Integritaet (Kernisolierung)'
        Recommended = 'Aus = mehr FPS, aber weniger Schutz'; OneClick = $false; Restart = $true
        Check = {
            $running = $null
            try {
                $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
                $running = (@($dg.SecurityServicesRunning) -contains 2)
            }
            catch { }
            $reg = Get-GSXRegValue $script:HVCI_KEY 'Enabled'
            if ($null -eq $running) { return @{ Ok = $null; Current = 'unbekannt' } }
            $text = if ($running) { 'An (kostet Leistung)' } else { 'Aus' }
            if ($running -and $reg -eq 0) { $text = 'Aus nach Neustart' }
            @{ Ok = (-not $running); Current = $text }
        }
        Apply = {
            Set-GSXTunedValue $script:HVCI_KEY 'Enabled' 0
        }
    }
)

# ----------------------------------------------------------
# Hardware-Infos (nur Anzeige, im BIOS/Herstellertool aenderbar)
# ----------------------------------------------------------

function New-GSXTuningItem {
    param($Id, $Category, $Name, $Ok, $Current, $Recommended, [string]$Status = '',
          [bool]$Fixable = $false, [bool]$OneClick = $false, [bool]$Restart = $false)

    if (-not $Status) {
        if ($null -eq $Ok) { $Status = 'INFO' }
        elseif ($Ok) { $Status = 'OPTIMAL' }
        elseif ($Fixable) { $Status = 'NICHT AKTIV' }
        else { $Status = 'HINWEIS' }
    }

    [PSCustomObject]@{
        Id = $Id; Category = $Category; Name = $Name; Ok = $Ok; Status = $Status
        Current = "$Current"; Recommended = "$Recommended"
        Fixable = $Fixable; OneClick = $OneClick; Restart = $Restart
    }
}

function Get-GSXHardwareItems {
    $items = New-Object System.Collections.Generic.List[object]

    # BIOS + Mainboard
    try {
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
        $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
        $boardName = "$($board.Manufacturer) $($board.Product)".Trim()
        $items.Add((New-GSXTuningItem 'board' 'System' 'Mainboard' $null $boardName ''))

        $date = $bios.ReleaseDate
        $dateText = if ($date) { $date.ToString('dd.MM.yyyy') } else { 'unbekannt' }
        $old = ($date -and $date -lt (Get-Date).AddYears(-2))
        $rec = if ($old) { 'Aelter als 2 Jahre - beim Mainboard-Hersteller nach Update suchen' } else { 'Aktuell genug' }
        $items.Add((New-GSXTuningItem 'bios' 'System' 'BIOS-Version' (-not $old) "$($bios.SMBIOSBIOSVersion) vom $dateText" $rec))
    }
    catch {
        $items.Add((New-GSXTuningItem 'bios' 'System' 'BIOS-Version' $null 'nicht lesbar' ''))
    }

    # Windows
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $display = Get-GSXRegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
        $items.Add((New-GSXTuningItem 'windows' 'System' 'Windows' $null "$($os.Caption) $display (Build $($os.BuildNumber))" ''))
    }
    catch { }

    # CPU
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $items.Add((New-GSXTuningItem 'cpu' 'CPU' 'Prozessor' $null "$($cpu.Name.Trim()) · $($cpu.NumberOfCores) Kerne / $($cpu.NumberOfLogicalProcessors) Threads" ''))
    }
    catch { }

    # RAM / XMP
    try {
        $mem = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)
        $totalGB = [math]::Round(($mem | Measure-Object Capacity -Sum).Sum / 1GB)
        $configured = ($mem | Measure-Object ConfiguredClockSpeed -Maximum).Maximum
        $rated = ($mem | Measure-Object Speed -Maximum).Maximum
        $type = ($mem | Select-Object -First 1).SMBIOSMemoryType
        $typeName = switch ($type) { 26 { 'DDR4' } 34 { 'DDR5' } default { 'RAM' } }
        $jedecMax = switch ($type) { 26 { 3200 } 34 { 4800 } default { 0 } }

        $current = "$totalGB GB $typeName · $configured MT/s · $($mem.Count) Module"
        if ($jedecMax -gt 0 -and $configured -gt $jedecMax) {
            $items.Add((New-GSXTuningItem 'xmp' 'RAM' 'XMP / EXPO (RAM-Profil)' $true $current 'Aktiv'))
        }
        elseif ($rated -gt $configured) {
            $items.Add((New-GSXTuningItem 'xmp' 'RAM' 'XMP / EXPO (RAM-Profil)' $false $current "Im BIOS XMP aktivieren (Module koennen $rated MT/s)" 'BIOS'))
        }
        else {
            $items.Add((New-GSXTuningItem 'xmp' 'RAM' 'XMP / EXPO (RAM-Profil)' $null $current 'Laeuft mit Standardtakt - pruefen, ob die Module mehr koennen (XMP im BIOS)' 'PRUEFEN'))
        }
        if ($mem.Count -eq 1) {
            $items.Add((New-GSXTuningItem 'dualchannel' 'RAM' 'Dual-Channel' $false '1 Modul (Single-Channel)' 'Zweites Modul einsetzen' 'HARDWARE'))
        }
    }
    catch { }

    # GPU, Treiber, Resizable BAR
    $smi = Get-GSXNvidiaSmi
    if ($smi) {
        try {
            $line = (& $smi --query-gpu=name,driver_version --format=csv,noheader 2>$null | Select-Object -First 1)
            $parts = "$line" -split ','
            $gpuName = $parts[0].Trim()
            $driver = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '?' }

            $vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1
            $driverDate = if ($vc) { $vc.DriverDate } else { $null }
            $oldDriver = ($driverDate -and $driverDate -lt (Get-Date).AddMonths(-6))
            $dateText = if ($driverDate) { " vom $($driverDate.ToString('dd.MM.yyyy'))" } else { '' }
            $rec = if ($oldDriver) { 'Aelter als 6 Monate - NVIDIA-App/GeForce Experience aktualisieren' } else { 'Aktuell' }
            $items.Add((New-GSXTuningItem 'gpu' 'GPU' 'Grafikkarte' $null $gpuName ''))
            $items.Add((New-GSXTuningItem 'driver' 'GPU' 'NVIDIA-Treiber' (-not $oldDriver) "$driver$dateText" $rec))

            $q = (& $smi -q -d MEMORY 2>$null) -join "`n"
            if ($q -match 'BAR1 Memory Usage[\s\S]*?Total\s*:\s*(\d+)\s*MiB') {
                $bar = [int]$Matches[1]
                if ($bar -gt 256) {
                    $items.Add((New-GSXTuningItem 'rebar' 'GPU' 'Resizable BAR' $true "Aktiv ($bar MiB)" 'Aktiv'))
                }
                else {
                    $items.Add((New-GSXTuningItem 'rebar' 'GPU' 'Resizable BAR' $false "Aus ($bar MiB)" "Im BIOS 'Above 4G Decoding' + 'Re-Size BAR' aktivieren" 'BIOS'))
                }
            }
        }
        catch { }
    }
    else {
        try {
            $vc = Get-CimInstance Win32_VideoController -ErrorAction Stop | Select-Object -First 1
            $items.Add((New-GSXTuningItem 'gpu' 'GPU' 'Grafikkarte' $null "$($vc.Name) · Treiber $($vc.DriverVersion)" ''))
        }
        catch { }
    }

    # Systemlaufwerk
    try {
        $part = Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop
        $disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop
        $phys = Get-PhysicalDisk -ErrorAction Stop | Where-Object { [int]$_.DeviceId -eq $disk.Number } | Select-Object -First 1
        $media = "$($phys.MediaType)"
        $bus = "$($phys.BusType)"
        $isSsd = ($media -eq 'SSD' -or $bus -eq 'NVMe')
        $rec = if ($isSsd) { 'SSD' } else { 'Windows auf eine SSD umziehen' }
        $items.Add((New-GSXTuningItem 'sysdisk' 'Laufwerk' 'Systemlaufwerk' $isSsd "$($disk.FriendlyName) · $media/$bus" $rec))

        $vol = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop
        $freePct = [math]::Round($vol.FreeSpace / $vol.Size * 100)
        $items.Add((New-GSXTuningItem 'sysfree' 'Laufwerk' 'Freier Platz Systemlaufwerk' ($freePct -ge 15) "$freePct % frei ($([math]::Round($vol.FreeSpace / 1GB)) GB)" 'Mind. 15 % frei'))
    }
    catch { }

    return $items
}

# ----------------------------------------------------------
# AMD Ryzen X3D mit zwei CCDs (z. B. 7950X3D, 9950X3D)
# ----------------------------------------------------------
# Diese CPUs parken beim Spielen absichtlich die Kerne ohne 3D-Cache
# (AMD-Chipsatztreiber + Xbox Game Bar + Energiesparplan "Ausbalanciert").
# Core-Parking aus, Hoechstleistungsplan oder Game-Bar-Aenderungen
# wuerden das aushebeln und Spiele langsamer machen -> dort nicht anfassen.

$script:X3DProtectedIds = @('powerplan', 'cpupark', 'gamedvr')

function Test-GSXDualCcdX3D {
    try {
        $name = (Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1).Name
        return ($name -match 'Ryzen 9 \d{4}X3D')
    }
    catch { return $false }
}

function Test-GSXTuningAllowed {
    param([string]$Id)
    if ($script:X3DProtectedIds -contains $Id -and (Test-GSXDualCcdX3D)) { return $false }
    return $true
}

# ----------------------------------------------------------
# Oeffentliche Funktionen
# ----------------------------------------------------------

function Get-GSXTuningReport {
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($i in (Get-GSXHardwareItems)) { $items.Add($i) }

    $x3d = Test-GSXDualCcdX3D
    foreach ($def in $script:TuningDefinitions) {
        $r = $null
        try { $r = & $def.Check } catch { $r = @{ Ok = $null; Current = "Fehler: $($_.Exception.Message)" } }
        if (-not $r) { $r = @{ Ok = $null; Current = 'unbekannt' } }

        if ($x3d -and $script:X3DProtectedIds -contains $def.Id) {
            $items.Add((New-GSXTuningItem $def.Id $def.Category $def.Name $null $r.Current `
                'Bei Ryzen X3D mit 2 CCDs NICHT aendern - Kern-Parken fuer den 3D-Cache noetig' 'GESCHUETZT'))
            continue
        }

        $status = ''
        if ($def.Id -eq 'hvci' -and $r.Ok -eq $false) { $status = 'AN' }
        elseif (-not $def.OneClick -and $r.Ok -eq $false) { $status = 'OPTIONAL' }

        $items.Add((New-GSXTuningItem $def.Id $def.Category $def.Name $r.Ok $r.Current $def.Recommended $status `
            -Fixable $true -OneClick $def.OneClick -Restart $def.Restart))
    }
    return $items
}

function Invoke-GSXOptimization {
    param(
        [string[]]$Ids,
        [switch]$OneClick
    )

    $results = New-Object System.Collections.Generic.List[object]
    $restart = $false

    foreach ($def in $script:TuningDefinitions) {
        $selected = if ($OneClick) { $def.OneClick } else { $Ids -contains $def.Id }
        if (-not $selected) { continue }
        if (-not (Test-GSXTuningAllowed $def.Id)) {
            $results.Add([PSCustomObject]@{ Name = $def.Name; Success = $true; Message = 'uebersprungen (Ryzen X3D mit 2 CCDs)' })
            continue
        }

        $state = $null
        try { $state = & $def.Check } catch { }
        if ($state -and $state.Ok -eq $true) {
            $results.Add([PSCustomObject]@{ Name = $def.Name; Success = $true; Message = 'war bereits optimal' })
            continue
        }

        try {
            & $def.Apply
            $results.Add([PSCustomObject]@{ Name = $def.Name; Success = $true; Message = 'optimiert' })
            if ($def.Restart) { $restart = $true }
        }
        catch {
            $results.Add([PSCustomObject]@{ Name = $def.Name; Success = $false; Message = $_.Exception.Message })
        }
    }

    Save-GSXTuningBackup

    return [PSCustomObject]@{ Results = $results; RestartRequired = $restart }
}

Initialize-GSXTuningBackup
