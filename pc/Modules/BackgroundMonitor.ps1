# ==========================================================
# GamingSuite X
# Background Monitor v10.0
# ==========================================================
# Misst die Hardware in einem eigenen Hintergrund-Thread.
# Vorher lief die Messung direkt im Fenster-Timer, wodurch die
# Oberflaeche bei jedem Update fuer 1-3 Sekunden eingefroren ist.
# Die Ergebnisse landen in $global:GSXState und werden von der
# Oberflaeche (UI.ps1) und dem Handy-Server (PhoneServer.ps1) gelesen.

$global:GSXState = [hashtable]::Synchronized(@{
    Running            = $true
    Snapshot           = $null
    Updated            = [datetime]::MinValue
    Version            = 0
    PhoneJson          = '{}'
    LastError          = $null
    PhoneServerRunning = $false
    PhoneServerError   = $null
    GamesJson          = '{"games":[],"tuning":[]}'
    GameStatusJson     = 'null'
    PhoneEnabled       = $true      # Handy-/Browser-Zugriff im WLAN
    PhonePin           = ''         # optionale PIN fuer /api/*
})

$script:BackgroundJobs = New-Object System.Collections.ArrayList

function Start-HardwareMonitor {
    param([int]$IntervalSeconds = 2)

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('State', $global:GSXState)
    $runspace.SessionStateProxy.SetVariable('ModuleDir', $PSScriptRoot)
    $runspace.SessionStateProxy.SetVariable('Interval', $IntervalSeconds)

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    [void]$ps.AddScript({
        try {
            . (Join-Path $ModuleDir 'Hardware.ps1')
            . (Join-Path $ModuleDir 'HardwareManager.ps1')
            . (Join-Path $ModuleDir 'PhoneData.ps1')
        }
        catch {
            $State.LastError = "Module konnten nicht geladen werden: $($_.Exception.Message)"
            return
        }

        while ($State.Running) {
            $start = Get-Date
            try {
                $snapshot = Get-HardwareSnapshot
                $State.Snapshot = $snapshot
                $State.Updated = Get-Date
                $State.Version = $State.Version + 1
                $State.PhoneJson = ConvertTo-PhoneJson -Snapshot $snapshot
                $State.LastError = $null
            }
            catch {
                $State.LastError = $_.Exception.Message
            }

            # In kleinen Schritten warten, damit das Beenden schnell geht.
            $deadline = $start.AddSeconds($Interval)
            while ($State.Running -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 100
            }
        }
    })

    $handle = $ps.BeginInvoke()
    [void]$script:BackgroundJobs.Add(@{ PowerShell = $ps; Handle = $handle; Runspace = $runspace })
}

function Stop-GamingSuiteBackground {
    $global:GSXState.Running = $false

    foreach ($job in $script:BackgroundJobs) {
        try {
            # Bis zu 3 Sekunden auf sauberes Ende warten.
            [void]$job.Handle.AsyncWaitHandle.WaitOne(3000)
            $job.PowerShell.Stop()
            $job.PowerShell.Dispose()
            $job.Runspace.Close()
            $job.Runspace.Dispose()
        }
        catch { }
    }

    $script:BackgroundJobs.Clear()
}
