# ==========================================================
# GamingSuite X
# Hardware Manager v8.5
# ==========================================================

function Get-HardwareSnapshot {

    $cpu     = Get-HardwareCPU
    $gpu     = Get-HardwareGPU
    $ram     = Get-HardwareRAM
    $storage = Get-HardwareStorage
    $network = Get-HardwareNetwork

    $os = $null
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    }
    catch {
        # Systeminformationen sind fuer das Dashboard optional.
    }

    $system = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME

        User = $env:USERNAME

        Windows = if ($os) { $os.Caption } else { "Nicht verfuegbar" }

        Version = if ($os) { $os.Version } else { "Nicht verfuegbar" }

        Uptime = if ($os) { (Get-Date) - $os.LastBootUpTime } else { $null }

    }

    return [PSCustomObject]@{

        CPU      = $cpu

        GPU      = $gpu

        RAM      = $ram

        Storage  = $storage

        Network  = $network

        System   = $system

    }

}
