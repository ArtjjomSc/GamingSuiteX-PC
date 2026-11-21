# ==========================================================
# GamingSuite X
# Phone Server v10.0
# ==========================================================
# Stellt die Messwerte per WLAN fuer die Handy-App bereit.
#   TCP 47801  ->  http://<PC-IP>:47801/api/stats   (JSON)
#   UDP 47800  ->  Automatische Suche ("GSX_DISCOVER")
# Laeuft in einem eigenen Hintergrund-Thread.

$script:PhonePort = 47801
$script:PhoneDiscoveryPort = 47800

function Get-PhoneServerAddresses {
    $result = @()
    try {
        foreach ($nic in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($nic.OperationalStatus -ne 'Up') { continue }
            if ($nic.NetworkInterfaceType -eq 'Loopback') { continue }
            if ($nic.Description -match 'Virtual|VMware|Hyper-V|VirtualBox|vEthernet|Bluetooth|TAP') { continue }

            foreach ($addr in $nic.GetIPProperties().UnicastAddresses) {
                $ip = $addr.Address
                if ($ip.AddressFamily -ne 'InterNetwork') { continue }
                $text = $ip.ToString()
                if ($text.StartsWith('169.254.') -or $text.StartsWith('127.')) { continue }
                $result += $text
            }
        }
    }
    catch { }
    return $result
}

function Add-PhoneFirewallRules {
    # Nur mit Administrator-Rechten moeglich. Ohne Admin fragt Windows
    # beim ersten Start selbst nach ("Zugriff zulassen").
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { return }

    try {
        if (-not (Get-NetFirewallRule -DisplayName 'GamingSuite X Handy (TCP)' -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName 'GamingSuite X Handy (TCP)' -Direction Inbound -Protocol TCP `
                -LocalPort $script:PhonePort -Action Allow -Profile Private, Domain -ErrorAction Stop | Out-Null
        }
        if (-not (Get-NetFirewallRule -DisplayName 'GamingSuite X Handy (UDP)' -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName 'GamingSuite X Handy (UDP)' -Direction Inbound -Protocol UDP `
                -LocalPort $script:PhoneDiscoveryPort -Action Allow -Profile Private, Domain -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Host "  Firewall-Regel konnte nicht angelegt werden: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Start-PhoneServer {
    Add-PhoneFirewallRules

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('State', $global:GSXState)
    $runspace.SessionStateProxy.SetVariable('Port', $script:PhonePort)
    $runspace.SessionStateProxy.SetVariable('DiscoveryPort', $script:PhoneDiscoveryPort)
    $runspace.SessionStateProxy.SetVariable('WebDir', (Join-Path $PSScriptRoot 'web'))

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    [void]$ps.AddScript({
        $utf8 = New-Object System.Text.UTF8Encoding($false)

        try {
            $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
            $listener.Start()
        }
        catch {
            $State.PhoneServerError = "Port $Port ist belegt oder blockiert: $($_.Exception.Message)"
            return
        }

        $udp = $null
        try {
            $udp = New-Object System.Net.Sockets.UdpClient
            $udp.Client.SetSocketOption(
                [System.Net.Sockets.SocketOptionLevel]::Socket,
                [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
            $udp.Client.Bind((New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, $DiscoveryPort)))
        }
        catch {
            $udp = $null   # Automatische Suche nicht moeglich, manuelle IP geht trotzdem.
        }

        $info = @{ service = 'gamingsuite-x'; version = '10.0'; name = $env:COMPUTERNAME; port = $Port } |
            ConvertTo-Json -Compress
        $reply = $utf8.GetBytes($info)
        $State.PhoneServerRunning = $true

        while ($State.Running) {
            $idle = $true

            # --- Automatische Suche (UDP) ---
            if ($udp -and $udp.Available -gt 0) {
                $idle = $false
                try {
                    $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                    $bytes = $udp.Receive([ref]$remote)
                    if ($State.PhoneEnabled -and $utf8.GetString($bytes).Trim() -eq 'GSX_DISCOVER') {
                        [void]$udp.Send($reply, $reply.Length, $remote)
                    }
                }
                catch { }
            }

            # --- Daten-Anfrage (HTTP ueber TCP) ---
            if ($listener.Pending()) {
                $idle = $false
                $client = $null
                try {
                    $client = $listener.AcceptTcpClient()
                    $client.ReceiveTimeout = 2000
                    $client.SendTimeout = 2000
                    $stream = $client.GetStream()
                    $reader = New-Object System.IO.StreamReader($stream, $utf8, $false, 1024, $true)

                    $requestLine = $reader.ReadLine()
                    $pinGiven = ''
                    while ($true) {
                        $line = $reader.ReadLine()
                        if ([string]::IsNullOrEmpty($line)) { break }
                        if ($line -match '^X-GSX-Pin:\s*(\S+)') { $pinGiven = $Matches[1] }
                    }

                    $path = '/'
                    $query = ''
                    if ($requestLine -match '^\w+\s+(\S+)') {
                        $parts = $Matches[1] -split '\?', 2
                        $path = $parts[0]
                        if ($parts.Count -gt 1) { $query = $parts[1] }
                    }
                    if (-not $pinGiven -and $query -match '(^|&)pin=([0-9]+)') { $pinGiven = $Matches[2] }

                    $code = '200 OK'
                    $type = 'application/json'
                    $rawBytes = $null
                    $isApi = $path.StartsWith('/api/')
                    if (-not $State.PhoneEnabled) {
                        # Zugriff in den Einstellungen abgeschaltet
                        $code = '403 Forbidden'
                        $type = if ($isApi) { 'application/json' } else { 'text/html' }
                        $body = if ($isApi) { '{"error":"disabled"}' } else { "<h1>GamingSuite X</h1><p>Handy-/Browser-Zugriff ist am PC unter 'Settings' abgeschaltet.</p>" }
                    }
                    elseif ($isApi -and $State.PhonePin -and $pinGiven -ne [string]$State.PhonePin) {
                        $code = '401 Unauthorized'
                        $body = '{"error":"pin"}'
                    }
                    elseif ($path -eq '/api/stats') {
                        # Messwerte + laufendes Spiel / Messung
                        $stats = [string]$State.PhoneJson
                        $game = [string]$State.GameStatusJson
                        if (-not $game) { $game = 'null' }
                        if ($stats.StartsWith('{') -and $stats.Length -gt 2) {
                            $body = '{"game":' + $game + ',' + $stats.Substring(1)
                        }
                        else { $body = $stats }
                    }
                    elseif ($path -eq '/api/games') {
                        # Spiele-Messungen und Auto-Tuning-Stufen (nur lesen)
                        $body = [string]$State.GamesJson
                        if (-not $body) { $body = '{"games":[],"tuning":[]}' }
                    }
                    elseif ($path -eq '/api/info') {
                        $body = $info
                    }
                    elseif ($path -match '^/(index\.html|icon\.png|icon-512\.png|manifest\.json)?$') {
                        # Web-App fuer iPhone, Android, Tablet (im Browser oeffnen)
                        $file = if ($Matches[1]) { $Matches[1] } else { 'index.html' }
                        $full = Join-Path $WebDir $file
                        $type = switch -Regex ($file) { '\.png$' { 'image/png' } '\.json$' { 'application/manifest+json' } default { 'text/html' } }
                        if (Test-Path -LiteralPath $full) {
                            $rawBytes = [System.IO.File]::ReadAllBytes($full)
                        }
                        else {
                            $type = 'text/html'
                            $body = "<h1>GamingSuite X</h1><p>Web-App fehlt (Ordner Modules\web).</p>"
                        }
                    }
                    else {
                        $code = '404 Not Found'
                        $body = '{"error":"not found"}'
                    }

                    $bodyBytes = if ($rawBytes) { $rawBytes } else { $utf8.GetBytes([string]$body) }
                    $rawBytes = $null
                    $ctype = if ($type -eq 'image/png') { $type } else { "$type; charset=utf-8" }
                    $head = "HTTP/1.1 $code`r`n" +
                            "Content-Type: $ctype`r`n" +
                            "Content-Length: $($bodyBytes.Length)`r`n" +
                            "Access-Control-Allow-Origin: *`r`n" +
                            "Cache-Control: no-store`r`n" +
                            "Connection: close`r`n`r`n"
                    $headBytes = $utf8.GetBytes($head)
                    $stream.Write($headBytes, 0, $headBytes.Length)
                    $stream.Write($bodyBytes, 0, $bodyBytes.Length)
                    $stream.Flush()
                }
                catch { }
                finally {
                    if ($client) { $client.Close() }
                }
            }

            if ($idle) { Start-Sleep -Milliseconds 30 }
        }

        $State.PhoneServerRunning = $false
        try { $listener.Stop() } catch { }
        if ($udp) { try { $udp.Close() } catch { } }
    })

    $handle = $ps.BeginInvoke()
    [void]$script:BackgroundJobs.Add(@{ PowerShell = $ps; Handle = $handle; Runspace = $runspace })
}
