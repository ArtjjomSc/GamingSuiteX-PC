# ==========================================================
# GamingSuite X
# Hardware Engine v8.2
# ==========================================================


# ==========================================================
# CPU
# ==========================================================

function Get-LibreHardwareMonitorTemperature {
    param(
        [ValidateSet("CPU", "GPU")]
        [string]$Device
    )

    try {
        $pattern = if ($Device -eq "CPU") { "cpu" } else { "gpu" }

        $sensor = Get-CimInstance `
            -Namespace "root\LibreHardwareMonitor" `
            -ClassName "Sensor" `
            -ErrorAction Stop |
            Where-Object {
                $_.SensorType -eq "Temperature" -and
                $_.Identifier -match $pattern
            } |
            Sort-Object {
                if ($_.Name -match "Package|Tctl|Tdie|Core Average|GPU Core") { 0 } else { 1 }
            } |
            Select-Object -First 1

        if ($sensor) {
            return [math]::Round([double]$sensor.Value, 1)
        }
    }
    catch {
        # LibreHardwareMonitor ist optional. Ohne laufenden WMI-Sensor
        # wird bewusst kein Fehler an die Benutzeroberflaeche weitergegeben.
        return $null
    }

    return $null
}

function Get-HardwareCPU {

    try {

        $cpu =
        Get-CimInstance Win32_Processor


        $allCores =
        @(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor)

        $load =
        $allCores |
        Where-Object {
            $_.Name -eq "_Total"
        }

        # Hoechste Auslastung eines einzelnen Threads - zeigt CPU-Limits,
        # die im Gesamtdurchschnitt (z. B. 16 % bei 24 Threads) untergehen.
        $coreMax =
        ($allCores |
        Where-Object { $_.Name -ne "_Total" } |
        Measure-Object -Property PercentProcessorTime -Maximum).Maximum


        [PSCustomObject]@{

            Name =
            $cpu.Name.Trim()


            Cores =
            $cpu.NumberOfCores


            Threads =
            $cpu.NumberOfLogicalProcessors


            Clock =
            [math]::Round(
                $cpu.MaxClockSpeed / 1000,
                2
            )


            Cache =
            [math]::Round(
                $cpu.L3CacheSize / 1024,
                1
            )


            Temperature =
            Get-LibreHardwareMonitorTemperature "CPU"


            Load =
            $load.PercentProcessorTime


            CoreMax =
            $coreMax

        }

    }
    catch {

        $null

    }

}



# ==========================================================
# Haupt-GPU
# NVIDIA bevorzugen
# ==========================================================

# ----------------------------------------------------------
# GPU-Auslastung und VRAM fuer ALLE Hersteller (NVIDIA, AMD, Intel)
# ueber die Windows-Leistungsindikatoren "GPU Engine" / "GPU Adapter Memory"
# (Windows 10 1709+). Gleiche Quelle wie der Task-Manager.
# ----------------------------------------------------------
function Get-WindowsGpuCounters {
    $result = $null
    try {
        $engines = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop |
            Where-Object { $_.Name -match 'engtype_3D' }
        # Pro Grafikkarte (luid) die 3D-Last aller Prozesse addieren
        $byAdapter = @{}
        foreach ($e in $engines) {
            if ($e.Name -match 'luid_(0x[0-9a-fA-F]+_0x[0-9a-fA-F]+)') {
                $luid = $Matches[1]
                if (-not $byAdapter.ContainsKey($luid)) { $byAdapter[$luid] = 0.0 }
                $byAdapter[$luid] += [double]$e.UtilizationPercentage
            }
        }

        $memory = @{}
        try {
            foreach ($m in @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -ErrorAction Stop)) {
                if ($m.Name -match 'luid_(0x[0-9a-fA-F]+_0x[0-9a-fA-F]+)') { $memory[$Matches[1]] = [double]$m.DedicatedUsage }
            }
        }
        catch { }

        # Die Karte mit dem meisten belegten VRAM ist die dedizierte
        $best = $null
        foreach ($luid in (@($byAdapter.Keys) + @($memory.Keys) | Select-Object -Unique)) {
            $mem = if ($memory.ContainsKey($luid)) { $memory[$luid] } else { 0 }
            if (-not $best -or $mem -gt $best.Memory) {
                $use = if ($byAdapter.ContainsKey($luid)) { $byAdapter[$luid] } else { 0 }
                $best = @{ Memory = $mem; Usage = [math]::Min(100, [math]::Round($use)) }
            }
        }
        if ($best) {
            $result = [PSCustomObject]@{ Usage = $best.Usage; VRAMUsedGB = [math]::Round($best.Memory / 1GB, 1) }
        }
    }
    catch { }
    return $result
}

function Get-HardwareGPU {

    try {

        # Dedizierte Karte bevorzugen: NVIDIA > AMD Radeon RX > Intel Arc > Rest
        # (vorher konnte die Ryzen-Grafik "AMD Radeon(TM) Graphics" gewaehlt werden)
        $gpu =
        Get-CimInstance Win32_VideoController |
        Where-Object {
            $_.Name -match "NVIDIA|AMD|Radeon|Arc"
        } |
        Sort-Object {
            if ($_.Name -match "NVIDIA") { 0 }
            elseif ($_.Name -match "Radeon (RX|Pro)|RX \d") { 1 }
            elseif ($_.Name -match "Arc") { 2 }
            else { 3 }
        } |
        Select-Object -First 1


        if($gpu)
        {

            $vram = 0
            $vramUsed = $null
            $usage = $null
            $usageSource = $null
            $nvidiaTemperature = $null
            $nvidiaPower = $null


            # nvidia-smi liefert den korrekten dedizierten Speicher, auch wenn
            # Win32_VideoController.AdapterRAM nur 0 oder einen falschen Wert meldet.
            if ($gpu.Name -match "NVIDIA") {
                $nvidiaSmi = Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue

                if (-not $nvidiaSmi -and (Test-Path "C:\Windows\System32\nvidia-smi.exe")) {
                    $nvidiaSmi = Get-Item "C:\Windows\System32\nvidia-smi.exe"
                }

                if ($nvidiaSmi) {
                    $metrics = & $nvidiaSmi.Source --query-gpu=memory.total,memory.used,utilization.gpu,temperature.gpu,power.draw --format=csv,noheader,nounits 2>$null |
                        Select-Object -First 1

                    $memoryMB = 0
                    $usedMemoryMB = 0
                    $usagePercent = 0
                    $values = "$metrics" -split ','

                    if ($values.Count -ge 3 -and
                        [int]::TryParse($values[0].Trim(), [ref]$memoryMB) -and
                        [int]::TryParse($values[1].Trim(), [ref]$usedMemoryMB) -and
                        [int]::TryParse($values[2].Trim(), [ref]$usagePercent)) {
                        $vram = [math]::Round($memoryMB / 1024, 1)
                        $vramUsed = [math]::Round($usedMemoryMB / 1024, 1)
                        $usage = $usagePercent
                    }

                    # Temperatur und Verbrauch liefert nvidia-smi direkt -
                    # dafuer wird kein LibreHardwareMonitor benoetigt.
                    $culture = [System.Globalization.CultureInfo]::InvariantCulture
                    $number = 0.0
                    if ($values.Count -ge 4 -and
                        [double]::TryParse($values[3].Trim(), [System.Globalization.NumberStyles]::Float, $culture, [ref]$number)) {
                        $nvidiaTemperature = [math]::Round($number, 1)
                    }
                    if ($values.Count -ge 5 -and
                        [double]::TryParse($values[4].Trim(), [System.Globalization.NumberStyles]::Float, $culture, [ref]$number)) {
                        $nvidiaPower = [math]::Round($number, 1)
                    }
                }
            }

            # Fallback: Der 64-Bit-Wert in der Grafikkarten-Registry ist genauer
            # als AdapterRAM, das bei vielen Treibern auf 4 GB begrenzt ist.
            if ($vram -eq 0) {
                $registryVRAM = Get-ItemProperty `
                    -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Video\*\0000" `
                    -Name "HardwareInformation.qwMemorySize" `
                    -ErrorAction SilentlyContinue |
                    ForEach-Object { $_."HardwareInformation.qwMemorySize" } |
                    Where-Object { $_ -gt 0 } |
                    Measure-Object -Maximum

                if ($registryVRAM.Maximum) {
                    $vram = [math]::Round($registryVRAM.Maximum / 1GB, 1)
                }
            }

            if ($vram -eq 0 -and $gpu.AdapterRAM -gt 0) {
                $vram = [math]::Round($gpu.AdapterRAM / 1GB, 1)
            }

            if ($null -ne $usage) { $usageSource = "nvidia-smi" }

            # AMD / Intel (oder nvidia-smi fehlt): Windows-Leistungsindikatoren
            if ($null -eq $usage -or $null -eq $vramUsed) {
                $counters = Get-WindowsGpuCounters
                if ($counters) {
                    if ($null -eq $usage) { $usage = $counters.Usage; $usageSource = "Windows" }
                    if ($null -eq $vramUsed) { $vramUsed = $counters.VRAMUsedGB }
                }
            }

            $temperature = Get-LibreHardwareMonitorTemperature "GPU"
            if ($null -eq $temperature) {
                $temperature = $nvidiaTemperature
            }


            return [PSCustomObject]@{

                Name =
                $gpu.Name

                VRAM =
                $vram

                VRAMUsed =
                $vramUsed

                Usage =
                $usage

                UsageSource =
                $usageSource

                Driver =
                $gpu.DriverVersion

                Temperature =
                $temperature

                Power =
                $nvidiaPower

            }

        }
    }
    catch {
        $null
    }

}


# ==========================================================
# Alle GPUs
# ==========================================================

function Get-AllGPUs {


    try {


        Get-CimInstance Win32_VideoController |
        ForEach-Object {


            [PSCustomObject]@{


                Name =
                $_.Name



                VRAM =
                [math]::Round(
                    $_.AdapterRAM / 1GB,
                    1
                )


            }

        }


    }
    catch {

        @()

    }


}



# ==========================================================
# RAM
# ==========================================================

function Get-HardwareRAM {
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $memory = Get-CimInstance Win32_PhysicalMemory

        $total = ($memory | Measure-Object Capacity -Sum).Sum / 1GB
        $free = $os.FreePhysicalMemory / 1MB
        $speed = ($memory | Measure-Object -Property ConfiguredClockSpeed -Maximum).Maximum

        if (-not $speed) {
            $speed = ($memory | Measure-Object -Property Speed -Maximum).Maximum
        }

        [PSCustomObject]@{
            Total   = [math]::Round($total, 1)
            Used    = [math]::Round($total - $free, 1)
            Free    = [math]::Round($free, 1)
            Percent = [math]::Round((($total - $free) / $total) * 100, 1)
            Speed   = $speed
            Modules = @($memory).Count
        }
    }
    catch {
        $null
    }
}



# ==========================================================
# Netzwerk
# ==========================================================

function Get-HardwareNetwork {
    try {
        $interfaces = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction Stop |
            Where-Object {
                # Virtuelle Adapter zaehlen den Verkehr sonst doppelt
                $_.Name -notmatch "Loopback|Teredo|isatap|vEthernet|Hyper-V|Virtual|VMware|VirtualBox|Bluetooth|WAN Miniport"
            }

        $download = ($interfaces | Measure-Object -Property BytesReceivedPerSec -Sum).Sum / 1MB
        $upload = ($interfaces | Measure-Object -Property BytesSentPerSec -Sum).Sum / 1MB

        [PSCustomObject]@{
            Download = [math]::Round($download, 2)
            Upload   = [math]::Round($upload, 2)
        }
    }
    catch {
        try {
            # Fallback fuer Systeme, auf denen die formatierten WMI-Zaehler
            # nicht verfuegbar sind: Rate aus Adapter-Bytezaehlern berechnen.
            $statistics = Get-NetAdapterStatistics -ErrorAction Stop
            $received = ($statistics | Measure-Object -Property ReceivedBytes -Sum).Sum
            $sent = ($statistics | Measure-Object -Property SentBytes -Sum).Sum
            $now = Get-Date
            $download = 0
            $upload = 0

            if ($script:PreviousNetworkSample) {
                $seconds = ($now - $script:PreviousNetworkSample.Time).TotalSeconds
                if ($seconds -gt 0) {
                    $download = ($received - $script:PreviousNetworkSample.Received) / $seconds / 1MB
                    $upload = ($sent - $script:PreviousNetworkSample.Sent) / $seconds / 1MB
                }
            }

            $script:PreviousNetworkSample = @{
                Time = $now
                Received = $received
                Sent = $sent
            }

            [PSCustomObject]@{
                Download = [math]::Round([math]::Max(0, $download), 2)
                Upload   = [math]::Round([math]::Max(0, $upload), 2)
            }
        }
        catch {
            $null
        }
    }
}


# ==========================================================
# Alle Laufwerke
# ==========================================================

function Get-HardwareStorage {


    try {


        $drives =
        Get-CimInstance Win32_LogicalDisk |
        Where-Object {
            $_.DriveType -eq 3
        }


        # Medientyp (SSD/HDD) aendert sich nicht - nur einmal ermitteln.
        # Get-PhysicalDisk ist langsam und wurde vorher bei jedem Update aufgerufen.
        if ($null -eq $script:DriveMediaTypes) {
            $script:DriveMediaTypes = @{}

            try {
                Get-PhysicalDisk -ErrorAction Stop |
                ForEach-Object {
                    $physicalDisk = $_
                    $disk = Get-Disk -Number ([int]$physicalDisk.DeviceId) -ErrorAction Stop

                    Get-Partition -DiskNumber $disk.Number -ErrorAction Stop |
                    Where-Object { $_.DriveLetter } |
                    ForEach-Object {
                        $script:DriveMediaTypes["$($_.DriveLetter):"] = "$($physicalDisk.MediaType)"
                    }
                }
            }
            catch {
                # Die Storage-Cmdlets sind nicht auf jedem Windows-System verfuegbar.
                # Die Laufwerksdaten werden dann weiterhin ohne Medientyp angezeigt.
            }
        }

        $driveMediaTypes = $script:DriveMediaTypes



        $list =
        @()



        foreach($drive in $drives)
        {

            # Laufwerke ohne Groesse (z. B. leere Kartenleser) wuerden durch 0 teilen
            if (-not $drive.Size -or $drive.Size -le 0) { continue }


            $list +=
            [PSCustomObject]@{


                Name =
                $drive.DeviceID



                Label =
                $drive.VolumeName



                Total =
                [math]::Round(
                    $drive.Size / 1GB,
                    1
                )



                Free =
                [math]::Round(
                    $drive.FreeSpace / 1GB,
                    1
                )



                Used =
                [math]::Round(
                    ($drive.Size-$drive.FreeSpace) / 1GB,
                    1
                )



                Percent =
                [math]::Round(
                    (($drive.Size-$drive.FreeSpace) /
                    $drive.Size) * 100,
                    1
                )


                Type =
                if ($driveMediaTypes.ContainsKey($drive.DeviceID)) {
                    $driveMediaTypes[$drive.DeviceID]
                }
                else {
                    "Unbekannt"
                }


            }

        }


        return $list


    }
    catch {

        @()

    }


}
