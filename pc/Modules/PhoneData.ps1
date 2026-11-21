# ==========================================================
# GamingSuite X
# Phone Data v10.0
# ==========================================================
# Wandelt den Hardware-Snapshot in das JSON-Format um, das die
# GamingSuite-X-Handy-App erwartet. Laeuft im Hintergrund-Thread.

$script:PrevProcTimes = @{}
$script:PrevProcSample = $null

function Get-PhoneTopProcesses {
    param([int]$Count = 8)

    $now = Get-Date
    $cores = [Environment]::ProcessorCount
    $elapsed = 0
    if ($script:PrevProcSample) {
        $elapsed = ($now - $script:PrevProcSample).TotalMilliseconds
    }

    $rows = New-Object System.Collections.Generic.List[object]
    $current = @{}

    foreach ($p in (Get-Process -ErrorAction SilentlyContinue)) {
        if ($p.Id -eq 0 -or $p.Id -eq 4) { continue }

        $cpuMs = $null
        try { $cpuMs = $p.TotalProcessorTime.TotalMilliseconds } catch { }
        if ($null -eq $cpuMs) { continue }   # geschuetzte Systemprozesse

        $current[$p.Id] = $cpuMs
        $percent = 0.0
        if ($elapsed -gt 0 -and $script:PrevProcTimes.ContainsKey($p.Id)) {
            $percent = ($cpuMs - $script:PrevProcTimes[$p.Id]) / ($elapsed * $cores) * 100
        }

        $rows.Add([PSCustomObject]@{
            pid    = $p.Id
            name   = $p.ProcessName
            cpu    = [math]::Round([math]::Max(0, $percent), 1)
            mem_mb = [int]($p.WorkingSet64 / 1MB)
        })
    }

    $script:PrevProcTimes = $current
    $script:PrevProcSample = $now

    return @($rows | Sort-Object -Property cpu, mem_mb -Descending | Select-Object -First $Count)
}

function Get-PhonePerCoreLoad {
    try {
        $cores = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -ErrorAction Stop |
            Where-Object { $_.Name -ne '_Total' } |
            Sort-Object {
                $parts = "$($_.Name)" -split ','
                if ($parts.Count -gt 1) { [int]$parts[0] * 1000 + [int]$parts[1] } else { [int]$parts[0] }
            }
        return @($cores | ForEach-Object { [double]$_.PercentProcessorTime })
    }
    catch {
        return @()
    }
}

function Get-PhoneCpuFrequency {
    param($MaxGHz)
    try {
        $info = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -ErrorAction Stop |
            Where-Object { $_.Name -eq '_Total' } |
            Select-Object -First 1
        if ($info -and $info.PercentProcessorPerformance -and $MaxGHz) {
            return [math]::Round($MaxGHz * 1000 * $info.PercentProcessorPerformance / 100)
        }
    }
    catch { }
    return $null
}

function Get-PhoneDiskIo {
    try {
        $disk = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop |
            Where-Object { $_.Name -eq '_Total' } |
            Select-Object -First 1
        if ($disk) {
            return @{ read_bps = [double]$disk.DiskReadBytesPersec; write_bps = [double]$disk.DiskWriteBytesPersec }
        }
    }
    catch { }
    return @{ read_bps = $null; write_bps = $null }
}

function Get-PhoneSwap {
    try {
        $files = @(Get-CimInstance Win32_PageFileUsage -ErrorAction Stop)
        $total = ($files | Measure-Object -Property AllocatedBaseSize -Sum).Sum * 1MB
        $used = ($files | Measure-Object -Property CurrentUsage -Sum).Sum * 1MB
        $percent = 0
        if ($total -gt 0) { $percent = [math]::Round($used / $total * 100, 1) }
        return [ordered]@{ total = [double]$total; used = [double]$used; percent = $percent }
    }
    catch {
        return [ordered]@{ total = 0; used = 0; percent = 0 }
    }
}

function Get-PhoneBattery {
    try {
        $bat = Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1
        if ($bat) {
            return [ordered]@{
                percent   = [int]$bat.EstimatedChargeRemaining
                plugged   = ($bat.BatteryStatus -eq 2 -or $bat.BatteryStatus -ge 6)
                secs_left = $null
            }
        }
    }
    catch { }
    return $null
}

function Get-PhoneWarnings {
    param($Cpu, $Gpu, $Ram, $Storage)

    $list = New-Object System.Collections.Generic.List[object]
    function Add-W($level, $text) { $list.Add([ordered]@{ level = $level; text = $text }) }

    if ($Cpu -and $null -ne $Cpu.Temperature) {
        if ($Cpu.Temperature -ge 95) { Add-W 'crit' "CPU sehr heiß ($([math]::Round($Cpu.Temperature)) °C) – Kühlung prüfen!" }
        elseif ($Cpu.Temperature -ge 85) { Add-W 'warn' "CPU wird warm ($([math]::Round($Cpu.Temperature)) °C)." }
    }
    if ($Cpu -and $Cpu.Load -ge 95) { Add-W 'warn' "CPU voll ausgelastet ($($Cpu.Load) %)." }

    if ($Gpu) {
        if ($null -ne $Gpu.Temperature) {
            if ($Gpu.Temperature -ge 90) { Add-W 'crit' "GPU sehr heiß ($([math]::Round($Gpu.Temperature)) °C)!" }
            elseif ($Gpu.Temperature -ge 83) { Add-W 'warn' "GPU wird warm ($([math]::Round($Gpu.Temperature)) °C)." }
        }
        if ($Gpu.VRAM -gt 0 -and ($Gpu.VRAMUsed / $Gpu.VRAM) -ge 0.95) {
            Add-W 'warn' "Grafikspeicher fast voll."
        }
    }

    if ($Ram) {
        if ($Ram.Percent -ge 95) { Add-W 'crit' "Arbeitsspeicher voll ($($Ram.Percent) %) – Programme schließen." }
        elseif ($Ram.Percent -ge 85) { Add-W 'warn' "Arbeitsspeicher stark belegt ($($Ram.Percent) %)." }
    }

    foreach ($d in @($Storage)) {
        if (-not $d) { continue }
        if ($d.Percent -ge 95) { Add-W 'crit' "Laufwerk $($d.Name) fast voll ($($d.Percent) %)." }
        elseif ($d.Percent -ge 90) { Add-W 'warn' "Laufwerk $($d.Name) wird knapp ($($d.Percent) %)." }
    }

    if ($Cpu -and $null -eq $Cpu.Temperature) {
        Add-W 'info' "CPU-Temperatur nicht verfügbar: LibreHardwareMonitor als Administrator starten."
    }
    if (-not $Gpu) {
        Add-W 'info' "Keine dedizierte Grafikkarte erkannt."
    }
    elseif ($null -eq $Gpu.Usage) {
        Add-W 'info' "GPU-Auslastung nicht lesbar (Windows-Leistungsindikatoren fehlen oder sind deaktiviert)."
    }
    if ($Gpu -and $null -eq $Gpu.Temperature -and $Gpu.Name -notmatch 'NVIDIA') {
        Add-W 'info' "GPU-Temperatur bei AMD/Intel nur mit LibreHardwareMonitor (als Administrator gestartet)."
    }

    return $list.ToArray()
}

function ConvertTo-PhoneJson {
    param($Snapshot)

    $cpu = $Snapshot.CPU
    $gpu = $Snapshot.GPU
    $ram = $Snapshot.RAM
    $storage = @($Snapshot.Storage | Where-Object { $_ })
    $net = $Snapshot.Network
    $sys = $Snapshot.System

    $cpuObj = [ordered]@{
        name           = if ($cpu) { $cpu.Name } else { 'CPU' }
        cores_physical = if ($cpu) { [int]$cpu.Cores } else { 0 }
        cores_logical  = if ($cpu) { [int]$cpu.Threads } else { 0 }
        usage          = if ($cpu) { [double]$cpu.Load } else { 0 }
        per_core       = @(Get-PhonePerCoreLoad)
        freq_mhz       = if ($cpu) { Get-PhoneCpuFrequency -MaxGHz $cpu.Clock } else { $null }
        freq_max_mhz   = if ($cpu -and $cpu.Clock) { [double]$cpu.Clock * 1000 } else { $null }
        temp           = if ($cpu) { $cpu.Temperature } else { $null }
        power_w        = $null
    }

    $gpus = @()
    if ($gpu) {
        $isNvidia = $gpu.Name -match 'NVIDIA'
        $gpus = @([ordered]@{
            name         = $gpu.Name
            vendor       = if ($isNvidia) { 'NVIDIA' } elseif ($gpu.Name -match 'AMD|Radeon') { 'AMD' } else { '' }
            usage        = if ($null -ne $gpu.Usage) { [double]$gpu.Usage } else { $null }
            mem_used_mb  = if ($null -ne $gpu.VRAMUsed) { [double]$gpu.VRAMUsed * 1024 } else { $null }
            mem_total_mb = if ($gpu.VRAM -gt 0) { [double]$gpu.VRAM * 1024 } else { $null }
            temp         = $gpu.Temperature
            power_w      = $gpu.Power
            driver       = $gpu.Driver
        })
    }

    $ramObj = [ordered]@{ total = 0; used = 0; percent = 0 }
    if ($ram) {
        $ramObj = [ordered]@{
            total   = [double]$ram.Total * 1GB
            used    = [double]$ram.Used * 1GB
            percent = [double]$ram.Percent
        }
    }

    $disks = @($storage | ForEach-Object {
        [ordered]@{
            mount   = "$($_.Name) $($_.Label)".Trim()
            fs      = "$($_.Type)"
            total   = [double]$_.Total * 1GB
            used    = [double]$_.Used * 1GB
            percent = [double]$_.Percent
        }
    })

    $temps = @()
    if ($cpu -and $null -ne $cpu.Temperature) {
        $temps += [ordered]@{ hardware = $cpu.Name; name = 'CPU'; value = [double]$cpu.Temperature }
    }
    if ($gpu -and $null -ne $gpu.Temperature) {
        $temps += [ordered]@{ hardware = $gpu.Name; name = 'GPU'; value = [double]$gpu.Temperature }
    }

    $uptime = 0
    if ($sys -and $sys.Uptime) { $uptime = [int]$sys.Uptime.TotalSeconds }

    $data = [ordered]@{
        service       = 'gamingsuite-x'
        version       = '10.0'
        timestamp     = [double][DateTimeOffset]::Now.ToUnixTimeSeconds()
        hostname      = $env:COMPUTERNAME
        os            = if ($sys) { "$($sys.Windows)" } else { 'Windows' }
        uptime_s      = $uptime
        cpu           = $cpuObj
        gpus          = $gpus
        ram           = $ramObj
        swap          = Get-PhoneSwap
        disks         = $disks
        disk_io       = Get-PhoneDiskIo
        net           = [ordered]@{
            up_bps   = if ($net) { [double]$net.Upload * 1MB } else { 0 }
            down_bps = if ($net) { [double]$net.Download * 1MB } else { 0 }
        }
        battery       = Get-PhoneBattery
        temps         = $temps
        fans          = @()
        processes     = @(Get-PhoneTopProcesses)
        warnings      = @(Get-PhoneWarnings -Cpu $cpu -Gpu $gpu -Ram $ram -Storage $storage)
        sensor_source = if ($cpu -and $null -ne $cpu.Temperature) { 'LibreHardwareMonitor' } else { 'Windows' }
    }

    return ($data | ConvertTo-Json -Depth 6 -Compress)
}
