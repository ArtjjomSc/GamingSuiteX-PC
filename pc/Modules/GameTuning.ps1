# ==========================================================
# GamingSuite X
# Game Tuning v10.2 - Spiele automatisch auf Monitor-Hz optimieren
# ==========================================================
# Ablauf:
#  1. Monitor-Hz + Aufloesung erkennen -> Ziel-FPS (Hz - 3 bei G-Sync/FreeSync)
#  2. Startstufe pro Spiel aus der Hardware (GPU-Klasse, Aufloesung, Hz)
#  3. Beim Spielen FPS mit Intel PresentMon messen
#  4. Nach dem Spiel Stufe automatisch anpassen (zu wenig FPS -> runter,
#     Reserve vorhanden -> rauf) und Einstellungsdatei des Spiels schreiben
# Originaldateien werden vor der ersten Aenderung gesichert.

$script:GameDataDir   = Join-Path (Get-ConfigPath) "games"
$script:GameStateFile = Join-Path $script:GameDataDir "games.json"
$script:ToolsDir      = Join-Path (Get-ConfigPath) "tools"
$script:PresentMonExe = Join-Path $script:ToolsDir "PresentMon.exe"

$script:LevelNames = @{ 1 = 'Leistung'; 2 = 'Ausgewogen-'; 3 = 'Ausgewogen'; 4 = 'Hoch'; 5 = 'Ultra' }

foreach ($dir in @($script:GameDataDir, $script:ToolsDir)) {
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

# ----------------------------------------------------------
# Spiele-Profile (Werte je Stufe 1-5)
# ----------------------------------------------------------

$script:GameProfiles = [ordered]@{

    cs2 = @{
        Name = 'Counter-Strike 2'
        Process = 'cs2'
        Weight = 'light'     # CPU-lastig, auch hohe Details kosten wenig
        # cs2_video.txt
        Levels = @{
            1 = @{ 'videocfg_shadow_quality' = 2; 'videocfg_dynamic_shadows' = 1; 'videocfg_texture_detail' = 1; 'shaderquality' = 0; 'videocfg_particle_detail' = 0; 'videocfg_ao_detail' = 0; 'msaa_samples' = 0; 'r_csgo_cmaa_enable' = 1; 'r_texturefilteringquality' = 4 }
            2 = @{ 'videocfg_shadow_quality' = 2; 'videocfg_dynamic_shadows' = 1; 'videocfg_texture_detail' = 2; 'shaderquality' = 0; 'videocfg_particle_detail' = 1; 'videocfg_ao_detail' = 1; 'msaa_samples' = 2; 'r_csgo_cmaa_enable' = 0; 'r_texturefilteringquality' = 5 }
            3 = @{ 'videocfg_shadow_quality' = 2; 'videocfg_dynamic_shadows' = 1; 'videocfg_texture_detail' = 2; 'shaderquality' = 1; 'videocfg_particle_detail' = 1; 'videocfg_ao_detail' = 1; 'msaa_samples' = 4; 'r_csgo_cmaa_enable' = 0; 'r_texturefilteringquality' = 5 }
            4 = @{ 'videocfg_shadow_quality' = 3; 'videocfg_dynamic_shadows' = 1; 'videocfg_texture_detail' = 2; 'shaderquality' = 1; 'videocfg_particle_detail' = 2; 'videocfg_ao_detail' = 2; 'msaa_samples' = 4; 'r_csgo_cmaa_enable' = 0; 'r_texturefilteringquality' = 5 }
            5 = @{ 'videocfg_shadow_quality' = 3; 'videocfg_dynamic_shadows' = 1; 'videocfg_texture_detail' = 2; 'shaderquality' = 1; 'videocfg_particle_detail' = 3; 'videocfg_ao_detail' = 2; 'msaa_samples' = 8; 'r_csgo_cmaa_enable' = 0; 'r_texturefilteringquality' = 5 }
        }
        Always = @{ 'r_low_latency' = 1; 'videocfg_fsr_detail' = 0 }
    }

    bf6 = @{
        Name = 'Battlefield 6'
        Process = 'bf6'
        Weight = 'heavy'
        # PROFSAVE_profile (GstRender.*), Qualitaetsstufen 0=Niedrig .. 3=Ultra
        Levels = @{
            1 = @{ TextureQuality = 2; MeshQuality = 1; TerrainQuality = 1; UndergrowthQuality = 1; LightingQuality = 1; EffectsQuality = 1; VolumetricQuality = 0; PostProcessQuality = 0; ShadowQuality = 1; SunShadowQuality = 1; LocalLightShadowQuality = 0; ReflectionQuality = 1; ScreenSpaceReflections = 0; AmbientOcclusion = 0; TransparentShadows = 0 }
            2 = @{ TextureQuality = 3; MeshQuality = 2; TerrainQuality = 2; UndergrowthQuality = 1; LightingQuality = 1; EffectsQuality = 1; VolumetricQuality = 0; PostProcessQuality = 1; ShadowQuality = 1; SunShadowQuality = 2; LocalLightShadowQuality = 1; ReflectionQuality = 1; ScreenSpaceReflections = 0; AmbientOcclusion = 1; TransparentShadows = 0 }
            3 = @{ TextureQuality = 3; MeshQuality = 2; TerrainQuality = 2; UndergrowthQuality = 2; LightingQuality = 2; EffectsQuality = 2; VolumetricQuality = 1; PostProcessQuality = 1; ShadowQuality = 2; SunShadowQuality = 2; LocalLightShadowQuality = 1; ReflectionQuality = 2; ScreenSpaceReflections = 1; AmbientOcclusion = 1; TransparentShadows = 0 }
            4 = @{ TextureQuality = 3; MeshQuality = 3; TerrainQuality = 3; UndergrowthQuality = 2; LightingQuality = 3; EffectsQuality = 2; VolumetricQuality = 2; PostProcessQuality = 2; ShadowQuality = 2; SunShadowQuality = 3; LocalLightShadowQuality = 2; ReflectionQuality = 2; ScreenSpaceReflections = 1; AmbientOcclusion = 1; TransparentShadows = 1 }
            5 = @{ TextureQuality = 3; MeshQuality = 3; TerrainQuality = 3; UndergrowthQuality = 3; LightingQuality = 3; EffectsQuality = 3; VolumetricQuality = 3; PostProcessQuality = 3; ShadowQuality = 3; SunShadowQuality = 3; LocalLightShadowQuality = 3; ReflectionQuality = 3; ScreenSpaceReflections = 1; AmbientOcclusion = 1; TransparentShadows = 1 }
        }
        # Effekte ohne Nutzen, die nur Sicht und FPS kosten
        Always = @{ MotionBlurWorld = '0.000000'; MotionBlurWeapon = '0.000000'; ChromaticAberration = 0; FilmGrain = 0; Vignette = 0; LensDistortion = 0; WeaponDOF = 0; VSyncMode = 0; NvidiaLowLatency = 1 }
    }
}

# ----------------------------------------------------------
# Monitor
# ----------------------------------------------------------

function Initialize-GSXDisplayNative {
    if ('GSXDisplayQuery' -as [type]) { return }
    # Komplett in C#, weil PowerShell Strukturen per [ref] nicht zuverlaessig uebergibt.
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class GSXDisplayQuery {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion; public short dmDriverVersion; public short dmSize;
        public short dmDriverExtra; public int dmFields; public int dmPositionX; public int dmPositionY;
        public int dmDisplayOrientation; public int dmDisplayFixedOutput; public short dmColor;
        public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight;
        public int dmDisplayFlags; public int dmDisplayFrequency; public int dmICMMethod; public int dmICMIntent;
        public int dmMediaType; public int dmDitherType; public int dmReserved1; public int dmReserved2;
        public int dmPanningWidth; public int dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    // Liefert { Breite, Hoehe, aktuelle Hz, maximale Hz bei dieser Aufloesung } des Hauptmonitors
    public static int[] Query() {
        DEVMODE dm = new DEVMODE();
        dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
        if (!EnumDisplaySettings(null, -1, ref dm)) return null;
        int w = dm.dmPelsWidth, h = dm.dmPelsHeight, cur = dm.dmDisplayFrequency, max = cur;

        DEVMODE m = new DEVMODE();
        m.dmSize = dm.dmSize;
        for (int i = 0; i < 5000 && EnumDisplaySettings(null, i, ref m); i++) {
            if (m.dmPelsWidth == w && m.dmPelsHeight == h && m.dmDisplayFrequency > max) max = m.dmDisplayFrequency;
        }
        return new int[] { w, h, cur, max };
    }
}
"@
}

function Get-GSXMonitorInfo {
    try {
        Initialize-GSXDisplayNative
        $r = [GSXDisplayQuery]::Query()
        if ($r -and $r[0] -gt 0 -and $r[2] -gt 1) {
            return [PSCustomObject]@{ Width = $r[0]; Height = $r[1]; Hz = $r[2]; MaxHz = [math]::Max($r[2], $r[3]) }
        }
    }
    catch { }

    # Ersatzweg ueber WMI
    $vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.CurrentRefreshRate -gt 1 } | Select-Object -First 1
    if ($vc) {
        $max = [math]::Max([int]$vc.CurrentRefreshRate, [int]$vc.MaxRefreshRate)
        if ($max -gt 500) { $max = [int]$vc.CurrentRefreshRate }   # manche Treiber melden Unsinn
        return [PSCustomObject]@{ Width = [int]$vc.CurrentHorizontalResolution; Height = [int]$vc.CurrentVerticalResolution; Hz = [int]$vc.CurrentRefreshRate; MaxHz = $max }
    }
    return $null
}

# ----------------------------------------------------------
# Zustand (Stufe, Messungen) speichern
# ----------------------------------------------------------

function Get-GSXGameState {
    $state = @{ Settings = @{ CapToHz = $true; AutoTune = $true }; Games = @{}; Measured = @{} }
    if (Test-Path -LiteralPath $script:GameStateFile) {
        try {
            $data = Get-Content -LiteralPath $script:GameStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($data.Settings) {
                $state.Settings.CapToHz = [bool]$data.Settings.CapToHz
                $state.Settings.AutoTune = [bool]$data.Settings.AutoTune
            }
            $games = @()
            if ($data.Games) { $games = @($data.Games.PSObject.Properties) }
            if ($data.Measured) {
                foreach ($mp in @($data.Measured.PSObject.Properties)) {
                    $h = @{}
                    foreach ($q in $mp.Value.PSObject.Properties) { $h[$q.Name] = $q.Value }
                    $state.Measured[$mp.Name] = $h
                }
            }
            foreach ($p in $games) {
                $g = $p.Value
                $state.Games[$p.Name] = @{
                    Level = [int]$g.Level
                    LastAvg = $g.LastAvg; LastLow = $g.LastLow; LastGpu = $g.LastGpu
                    LastMeasured = $g.LastMeasured; LastAction = $g.LastAction
                    PendingLevel = $g.PendingLevel
                }
            }
        }
        catch { }
    }
    return $state
}

function Save-GSXGameState {
    param($State)
    $State | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:GameStateFile -Encoding UTF8
}

# ----------------------------------------------------------
# Ziel-FPS und Startstufe aus der Hardware
# ----------------------------------------------------------

function Get-GSXTargetFps {
    param($Monitor, [bool]$CapToHz)
    if (-not $Monitor -or $Monitor.MaxHz -lt 30) { return 60 }
    # Gleiche Formel wie NVIDIA Reflex / Low Latency Ultra mit G-Sync:
    # Hz - Hz^2/3600  (165 Hz -> 157 FPS, 144 -> 138, 240 -> 224)
    if ($CapToHz) { return [math]::Max(30, [int][math]::Floor($Monitor.MaxHz - ($Monitor.MaxHz * $Monitor.MaxHz / 3600))) }
    return $Monitor.MaxHz
}

function Get-GSXGpuScore {
    $name = ''
    try {
        $vc = Get-CimInstance Win32_VideoController -ErrorAction Stop |
            Where-Object { $_.Name -match 'NVIDIA|AMD|Radeon|Arc' } | Select-Object -First 1
        $name = "$($vc.Name)"
    }
    catch { }

    $score = 1
    if     ($name -match 'RTX 50(90|80)|RTX 40(90|80)') { $score = 5 }
    elseif ($name -match 'RTX 5070|RTX 4070 Ti|RTX 3090|RTX 3080|RX 7900|RX 9070') { $score = 4 }
    elseif ($name -match 'RTX 4070|RTX 3070|RTX 5060 Ti|RX 7800|RX 6800|RX 6900') { $score = 3 }
    elseif ($name -match 'RTX 4060|RTX 3060|RTX 5060|RX 7600|RX 6700|RTX 20') { $score = 2 }

    return [PSCustomObject]@{ Name = $name; Score = $score }
}

function Get-GSXRecommendedLevel {
    param([string]$GameId, $Monitor)
    $gp = $script:GameProfiles[$GameId]
    $gpu = Get-GSXGpuScore
    $level = $gpu.Score
    if ($gp.Weight -eq 'heavy') { $level -= 1 } else { $level += 1 }

    if ($Monitor) {
        $pixels = $Monitor.Width * $Monitor.Height
        if ($pixels -ge 3840 * 2160 * 0.9) { $level -= 1 }
        elseif ($pixels -le 1920 * 1080) { $level += 1 }
        if ($Monitor.MaxHz -ge 200 -and $gp.Weight -eq 'heavy') { $level -= 1 }
        if ($Monitor.MaxHz -ge 300) { $level -= 1 }
    }
    return [math]::Max(1, [math]::Min(5, $level))
}

# ----------------------------------------------------------
# Einstellungsdateien finden
# ----------------------------------------------------------

function Get-GSXSteamPath {
    try { return (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath -replace '/', '\' }
    catch { return (Join-Path ${env:ProgramFiles(x86)} 'Steam') }
}

function Get-GSXGameConfigFiles {
    param([string]$GameId)

    if ($GameId -eq 'cs2') {
        $userdata = Join-Path (Get-GSXSteamPath) 'userdata'
        if (-not (Test-Path -LiteralPath $userdata)) { return @() }
        # Aktives Konto = zuletzt geaenderte cs2_video.txt
        $video = Get-ChildItem -LiteralPath $userdata -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName '730\local\cfg\cs2_video.txt' } |
            Where-Object { Test-Path -LiteralPath $_ } |
            ForEach-Object { Get-Item -LiteralPath $_ } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $video) { return @() }
        return @($video.FullName)
    }

    if ($GameId -eq 'bf6') {
        $docs = [Environment]::GetFolderPath('MyDocuments')
        $settings = Join-Path $docs 'Battlefield 6\settings'
        if (-not (Test-Path -LiteralPath $settings)) { return @() }
        return @(Get-ChildItem -LiteralPath $settings -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'PROFSAVE*profile' } |
            Where-Object { (Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue) -match 'GstRender\.' } |
            ForEach-Object { $_.FullName })
    }
    return @()
}

function Test-GSXGameRunning {
    param([string]$GameId)
    $p = $script:GameProfiles[$GameId].Process
    return [bool](Get-Process -Name $p -ErrorAction SilentlyContinue)
}

function Backup-GSXGameFile {
    param([string]$GameId, [string]$Path)
    $dir = Join-Path $script:GameDataDir "backup_$GameId"
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $name = ($Path -replace '[:\\/ ]', '_')
    $orig = Join-Path $dir "$name.original"
    if (-not (Test-Path -LiteralPath $orig)) {
        Copy-Item -LiteralPath $Path -Destination $orig -Force
    }
    Copy-Item -LiteralPath $Path -Destination (Join-Path $dir "$name.last") -Force
}

function Restore-GSXGameFiles {
    param([string]$GameId)
    if (Test-GSXGameRunning $GameId) { throw "Bitte das Spiel zuerst beenden." }
    $dir = Join-Path $script:GameDataDir "backup_$GameId"
    $count = 0
    $paths = @(Get-GSXGameConfigFiles $GameId)
    if ($GameId -eq 'cs2') { $paths += @(Get-GSXCs2ConvarFile) }
    foreach ($path in $paths) {
        if (-not $path) { continue }
        $name = ($path -replace '[:\\/ ]', '_')
        $orig = Join-Path $dir "$name.original"
        if (Test-Path -LiteralPath $orig) {
            Copy-Item -LiteralPath $orig -Destination $path -Force
            $count++
        }
    }
    return $count
}

# ----------------------------------------------------------
# Schreiben der Einstellungen
# ----------------------------------------------------------

function Write-GSXTextFile {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-GSXCs2ConvarFile {
    $video = @(Get-GSXGameConfigFiles 'cs2') | Select-Object -First 1
    if (-not $video) { return $null }
    $f = Join-Path (Split-Path $video -Parent) 'cs2_machine_convars.vcfg'
    if (Test-Path -LiteralPath $f) { return $f }
    return $null
}

function Set-GSXValveKey {
    param([string]$Text, [string]$Key, [string]$Value)
    $pattern = '("' + [regex]::Escape($Key) + '"\s+)"[^"]*"'
    if ([regex]::IsMatch($Text, $pattern)) {
        return [regex]::Replace($Text, $pattern, { param($m) $m.Groups[1].Value + '"' + $Value + '"' })
    }
    # Fehlt der Schluessel: vor der letzten schliessenden Klammer einfuegen
    $idx = $Text.LastIndexOf('}')
    if ($idx -lt 0) { return $Text }
    return $Text.Insert($idx, "`t`"$Key`"`t`t`"$Value`"`r`n")
}

function Set-GSXFrostbiteKey {
    param([string]$Text, [string]$Key, [string]$Value)
    $pattern = '(?m)^(GstRender\.' + [regex]::Escape($Key) + ')[ \t]+[^\r\n]*$'
    if ([regex]::IsMatch($Text, $pattern)) {
        return [regex]::Replace($Text, $pattern, { param($m) $m.Groups[1].Value + ' ' + $Value })
    }
    if (-not $Text.EndsWith("`n")) { $Text += "`r`n" }
    return $Text + "GstRender.$Key $Value`r`n"
}

function Set-GSXGameLevel {
    param([string]$GameId, [int]$Level, [int]$TargetFps, $Monitor, [bool]$CapToHz)

    if (Test-GSXGameRunning $GameId) { throw "Das Spiel laeuft noch - Einstellungen werden beim Beenden uebernommen." }
    $gp = $script:GameProfiles[$GameId]
    $files = @(Get-GSXGameConfigFiles $GameId)
    if ($files.Count -eq 0) { throw "Einstellungsdatei nicht gefunden. Spiel einmal starten und Grafikoptionen speichern." }

    $values = @{}
    foreach ($k in $gp.Levels[$Level].Keys) { $values[$k] = $gp.Levels[$Level][$k] }
    foreach ($k in $gp.Always.Keys) { $values[$k] = $gp.Always[$k] }
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    foreach ($file in $files) {
        Backup-GSXGameFile -GameId $GameId -Path $file
        $text = [System.IO.File]::ReadAllText($file)

        if ($GameId -eq 'cs2') {
            foreach ($k in $values.Keys) { $text = Set-GSXValveKey $text "setting.$k" "$($values[$k])" }
            # Bildwiederholrate im Spiel auf das Maximum des Monitors setzen
            if ($Monitor) {
                $num = [regex]::Match($text, '"setting\.refreshrate_numerator"\s+"(\d+)"')
                $den = [regex]::Match($text, '"setting\.refreshrate_denominator"\s+"(\d+)"')
                if ($num.Success -and $den.Success -and [int]$den.Groups[1].Value -gt 0) {
                    $hz = [int]$num.Groups[1].Value / [int]$den.Groups[1].Value
                    if ($hz -lt $Monitor.MaxHz - 2) {
                        $text = Set-GSXValveKey $text 'setting.refreshrate_numerator' "$($Monitor.MaxHz)"
                        $text = Set-GSXValveKey $text 'setting.refreshrate_denominator' '1'
                    }
                }
            }
        }
        else {
            foreach ($k in $values.Keys) { $text = Set-GSXFrostbiteKey $text $k "$($values[$k])" }
            if ($CapToHz) {
                $text = Set-GSXFrostbiteKey $text 'FrameRateLimiterEnable' '1'
                $text = Set-GSXFrostbiteKey $text 'FrameRateLimit' ([double]$TargetFps).ToString('F6', $culture)
            }
            else {
                $text = Set-GSXFrostbiteKey $text 'FrameRateLimiterEnable' '0'
            }
        }
        Write-GSXTextFile -Path $file -Text $text
    }

    # CS2: FPS-Limit in cs2_machine_convars.vcfg
    if ($GameId -eq 'cs2') {
        $convars = Get-GSXCs2ConvarFile
        if ($convars) {
            Backup-GSXGameFile -GameId $GameId -Path $convars
            $text = [System.IO.File]::ReadAllText($convars)
            $fps = if ($CapToHz) { "$TargetFps" } else { '0' }
            if ($text -match '"fps_max"\s+"') {
                $text = Set-GSXValveKey $text 'fps_max' $fps
            }
            elseif ($text -match '"convars"\s*\{') {
                $text = [regex]::Replace($text, '("convars"\s*\{)', { param($m) $m.Groups[1].Value + "`r`n`t`t`"fps_max`"`t`t`"$fps`"" })
            }
            Write-GSXTextFile -Path $convars -Text $text
        }
    }

    return $files.Count
}

# ----------------------------------------------------------
# FPS-Messung mit Intel PresentMon
# ----------------------------------------------------------

function Install-GSXPresentMon {
    if (Test-Path -LiteralPath $script:PresentMonExe) { return $true }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ 'User-Agent' = 'GamingSuiteX' }
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/GameTechDev/PresentMon/releases/latest' -Headers $headers -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -match '^PresentMon-[\d\.]+-x64\.exe$' } | Select-Object -First 1
        if (-not $asset) { throw "Kein passender Download gefunden." }
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $script:PresentMonExe -Headers $headers -UseBasicParsing
        return (Test-Path -LiteralPath $script:PresentMonExe)
    }
    catch {
        Write-Warning "PresentMon konnte nicht geladen werden: $_"
        return $false
    }
}

function Start-GSXFpsCapture {
    param([string]$Key, [string]$Exe, [string]$Name, [string]$ProfileId, [string]$Path, [int]$Seconds = 120, [switch]$NoFrameType)
    if (-not (Install-GSXPresentMon)) { throw "Intel PresentMon fehlt (Download fehlgeschlagen)." }
    $safe = ($Key -replace '[^a-zA-Z0-9_\-]', '_')
    $csv = Join-Path $script:GameDataDir "capture_$safe.csv"
    Remove-Item -LiteralPath $csv -Force -ErrorAction SilentlyContinue
    $pmArgs = "--process_name `"$Exe`" --output_file `"$csv`" --timed $Seconds --terminate_after_timed " +
              "--stop_existing_session --session_name GamingSuiteX --no_console_stats"
    if (-not $NoFrameType) { $pmArgs += " --track_frame_type" }
    # Ausgabe von PresentMon mitschreiben, damit Fehler sichtbar werden
    $outLog = "$csv.out.txt"; $errLog = "$csv.err.txt"
    Remove-Item -LiteralPath $outLog, $errLog -Force -ErrorAction SilentlyContinue
    $proc = Start-Process -FilePath $script:PresentMonExe -ArgumentList $pmArgs -NoNewWindow -PassThru `
        -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    return [PSCustomObject]@{
        Key = $Key; Exe = $Exe; Name = $Name; ProfileId = $ProfileId; Path = $Path
        OutLog = $outLog; ErrLog = $errLog; FrameType = (-not $NoFrameType); Seconds = $Seconds
        Process = $proc; Csv = $csv; Started = Get-Date
        Samples = (New-Object System.Collections.ArrayList)
    }
}

function Get-GSXCaptureOutput {
    param($Capture)
    $lines = @()
    foreach ($f in @($Capture.ErrLog, $Capture.OutLog)) {
        if ($f -and (Test-Path -LiteralPath $f)) {
            $lines += @(Get-Content -LiteralPath $f -ErrorAction SilentlyContinue | Where-Object { "$_".Trim() })
        }
    }
    return @($lines | Select-Object -Last 6)
}

function Get-GSXPercentile {
    param([double[]]$Sorted, [double]$P)
    $idx = [int][math]::Ceiling($Sorted.Length * $P) - 1
    $idx = [math]::Max(0, [math]::Min($Sorted.Length - 1, $idx))
    return $Sorted[$idx]
}

# Vordergrundfenster -> Prozess-ID (fuer "Spiel hat den Fokus?")
function Get-GSXForegroundProcessName {
    try {
        if (-not ('GSXForeground' -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class GSXForeground {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    public static uint Pid() { uint pid; GetWindowThreadProcessId(GetForegroundWindow(), out pid); return pid; }
}
"@
        }
        $fgPid = [GSXForeground]::Pid()
        if ($fgPid -eq 0) { return $null }
        return (Get-Process -Id $fgPid -ErrorAction Stop).ProcessName
    }
    catch { return $null }
}

function Get-GSXCaptureResult {
    param($Capture, [int]$TargetFps = 60)
    if (-not (Test-Path -LiteralPath $Capture.Csv)) { return $null }
    $rows = @(Import-Csv -LiteralPath $Capture.Csv)
    if ($rows.Count -eq 0) { return $null }

    $props = $rows[0].PSObject.Properties
    $col = $null
    foreach ($c in @('MsBetweenPresents', 'msBetweenPresents', 'MsBetweenDisplayChange', 'FrameTime', 'MsBetweenAppStart')) {
        if ($props[$c]) { $col = $c; break }
    }
    if (-not $col) { return $null }
    $timeCol = $null
    foreach ($c in @('CPUStartTime', 'TimeInSeconds', 'TimeInMs', 'CPUStartQPCTime')) { if ($props[$c]) { $timeCol = $c; break } }
    if (-not $timeCol) {
        $guess = $props | Where-Object { $_.Name -match 'Time' -and $_.Name -notmatch '^Ms' } | Select-Object -First 1
        if ($guess) { $timeCol = $guess.Name }
    }
    $timeScale = if ($timeCol -eq 'TimeInSeconds') { 1.0 } else { 0.001 }   # Zeitwerte in ms seit Messbeginn
    $hasType = [bool]$props['FrameType']
    $appCol = if ($props['MsBetweenAppStart']) { 'MsBetweenAppStart' } else { $null }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.NumberStyles]::Float

    # --- Frames einlesen
    $frames = New-Object System.Collections.Generic.List[object]
    $typeSeen = $false
    foreach ($r in $rows) {
        $v = 0.0
        if (-not ([double]::TryParse($r.$col, $styles, $culture, [ref]$v) -and $v -gt 0 -and $v -lt 1000)) { continue }
        $t = 0.0
        if ($timeCol) { [void][double]::TryParse($r.$timeCol, $styles, $culture, [ref]$t) }
        $isApp = $true
        if ($hasType) {
            $ft = "$($r.FrameType)"
            if ($ft -and $ft -notmatch '^(NA|)$') { $typeSeen = $true }
            if ($ft -and $ft -notmatch '^(Application|NotSet|NA|)$') { $isApp = $false }
        }
        $a = 0.0
        $appMs = $null
        if ($isApp -and $appCol -and [double]::TryParse($r.$appCol, $styles, $culture, [ref]$a) -and $a -gt 0 -and $a -lt 1000) { $appMs = $a }
        $frames.Add([PSCustomObject]@{ T = $t * $timeScale; Ms = $v; App = $isApp; AppMs = $appMs })
    }
    if ($frames.Count -lt 300) { return $null }

    # Zeitspalte unbrauchbar (alles 0 oder Sekunden statt ms)? -> ohne Abschnitte auswerten
    $tMax = ($frames | Measure-Object T -Maximum).Maximum
    if ($timeCol -and $tMax -gt 0 -and $tMax -lt 5 -and $timeScale -lt 1) {
        foreach ($f in $frames) { $f.T = $f.T * 1000 }   # Spalte war bereits in Sekunden
        $tMax = $tMax * 1000
    }
    if (-not $tMax -or $tMax -le 0) { $timeCol = $null }

    # --- In 5-s-Abschnitte einteilen und Abschnitte bewerten
    $samples = @($Capture.Samples | Sort-Object T)
    $buckets = @{}
    $si = 0
    foreach ($f in ($frames | Sort-Object T)) {
        $idx = -1
        if ($timeCol -and $samples.Count -gt 0) {
            # Frames sind zeitlich sortiert -> Zeiger nur vorwaerts bewegen (schnell)
            while ($si -lt $samples.Count - 1 -and $samples[$si].T -lt $f.T) { $si++ }
            $idx = $si
        }
        if (-not $buckets.ContainsKey($idx)) { $buckets[$idx] = New-Object System.Collections.Generic.List[object] }
        $buckets[$idx].Add($f)
    }

    $active = New-Object System.Collections.Generic.List[object]
    $activeSamples = New-Object System.Collections.Generic.List[object]
    $bgSec = 0.0; $limSec = 0.0; $limFps = New-Object System.Collections.Generic.List[double]
    foreach ($key in $buckets.Keys) {
        $list = $buckets[$key]
        $sec = ($list | Measure-Object Ms -Sum).Sum / 1000
        $fps = $list.Count / [math]::Max(0.001, $sec)
        $smp = if ($key -ge 0) { $samples[$key] } else { $null }

        if ($smp -and $smp.Focus -eq $false) { $bgSec += $sec; continue }
        # Menue / Ladebildschirm / Zwischensequenz / externer Limiter:
        # GPU und staerkster Kern haben Luft, FPS aber deutlich unter dem Ziel
        if ($smp -and $null -ne $smp.Gpu -and $smp.Gpu -lt 50 -and ($null -eq $smp.Core -or $smp.Core -lt 85) -and $fps -lt $TargetFps * 0.9) {
            $limSec += $sec; $limFps.Add($fps); continue
        }
        foreach ($f in $list) { $active.Add($f) }
        if ($smp) { $activeSamples.Add($smp) }
    }
    $activeSec = ($active | Measure-Object Ms -Sum).Sum / 1000
    if ($activeSamples.Count -eq 0) {
        foreach ($smp in @($samples | Where-Object { $_.Focus -ne $false })) { $activeSamples.Add($smp) }
        if ($activeSamples.Count -eq 0) { foreach ($smp in $samples) { $activeSamples.Add($smp) } }
    }

    function Avg($list, $prop) {
        $vals = @($list | ForEach-Object { $_.$prop } | Where-Object { $null -ne $_ })
        if ($vals.Count -gt 0) { [math]::Round(($vals | Measure-Object -Average).Average) } else { $null }
    }

    $common = @{
        ActiveSec = [math]::Round($activeSec); BackgroundSec = [math]::Round($bgSec); LimitedSec = [math]::Round($limSec)
        FgDetectable = $typeSeen
        TimeColumn = $(if ($timeCol) { $timeCol } else { 'keine' })
    }

    if ($activeSec -lt 30 -or $active.Count -lt 300) {
        $limAvg = if ($limFps.Count -gt 0) { [math]::Round(($limFps | Measure-Object -Average).Average) } else { $null }
        $cap = $null
        if ($limAvg) { foreach ($c in @(30, 60, 90, 120, 144, $TargetFps)) { if ([math]::Abs($limAvg - $c) -le $c * 0.04) { $cap = $c; break } } }
        $reason = if ($bgSec -ge $limSec) { "Spiel war ueberwiegend im Hintergrund (Alt+Tab, $([math]::Round($bgSec)) s)" }
                  else { "FPS-Begrenzung aktiv (Menue, Karte, Zwischensequenz, Ladebildschirm oder Limiter)" + $(if ($cap) { " - fest bei ca. $cap FPS" } else { "" }) }
        return [PSCustomObject](@{ Valid = $false; Reason = $reason; LimitAvg = $limAvg } + $common)
    }

    # --- Kennzahlen nur aus echtem Spielgeschehen
    $times = [double[]]@($active | ForEach-Object { $_.Ms })
    $sorted = $times.Clone(); [Array]::Sort($sorted)
    $avgMs = ($times | Measure-Object -Average).Average
    $median = Get-GSXPercentile $sorted 0.5
    $p99  = Get-GSXPercentile $sorted 0.99
    $p999 = Get-GSXPercentile $sorted 0.999
    $stutter = @($times | Where-Object { $_ -gt 2 * $median }).Count
    # Haenger = Bild > 50 ms UND > 2,5x Median -> spuerbar, unabhaengig von der FPS-Hoehe
    $hitches = @($times | Where-Object { $_ -gt 50 -and $_ -gt 2.5 * $median }).Count
    $minutes = [math]::Max(0.5, $activeSec / 60)
    $avgFps = [math]::Round(1000 / $avgMs)
    $lowFps = [math]::Round(1000 / $p99)

    $generated = @($active | Where-Object { -not $_.App }).Count
    $fgActive = ($generated -gt $active.Count * 0.2)
    $baseAvg = $null; $baseLow = $null
    if ($fgActive) {
        $appTimes = [double[]]@($active | Where-Object { $_.App -and $_.AppMs } | ForEach-Object { $_.AppMs })
        if ($appTimes.Length -ge 100) {
            $as = $appTimes.Clone(); [Array]::Sort($as)
            $baseAvg = [math]::Round(1000 / ($appTimes | Measure-Object -Average).Average)
            $baseLow = [math]::Round(1000 / (Get-GSXPercentile $as 0.99))
        }
        else {
            $share = ($active.Count - $generated) / [math]::Max(1, $active.Count)
            $baseAvg = [math]::Round($avgFps * $share)
            $baseLow = [math]::Round($lowFps * $share)
        }
    }

    return [PSCustomObject](@{
        Valid      = $true
        FgActive   = $fgActive
        BaseAvg    = $baseAvg
        BaseLow    = $baseLow
        AvgFps     = $avgFps
        LowFps     = $lowFps
        Low01Fps   = [math]::Round(1000 / $p999)
        LowRatio   = [math]::Round($lowFps / [math]::Max(1, $avgFps) * 100)
        StutterPct = [math]::Round($stutter / $times.Length * 100, 2)
        Hitches    = $hitches
        HitchesPerMin = [math]::Round($hitches / $minutes, 1)
        GpuAvg     = Avg $activeSamples 'Gpu'
        CpuAvg     = Avg $activeSamples 'Cpu'
        VramPct    = Avg $activeSamples 'Vram'
        CoreMax    = Avg $activeSamples 'Core'
        Frames     = $times.Length
    } + $common)
}

# ----------------------------------------------------------
# Frame Generation: Status ermitteln
# ----------------------------------------------------------
# 1. Spieleigene Einstellungsdatei (sicher an/aus, wo bekannt)
# 2. Mod-Hinweis: version.dll + dlssg_*.ini = DLSS-FG-Mod (z. B. RTX 30)
# 3. Spieleigene FG-DLLs = FG wird UNTERSTUETZT (sagt nichts ueber an/aus)
# Zusaetzlich: PresentMon-Spalte FrameType (in Get-GSXCaptureResult)

$script:FgConfigReaders = @(
    @{
        Match = 'stalker2'
        File  = Join-Path $env:LOCALAPPDATA 'Stalker2\Saved\Config\Windows\GSCReXFrameGeneration.ini'
        Name  = 'GSCReXFrameGeneration.ini'
    }
)

function Get-GSXGameRoot {
    param([string]$ExePath)
    $dir = Split-Path $ExePath -Parent
    for ($i = 0; $i -lt 4; $i++) {
        $parent = Split-Path $dir -Parent
        if (-not $parent -or (Split-Path $parent -Leaf) -match '^(common|Epic Games|EA Games|games|XboxGames)$') { break }
        $dir = $parent
    }
    return $dir
}

function Get-GSXFgStatus {
    param([string]$ExePath, [string]$Key)
    $status = [PSCustomObject]@{ State = 'unknown'; Multiplier = 2; Source = ''; Mod = $false; Supported = $false }

    # 1) Bekannte Einstellungsdateien
    foreach ($reader in $script:FgConfigReaders) {
        if ("$Key" -notmatch $reader.Match) { continue }
        if (-not (Test-Path -LiteralPath $reader.File)) { continue }
        $text = Get-Content -LiteralPath $reader.File -Raw -ErrorAction SilentlyContinue
        $m = [regex]::Match("$text", '(?im)^\s*Mode\s*=\s*([^\r\n;]+)')
        if ($m.Success) {
            $value = $m.Groups[1].Value.Trim()
            $status.Source = "$($reader.Name): Mode=$value"
            if ($value -match '^(Off|0|False|Disabled)$') { $status.State = 'off' }
            elseif ($value -match '(\d)\s*x') { $status.State = 'on'; $status.Multiplier = [int]$Matches[1] }
            elseif ($value -match '^On') { $status.State = 'on' }
        }
    }

    if (-not $ExePath -or -not (Test-Path -LiteralPath $ExePath)) { return $status }

    # 2) DLSS-FG-Mod (version.dll + dlssg_*.ini neben der EXE)
    $exeDir = Split-Path $ExePath -Parent
    if ((Test-Path -LiteralPath (Join-Path $exeDir 'version.dll')) -and
        @(Get-ChildItem -LiteralPath $exeDir -Filter 'dlssg_*.ini' -File -ErrorAction SilentlyContinue).Count -gt 0) {
        $status.Mod = $true
    }

    # 3) Spieleigene FG-Bibliotheken = FG wird unterstuetzt
    $pattern = '^(nvngx_dlssg\.dll|sl\.dlss_g\.dll|amd_fidelityfx_.*\.dll|ffx_frameinterpolation.*\.dll|ffx_fsr3.*\.dll|libxess_fg\.dll)$'
    $found = @(Get-ChildItem -LiteralPath (Get-GSXGameRoot $ExePath) -Recurse -Depth 5 -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pattern } | Select-Object -First 1)
    $status.Supported = ($found.Count -gt 0 -or $status.Mod)
    return $status
}

function Get-GSXFgText {
    param($Fg)
    $text = switch ($Fg.State) { 'on' { "an ($($Fg.Multiplier)x)" } 'off' { 'aus' } default { if ($Fg.Supported) { 'unbekannt' } else { 'nicht unterstuetzt' } } }
    if ($Fg.Mod) { $text += ', Mod' }
    return $text
}

# Bewertung nach Haengern pro Minute + konkrete Empfehlung
function Get-GSXFpsAdvice {
    param($Result, [int]$TargetFps, $FgStatus = $null)
    $r = $Result
    $tips = New-Object System.Collections.Generic.List[string]
    $fgUnknown = ($FgStatus -and $FgStatus.State -eq 'unknown' -and $FgStatus.Supported)
    $fg = ($r.FgActive -or $fgUnknown)
    $fgFloor = 55   # unter ~55 echten FPS fuehlt sich Frame Generation traege an

    $coreText = if ($null -ne $r.CoreMax) { ", staerkster CPU-Kern $($r.CoreMax) %" } else { "" }
    # GPU-Last entscheidet: Unter ~80 % bringt "Grafik runter" so gut wie nichts.
    $gpuKnown = ($null -ne $r.GpuAvg)
    $gpuLimit = ($gpuKnown -and $r.GpuAvg -ge 90)
    $gpuIdle  = ($gpuKnown -and $r.GpuAvg -lt 80)
    # CPU-Limit: GPU nicht ausgelastet und ein Kern stark belastet (Hauptthread des Spiels).
    # Windows misst pro Kern; der Hauptthread springt zwischen Kernen, daher reichen ~80 %.
    $cpuLimit = ($gpuIdle -and $null -ne $r.CoreMax -and $r.CoreMax -ge 80)
    # GPU kaum ausgelastet und kein Kern am Limit -> eher FPS-Limit / V-Sync / Engine
    $limiter  = ($gpuIdle -and -not $cpuLimit -and $r.GpuAvg -lt 60)
    $fgSupported = ($FgStatus -and ($FgStatus.Supported -or $FgStatus.State -eq 'on'))
    $vramFull = ($null -ne $r.VramPct -and $r.VramPct -ge 90)

    # Bewertung: Haenger pro Minute (Bilder > 50 ms und > 2,5x Median)
    $hpm = $r.HitchesPerMin
    $rating = if ($hpm -lt 2) { 'GUT' } elseif ($hpm -le 10) { 'GELEGENTLICH' } else { 'RUCKLER' }

    if ($hpm -ge 2) {
        $tips.Add("$hpm Haenger pro Minute (Bilder ueber 50 ms) - 1%-Low $($r.LowFps), 0,1%-Low $($r.Low01Fps).")
        if ($vramFull) { $tips.Add("VRAM zu $($r.VramPct) % voll -> Texturqualitaet eine Stufe runter (haeufigste Ursache fuer Nachlade-Haenger).") }
        if ($cpuLimit) { $tips.Add("CPU-Limit (GPU nur $($r.GpuAvg) %$coreText) -> CPU-lastige Einstellungen runter: Sichtweite, Effekte/Partikel, Physik/Zerstoerung, Objekt-/NPC-Dichte. Hintergrundprogramme schliessen.") }
        if ($limiter)  { $tips.Add("Kein Hardware-Limit (GPU $($r.GpuAvg) %$coreText) - Haenger kommen eher vom Nachladen der Welt (Streaming) oder Shader-Kompilieren.") }
        if (-not $vramFull -and -not $cpuLimit) {
            $tips.Add("Typisch fuer Nachladen/Shader: Spiel auf eine NVMe-SSD legen, NVIDIA-Shader-Cache auf 'Unbegrenzt' lassen.")
        }
    }
    elseif ($r.LowRatio -lt 50) {
        $tips.Add("1%-Low $($r.LowFps) wirkt niedrig, betrifft aber nur 1 % der Bilder - weniger als 2 Haenger/Minute, im Spiel kaum spuerbar.")
    }

    if ($r.AvgFps -lt $TargetFps * 0.93) {
        if ($gpuLimit) { $tips.Add("GPU-Limit ($($r.GpuAvg) %) -> Schatten, Volumetrik, Raytracing reduzieren oder DLSS eine Stufe staerker.") }
        elseif ($cpuLimit) {
            $tips.Add("CPU-Limit: Die Grafikkarte ist nur zu $($r.GpuAvg) % ausgelastet$coreText. Grafik runter bringt hier so gut wie nichts - Texturen, Schatten und Kantenglaettung koennen hoch bleiben.")
            $tips.Add("Hilft im CPU-Limit: NVIDIA Reflex auf 'An + Boost' (falls vorhanden) und CPU-lastige Einstellungen eine Stufe runter (Sichtweite, Effekte/Partikel, Physik).")
            if ($fgSupported -and -not $r.FgActive) { $tips.Add("Frame Generation (falls im Spiel nicht schon an) hilft gerade im CPU-Limit: Die Grafikkarte erzeugt Zwischenbilder ohne Arbeit fuer die CPU.") }
        }
        elseif ($limiter) { $tips.Add("Grafikkarte nur zu $($r.GpuAvg) % ausgelastet, aber kein Kern am Limit${coreText}: Meist ist ein FPS-Limit oder V-Sync aktiv (Spiel / NVIDIA-App pruefen). Grafik runter bringt hier nichts.") }
        elseif ($gpuIdle) { $tips.Add("Grafikkarte nur zu $($r.GpuAvg) % ausgelastet$coreText - die Grenze liegt eher bei CPU oder Spiel-Engine. Grafik runter bringt wenig; eher CPU-lastige Einstellungen (Sichtweite, Effekte, Physik) senken.") }
        elseif ($gpuKnown) { $tips.Add("Ziel $TargetFps FPS knapp verfehlt (GPU $($r.GpuAvg) %) -> eine Grafikstufe runter oder DLSS eine Stufe staerker.") }
        else { $tips.Add("Ziel $TargetFps FPS nicht erreicht. GPU-Last unbekannt - erst pruefen, ob die Grafikkarte voll ausgelastet ist, bevor du Grafik reduzierst.") }
    }
    elseif ($hpm -lt 2 -and $null -ne $r.GpuAvg -and $r.GpuAvg -lt 75 -and -not $fg) {
        $tips.Add("Ziel erreicht und GPU nur $($r.GpuAvg) % ausgelastet -> Reserve fuer mehr Grafikqualitaet.")
    }

    # FPS-Limit nur empfehlen, wenn sinnvoll - und abgesichert
    if ($hpm -gt 10 -and -not $fg) {
        $cap = [math]::Max([math]::Round($r.LowFps * 1.1), [math]::Round($r.AvgFps * 0.6))
        if ($cap -lt $r.AvgFps * 0.95) { $tips.Add("Optional: FPS-Limit bei ca. $cap FPS fuer gleichmaessigere Frametimes.") }
    }

    if ($r.FgActive) {
        $src = if ($FgStatus -and $FgStatus.Source) { " (laut $($FgStatus.Source))" } else { " (laut PresentMon)" }
        $tips.Insert(0, "Frame Generation aktiv$src - angezeigt Ø $($r.AvgFps) FPS, echte FPS: Ø $($r.BaseAvg), 1%-Low $($r.BaseLow).")
        if ($null -ne $r.BaseAvg -and $r.BaseAvg -lt $fgFloor) {
            $tips.Add("Nur $($r.BaseAvg) echte FPS - mit FG fuehlt sich das traege an. Grafik/DLSS runter, bis mind. $fgFloor-60 echte FPS erreicht sind.")
            # Fluessige Anzeige, aber traege Steuerung -> nicht als GUT werten
            if ($rating -eq 'GUT') { $rating = 'MITTEL' }
        }
    }
    elseif ($fgUnknown) {
        $modText = if ($FgStatus.Mod) { " Ein DLSS-FG-Mod ist installiert (version.dll + dlssg-ini)." } else { "" }
        $tips.Insert(0, "Das Spiel unterstuetzt Frame Generation, ob sie an ist, ist nicht auslesbar.$modText Falls an: echte FPS ca. $([math]::Round($r.AvgFps / 2)) - dann kein FPS-Limit unter $(2 * $fgFloor).")
    }

    if ($tips.Count -eq 0) { $tips.Add("Laeuft sauber an der Zielgrenze - nichts zu tun.") }
    return [PSCustomObject]@{ Rating = $rating; Tips = $tips.ToArray() }
}

# ----------------------------------------------------------
# Laufende Spiele automatisch erkennen (alle Launcher)
# ----------------------------------------------------------

$script:GameFolderCache = $null
$script:GameFolderCacheTime = [datetime]::MinValue
$script:NonGameExe = 'crash|launcher|helper|anticheat|easyanticheat|beservice|battleye|setup|redist|vc_redist|unins|update|webhelper|overlay|reporter|bootstrap|steamservice|epicgameslauncher|eadesktop|origin|ubisoftconnect|upc|battle\.net|agent|riotclient|leagueclient|clientux|uxrender|cefsharp|webview|qtwebengine|crashpad|renderer|socialclub|galaxyclient|overwolf'

# Einheitlicher Vergleichsname ("Battlefield™ 6" == "Battlefield 6")
function Get-GSXNormName {
    param([string]$Name)
    return ((("$Name" -replace '[™®©]', '') -replace '\s+', ' ').Trim().ToLowerInvariant())
}

# Alle installierten Spiele aus den Launcher-Daten (Name, Ordner, Startbefehl)
function Get-GSXGameFolders {
    if ($script:GameFolderCache -and ((Get-Date) - $script:GameFolderCacheTime).TotalMinutes -lt 10) {
        return $script:GameFolderCache
    }
    $list = New-Object System.Collections.Generic.List[object]
    function Add-Game($name, $root, $source, $launch) {
        if (-not $name -or -not $root) { return }
        $list.Add([PSCustomObject]@{ Name = "$name".Trim(); Root = "$root".TrimEnd('\'); Source = $source; Launch = $launch })
    }

    # --- Steam (appmanifest, UTF-8)
    foreach ($lib in @(Get-SteamLibraryPaths)) {
        $apps = Join-Path $lib 'steamapps'
        foreach ($m in @(Get-ChildItem -LiteralPath $apps -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue)) {
            $c = Get-Content -LiteralPath $m.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $id = [regex]::Match("$c", '"appid"\s+"(\d+)"').Groups[1].Value
            $n = [regex]::Match("$c", '"name"\s+"([^"]+)"').Groups[1].Value
            $d = [regex]::Match("$c", '"installdir"\s+"([^"]+)"').Groups[1].Value
            if ($n -and $d -and $n -notmatch 'Steamworks|Redistributable|Proton|SteamVR') {
                Add-Game $n (Join-Path $apps "common\$d") 'Steam' "steam://rungameid/$id"
            }
        }
    }

    # --- Epic Games (Manifeste)
    $epic = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    foreach ($f in @(Get-ChildItem -LiteralPath $epic -Filter '*.item' -File -ErrorAction SilentlyContinue)) {
        try {
            $j = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.bIsIncompleteInstall) { continue }
            $cats = @($j.AppCategories)
            if ($cats.Count -gt 0 -and $cats -notcontains 'games') { continue }   # Unreal Engine, Plugins ...
            $launch = "com.epicgames.launcher://apps/$($j.CatalogNamespace)%3A$($j.CatalogItemId)%3A$($j.AppName)?action=launch&silent=true"
            Add-Game $j.DisplayName $j.InstallLocation 'Epic' $launch
        }
        catch { }
    }

    # --- GOG
    foreach ($k in @(Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games' -ErrorAction SilentlyContinue)) {
        $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
        $exe = if ($p.exe -and (Test-Path -LiteralPath $p.exe)) { $p.exe } else { $null }
        Add-Game $p.gameName $p.path 'GOG' $exe
    }

    # --- Ubisoft Connect
    foreach ($k in @(Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs' -ErrorAction SilentlyContinue)) {
        $dir = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).InstallDir
        if ($dir -and (Test-Path -LiteralPath $dir)) {
            Add-Game (Split-Path $dir.TrimEnd('/', '\') -Leaf) $dir 'Ubisoft' "uplay://launch/$($k.PSChildName)/0"
        }
    }

    # --- EA app, Battle.net, Riot, Rockstar (Windows-Programmliste)
    $riotClient = Join-Path $env:SystemDrive 'Riot Games\Riot Client\RiotClientServices.exe'
    $riotIds = @{ 'league of legends' = 'league_of_legends'; 'valorant' = 'valorant'; 'legends of runeterra' = 'bacon' }
    $uninstall = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
                   'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
                   'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall')
    foreach ($u in $uninstall) {
        foreach ($k in @(Get-ChildItem $u -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
            if ($p.Publisher -notmatch 'Electronic Arts|Blizzard|Riot Games|Rockstar Games') { continue }
            if (-not $p.InstallLocation -or -not (Test-Path -LiteralPath $p.InstallLocation)) { continue }
            $src = switch -Regex ($p.Publisher) { 'Electronic' { 'EA' } 'Blizzard' { 'Battle.net' } 'Riot' { 'Riot' } default { 'Rockstar' } }
            $launch = $null
            $rid = $riotIds[(Get-GSXNormName $p.DisplayName)]
            if ($src -eq 'Riot' -and $rid -and (Test-Path -LiteralPath $riotClient)) {
                $launch = "`"$riotClient`" --launch-product=$rid --launch-patchline=live"
            }
            Add-Game $p.DisplayName $p.InstallLocation $src $launch
        }
    }

    # --- Bekannte Spiele-Ordner (jeder Unterordner = ein Spiel)
    $roots = @(
        "$env:ProgramFiles\Epic Games", "${env:ProgramFiles(x86)}\Epic Games",
        "$env:ProgramFiles\EA Games", "${env:ProgramFiles(x86)}\EA Games", "$env:ProgramFiles\Electronic Arts",
        "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher\games",
        "$env:ProgramFiles\Riot Games", "C:\Riot Games", "C:\XboxGames"
    )
    foreach ($drive in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        $roots += @((Join-Path $drive.Root 'Games'), (Join-Path $drive.Root 'XboxGames'), (Join-Path $drive.Root 'Epic Games'), (Join-Path $drive.Root 'EA Games'))
    }
    foreach ($root in ($roots | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $src = if ($root -match 'Xbox') { 'Xbox' } else { 'Ordner' }
        foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
            Add-Game $d.Name $d.FullName $src $null
        }
    }

    $script:GameFolderCache = $list.ToArray()
    $script:GameFolderCacheTime = Get-Date
    return $script:GameFolderCache
}

$script:GameSkipPattern = 'Launcher|Redist|DirectX|Online Services|Uplay|Battle\.net|Bootstrapper|Overlay|^Common|Steamworks|Proton|SteamVR|Wallpaper Engine|Dedicated Server|SDK|Tools?$|Editor|Riot Client|EA app|Origin$|Anti-?Cheat|Vanguard'

# Bibliothek: ein Eintrag pro Spiel (doppelte zusammengefasst, Eintraege mit Startbefehl bevorzugt)
function Get-GSXGameLibrary {
    $byName = [ordered]@{}
    foreach ($g in @(Get-GSXGameFolders)) {
        if (-not $g.Name -or $g.Name -match $script:GameSkipPattern) { continue }
        $key = Get-GSXNormName $g.Name
        if (-not $byName.Contains($key) -or (-not $byName[$key].Launch -and $g.Launch)) { $byName[$key] = $g }
    }
    return @($byName.Values | Sort-Object Name)
}

# Kompatibilitaet: nur die Namen
function Get-GSXInstalledGames {
    return @(Get-GSXGameLibrary | ForEach-Object { $_.Name })
}

# Spiel ueber seinen Launcher bzw. die EXE starten
function Start-GSXLibraryGame {
    param($Game)
    if (-not $Game.Launch) { throw "Fuer $($Game.Name) ist kein Startbefehl bekannt - bitte ueber den Launcher starten." }
    $cmd = "$($Game.Launch)"
    if ($cmd -match '^"([^"]+)"\s*(.*)$') {
        Start-Process -FilePath $Matches[1] -ArgumentList $Matches[2] -ErrorAction Stop
    }
    elseif ($cmd -match '^[a-z][a-z0-9+.\-]*://') {
        Start-Process -FilePath $cmd -ErrorAction Stop   # steam://, uplay://, com.epicgames...://
    }
    else {
        Start-Process -FilePath $cmd -WorkingDirectory (Split-Path $cmd -Parent) -ErrorAction Stop
    }
}

function Find-GSXRunningGame {
    param([string[]]$PreferKeys = @())
    # Bekannte Profile zuerst
    foreach ($id in $script:GameProfiles.Keys) {
        $p = Get-Process -Name $script:GameProfiles[$id].Process -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) {
            $pp = $null; try { $pp = $p.Path } catch { }
            return [PSCustomObject]@{ Key = "$($p.ProcessName).exe".ToLower(); Exe = "$($p.ProcessName).exe"; Name = $script:GameProfiles[$id].Name; ProfileId = $id; Path = $pp }
        }
    }

    $folders = @(Get-GSXGameFolders)
    if ($folders.Count -eq 0) { return $null }

    $candidates = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -gt 4 -and $_.WorkingSet64 -gt 300MB -and $_.ProcessName -notmatch $script:NonGameExe })
    if ($candidates.Count -eq 0) { return $null }

    $paths = @{}
    $missing = @()
    foreach ($c in $candidates) {
        $path = $null
        try { $path = $c.Path } catch { }
        if ($path) { $paths[$c.Id] = $path } else { $missing += $c.Id }
    }
    if ($missing.Count -gt 0) {
        $filter = ($missing | ForEach-Object { "ProcessId=$_" }) -join ' OR '
        foreach ($w in @(Get-CimInstance Win32_Process -Filter $filter -ErrorAction SilentlyContinue)) {
            if ($w.ExecutablePath) { $paths[[int]$w.ProcessId] = $w.ExecutablePath }
        }
    }

    # Alle Kandidaten in Spielordnern sammeln
    $games = New-Object System.Collections.Generic.List[object]
    foreach ($c in ($candidates | Sort-Object WorkingSet64 -Descending)) {
        $path = $paths[$c.Id]
        if (-not $path) { continue }
        foreach ($f in $folders) {
            if ($path.StartsWith($f.Root.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
                $games.Add([PSCustomObject]@{ Key = "$($c.ProcessName).exe".ToLower(); Exe = "$($c.ProcessName).exe"; Name = $f.Name; ProfileId = $null; Path = $path; ProcName = $c.ProcessName })
                break
            }
        }
    }
    if ($games.Count -eq 0) { return $null }

    # 1. Bereits laufende Sitzung beibehalten (kein Hin- und Herspringen)
    foreach ($g in $games) { if ($PreferKeys -contains $g.Key) { return $g } }
    # 2. Programm im Vordergrund bevorzugen
    $fg = Get-GSXForegroundProcessName
    if ($fg) { foreach ($g in $games) { if ($g.ProcName -eq $fg) { return $g } } }
    # 3. Sonst das groesste
    return $games[0]
}

function Get-GSXLevelDecision {
    param([int]$Level, $Result, [int]$TargetFps)
    if (-not $Result) { return @{ Level = $Level; Reason = 'Keine verwertbare Messung' } }
    $avg = $Result.AvgFps; $low = $Result.LowFps; $gpu = $Result.GpuAvg

    # Haenger werden separat ueber Haenger/Minute bewertet (nicht ueber das 1%-Low)
    if ($avg -lt $TargetFps * 0.93) {
        # Grafikkarte nicht ausgelastet -> CPU/Engine bremst, weniger Grafik bringt nichts
        if ($null -ne $gpu -and $gpu -lt 80) {
            return @{ Level = $Level; Reason = "Ø $avg FPS unter Ziel, aber GPU nur $gpu % ausgelastet -> CPU-/Spiel-Limit, Grafikstufe bleibt" }
        }
        if ($Level -gt 1) { return @{ Level = $Level - 1; Reason = "Ø $avg FPS / 1% $low unter Ziel $TargetFps -> eine Stufe runter" } }
        return @{ Level = $Level; Reason = "Ø $avg FPS unter Ziel, bereits niedrigste Stufe (DLSS im Spiel auf Leistung stellen)" }
    }
    if ($avg -ge $TargetFps * 0.97 -and $null -ne $gpu -and $gpu -lt 75) {
        if ($Level -lt 5) { return @{ Level = $Level + 1; Reason = "Ziel erreicht, GPU nur $gpu % ausgelastet -> eine Stufe mehr Qualitaet" } }
        return @{ Level = $Level; Reason = "Ziel erreicht, hoechste Stufe aktiv" }
    }
    return @{ Level = $Level; Reason = "Ø $avg FPS / 1% $low - passt zum Ziel $TargetFps, Stufe bleibt" }
}
