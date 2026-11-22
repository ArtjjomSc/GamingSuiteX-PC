# ==========================================================
# GamingSuite X
# UI Engine v10.0
# ==========================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# HINWEIS: Kein erneutes Dot-Sourcing der Module hier - GamingSuiteX.ps1
# laedt HardwareManager.ps1, GamingCenter.ps1, Logger.ps1, Optimizer.ps1
# und StorageManager.ps1 bereits, bevor UI.ps1 geladen wird. Das doppelte
# Laden fuehrte dazu, dass alle Initialize-Routinen zweimal liefen.

function Start-GamingSuiteUI {
    # ======================================================
    # Colors & Styling
    # ======================================================

    # Gleiche Farbwelt wie die Handy-App
    $Colors = @{
        Background = [System.Drawing.Color]::FromArgb(11,13,18)
        Panel      = [System.Drawing.Color]::FromArgb(16,20,28)
        Card       = [System.Drawing.Color]::FromArgb(21,26,35)
        Button     = [System.Drawing.Color]::FromArgb(28,34,46)
        Border     = [System.Drawing.Color]::FromArgb(38,45,58)
        Graph      = [System.Drawing.Color]::FromArgb(14,17,23)
        Text       = [System.Drawing.Color]::FromArgb(229,231,235)
        Dim        = [System.Drawing.Color]::FromArgb(156,163,175)
        Green      = [System.Drawing.Color]::FromArgb(74,222,128)
        Cyan       = [System.Drawing.Color]::FromArgb(34,211,238)
        Yellow     = [System.Drawing.Color]::FromArgb(251,191,36)
        Red        = [System.Drawing.Color]::FromArgb(248,113,113)
        Blue       = [System.Drawing.Color]::FromArgb(96,165,250)
        Purple     = [System.Drawing.Color]::FromArgb(167,139,250)
    }
    $FontTitle   = New-Object Drawing.Font("Segoe UI Semibold",11)
    $FontCardTxt = New-Object Drawing.Font("Segoe UI",10.5)

    # ======================================================
    # Main Form
    # ======================================================

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "GamingSuite X v$Version"
    $form.Size = New-Object System.Drawing.Size(1400,850)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = $Colors.Background
    $form.ForeColor = $Colors.Text
    $form.Font = New-Object Drawing.Font("Segoe UI",9.75)
    # Feste Groesse: das Layout ist pixelgenau, Vergroessern wuerde es zerreissen
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    $iconPath = Join-Path $PSScriptRoot "web\icon.png"
    if (Test-Path -LiteralPath $iconPath) {
        try { $form.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::FromFile($iconPath)).GetHicon()) } catch { }
    }
    $form.Add_Load({ if ($script:GSXUiOk) { [GSXWindow]::DarkTitleBar($form.Handle) } })

    # ======================================================
    # Header
    # ======================================================

    $brand = New-Object System.Windows.Forms.Label
    $brand.Text = "GAMINGSUITE X"
    $brand.Location = New-Object System.Drawing.Point(0,0)
    $brand.Size = New-Object System.Drawing.Size(220,60)
    $brand.BackColor = $Colors.Panel
    $brand.ForeColor = $Colors.Green
    $brand.Font = New-Object Drawing.Font("Segoe UI",14,[Drawing.FontStyle]::Bold)
    $brand.TextAlign = "MiddleCenter"
    $form.Controls.Add($brand)

    $header = New-Object System.Windows.Forms.Label
    $header.UseMnemonic = $false
    $header.Text = "Dashboard"
    $header.Location = New-Object System.Drawing.Point(220,0)
    $header.Size = New-Object System.Drawing.Size(1180,60)
    $header.BackColor = $Colors.Panel
    $header.ForeColor = $Colors.Text
    $header.Font = New-Object Drawing.Font("Segoe UI Semibold",17)
    $header.TextAlign = "MiddleLeft"
    $header.Padding = New-Object System.Windows.Forms.Padding(24,0,0,0)
    $form.Controls.Add($header)

    $headerLine = New-Object System.Windows.Forms.Panel
    $headerLine.Location = New-Object System.Drawing.Point(0,60)
    $headerLine.Size = New-Object System.Drawing.Size(1400,1)
    $headerLine.BackColor = $Colors.Border
    $form.Controls.Add($headerLine)

    # ======================================================
    # Navigation
    # ======================================================

    $nav = New-Object System.Windows.Forms.Panel
    $nav.Location = New-Object System.Drawing.Point(0,61)
    $nav.Size = New-Object System.Drawing.Size(220,760)
    $nav.BackColor = $Colors.Panel
    $form.Controls.Add($nav)

    $menu = @(
        "Dashboard",
        "Live Monitor",
        "Gaming Center",
        "Spiele-Tuning",
        "Optimizer",
        "Storage",
        "Settings",
        "Statistics"
    )

    # Symbole aus der Windows-Schrift "Segoe MDL2 Assets"
    $navIcons = @{
        "Dashboard"     = [string][char]0xE80F
        "Live Monitor"  = [string][char]0xE9D9
        "Gaming Center" = [string][char]0xE7FC
        "Spiele-Tuning" = [string][char]0xEC4A
        "Optimizer"     = [string][char]0xE90F
        "Storage"       = [string][char]0xEDA2
        "Settings"      = [string][char]0xE713
        "Statistics"    = [string][char]0xE9F9
    }

    $y = 16
    $navButtons = @{}
    $script:CurrentPage = "Dashboard"

    foreach($m in $menu)
    {
        $b = New-GSXNavButton -Icon $navIcons[$m]
        $b.Text = $m
        $b.Location = New-Object System.Drawing.Point(12,$y)
        $b.Size = New-Object System.Drawing.Size(196,44)
        $b.ForeColor = $Colors.Text
        $b.BackColor = $Colors.Panel
        $b.Font = New-Object Drawing.Font("Segoe UI Semibold",10)
        if (-not $script:GSXUiOk) { $b.BackColor = $Colors.Card; $b.FlatStyle = "Flat" }
        $b.Tag = $m
        $b.Add_Click({
            param($sender, $eventArgs)
            $script:CurrentPage = $sender.Tag
        })
        $nav.Controls.Add($b)
        $navButtons[$m] = $b
        $y += 50
    }

    # ======================================================
    # Karten Funktion
    # ======================================================

    function New-Card($title,$x,$y)
    {
        $panel = New-GSXCard -Fill $Colors.Card -Border $Colors.Border
        $panel.Location = New-Object System.Drawing.Point($x,$y)
        $panel.Size = New-Object System.Drawing.Size(350,250)

        $label = New-Object System.Windows.Forms.Label
        $label.Text = $title.ToUpper()
        $label.Location = New-Object System.Drawing.Point(20,18)
        $label.Size = New-Object System.Drawing.Size(310,24)
        $label.ForeColor = $Colors.Green
        $label.Font = $FontTitle

        $value = New-Object System.Windows.Forms.Label
        $value.UseMnemonic = $false
        $value.Location = New-Object System.Drawing.Point(20,50)
        $value.Size = New-Object System.Drawing.Size(310,120)
        $value.ForeColor = $Colors.Text
        $value.Font = $FontCardTxt

        $bar = New-GSXBar
        $bar.Location = New-Object System.Drawing.Point(20,186)
        $bar.Size = New-Object System.Drawing.Size(310,8)
        $bar.Minimum = 0
        $bar.Maximum = 100

        $percent = New-Object System.Windows.Forms.Label
        $percent.UseMnemonic = $false
        $percent.Location = New-Object System.Drawing.Point(20,204)
        $percent.Size = New-Object System.Drawing.Size(310,24)
        $percent.ForeColor = $Colors.Dim
        $percent.Font = New-Object Drawing.Font("Segoe UI",9.5)

        $panel.Controls.Add($label)
        $panel.Controls.Add($value)
        $panel.Controls.Add($bar)
        $panel.Controls.Add($percent)

        return @{
            Panel   = $panel
            Value   = $value
            Bar     = $bar
            Percent = $percent
        }
    }

    # ======================================================
    # Dashboard Karten
    # ======================================================

    $cpuCard     = New-Card "CPU" 250 90
    $gpuCard     = New-Card "GPU" 620 90
    $ramCard     = New-Card "RAM" 990 90
    $storageCard = New-Card "Laufwerke" 250 365
    $networkCard = New-Card "Netzwerk" 620 365
    $systemCard  = New-Card "System" 990 365
    $systemCard.Bar.Visible = $false

    $form.Controls.Add($cpuCard.Panel)
    $form.Controls.Add($gpuCard.Panel)
    $form.Controls.Add($ramCard.Panel)
    $form.Controls.Add($storageCard.Panel)
    $form.Controls.Add($networkCard.Panel)
    $form.Controls.Add($systemCard.Panel)

    # ======================================================
    # Live Monitor
    # ======================================================

    $livePanel = New-Object System.Windows.Forms.Panel
    $livePanel.Location = New-Object System.Drawing.Point(240,90)
    $livePanel.Size = New-Object System.Drawing.Size(1120,660)
    $livePanel.BackColor = $Colors.Background
    $livePanel.Visible = $false
    $form.Controls.Add($livePanel)

    function New-MonitorCard($title,$x,$y) {
        $panel = New-GSXCard -Fill $Colors.Card -Border $Colors.Border
        $panel.Location = New-Object System.Drawing.Point($x,$y)
        $panel.Size = New-Object System.Drawing.Size(350,290)

        $label = New-Object System.Windows.Forms.Label
        $label.Text = $title.ToUpper()
        $label.Location = New-Object System.Drawing.Point(16,14)
        $label.Size = New-Object System.Drawing.Size(180,24)
        $label.ForeColor = $Colors.Green
        $label.Font = $FontTitle
        $panel.Controls.Add($label)

        $value = New-Object System.Windows.Forms.Label
        $value.Text = "Warte auf Messwerte ..."
        $value.Location = New-Object System.Drawing.Point(180,14)
        $value.Size = New-Object System.Drawing.Size(155,24)
        $value.Font = New-Object Drawing.Font("Segoe UI Semibold",10.5)
        $value.ForeColor = $Colors.Text
        $value.TextAlign = "MiddleRight"
        $panel.Controls.Add($value)

        $graph = New-Object System.Windows.Forms.Panel
        $graph.Location = New-Object System.Drawing.Point(16,50)
        $graph.Size = New-Object System.Drawing.Size(318,222)
        $graph.BackColor = $Colors.Graph
        $graph.Tag = New-Object System.Collections.ArrayList
        $graph.Add_Paint({
            param($sender, $eventArgs)

            $graphics = $eventArgs.Graphics
            $values = $sender.Tag
            $width = $sender.ClientSize.Width
            $height = $sender.ClientSize.Height
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $gridPen = New-Object System.Drawing.Pen($Colors.Border)

            for ($grid = 1; $grid -lt 4; $grid++) {
                $gridY = [int](($height / 4) * $grid)
                $graphics.DrawLine($gridPen, 0, $gridY, $width, $gridY)
            }
            $gridPen.Dispose()

            if ($values.Count -lt 2) { return }

            # Linie rechtsbuendig (neuester Wert rechts) mit halbtransparenter Flaeche
            $offset = 60 - $values.Count
            $points = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
            for ($index = 0; $index -lt $values.Count; $index++) {
                $px = [single](($index + $offset) * ($width - 1) / 59)
                $py = [single](($height - 1) - (([double]$values[$index] / 100.0) * ($height - 6)))
                $points.Add((New-Object System.Drawing.PointF($px, $py)))
            }
            $area = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
            $area.AddRange($points)
            $area.Add((New-Object System.Drawing.PointF($points[$points.Count - 1].X, [single]$height)))
            $area.Add((New-Object System.Drawing.PointF($points[0].X, [single]$height)))
            $fillBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, $Colors.Green))
            $graphics.FillPolygon($fillBrush, $area.ToArray())
            $fillBrush.Dispose()
            $linePen = New-Object System.Drawing.Pen($Colors.Green, 2)
            $graphics.DrawLines($linePen, $points.ToArray())
            $linePen.Dispose()
        })
        $panel.Controls.Add($graph)

        $livePanel.Controls.Add($panel)
        return @{ Value = $value; Graph = $graph }
    }

    function Add-MonitorValue($monitor,$value,$label,$displayText = $null) {
        $history = $monitor.Graph.Tag
        [void]$history.Add([math]::Max(0, [math]::Min(100, [double]$value)))
        if ($history.Count -gt 60) { $history.RemoveAt(0) }
        if ($null -ne $displayText) {
            $monitor.Value.Text = $displayText
        }
        else {
            $monitor.Value.Text = "$([math]::Round([double]$value, 1))% $label"
        }
        $monitor.Graph.Invalidate()
    }

    $cpuMonitor = New-MonitorCard "CPU-Auslastung" 10 0
    $gpuMonitor = New-MonitorCard "GPU-Auslastung" 380 0
    $ramMonitor = New-MonitorCard "RAM-Auslastung" 750 0
    $vramMonitor = New-MonitorCard "VRAM-Belegung" 10 310
    $networkMonitor = New-MonitorCard "Download" 380 310

    # ======================================================
    # Gaming Center
    # ======================================================

    $gamingPanel = New-Object System.Windows.Forms.Panel
    $gamingPanel.Location = New-Object System.Drawing.Point(240,90)
    $gamingPanel.Size = New-Object System.Drawing.Size(1120,660)
    $gamingPanel.BackColor = $Colors.Background
    $gamingPanel.Visible = $false
    $form.Controls.Add($gamingPanel)

    $gamingTitle = New-Object System.Windows.Forms.Label
    $gamingTitle.Text = "Gaming Center | Steam-Bibliothek"
    $gamingTitle.Location = New-Object System.Drawing.Point(15,10)
    $gamingTitle.Size = New-Object System.Drawing.Size(650,35)
    $gamingTitle.ForeColor = $Colors.Text
    $gamingTitle.Font = New-Object Drawing.Font("Segoe UI",16,[Drawing.FontStyle]::Bold)
    $gamingPanel.Controls.Add($gamingTitle)

    $gameList = New-Object System.Windows.Forms.ListBox
    $gameList.Location = New-Object System.Drawing.Point(15,60)
    $gameList.Size = New-Object System.Drawing.Size(720,540)
    $gameList.BackColor = $Colors.Card
    $gameList.ForeColor = $Colors.Text
    $gameList.Font = New-Object Drawing.Font("Segoe UI",11)
    $gameList.DisplayMember = "Name"
    $gamingPanel.Controls.Add($gameList)

    $gameInfo = New-Object System.Windows.Forms.Label
    $gameInfo.Text = "Steam-Bibliothek wird geladen ..."
    $gameInfo.Location = New-Object System.Drawing.Point(765,80)
    $gameInfo.Size = New-Object System.Drawing.Size(320,120)
    $gameInfo.ForeColor = $Colors.Text
    $gameInfo.Font = New-Object Drawing.Font("Segoe UI",11)
    $gamingPanel.Controls.Add($gameInfo)

    $refreshGamesButton = New-Object System.Windows.Forms.Button
    $refreshGamesButton.Text = "Steam aktualisieren"
    $refreshGamesButton.Location = New-Object System.Drawing.Point(765,230)
    $refreshGamesButton.Size = New-Object System.Drawing.Size(220,42)
    $refreshGamesButton.ForeColor = $Colors.Text
    $refreshGamesButton.BackColor = $Colors.Card
    $refreshGamesButton.FlatStyle = "Flat"
    $gamingPanel.Controls.Add($refreshGamesButton)

    $launchGameButton = New-Object System.Windows.Forms.Button
    $launchGameButton.Text = "Spiel starten"
    $launchGameButton.Location = New-Object System.Drawing.Point(765,285)
    $launchGameButton.Size = New-Object System.Drawing.Size(220,42)
    $launchGameButton.ForeColor = $Colors.Text
    $launchGameButton.BackColor = $Colors.Green
    $launchGameButton.FlatStyle = "Flat"
    $gamingPanel.Controls.Add($launchGameButton)

    $favoriteButton = New-Object System.Windows.Forms.Button
    $favoriteButton.Text = "Zu Favoriten hinzufuegen"
    $favoriteButton.Location = New-Object System.Drawing.Point(765,340)
    $favoriteButton.Size = New-Object System.Drawing.Size(220,42)
    $favoriteButton.ForeColor = $Colors.Text
    $favoriteButton.BackColor = $Colors.Purple
    $favoriteButton.FlatStyle = "Flat"
    $gamingPanel.Controls.Add($favoriteButton)

    function Update-GamingCenterView {
        # Ruft den echten Cache-Refresh aus GamingCenter.ps1 auf (statt ihn
        # durch eine gleichnamige lokale Funktion zu ueberschatten), damit
        # $script:GamingLibrary tatsaechlich aktuell bleibt und
        # Get-GamingLibrary / Find-GamingSuiteGame / Get-GamingCenterStatistics
        # nach einem manuellen Refresh keine veralteten Daten mehr liefern.
        $games = @(Update-GamingCenter)

        $gameList.Items.Clear()
        foreach ($game in $games) {
            [void]$gameList.Items.Add($game)
        }

        if ($games.Count -gt 0) {
            $gameInfo.Text = "$($games.Count) Steam-Spiele gefunden.`n`nSpiel auswaehlen und starten."
        }
        else {
            $gameInfo.Text = "Keine Steam-Spiele gefunden.`n`nSteam muss installiert sein und mindestens ein Spiel enthalten."
        }
    }

    $gameList.Add_SelectedIndexChanged({
        $game = $gameList.SelectedItem
        if ($game) {
            $gameInfo.Text = "Name: $($game.Name)`nPlattform: $($game.Platform)`nApp-ID: $($game.AppId)"
        }
    })

    $refreshGamesButton.Add_Click({ Update-GamingCenterView })

    $launchGameButton.Add_Click({
        $game = $gameList.SelectedItem
        if ($game) {
            Start-GamingSuiteGame $game
        }
        else {
            $gameInfo.Text = "Bitte zuerst ein Spiel auswaehlen."
        }
    })

    $favoriteButton.Add_Click({
        $game = $gameList.SelectedItem
        if ($game) {
            if (Add-FavoriteGame $game) {
                $gameInfo.Text = "$($game.Name) zu Favoriten hinzugefuegt!"
            }
            else {
                $gameInfo.Text = "$($game.Name) ist bereits in Favoriten."
            }
        }
        else {
            $gameInfo.Text = "Bitte zuerst ein Spiel auswaehlen."
        }
    })

    # ======================================================
    # Spiele-Tuning Page - Messung aller Spiele + Auto-Tuning
    # ======================================================

    $gameTunePanel = New-Object System.Windows.Forms.Panel
    $gameTunePanel.Location = New-Object System.Drawing.Point(240,90)
    $gameTunePanel.Size = New-Object System.Drawing.Size(1120,680)
    $gameTunePanel.BackColor = $Colors.Background
    $gameTunePanel.Visible = $false
    $form.Controls.Add($gameTunePanel)

    function New-GtLabel($text, $y, $size, $bold) {
        $l = New-Object System.Windows.Forms.Label
        $l.UseMnemonic = $false
        $l.Text = $text
        $l.Location = New-Object System.Drawing.Point(15, $y)
        $l.Size = New-Object System.Drawing.Size(1090, ($size * 2 + 6))
        $l.ForeColor = $Colors.Text
        $style = if ($bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
        $l.Font = New-Object Drawing.Font("Segoe UI", $size, $style)
        $gameTunePanel.Controls.Add($l)
        return $l
    }

    function New-GtList($y, $height) {
        $lv = New-GSXListView
        $lv.Location = New-Object System.Drawing.Point(15, $y)
        $lv.Size = New-Object System.Drawing.Size(1090, $height)
        $lv.View = "Details"
        $lv.FullRowSelect = $true
        $lv.MultiSelect = $false
        $lv.HideSelection = $false
        $lv.HeaderStyle = "Nonclickable"
        $lv.BackColor = $Colors.Card
        $lv.ForeColor = $Colors.Text
        $lv.BorderStyle = "None"
        $lv.Font = New-Object Drawing.Font("Segoe UI",10)
        $gameTunePanel.Controls.Add($lv)
        return $lv
    }

    function New-GtButton($text, $x, $y, $color) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text
        $b.Location = New-Object System.Drawing.Point($x, $y)
        $b.Size = New-Object System.Drawing.Size(205,36)
        $b.ForeColor = $Colors.Text
        $b.BackColor = $color
        $b.FlatStyle = "Flat"
        $b.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
        $gameTunePanel.Controls.Add($b)
        return $b
    }

    [void](New-GtLabel "Spiele-Tuning  |  Ziel: volle Monitor-Hz, stabile 1%-Lows" 0 15 $true)
    $gtMonitor = New-GtLabel "" 36 10 $false
    $gtMonitor.Height = 40

    $gtCap = New-Object System.Windows.Forms.CheckBox
    $gtCap.Text = "FPS knapp unter Monitor-Hz begrenzen (G-Sync / FreeSync)"
    $gtCap.Location = New-Object System.Drawing.Point(15,78)
    $gtCap.Size = New-Object System.Drawing.Size(480,24)
    $gtCap.ForeColor = $Colors.Text
    $gameTunePanel.Controls.Add($gtCap)

    $gtAuto = New-Object System.Windows.Forms.CheckBox
    $gtAuto.Text = "Jedes Spiel automatisch messen (CS2/BF6 zusaetzlich automatisch nachregeln)"
    $gtAuto.Location = New-Object System.Drawing.Point(500,78)
    $gtAuto.Size = New-Object System.Drawing.Size(600,24)
    $gtAuto.ForeColor = $Colors.Text
    $gameTunePanel.Controls.Add($gtAuto)

    # --- Bereich 1: Auto-Tuning (Spiele mit Profil)
    [void](New-GtLabel "AUTO-TUNING (Grafik wird automatisch gesetzt)" 108 9 $true)
    $gtList = New-GtList 128 62
    [void]$gtList.Columns.Add("Spiel", 170)
    [void]$gtList.Columns.Add("Einstellungen", 110)
    [void]$gtList.Columns.Add("Aktuelle Stufe", 150)
    [void]$gtList.Columns.Add("Startwert (Hardware)", 150)
    [void]$gtList.Columns.Add("Status", 490)

    $gtStartButton   = New-GtButton "OPTIMIEREN (Startwert)"     15 196 ([System.Drawing.Color]::FromArgb(0,140,60))
    $gtUpButton      = New-GtButton "Mehr Qualitaet (+1)"       236 196 $Colors.Card
    $gtDownButton    = New-GtButton "Mehr FPS (-1)"             457 196 $Colors.Card
    $gtRestoreButton = New-GtButton "Original wiederherstellen" 678 196 $Colors.Card
    $gtMeasureButton = New-GtButton "Laufendes Spiel messen"    899 196 $Colors.Card

    # --- Bereich 2: Messungen aller Spiele
    $gtMeasTitle = New-GtLabel "SPIELEBIBLIOTHEK" 240 9 $true
    $gtMeasList = New-GtList 260 196
    foreach ($col in @(@("Spiel",205), @("Quelle",70), @("Bewertung",95), @("Ø FPS",52), @("1%-Low",58), @("0,1%-Low",66),
                       @("1%/Ø",48), @("Hänger/min",80), @("GPU",46), @("Kern",48), @("VRAM",50), @("Frame Gen.",100), @("Mess.",46), @("Zuletzt",90))) {
        [void]$gtMeasList.Columns.Add($col[0], $col[1])
    }

    $gtLaunchButton = New-GtButton "SPIEL STARTEN + MESSEN" 15 462 ([System.Drawing.Color]::FromArgb(0,140,60))
    $gtLaunchButton.Width = 260
    $gtTipsButton = New-GtButton "Empfehlungen anzeigen" 286 462 $Colors.Card
    $gtRescanButton = New-GtButton "Bibliothek neu einlesen" 507 462 $Colors.Card
    $gtLibInfo = New-GtLabel "" 470 9 $false
    $gtLibInfo.Location = New-Object System.Drawing.Point(728, 470)
    $gtLibInfo.Size = New-Object System.Drawing.Size(377, 22)
    $gtLibInfo.ForeColor = $Colors.Dim

    $gtLog = New-Object System.Windows.Forms.TextBox
    $gtLog.Multiline = $true
    $gtLog.ReadOnly = $true
    $gtLog.ScrollBars = "Vertical"
    $gtLog.Location = New-Object System.Drawing.Point(15,506)
    $gtLog.Size = New-Object System.Drawing.Size(1090,127)
    $gtLog.BackColor = $Colors.Card
    $gtLog.ForeColor = $Colors.Text
    $gtLog.BorderStyle = "None"
    $gtLog.Font = New-Object Drawing.Font("Consolas",9.5)
    $gameTunePanel.Controls.Add($gtLog)

    $script:GTState = Get-GSXGameState
    $script:GTMonitor = $null
    $script:GTCapture = $null
    $script:GTRunning = @{}
    $script:GTLastCheck = [datetime]::MinValue
    $script:GTRecCache = @{}
    $gtCap.Checked = [bool]$script:GTState.Settings.CapToHz
    $gtAuto.Checked = [bool]$script:GTState.Settings.AutoTune

    function Add-GtLog([string]$text) {
        $gtLog.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] $text`r`n")
    }

    function Get-GtGame([string]$id) {
        if (-not $script:GTState.Games.ContainsKey($id)) {
            $script:GTState.Games[$id] = @{ Level = 0; LastAvg = $null; LastLow = $null; LastGpu = $null; LastMeasured = $null; LastAction = ''; PendingLevel = $null }
        }
        return $script:GTState.Games[$id]
    }

    function Get-GtTarget { return (Get-GSXTargetFps -Monitor $script:GTMonitor -CapToHz $gtCap.Checked) }

    function Get-GtSelectedId {
        if ($gtList.SelectedItems.Count -gt 0) { return $gtList.SelectedItems[0].Tag }
        if ($gtList.Items.Count -gt 0) { return $gtList.Items[0].Tag }
        return $null
    }

    # Messungen + Stufen als JSON fuer die Handy-App (/api/games)
    function Update-GtPhoneData {
        try {
            $games = @()
            foreach ($e in @($script:GTState.Measured.GetEnumerator() | Sort-Object { $_.Value.Date } -Descending)) {
                $m = $e.Value
                $games += ,([ordered]@{
                    key = $e.Key; name = "$($m.Name)"; rating = "$($m.Rating)"; date = "$($m.Date)"; target = $m.Target
                    avg = $m.Avg; low = $m.Low; low01 = $m.Low01; lowRatio = $m.LowRatio; hitchesPerMin = $m.HitchesPerMin
                    gpu = $m.Gpu; core = $m.Core; vram = $m.Vram
                    fgActive = [bool]$m.Fg; fg = "$($m.FgText)"; baseAvg = $m.BaseAvg; baseLow = $m.BaseLow
                    runs = $m.Runs; tips = @($m.Tips | ForEach-Object { "$_" })
                })
            }
            $tuning = @()
            foreach ($id in $script:GameProfiles.Keys) {
                $g = Get-GtGame $id
                $tuning += ,([ordered]@{
                    id = $id; name = $script:GameProfiles[$id].Name; level = [int]$g.Level
                    levelName = $(if ($g.Level -ge 1) { $script:LevelNames[[int]$g.Level] } else { '' })
                    pending = $g.PendingLevel; recommended = $script:GTRecCache[$id]; status = "$($g.LastAction)"
                })
            }
            $data = [ordered]@{
                target = (Get-GtTarget)
                monitorHz = $(if ($script:GTMonitor) { $script:GTMonitor.MaxHz } else { $null })
                games = $games
                tuning = $tuning
            }
            $global:GSXState.GamesJson = ($data | ConvertTo-Json -Depth 6 -Compress)
        }
        catch { }
    }

    # Laufendes Spiel / Messung fuer die Handy-App (/api/stats -> "game")
    function Update-GtGameStatus {
        $json = 'null'
        $sessions = @($script:GTRunning.Values)
        if ($sessions.Count -gt 0) {
            $s = $sessions[0]
            $measuring = [bool]$script:GTCapture
            $left = $null; $wait = $null
            if ($measuring) { $left = [math]::Max(0, 120 - [int]((Get-Date) - $script:GTCapture.Started).TotalSeconds) }
            elseif (-not $s.Measured -and $gtAuto.Checked) { $wait = [math]::Max(0, 90 - [int]((Get-Date) - $s.Start).TotalSeconds) }
            $json = ([ordered]@{ name = "$($s.Game.Name)"; measuring = $measuring; secondsLeft = $left; waitSeconds = $wait } | ConvertTo-Json -Compress)
        }
        $global:GSXState.GameStatusJson = $json
    }

    function Save-GtState {
        $script:GTState.Settings.CapToHz = $gtCap.Checked
        $script:GTState.Settings.AutoTune = $gtAuto.Checked
        Save-GSXGameState $script:GTState
        Update-GtPhoneData
    }

    function Update-GtList {
        $selected = Get-GtSelectedId
        $gtList.BeginUpdate()
        $gtList.Items.Clear()
        foreach ($id in $script:GameProfiles.Keys) {
            $gp = $script:GameProfiles[$id]
            $g = Get-GtGame $id
            $files = @(Get-GSXGameConfigFiles $id)
            $rec = Get-GSXRecommendedLevel -GameId $id -Monitor $script:GTMonitor
            $script:GTRecCache[$id] = $rec
            $lvi = New-Object System.Windows.Forms.ListViewItem($gp.Name)
            [void]$lvi.SubItems.Add($(if ($files.Count -gt 0) { "gefunden" } else { "nicht gefunden" }))
            $levelText = if ($g.Level -ge 1) { "$($g.Level) - $($script:LevelNames[[int]$g.Level])" } else { "nicht gesetzt" }
            if ($null -ne $g.PendingLevel) { $levelText += " -> $($g.PendingLevel)" }
            [void]$lvi.SubItems.Add($levelText)
            [void]$lvi.SubItems.Add("$rec - $($script:LevelNames[$rec])")
            [void]$lvi.SubItems.Add($(if (Test-GSXGameRunning $id) { "LAEUFT" } else { "$($g.LastAction)" }))
            $lvi.Tag = $id
            $lvi.ForeColor = if ($files.Count -eq 0) { [System.Drawing.Color]::Silver } elseif ($g.Level -ge 1) { $Colors.Green } else { $Colors.Text }
            [void]$gtList.Items.Add($lvi)
            if ($id -eq $selected) { $lvi.Selected = $true }
        }
        $gtList.EndUpdate()
    }

    $script:GTLibrary = @{}
    $script:GTForceMeasure = $null

    function Update-GtMeasList {
        $gtMeasList.BeginUpdate()
        $gtMeasList.Items.Clear()

        # Bibliothek einlesen (Name -> Eintrag mit Quelle/Startbefehl)
        $library = @()
        try { $library = @(Get-GSXGameLibrary) } catch { }
        $script:GTLibrary = @{}
        foreach ($g in $library) { $script:GTLibrary[(Get-GSXNormName $g.Name)] = $g }

        # 1) Gemessene Spiele (neueste zuerst)
        $entries = @($script:GTState.Measured.GetEnumerator() | Sort-Object { $_.Value.Date } -Descending)
        $measuredNames = @{}
        foreach ($e in $entries) {
            $m = $e.Value
            $norm = Get-GSXNormName $m.Name
            $measuredNames[$norm] = $true
            $lib = $script:GTLibrary[$norm]
            $lvi = New-Object System.Windows.Forms.ListViewItem("$($m.Name)")
            foreach ($v in @($(if ($lib) { $lib.Source } else { "-" }), $m.Rating, $m.Avg, $m.Low, $m.Low01, "$($m.LowRatio) %",
                             $(if ($null -ne $m.HitchesPerMin) { "$($m.HitchesPerMin)" } else { "($($m.Stutter) %)" }),
                             $(if ($null -ne $m.Gpu) { "$($m.Gpu) %" } else { "-" }),
                             $(if ($null -ne $m.Core) { "$($m.Core) %" } elseif ($null -ne $m.Cpu) { "($($m.Cpu) %)" } else { "-" }),
                             $(if ($null -ne $m.Vram) { "$($m.Vram) %" } else { "-" }),
                             $(if ($m.Fg) { "an, echt $($m.BaseAvg)" } elseif ($m.FgText) { "$($m.FgText)" } else { "aus" }),
                             $m.Runs, $(try { ([datetime]$m.Date).ToString('dd.MM. HH:mm') } catch { "" }))) {
                [void]$lvi.SubItems.Add("$v")
            }
            $lvi.Tag = $e.Key
            $lvi.ForeColor = switch ("$($m.Rating)") { 'GUT' { $Colors.Green } 'GELEGENTLICH' { $Colors.Yellow } 'MITTEL' { $Colors.Yellow } 'RUCKLER' { $Colors.Red } 'AUFWAERMEN' { $Colors.Blue } default { $Colors.Text } }
            [void]$gtMeasList.Items.Add($lvi)
        }

        # 2) Alle installierten, noch nicht gemessenen Spiele
        $open = @($library | Where-Object { -not $measuredNames.ContainsKey((Get-GSXNormName $_.Name)) })
        foreach ($g in $open) {
            $lvi = New-Object System.Windows.Forms.ListViewItem($g.Name)
            [void]$lvi.SubItems.Add($g.Source)
            [void]$lvi.SubItems.Add("noch nicht gemessen")
            $lvi.Tag = "unmeasured:$($g.Name)"
            $lvi.ForeColor = $Colors.Dim
            [void]$gtMeasList.Items.Add($lvi)
        }
        if ($entries.Count -eq 0 -and $open.Count -eq 0) {
            $lvi = New-Object System.Windows.Forms.ListViewItem("Keine Spiele gefunden")
            $lvi.ForeColor = $Colors.Dim
            [void]$gtMeasList.Items.Add($lvi)
        }
        $gtMeasList.EndUpdate()

        $total = $entries.Count + $open.Count
        $gtMeasTitle.Text = "SPIELEBIBLIOTHEK  -  $($entries.Count) von $total gemessen (Schwerpunkt 1%-Low)"
        $startable = @($library | Where-Object { $_.Launch }).Count
        $gtLibInfo.Text = "$($library.Count) Spiele gefunden, $startable direkt startbar"
    }

    # Ausgewaehlter Eintrag -> Bibliothekseintrag (falls vorhanden)
    function Get-GtSelectedLibraryGame {
        if ($gtMeasList.SelectedItems.Count -eq 0) { return $null }
        $item = $gtMeasList.SelectedItems[0]
        return $script:GTLibrary[(Get-GSXNormName $item.Text)]
    }

    function Update-GtMonitor {
        $script:GTMonitor = Get-GSXMonitorInfo
        $gpu = Get-GSXGpuScore
        $m = $script:GTMonitor
        if ($m -and $m.MaxHz -ge 30) {
            $text = "Monitor: $($m.Width) x $($m.Height) · $($m.Hz) Hz (max. $($m.MaxHz) Hz)   ·   GPU: $($gpu.Name)   ·   Ziel: $(Get-GtTarget) FPS"
            if ($m.Hz -lt $m.MaxHz) {
                $text += "`nACHTUNG: Windows laeuft nur mit $($m.Hz) Hz! Einstellungen > Anzeige > Erweitert > Bildwiederholrate auf $($m.MaxHz) Hz."
                $gtMonitor.ForeColor = $Colors.Yellow
            }
            else { $gtMonitor.ForeColor = $Colors.Text }
            $gtMonitor.Text = $text
        }
        else {
            $gtMonitor.ForeColor = $Colors.Yellow
            $gtMonitor.Text = "Monitor konnte nicht ausgelesen werden - Ziel vorerst 60 FPS."
        }
    }

    function Set-GtLevel([string]$id, [int]$level, [string]$why) {
        $gp = $script:GameProfiles[$id]
        $g = Get-GtGame $id
        $level = [math]::Max(1, [math]::Min(5, $level))
        try {
            $n = Set-GSXGameLevel -GameId $id -Level $level -TargetFps (Get-GtTarget) -Monitor $script:GTMonitor -CapToHz $gtCap.Checked
            $g.Level = $level; $g.PendingLevel = $null
            $g.LastAction = "Stufe $level gesetzt"
            Add-GtLog "$($gp.Name): Stufe $level ($($script:LevelNames[$level])) geschrieben ($n Datei/en). $why"
        }
        catch {
            if (Test-GSXGameRunning $id) {
                $g.PendingLevel = $level
                $g.LastAction = "Stufe $level nach Spielende"
                Add-GtLog "$($gp.Name) laeuft - Stufe $level wird nach dem Beenden uebernommen."
            }
            else { Add-GtLog "$($gp.Name): FEHLER - $($_.Exception.Message)" }
        }
        Save-GtState
        Update-GtList
    }

    function Start-GtCapture($game, [string]$reason, [switch]$NoFrameType) {
        if ($script:GTCapture) { Add-GtLog "Es laeuft bereits eine Messung."; return }
        try {
            if (-not (Test-Path -LiteralPath $script:PresentMonExe)) { Add-GtLog "Lade Intel PresentMon herunter (einmalig) ..." }
            $script:GTCapture = Start-GSXFpsCapture -Key $game.Key -Exe $game.Exe -Name $game.Name -ProfileId $game.ProfileId -Path $game.Path -Seconds 120 -NoFrameType:$NoFrameType
            if ($script:GTRunning.ContainsKey($game.Key)) { $script:GTRunning[$game.Key].Measured = $true }
            Add-GtLog "$($game.Name): Messung laeuft (2 Minuten) - $reason"
        }
        catch { Add-GtLog "Messung nicht moeglich: $($_.Exception.Message)" }
    }

    function Complete-GtCapture {
        $cap = $script:GTCapture
        $script:GTCapture = $null
        $target = Get-GtTarget
        $fgStatus = Get-GSXFgStatus -ExePath $cap.Path -Key $cap.Key
        $result = Get-GSXCaptureResult -Capture $cap -TargetFps $target
        if (-not $result) {
            $ranSec = [int]((Get-Date) - $cap.Started).TotalSeconds
            if ($ranSec -lt 30) {
                # PresentMon hat sich sofort beendet -> Fehlermeldung zeigen
                Add-GtLog "$($cap.Name): PresentMon hat nach $ranSec s abgebrochen. Ausgabe:"
                $out = @(Get-GSXCaptureOutput $cap)
                if ($out.Count -eq 0) { Add-GtLog "   (keine Ausgabe)" }
                foreach ($l in $out) { Add-GtLog "   > $l" }
                $session = $script:GTRunning[$cap.Key]
                if ($cap.FrameType -and $session) {
                    Add-GtLog "   Neuer Versuch ohne Frame-Typ-Erkennung (Beta-Option) ..."
                    Start-GtCapture $session.Game "Wiederholung ohne --track_frame_type" -NoFrameType
                }
                elseif ($session) {
                    $session.Measured = $true   # keine Endlosschleife
                    Add-GtLog "   Messung fuer dieses Spiel nicht moeglich. Bitte die Ausgabe oben an den Entwickler schicken."
                }
            }
            else {
                Add-GtLog "$($cap.Name): Messung ohne Ergebnis (zu wenige Frames - Spiel minimiert?)."
            }
            return
        }
        if (-not $result.Valid) {
            Add-GtLog "$($cap.Name): Messung NICHT AUSSAGEKRAEFTIG - $($result.Reason)."
            Add-GtLog "   Nur $($result.ActiveSec) s echtes Spielgeschehen (verworfen: Hintergrund $($result.BackgroundSec) s, Menue/Limit $($result.LimitedSec) s). Fruehere Messung bleibt erhalten."
            Add-GtLog "   Tipp: 2 Minuten normal im Spiel unterwegs sein - ohne Menue, Karte oder Alt+Tab. 'Laufendes Spiel messen' startet eine neue Messung."
            if ($script:GTRunning.ContainsKey($cap.Key)) { $script:GTRunning[$cap.Key].Measured = $false; $script:GTRunning[$cap.Key].Start = Get-Date }
            return
        }
        # FG laut Spieleinstellung an, PresentMon meldet nichts -> echte FPS aus dem Faktor berechnen
        if ($fgStatus.State -eq 'on' -and -not $result.FgActive) {
            $result.FgActive = $true
            $result.BaseAvg = [math]::Round($result.AvgFps / $fgStatus.Multiplier)
            $result.BaseLow = [math]::Round($result.LowFps / $fgStatus.Multiplier)
        }
        elseif ($fgStatus.State -eq 'off' -and $result.FgActive) {
            $fgStatus.Source = "PresentMon (Spieldatei sagt aus)"
        }
        $advice = Get-GSXFpsAdvice -Result $result -TargetFps $target -FgStatus $fgStatus
        $old = $script:GTState.Measured[$cap.Key]

        # Erste Messung nach Neuinstallation, Spiel- oder Treiber-Update = Shader-Kompilierung -> nicht bewerten
        $exeTime = $null
        if ($cap.Path) {
            try { $ei = Get-Item -LiteralPath $cap.Path -ErrorAction Stop; $exeTime = "$($ei.LastWriteTime.ToString('s'))|$($ei.Length)" } catch { }
        }
        $driver = $null
        $snap = $global:GSXState.Snapshot
        if ($snap -and $snap.GPU) { $driver = "$($snap.GPU.Driver)" }
        $warmupReason = $null
        if (-not $old) { $warmupReason = "erste Messung dieses Spiels" }
        elseif ($exeTime -and $old.ExeTime -and $old.ExeTime -ne $exeTime) { $warmupReason = "Spiel wurde aktualisiert" }
        elseif ($driver -and $old.Driver -and $old.Driver -ne $driver) { $warmupReason = "Grafiktreiber wurde aktualisiert" }
        $isWarmup = [bool]$warmupReason
        if ($isWarmup) {
            $advice = [PSCustomObject]@{
                Rating = 'AUFWAERMEN'
                Tips = @("Aufwaermrunde ($warmupReason): Shader werden kompiliert, Ruckler sind normal - wird nicht bewertet. Die naechste Runde zaehlt.") + @($advice.Tips)
            }
        }

        $count = if ($old -and $old.Runs) { [int]$old.Runs + 1 } else { 1 }
        $script:GTState.Measured[$cap.Key] = @{
            Name = $cap.Name; Exe = $cap.Exe; Runs = $count; Date = (Get-Date).ToString('s'); Target = $target
            Avg = $result.AvgFps; Low = $result.LowFps; Low01 = $result.Low01Fps; LowRatio = $result.LowRatio
            Stutter = $result.StutterPct; Gpu = $result.GpuAvg; Cpu = $result.CpuAvg; Core = $result.CoreMax; Vram = $result.VramPct
            Fg = $result.FgActive; FgText = (Get-GSXFgText $fgStatus); BaseAvg = $result.BaseAvg; BaseLow = $result.BaseLow
            HitchesPerMin = $result.HitchesPerMin
            ExeTime = $exeTime; Driver = $driver
            Rating = $advice.Rating; Tips = @($advice.Tips)
        }

        Add-GtLog "$($cap.Name): ausgewertet $($result.ActiveSec) s Spielgeschehen (verworfen: Hintergrund $($result.BackgroundSec) s, Menue/Limit $($result.LimitedSec) s, Zeitspalte: $($result.TimeColumn))"
        $fgSrc = if ($fgStatus.Source) { " - $($fgStatus.Source)" } else { "" }
        Add-GtLog "   Frame Generation: $(Get-GSXFgText $fgStatus)$fgSrc"
        Add-GtLog ("$($cap.Name): Ø $($result.AvgFps) FPS · 1%-Low $($result.LowFps) · 0,1%-Low $($result.Low01Fps) · " +
                   "Haenger $($result.HitchesPerMin)/min · GPU $($result.GpuAvg) % · CPU $($result.CpuAvg) % (Kern max. $($result.CoreMax) %) · VRAM $($result.VramPct) %  => $($advice.Rating)")
        foreach ($t in $advice.Tips) { Add-GtLog "   - $t" }

        if ($result.FgActive) { Add-GtLog "   Frame Generation aktiv - echte FPS: Ø $($result.BaseAvg), 1%-Low $($result.BaseLow)" }

        # CS2 / BF6: Stufe automatisch anpassen (nicht nach Aufwaermrunde)
        if ($cap.ProfileId -and $isWarmup) {
            Add-GtLog "   Auto-Tuning: Aufwaermrunde - Stufe bleibt, naechste Messung entscheidet."
        }
        elseif ($cap.ProfileId) {
            $id = $cap.ProfileId
            $g = Get-GtGame $id
            $g.LastAvg = $result.AvgFps; $g.LastLow = $result.LowFps; $g.LastGpu = $result.GpuAvg
            $current = if ($g.Level -ge 1) { [int]$g.Level } else { Get-GSXRecommendedLevel -GameId $id -Monitor $script:GTMonitor }
            $decision = Get-GSXLevelDecision -Level $current -Result $result -TargetFps $target
            if ($result.FgActive -and $null -ne $result.BaseAvg -and $result.BaseAvg -lt 55 -and $current -gt 1) {
                $decision = @{ Level = $current - 1; Reason = "Frame Generation aktiv, aber nur $($result.BaseAvg) echte FPS -> eine Stufe runter" }
            }
            # Haenger nur dann ueber die Grafikstufe angehen, wenn die GPU wirklich ausgelastet ist
            # oder der VRAM voll ist - sonst kommen sie von CPU, Streaming oder Shadern.
            $gpuBusy = ($null -ne $result.GpuAvg -and $result.GpuAvg -ge 80) -or ($null -ne $result.VramPct -and $result.VramPct -ge 90)
            if ($result.HitchesPerMin -gt 10 -and $gpuBusy -and $decision.Level -ge $current -and $current -gt 1) {
                $decision = @{ Level = $current - 1; Reason = "$($result.HitchesPerMin) Haenger/Minute -> eine Stufe runter fuer stabilere Frametimes" }
            }
            Add-GtLog "   Auto-Tuning: $($decision.Reason)"
            if ($decision.Level -ne $current) {
                $g.PendingLevel = $decision.Level
                $g.LastAction = "Stufe $($decision.Level) nach Spielende"
            }
            else { $g.LastAction = "passt (Stufe $current)" }
        }
        Save-GtState
        if ($gameTunePanel.Visible) { Update-GtList; Update-GtMeasList }
    }

    # Wird vom Haupt-Timer aufgerufen (alle 0,5 s), arbeitet alle 5 s.
    function Invoke-GtBackground {
        if (((Get-Date) - $script:GTLastCheck).TotalSeconds -lt 5) { return }
        $script:GTLastCheck = Get-Date
        $changed = $false

        if ($script:GTCapture) {
            $snap = $global:GSXState.Snapshot
            $fgName = Get-GSXForegroundProcessName
            $gameName = [System.IO.Path]::GetFileNameWithoutExtension($script:GTCapture.Exe)
            [void]$script:GTCapture.Samples.Add([PSCustomObject]@{
                T     = ((Get-Date) - $script:GTCapture.Started).TotalSeconds
                Focus = ($null -eq $fgName -or $fgName -eq $gameName)
                Gpu   = $(if ($snap -and $snap.GPU -and $null -ne $snap.GPU.Usage) { [double]$snap.GPU.Usage } else { $null })
                Cpu   = $(if ($snap -and $snap.CPU -and $null -ne $snap.CPU.Load) { [double]$snap.CPU.Load } else { $null })
                Core  = $(if ($snap -and $snap.CPU -and $null -ne $snap.CPU.CoreMax) { [double]$snap.CPU.CoreMax } else { $null })
                Vram  = $(if ($snap -and $snap.GPU -and $snap.GPU.VRAM -gt 0) { [double]($snap.GPU.VRAMUsed / $snap.GPU.VRAM * 100) } else { $null })
            })
            if ($script:GTCapture.Process.HasExited) { Complete-GtCapture; $changed = $true }
        }

        $game = Find-GSXRunningGame -PreferKeys @($script:GTRunning.Keys)
        $runningKey = if ($game) { $game.Key } else { $null }

        if ($game -and -not $script:GTRunning.ContainsKey($game.Key)) {
            $script:GTRunning[$game.Key] = @{ Start = Get-Date; Measured = $false; Game = $game }
            Add-GtLog "$($game.Name) erkannt ($($game.Exe))."
            $changed = $true
        }
        elseif ($game -and ($gtAuto.Checked -or $script:GTForceMeasure) -and -not $script:GTCapture) {
            $session = $script:GTRunning[$game.Key]
            if (-not $session.Measured -and ((Get-Date) - $session.Start).TotalSeconds -ge 90) {
                $why = if ($script:GTForceMeasure) { "per Knopf gestartet" } else { "automatisch nach 90 s Spielzeit" }
                Start-GtCapture $game $why
                $script:GTForceMeasure = $null
            }
        }

        foreach ($key in @($script:GTRunning.Keys)) {
            if ($key -eq $runningKey) { continue }
            $session = $script:GTRunning[$key]
            $script:GTRunning.Remove($key)
            Add-GtLog "$($session.Game.Name) beendet."
            $id = $session.Game.ProfileId
            if ($id) {
                $g = Get-GtGame $id
                if ($null -ne $g.PendingLevel) {
                    Start-Sleep -Seconds 2   # Spiel schreibt beim Beenden seine Einstellungen
                    Set-GtLevel $id ([int]$g.PendingLevel) "(automatisch nach Messung)"
                }
            }
            $changed = $true
        }

        if ($changed -and $gameTunePanel.Visible) { Update-GtList; Update-GtMeasList }
        Update-GtGameStatus
        if ($changed) { Update-GtPhoneData }
    }

    function Update-GameTuningView {
        Update-GtMonitor
        Update-GtList
        Update-GtMeasList
        if ($gtLog.TextLength -eq 0) {
            Add-GtLog "Jedes Spiel (Steam, Epic, EA, Ubisoft, Battle.net, Xbox) wird automatisch erkannt und nach 90 s fuer 2 Minuten gemessen."
            Add-GtLog "CS2/BF6: vorher OPTIMIEREN klicken - danach wird die Grafikstufe nach jeder Messung automatisch angepasst."
            Add-GtLog "Tipp: DLSS im Spiel auf 'Qualitaet', NVIDIA Reflex auf 'An + Boost'."
        }
    }

    $gtCap.Add_CheckedChanged({ Save-GtState; if ($gameTunePanel.Visible) { Update-GtMonitor } })
    $gtAuto.Add_CheckedChanged({ Save-GtState })

    function Show-GtTips {
        if ($gtMeasList.SelectedItems.Count -eq 0) { Add-GtLog "Bitte zuerst ein Spiel in der Liste auswaehlen."; return }
        $key = $gtMeasList.SelectedItems[0].Tag
        if (-not $key) { return }
        if ("$key".StartsWith('unmeasured:')) {
            Add-GtLog "$($key.Substring(11)): noch nicht gemessen - einfach spielen, nach 90 s wird automatisch 2 Minuten gemessen."
            return
        }
        $m = $script:GTState.Measured[$key]
        Add-GtLog "Empfehlungen fuer $($m.Name) (Ziel $($m.Target) FPS, Bewertung $($m.Rating)):"
        foreach ($t in @($m.Tips)) { Add-GtLog "   - $t" }
    }
    $gtMeasList.Add_DoubleClick({ Show-GtTips })
    $gtTipsButton.Add_Click({ Show-GtTips })

    $gtStartButton.Add_Click({
        $id = Get-GtSelectedId; if (-not $id) { return }
        Set-GtLevel $id (Get-GSXRecommendedLevel -GameId $id -Monitor $script:GTMonitor) "(Startwert nach Hardware)"
    })
    $gtUpButton.Add_Click({
        $id = Get-GtSelectedId; if (-not $id) { return }
        $g = Get-GtGame $id
        $base = if ($g.Level -ge 1) { [int]$g.Level } else { Get-GSXRecommendedLevel -GameId $id -Monitor $script:GTMonitor }
        Set-GtLevel $id ($base + 1) "(manuell: mehr Qualitaet)"
    })
    $gtDownButton.Add_Click({
        $id = Get-GtSelectedId; if (-not $id) { return }
        $g = Get-GtGame $id
        $base = if ($g.Level -ge 1) { [int]$g.Level } else { Get-GSXRecommendedLevel -GameId $id -Monitor $script:GTMonitor }
        Set-GtLevel $id ($base - 1) "(manuell: mehr FPS)"
    })
    $gtMeasureButton.Add_Click({
        $game = Find-GSXRunningGame
        if (-not $game) { Add-GtLog "Kein laufendes Spiel erkannt. Spiel starten - die Messung beginnt automatisch."; return }
        if (-not $script:GTRunning.ContainsKey($game.Key)) {
            $script:GTRunning[$game.Key] = @{ Start = Get-Date; Measured = $false; Game = $game }
        }
        Start-GtCapture $game "manuell gestartet"
    })
    # Handy-Daten beim Start bereitstellen
    $script:GTMonitor = Get-GSXMonitorInfo
    foreach ($id in $script:GameProfiles.Keys) {
        try { $script:GTRecCache[$id] = Get-GSXRecommendedLevel -GameId $id -Monitor $script:GTMonitor } catch { }
    }
    Update-GtPhoneData

    $gtLaunchButton.Add_Click({
        $g = Get-GtSelectedLibraryGame
        if (-not $g) { Add-GtLog "Bitte zuerst ein Spiel in der Bibliothek auswaehlen."; return }
        if (-not $g.Launch) {
            Add-GtLog "$($g.Name) ($($g.Source)): kein direkter Startbefehl - bitte ueber den Launcher starten. Die Messung laeuft trotzdem automatisch."
            $script:GTForceMeasure = $true
            return
        }
        try {
            Start-GSXLibraryGame $g
            $script:GTForceMeasure = $true
            Add-GtLog "$($g.Name) wird gestartet ($($g.Source)) - Messung beginnt 90 s nach Spielstart (2 Minuten). Normal spielen, nicht im Menue bleiben."
        }
        catch { Add-GtLog "Start fehlgeschlagen: $($_.Exception.Message)" }
    })

    $gtRescanButton.Add_Click({
        $script:GameFolderCache = $null
        Update-GtMeasList
        Add-GtLog "Bibliothek neu eingelesen."
    })

    $gtRestoreButton.Add_Click({
        $id = Get-GtSelectedId; if (-not $id) { return }
        try {
            $n = Restore-GSXGameFiles $id
            $g = Get-GtGame $id
            $g.Level = 0; $g.PendingLevel = $null; $g.LastAction = "Original"
            Save-GtState
            Add-GtLog "$($script:GameProfiles[$id].Name): $n Datei(en) auf Original zurueckgesetzt."
            Update-GtList
        }
        catch { Add-GtLog "FEHLER: $($_.Exception.Message)" }
    })

    # ======================================================
    # Optimizer Page - Hardware-Diagnose & Gaming-Optimierung
    # ======================================================

    $optimizerPanel = New-Object System.Windows.Forms.Panel
    $optimizerPanel.Location = New-Object System.Drawing.Point(240,90)
    $optimizerPanel.Size = New-Object System.Drawing.Size(1120,680)
    $optimizerPanel.BackColor = $Colors.Background
    $optimizerPanel.Visible = $false
    $form.Controls.Add($optimizerPanel)

    $optimizerTitle = New-Object System.Windows.Forms.Label
    $optimizerTitle.UseMnemonic = $false
    $optimizerTitle.Text = "Hardware-Diagnose & Gaming-Optimierung"
    $optimizerTitle.Location = New-Object System.Drawing.Point(15,5)
    $optimizerTitle.Size = New-Object System.Drawing.Size(700,35)
    $optimizerTitle.ForeColor = $Colors.Text
    $optimizerTitle.Font = New-Object Drawing.Font("Segoe UI",16,[Drawing.FontStyle]::Bold)
    $optimizerPanel.Controls.Add($optimizerTitle)

    $tuningScore = New-Object System.Windows.Forms.Label
    $tuningScore.Location = New-Object System.Drawing.Point(720,10)
    $tuningScore.Size = New-Object System.Drawing.Size(385,30)
    $tuningScore.ForeColor = $Colors.Green
    $tuningScore.Font = New-Object Drawing.Font("Segoe UI",12,[Drawing.FontStyle]::Bold)
    $tuningScore.TextAlign = "MiddleRight"
    $optimizerPanel.Controls.Add($tuningScore)

    $tuningList = New-GSXListView
    $tuningList.Location = New-Object System.Drawing.Point(15,48)
    $tuningList.Size = New-Object System.Drawing.Size(1090,455)
    $tuningList.View = "Details"
    $tuningList.FullRowSelect = $true
    $tuningList.CheckBoxes = $true
    $tuningList.HeaderStyle = "Nonclickable"
    $tuningList.BackColor = $Colors.Card
    $tuningList.ForeColor = $Colors.Text
    $tuningList.BorderStyle = "None"
    $tuningList.Font = New-Object Drawing.Font("Segoe UI",10)
    [void]$tuningList.Columns.Add("Bereich", 105)
    [void]$tuningList.Columns.Add("Einstellung", 300)
    [void]$tuningList.Columns.Add("Status", 110)
    [void]$tuningList.Columns.Add("Aktuell", 270)
    [void]$tuningList.Columns.Add("Empfehlung / Hinweis", 300)
    $optimizerPanel.Controls.Add($tuningList)

    # Haken nur bei Punkten erlauben, die sich per Software aendern lassen.
    $tuningList.Add_ItemCheck({
        param($sender, $e)
        $item = $sender.Items[$e.Index].Tag
        if (-not $item -or -not $item.Fixable) { $e.NewValue = $e.CurrentValue }
    })

    $tuningInfo = New-Object System.Windows.Forms.Label
    $tuningInfo.Location = New-Object System.Drawing.Point(15,510)
    $tuningInfo.Size = New-Object System.Drawing.Size(1090,58)
    $tuningInfo.ForeColor = $Colors.Text
    $tuningInfo.Font = New-Object Drawing.Font("Segoe UI",10)
    $tuningInfo.Text = "Wird geprueft ..."
    $optimizerPanel.Controls.Add($tuningInfo)

    function New-TuningButton($text, $x, $color) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text
        $b.Location = New-Object System.Drawing.Point($x, 575)
        $b.Size = New-Object System.Drawing.Size(172,45)
        $b.ForeColor = $Colors.Text
        $b.BackColor = $color
        $b.FlatStyle = "Flat"
        $b.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
        $optimizerPanel.Controls.Add($b)
        return $b
    }

    $tuneCheckButton    = New-TuningButton "Erneut pruefen"           15 $Colors.Card
    $tuneAllButton      = New-TuningButton "ALLES OPTIMIEREN"        198 ([System.Drawing.Color]::FromArgb(0,140,60))
    $tuneSelectedButton = New-TuningButton "Auswahl optimieren"      381 $Colors.Card
    $tuneResetButton    = New-TuningButton "Alles zuruecksetzen"     564 $Colors.Card
    $tuneHvciButton     = New-TuningButton "Speicher-Integritaet ..." 747 ([System.Drawing.Color]::FromArgb(110,40,40))
    $clearTempButton    = New-TuningButton "Temp-Dateien loeschen"   930 $Colors.Card

    function Update-TuningView {
        param([string]$Message = "")

        $tuningInfo.Text = "Hardware und Einstellungen werden geprueft ..."
        $optimizerPanel.Refresh()

        $items = @(Get-GSXTuningReport)

        $tuningList.BeginUpdate()
        $tuningList.Items.Clear()
        foreach ($it in $items) {
            $lvi = New-Object System.Windows.Forms.ListViewItem($it.Category)
            [void]$lvi.SubItems.Add($it.Name)
            [void]$lvi.SubItems.Add($it.Status)
            [void]$lvi.SubItems.Add($it.Current)
            $hint = $it.Recommended
            if ($it.Restart -and $it.Fixable -and $it.Ok -ne $true) { $hint = "$hint (Neustart)" }
            # Bereits optimal -> klar als erledigt kennzeichnen statt nur den Zielwert zu zeigen
            if ($it.Ok -eq $true -and $it.Status -eq 'OPTIMAL') { $hint = "$([char]0x2713) erledigt  ($($it.Recommended))" }
            [void]$lvi.SubItems.Add($hint)
            $lvi.Tag = $it
            $lvi.ForeColor = switch ($it.Status) {
                'OPTIMAL'     { $Colors.Green }
                'NICHT AKTIV' { $Colors.Red }
                'AN'          { $Colors.Yellow }
                'BIOS'        { $Colors.Red }
                'HARDWARE'    { $Colors.Yellow }
                'HINWEIS'     { $Colors.Yellow }
                'PRUEFEN'     { $Colors.Yellow }
                'GESCHUETZT'  { $Colors.Blue }
                'OPTIONAL'    { $Colors.Dim }
                default       { [System.Drawing.Color]::Silver }
            }
            [void]$tuningList.Items.Add($lvi)
            $lvi.Checked = ($it.Fixable -and $it.OneClick -and $it.Ok -eq $false)   # optionale Punkte nur per Hand
        }
        $tuningList.EndUpdate()

        $fixable = @($items | Where-Object { $_.Fixable -and $_.OneClick })
        $done = @($fixable | Where-Object { $_.Ok -eq $true })
        $tuningScore.Text = "Optimiert: $($done.Count) von $($fixable.Count)"
        $tuningScore.ForeColor = if ($done.Count -eq $fixable.Count) { $Colors.Green } else { $Colors.Yellow }

        $bios = @($items | Where-Object { $_.Status -eq 'BIOS' -or $_.Status -eq 'HARDWARE' })
        $text = ""
        if ($Message) { $text += "$Message`n" }
        if (-not (Test-GSXAdmin)) {
            $text += "ACHTUNG: Ohne Administrator-Rechte koennen viele Einstellungen nicht geaendert werden. GamingSuite X als Administrator starten.`n"
        }
        if ($bios.Count -gt 0) {
            $text += "Im BIOS / an der Hardware zu erledigen: " + (($bios | ForEach-Object { $_.Name }) -join ", ") + "`n"
        }
        if (Test-GSXTuningBackup) {
            $text += "Backup der Originaleinstellungen vorhanden - 'Alles zuruecksetzen' stellt den Ursprungszustand wieder her."
        }
        $tuningInfo.Text = $text.Trim()
    }

    function Show-TuningResult($result, [string]$title) {
        $ok = @($result.Results | Where-Object { $_.Success })
        $failed = @($result.Results | Where-Object { -not $_.Success })
        $msg = "$($ok.Count) Einstellungen erledigt."
        if ($failed.Count -gt 0) {
            $msg += "`n`nFehlgeschlagen:`n" + (($failed | ForEach-Object { "- $($_.Name): $($_.Message)" }) -join "`n")
        }
        if ($result.RestartRequired) {
            $msg += "`n`nEinige Aenderungen wirken erst nach einem NEUSTART."
        }
        [void][System.Windows.Forms.MessageBox]::Show($msg, $title, 'OK', 'Information')
        $summary = "$title abgeschlossen: $($ok.Count) erledigt, $($failed.Count) Fehler."
        if ($result.RestartRequired) { $summary += " Neustart empfohlen." }
        Update-TuningView $summary
    }

    $tuneCheckButton.Add_Click({ Update-TuningView })

    $tuneAllButton.Add_Click({
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Es werden nur die risikoarmen Einstellungen gesetzt (Spielmodus, GPU-Planung, Game DVR aus).`n`n" +
            "NICHT veraendert werden: Energiesparplan, CPU-Mindestleistung, Power Throttling (mehr Stromverbrauch),`n" +
            "Speicher-Integritaet und die uebrigen optionalen Punkte (MMCSS, Maus, Netzwerk). Windows-Dienste werden nie angefasst.`n" +
            "Optionale Punkte kannst du einzeln ankreuzen und mit 'Auswahl optimieren' setzen.`n" +
            "die kannst du einzeln ankreuzen und mit 'Auswahl optimieren' setzen.`n" +
            "Vorher wird ein Backup angelegt - alles laesst sich zuruecksetzen.`n`nFortfahren?",
            "Alles optimieren", 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        $tuningInfo.Text = "Optimiere ..."
        $optimizerPanel.Refresh()
        Show-TuningResult (Invoke-GSXOptimization -OneClick) "Optimierung"
    })

    $tuneSelectedButton.Add_Click({
        $ids = @($tuningList.CheckedItems | ForEach-Object { $_.Tag } | Where-Object { $_.Fixable } | ForEach-Object { $_.Id })
        if ($ids.Count -eq 0) {
            [void][System.Windows.Forms.MessageBox]::Show("Bitte zuerst Einstellungen mit einem Haken auswaehlen.", "Auswahl optimieren")
            return
        }
        if ($ids -contains 'hvci') {
            $warn = [System.Windows.Forms.MessageBox]::Show(
                "Die Auswahl enthaelt 'Speicher-Integritaet'. Ausschalten bringt mehr Leistung, senkt aber den Schutz vor Schadsoftware.`n`nTrotzdem ausschalten?",
                "Sicherheitshinweis", 'YesNo', 'Warning')
            if ($warn -ne 'Yes') { $ids = @($ids | Where-Object { $_ -ne 'hvci' }) }
        }
        if ($ids -contains 'powerplan' -or $ids -contains 'cpupark' -or $ids -contains 'throttling') {
            $warn = [System.Windows.Forms.MessageBox]::Show(
                "Die Auswahl enthaelt Energie-Einstellungen (Energiesparplan / CPU-Mindestleistung / Power Throttling).`n`n" +
                "Das kann in Spielen etwas bringen, erhoeht aber den Stromverbrauch - auch im Leerlauf, je nach PC um ca. 10-50 W.`n" +
                "Bei Laptops sinkt die Akkulaufzeit. 'Alles zuruecksetzen' stellt den alten Zustand wieder her.`n`nTrotzdem setzen?",
                "Hinweis Stromverbrauch", 'YesNo', 'Warning')
            if ($warn -ne 'Yes') { $ids = @($ids | Where-Object { $_ -notin @('powerplan', 'cpupark', 'throttling') }) }
        }
        if ($ids.Count -eq 0) { return }
        $tuningInfo.Text = "Optimiere Auswahl ..."
        $optimizerPanel.Refresh()
        Show-TuningResult (Invoke-GSXOptimization -Ids $ids) "Auswahl optimieren"
    })

    $tuneResetButton.Add_Click({
        if (-not (Test-GSXTuningBackup)) {
            [void][System.Windows.Forms.MessageBox]::Show("Es gibt nichts zurueckzusetzen - es wurde noch nichts optimiert.", "Zuruecksetzen")
            return
        }
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Alle von GamingSuite X geaenderten Einstellungen werden auf den Originalzustand zurueckgesetzt.`n`nFortfahren?",
            "Alles zuruecksetzen", 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        $r = Restore-GSXTuning
        $msg = "Originaleinstellungen wiederhergestellt. Neustart empfohlen."
        if ($r.Errors.Count -gt 0) { $msg += "`n`nFehler:`n" + ($r.Errors -join "`n") }
        [void][System.Windows.Forms.MessageBox]::Show($msg, "Zuruecksetzen", 'OK', 'Information')
        Update-TuningView "Zurueckgesetzt."
    })

    $tuneHvciButton.Add_Click({
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Speicher-Integritaet (Kernisolierung) ausschalten?`n`n" +
            "+ Mehr FPS und weniger Latenz in vielen Spielen`n" +
            "- Windows ist schlechter gegen bestimmte Schadsoftware geschuetzt`n`n" +
            "Wirkt nach einem Neustart. Laesst sich mit 'Alles zuruecksetzen' wieder einschalten.",
            "Speicher-Integritaet", 'YesNo', 'Warning')
        if ($answer -ne 'Yes') { return }
        Show-TuningResult (Invoke-GSXOptimization -Ids @('hvci')) "Speicher-Integritaet"
    })

    $clearTempButton.Add_Click({
        $tuningInfo.Text = "Temp-Dateien werden geloescht ..."
        $optimizerPanel.Refresh()
        $result = Clear-TempFiles
        Update-TuningView "Temp-Dateien: $($result.Removed) geloescht, $($result.Errors) gesperrt (in Benutzung)."
    })

    # ======================================================
    # Storage Manager Page
    # ======================================================

    $storagePanel = New-Object System.Windows.Forms.Panel
    $storagePanel.Location = New-Object System.Drawing.Point(240,90)
    $storagePanel.Size = New-Object System.Drawing.Size(1120,660)
    $storagePanel.BackColor = $Colors.Background
    $storagePanel.Visible = $false
    $storagePanel.AutoScroll = $true
    $form.Controls.Add($storagePanel)

    $storageTitle = New-Object System.Windows.Forms.Label
    $storageTitle.Text = "Storage Manager"
    $storageTitle.Location = New-Object System.Drawing.Point(15,10)
    $storageTitle.Size = New-Object System.Drawing.Size(400,35)
    $storageTitle.ForeColor = $Colors.Text
    $storageTitle.Font = New-Object Drawing.Font("Segoe UI",16,[Drawing.FontStyle]::Bold)
    $storagePanel.Controls.Add($storageTitle)

    $storageInfoText = New-Object System.Windows.Forms.Label
    $storageInfoText.Location = New-Object System.Drawing.Point(15,55)
    $storageInfoText.Size = New-Object System.Drawing.Size(1080,460)
    $storageInfoText.ForeColor = $Colors.Text
    $storageInfoText.Font = New-Object Drawing.Font("Segoe UI",10)
    $storageInfoText.AutoSize = $false
    $storageInfoText.Text = "Storage wird analysiert ..."
    $storagePanel.Controls.Add($storageInfoText)

    $analyzeCacheButton = New-Object System.Windows.Forms.Button
    $analyzeCacheButton.Text = "Cache analysieren"
    $analyzeCacheButton.Location = New-Object System.Drawing.Point(15,530)
    $analyzeCacheButton.Size = New-Object System.Drawing.Size(210,45)
    $analyzeCacheButton.ForeColor = $Colors.Text
    $analyzeCacheButton.BackColor = $Colors.Card
    $analyzeCacheButton.FlatStyle = "Flat"
    $storagePanel.Controls.Add($analyzeCacheButton)

    $clearCacheButton = New-Object System.Windows.Forms.Button
    $clearCacheButton.Text = "Cache leeren"
    $clearCacheButton.Location = New-Object System.Drawing.Point(235,530)
    $clearCacheButton.Size = New-Object System.Drawing.Size(210,45)
    $clearCacheButton.ForeColor = $Colors.Text
    $clearCacheButton.BackColor = $Colors.Card
    $clearCacheButton.FlatStyle = "Flat"
    $storagePanel.Controls.Add($clearCacheButton)

    $emptyRecycleButton = New-Object System.Windows.Forms.Button
    $emptyRecycleButton.Text = "Papierkorb leeren"
    $emptyRecycleButton.Location = New-Object System.Drawing.Point(455,530)
    $emptyRecycleButton.Size = New-Object System.Drawing.Size(210,45)
    $emptyRecycleButton.ForeColor = $Colors.Text
    $emptyRecycleButton.BackColor = $Colors.Card
    $emptyRecycleButton.FlatStyle = "Flat"
    $storagePanel.Controls.Add($emptyRecycleButton)

    $largeFilesButton = New-Object System.Windows.Forms.Button
    $largeFilesButton.Text = "Grosse Dateien finden"
    $largeFilesButton.Location = New-Object System.Drawing.Point(15,585)
    $largeFilesButton.Size = New-Object System.Drawing.Size(210,45)
    $largeFilesButton.ForeColor = $Colors.Text
    $largeFilesButton.BackColor = $Colors.Card
    $largeFilesButton.FlatStyle = "Flat"
    $storagePanel.Controls.Add($largeFilesButton)

    $duplicatesButton = New-Object System.Windows.Forms.Button
    $duplicatesButton.Text = "Duplikate finden"
    $duplicatesButton.Location = New-Object System.Drawing.Point(235,585)
    $duplicatesButton.Size = New-Object System.Drawing.Size(210,45)
    $duplicatesButton.ForeColor = $Colors.Text
    $duplicatesButton.BackColor = $Colors.Card
    $duplicatesButton.FlatStyle = "Flat"
    $storagePanel.Controls.Add($duplicatesButton)

    $unusedSoftwareButton = New-Object System.Windows.Forms.Button
    $unusedSoftwareButton.Text = "Groesste Programme"
    $unusedSoftwareButton.Location = New-Object System.Drawing.Point(455,585)
    $unusedSoftwareButton.Size = New-Object System.Drawing.Size(210,45)
    $unusedSoftwareButton.ForeColor = $Colors.Text
    $unusedSoftwareButton.BackColor = $Colors.Card
    $unusedSoftwareButton.FlatStyle = "Flat"
    $storagePanel.Controls.Add($unusedSoftwareButton)

    function Update-StorageView {
        $drives = Get-StorageInfo   # liefert bereits ein Array (kein @() drumherum, sonst wird alles eine Zeile)
        $text = "Laufwerke:`n`n"
        foreach ($drive in $drives) {
            $label = if ($drive.Label) { " ($($drive.Label))" } else { "" }
            $text += "$($drive.Drive)$label   $($drive.Used) von $($drive.Total) GB belegt ($($drive.Percent) %)   -   $($drive.Free) GB frei`n"
        }
        $storageInfoText.Text = $text
    }

    $analyzeCacheButton.Add_Click({
        $caches = Get-CacheDirectories
        $text = "Cache-Verzeichnisse:`n`n"
        foreach ($cache in $caches) {
            $text += "$($cache.Name): $($cache.SizeMB) MB`n"
        }
        $storageInfoText.Text = $text
    })

    $clearCacheButton.Add_Click({
        $storageInfoText.Text = "Cache wird geleert ..."
        $result = Clear-CacheFiles
        $storageInfoText.Text = "Cache geleert:`n$($result.Removed) Dateien geloescht`n$($result.FreedMB) MB freigegeben`n$($result.Errors) Fehler (gesperrte/geschuetzte Dateien)"
    })

    $emptyRecycleButton.Add_Click({
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Der Papierkorb wird endgueltig geleert. Geloeschte Dateien lassen sich danach nicht wiederherstellen.`n`nFortfahren?",
            "Papierkorb leeren", 'YesNo', 'Warning')
        if ($confirm -ne 'Yes') { return }
        $result = Clear-Recycle
        if ($result) {
            $storageInfoText.Text = "Papierkorb erfolgreich geleert!"
        }
        else {
            $storageInfoText.Text = "Fehler beim Leeren des Papierkorbs."
        }
    })

    $largeFilesButton.Add_Click({
        $storageInfoText.Text = "Suche grosse Dateien (>500 MB) - das kann etwas dauern ..."
        $storagePanel.Refresh()
        $files = @(Find-LargeFiles | Select-Object -First 25)
        if ($files.Count -eq 0) {
            $storageInfoText.Text = "Keine Dateien ueber 500 MB gefunden."
        }
        else {
            $text = "Groesste Dateien (Top 25):`n`n"
            foreach ($f in $files) {
                $text += "$($f.SizeGB) GB  -  $($f.Path)`n"
            }
            $storageInfoText.Text = $text
        }
    })

    $duplicatesButton.Add_Click({
        $storageInfoText.Text = "Suche Duplikate (>10 MB) - das kann etwas dauern ..."
        $storagePanel.Refresh()
        $dupes = @(Get-DuplicateFiles | Select-Object -First 25)
        if ($dupes.Count -eq 0) {
            $storageInfoText.Text = "Keine Duplikate gefunden."
        }
        else {
            $text = "Gefundene Duplikate (Top 25):`n`n"
            foreach ($d in $dupes) {
                $text += "$($d.Size) MB  -  $($d.Duplicate)`n    (Original: $($d.Original))`n"
            }
            $storageInfoText.Text = $text
        }
    })

    $unusedSoftwareButton.Add_Click({
        $storageInfoText.Text = "Analysiere installierte Software - das kann etwas dauern ..."
        $storagePanel.Refresh()
        $software = @(Get-UninstalledSoftwareSize)
        if ($software.Count -eq 0) {
            $storageInfoText.Text = "Keine Software-Groessen ermittelt."
        }
        else {
            $text = "Groesste installierte Programme:`n`n"
            foreach ($s in $software) {
                $text += "$($s.SizeMB) MB  -  $($s.Name)`n"
            }
            $storageInfoText.Text = $text
        }
    })

    # ======================================================
    # Settings Page
    # ======================================================

    $settingsPanel = New-Object System.Windows.Forms.Panel
    $settingsPanel.Location = New-Object System.Drawing.Point(240,90)
    $settingsPanel.Size = New-Object System.Drawing.Size(1120,660)
    $settingsPanel.BackColor = $Colors.Background
    $settingsPanel.Visible = $false
    $form.Controls.Add($settingsPanel)

    $settingsTitle = New-Object System.Windows.Forms.Label
    $settingsTitle.Text = "Settings"
    $settingsTitle.Location = New-Object System.Drawing.Point(15,10)
    $settingsTitle.Size = New-Object System.Drawing.Size(400,35)
    $settingsTitle.ForeColor = $Colors.Text
    $settingsTitle.Font = New-Object Drawing.Font("Segoe UI",16,[Drawing.FontStyle]::Bold)
    $settingsPanel.Controls.Add($settingsTitle)

    $settingsText = New-Object System.Windows.Forms.Label
    $settingsText.UseMnemonic = $false
    $settingsText.Location = New-Object System.Drawing.Point(15,55)
    $settingsText.Size = New-Object System.Drawing.Size(1080,105)
    $settingsText.ForeColor = $Colors.Text
    $settingsText.Font = New-Object Drawing.Font("Segoe UI",11)
    $settingsPanel.Controls.Add($settingsText)

    $script:PhoneAddressText = (@(Get-PhoneServerAddresses) | ForEach-Object { "$($_):47801" }) -join ", "
    if (-not $script:PhoneAddressText) { $script:PhoneAddressText = "keine WLAN/LAN-Adresse gefunden" }
    $script:PhoneUrl = $null
    $firstAddr = @(Get-PhoneServerAddresses) | Select-Object -First 1
    if ($firstAddr) { $script:PhoneUrl = "http://$($firstAddr):47801" }

    # --- Karte: Handy verbinden (fuer Einsteiger: QR-Code + Schritt-fuer-Schritt)
    $connectCard = New-GSXCard -Fill $Colors.Card -Border $Colors.Border
    $connectCard.Location = New-Object System.Drawing.Point(15,170)
    $connectCard.Size = New-Object System.Drawing.Size(1080,180)
    $settingsPanel.Controls.Add($connectCard)

    $qrBox = New-Object System.Windows.Forms.PictureBox
    $qrBox.Location = New-Object System.Drawing.Point(18,22)
    $qrBox.Size = New-Object System.Drawing.Size(136,136)
    $qrBox.SizeMode = 'Zoom'
    $qrBox.BackColor = [System.Drawing.Color]::White
    $qrImage = if ($script:PhoneUrl -and (Get-Command New-GSXQrImage -ErrorAction SilentlyContinue)) { New-GSXQrImage -Text $script:PhoneUrl -PixelSize 4 } else { $null }
    if ($qrImage) { $qrBox.Image = $qrImage } else { $qrBox.Visible = $false }
    $connectCard.Controls.Add($qrBox)
    $connectLeft = if ($qrImage) { 172 } else { 18 }

    $connectTitle = New-Object System.Windows.Forms.Label
    $connectTitle.Text = "HANDY ODER TABLET VERBINDEN  (iPhone, Android, jeder Browser)"
    $connectTitle.Location = New-Object System.Drawing.Point($connectLeft,14)
    $connectTitle.Size = New-Object System.Drawing.Size(880,22)
    $connectTitle.ForeColor = $Colors.Green
    $connectTitle.Font = $FontTitle
    $connectCard.Controls.Add($connectTitle)

    $connectUrl = New-Object System.Windows.Forms.Label
    $connectUrl.UseMnemonic = $false
    $connectUrl.Text = if ($script:PhoneUrl) { $script:PhoneUrl } else { "Keine Netzwerkverbindung gefunden - ist der PC mit dem Router verbunden?" }
    $connectUrl.Location = New-Object System.Drawing.Point($connectLeft,40)
    $connectUrl.Size = New-Object System.Drawing.Size(560,34)
    $connectUrl.ForeColor = $Colors.Text
    $connectUrl.Font = New-Object Drawing.Font("Consolas",18,[Drawing.FontStyle]::Bold)
    $connectCard.Controls.Add($connectUrl)

    $copyUrlButton = New-Object System.Windows.Forms.Button
    $copyUrlButton.Text = "Adresse kopieren"
    $copyUrlButton.Location = New-Object System.Drawing.Point(($connectLeft + 570),40)
    $copyUrlButton.Size = New-Object System.Drawing.Size(150,32)
    $copyUrlButton.BackColor = $Colors.Button
    $copyUrlButton.ForeColor = $Colors.Text
    $copyUrlButton.Enabled = [bool]$script:PhoneUrl
    $connectCard.Controls.Add($copyUrlButton)
    $copyUrlButton.Add_Click({
        try { [System.Windows.Forms.Clipboard]::SetText($script:PhoneUrl); $copyUrlButton.Text = "Kopiert" } catch { }
    })

    $connectSteps = New-Object System.Windows.Forms.Label
    $connectSteps.UseMnemonic = $false
    $scanHint = if ($qrImage) { "Kamera-App am Handy oeffnen und den QR-Code links scannen - oder die Adresse oben im Browser eintippen." } else { "Die Adresse oben im Browser des Handys eintippen (Safari, Chrome ...)." }
    $connectSteps.Text =
        "1.  Handy und PC muessen im selben WLAN / Heimnetz sein.`n" +
        "2.  $scanHint`n" +
        "3.  Fuer schnellen Zugriff: im Browser 'Teilen' -> 'Zum Home-Bildschirm'.  Android-App: PC CONNECT -> Automatisch suchen.`n" +
        "Klappt nicht? PC und Handy im selben WLAN? Beim ersten Start die Windows-Firewall-Frage mit 'Zulassen' beantwortet?"
    $connectSteps.Location = New-Object System.Drawing.Point($connectLeft,82)
    $connectSteps.Size = New-Object System.Drawing.Size((1060 - $connectLeft),90)
    $connectSteps.ForeColor = $Colors.Dim
    $connectCard.Controls.Add($connectSteps)

    # --- Karte: Handy-/Browser-Zugriff
    $phoneCard = New-GSXCard -Fill $Colors.Card -Border $Colors.Border
    $phoneCard.Location = New-Object System.Drawing.Point(15,365)
    $phoneCard.Size = New-Object System.Drawing.Size(530,170)
    $settingsPanel.Controls.Add($phoneCard)

    $phoneTitle = New-Object System.Windows.Forms.Label
    $phoneTitle.Text = "HANDY- / BROWSER-ZUGRIFF"
    $phoneTitle.Location = New-Object System.Drawing.Point(18,14)
    $phoneTitle.Size = New-Object System.Drawing.Size(480,22)
    $phoneTitle.ForeColor = $Colors.Green
    $phoneTitle.Font = $FontTitle
    $phoneCard.Controls.Add($phoneTitle)

    $phoneEnabledBox = New-Object System.Windows.Forms.CheckBox
    $phoneEnabledBox.Text = "Zugriff im WLAN erlauben (App und Browser, nur lesen)"
    $phoneEnabledBox.Location = New-Object System.Drawing.Point(18,44)
    $phoneEnabledBox.Size = New-Object System.Drawing.Size(490,24)
    $phoneCard.Controls.Add($phoneEnabledBox)

    $pinLabel = New-Object System.Windows.Forms.Label
    $pinLabel.Text = "PIN (optional, 4-8 Ziffern, leer = keine):"
    $pinLabel.Location = New-Object System.Drawing.Point(18,82)
    $pinLabel.Size = New-Object System.Drawing.Size(260,24)
    $pinLabel.ForeColor = $Colors.Dim
    $phoneCard.Controls.Add($pinLabel)

    $pinBox = New-Object System.Windows.Forms.TextBox
    $pinBox.Location = New-Object System.Drawing.Point(285,80)
    $pinBox.Size = New-Object System.Drawing.Size(110,24)
    $pinBox.MaxLength = 8
    $pinBox.BackColor = $Colors.Button
    $pinBox.ForeColor = $Colors.Text
    $pinBox.Font = New-Object Drawing.Font("Consolas",12)
    $phoneCard.Controls.Add($pinBox)

    $phoneSaveButton = New-Object System.Windows.Forms.Button
    $phoneSaveButton.Text = "Speichern"
    $phoneSaveButton.Location = New-Object System.Drawing.Point(18,118)
    $phoneSaveButton.Size = New-Object System.Drawing.Size(140,36)
    $phoneSaveButton.BackColor = [System.Drawing.Color]::FromArgb(0,140,60)
    $phoneSaveButton.ForeColor = $Colors.Text
    $phoneCard.Controls.Add($phoneSaveButton)

    $pinHint = New-Object System.Windows.Forms.Label
    $pinHint.Text = "Die PIN fragt die Web-App beim ersten Aufruf ab."
    $pinHint.Location = New-Object System.Drawing.Point(170,126)
    $pinHint.Size = New-Object System.Drawing.Size(345,22)
    $pinHint.ForeColor = $Colors.Dim
    $pinHint.Font = New-Object Drawing.Font("Segoe UI",9)
    $phoneCard.Controls.Add($pinHint)

    # --- Karte: Fehlerbericht
    $reportCard = New-GSXCard -Fill $Colors.Card -Border $Colors.Border
    $reportCard.Location = New-Object System.Drawing.Point(565,365)
    $reportCard.Size = New-Object System.Drawing.Size(530,170)
    $settingsPanel.Controls.Add($reportCard)

    $reportTitle = New-Object System.Windows.Forms.Label
    $reportTitle.Text = "FEHLER MELDEN"
    $reportTitle.Location = New-Object System.Drawing.Point(18,14)
    $reportTitle.Size = New-Object System.Drawing.Size(480,22)
    $reportTitle.ForeColor = $Colors.Green
    $reportTitle.Font = $FontTitle
    $reportCard.Controls.Add($reportTitle)

    $reportInfo = New-Object System.Windows.Forms.Label
    $reportInfo.Text = "Erstellt eine ZIP-Datei auf dem Desktop mit Systeminfos und Protokollen " +
                       "(ohne PC-Name, Benutzername und Prozessliste). Bei Problemen diese Datei im " +
                       "GitHub-Issue anhaengen."
    $reportInfo.Location = New-Object System.Drawing.Point(18,44)
    $reportInfo.Size = New-Object System.Drawing.Size(495,66)
    $reportInfo.ForeColor = $Colors.Dim
    $reportCard.Controls.Add($reportInfo)

    $reportButton = New-Object System.Windows.Forms.Button
    $reportButton.Text = "Fehlerbericht erstellen"
    $reportButton.Location = New-Object System.Drawing.Point(18,118)
    $reportButton.Size = New-Object System.Drawing.Size(200,36)
    $reportButton.BackColor = $Colors.Card
    $reportButton.ForeColor = $Colors.Text
    $reportCard.Controls.Add($reportButton)

    function Update-SettingsView {
        $state = $global:GSXState
        $phoneStatus = if (-not $state.PhoneEnabled) { "abgeschaltet" }
                       elseif ($state.PhoneServerRunning) { "aktiv" + $(if ($state.PhonePin) { " (mit PIN)" } else { "" }) }
                       elseif ($state.PhoneServerError) { "Fehler: $($state.PhoneServerError)" }
                       else { "startet ..." }
        $settingsText.Text =
            "GamingSuite X v$Version`n" +
            "Konfiguration: $(Get-ConfigPath)\config.json`n" +
            "Protokolle: $(Get-LogPath)`n" +
            "Handy-Zugriff: $phoneStatus     (alle Adressen dieses PCs: $script:PhoneAddressText)`n" +
            "Kostenlos und quelloffen. Es werden keine Daten ins Internet gesendet."
        $phoneEnabledBox.Checked = [bool]$state.PhoneEnabled
        $pinBox.Text = [string]$state.PhonePin
    }

    $phoneSaveButton.Add_Click({
        $pin = $pinBox.Text.Trim()
        if ($pin -and $pin -notmatch '^\d{4,8}$') {
            [void][System.Windows.Forms.MessageBox]::Show("Die PIN muss aus 4 bis 8 Ziffern bestehen (oder leer sein).", "PIN", 'OK', 'Warning')
            return
        }
        [void](Update-GamingSuiteConfigValue -Key 'PhoneAccessEnabled' -Value ([bool]$phoneEnabledBox.Checked))
        [void](Update-GamingSuiteConfigValue -Key 'PhonePin' -Value $pin)
        $global:GSXState.PhoneEnabled = [bool]$phoneEnabledBox.Checked
        $global:GSXState.PhonePin = $pin
        Update-SettingsView
        [void][System.Windows.Forms.MessageBox]::Show("Gespeichert. Gilt sofort.", "Handy-Zugriff", 'OK', 'Information')
    })

    $reportButton.Add_Click({
        $reportButton.Enabled = $false
        $reportButton.Text = "Wird erstellt ..."
        $settingsPanel.Refresh()
        try {
            $zip = New-GSXErrorReport -UiLog $gtLog.Text
            [void][System.Windows.Forms.MessageBox]::Show("Fehlerbericht gespeichert:`n$zip`n`nBitte vor dem Hochladen kurz reinschauen.", "Fehlerbericht", 'OK', 'Information')
            Start-Process explorer.exe "/select,`"$zip`""
        }
        catch {
            [void][System.Windows.Forms.MessageBox]::Show("Fehlerbericht konnte nicht erstellt werden:`n$($_.Exception.Message)", "Fehlerbericht", 'OK', 'Error')
        }
        $reportButton.Text = "Fehlerbericht erstellen"
        $reportButton.Enabled = $true
    })

    # ======================================================
    # Statistics Page
    # ======================================================

    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Location = New-Object System.Drawing.Point(240,90)
    $statsPanel.Size = New-Object System.Drawing.Size(1120,660)
    $statsPanel.BackColor = $Colors.Background
    $statsPanel.Visible = $false
    $statsPanel.AutoScroll = $true
    $form.Controls.Add($statsPanel)

    $statsTitle = New-Object System.Windows.Forms.Label
    $statsTitle.Text = "Performance Statistiken"
    $statsTitle.Location = New-Object System.Drawing.Point(15,10)
    $statsTitle.Size = New-Object System.Drawing.Size(400,35)
    $statsTitle.ForeColor = $Colors.Text
    $statsTitle.Font = New-Object Drawing.Font("Segoe UI",16,[Drawing.FontStyle]::Bold)
    $statsPanel.Controls.Add($statsTitle)

    $statsText = New-Object System.Windows.Forms.Label
    $statsText.Location = New-Object System.Drawing.Point(15,55)
    $statsText.Size = New-Object System.Drawing.Size(1080,500)
    $statsText.ForeColor = $Colors.Text
    $statsText.Font = New-Object Drawing.Font("Segoe UI",10)
    $statsText.AutoSize = $false
    $statsText.Text = "Statistiken werden generiert ..."
    $statsPanel.Controls.Add($statsText)

    $refreshStatsButton = New-Object System.Windows.Forms.Button
    $refreshStatsButton.Text = "Aktualisieren"
    $refreshStatsButton.Location = New-Object System.Drawing.Point(15,565)
    $refreshStatsButton.Size = New-Object System.Drawing.Size(220,45)
    $refreshStatsButton.ForeColor = $Colors.Text
    $refreshStatsButton.BackColor = $Colors.Card
    $refreshStatsButton.FlatStyle = "Flat"
    $statsPanel.Controls.Add($refreshStatsButton)

    function Update-StatisticsView {
        $text = ""

        foreach ($component in @("CPU","GPU","RAM","Network")) {
            $stats = Get-PerformanceStats -Component $component
            if ($stats) {
                $text += "$component  -  Aktuell: $($stats.Current)  |  Durchschnitt: $($stats.Average)  |  Min: $($stats.Min)  |  Max: $($stats.Max)  ($($stats.Count) Messwerte)`n"
            }
            else {
                $text += "$component  -  Noch keine Daten gesammelt.`n"
            }
        }

        $text += "`nGaming Center:`n"
        if ($null -eq $script:GamingLibraryLastUpdate) {
            $text += "Noch nicht geladen - Seite 'Gaming Center' einmal oeffnen.`n"
            $statsText.Text = $text
            return
        }
        $gcStats = Get-GamingCenterStatistics
        $text += "Spiele insgesamt: $($gcStats.TotalGames)  |  Steam-Spiele: $($gcStats.SteamGames)`n"
        if ($gcStats.LastUpdate) {
            $text += "Letztes Update: $($gcStats.LastUpdate)`n"
        }
        else {
            $text += "Letztes Update: noch nie`n"
        }

        $statsText.Text = $text
    }

    $refreshStatsButton.Add_Click({ Update-StatisticsView })

    # ======================================================
    # Status Bar
    # ======================================================

    $status = New-Object System.Windows.Forms.Label
    $status.UseMnemonic = $false
    $status.Location = New-Object System.Drawing.Point(220,785)
    $status.Size = New-Object System.Drawing.Size(1180,26)
    $status.ForeColor = $Colors.Dim
    $status.BackColor = $Colors.Panel
    $status.Font = New-Object Drawing.Font("Segoe UI",9.5)
    $status.TextAlign = "MiddleLeft"
    $status.Padding = New-Object System.Windows.Forms.Padding(24,0,0,0)
    $status.Text = "GamingSuite X v$Version | Bereit"
    $form.Controls.Add($status)

    # ======================================================
    # Seitenwechsel
    # ======================================================
    # Vorher wurden bei JEDEM Timer-Tick (alle 0,5 s) alle Seiten
    # versteckt und wieder eingeblendet -> Flackern. Jetzt nur noch,
    # wenn wirklich eine andere Seite gewaehlt wurde.

    function Show-GamingSuitePage([string]$page) {
        $isDashboard = ($page -eq "Dashboard")
        $cpuCard.Panel.Visible     = $isDashboard
        $gpuCard.Panel.Visible     = $isDashboard
        $ramCard.Panel.Visible     = $isDashboard
        $storageCard.Panel.Visible = $isDashboard
        $networkCard.Panel.Visible = $isDashboard
        $systemCard.Panel.Visible  = $isDashboard
        $livePanel.Visible         = ($page -eq "Live Monitor")
        $gamingPanel.Visible       = ($page -eq "Gaming Center")
        $gameTunePanel.Visible     = ($page -eq "Spiele-Tuning")
        $optimizerPanel.Visible    = ($page -eq "Optimizer")
        $storagePanel.Visible      = ($page -eq "Storage")
        $settingsPanel.Visible     = ($page -eq "Settings")
        $statsPanel.Visible        = ($page -eq "Statistics")

        foreach ($key in @($navButtons.Keys)) {
            if ($script:GSXUiOk) { $navButtons[$key].Active = ($key -eq $page) }
            elseif ($key -eq $page) { $navButtons[$key].BackColor = $Colors.Green; $navButtons[$key].ForeColor = $Colors.Background }
            else { $navButtons[$key].BackColor = $Colors.Card; $navButtons[$key].ForeColor = $Colors.Text }
        }

        $header.Text = "$page"
        $form.Refresh()

        switch ($page) {
            "Gaming Center" {
                if (-not $script:GamingCenterLoaded) {
                    $script:GamingCenterLoaded = $true
                    $gameInfo.Text = "Steam-Bibliothek wird geladen ..."
                    $gamingPanel.Refresh()
                    Update-GamingCenterView
                }
            }
            "Optimizer" {
                if (-not $script:OptimizerLoaded) {
                    $script:OptimizerLoaded = $true
                    Update-TuningView
                }
            }
            "Storage" {
                if (-not $script:StorageLoaded) {
                    $script:StorageLoaded = $true
                    Update-StorageView
                }
            }
            "Spiele-Tuning" {
                Update-GameTuningView
            }
            "Settings" {
                Update-SettingsView
            }
            "Statistics" {
                Update-StatisticsView
                $script:LastStatsUpdate = Get-Date
            }
        }
    }

    # ======================================================
    # Timer & Updates
    # ======================================================
    # Die Hardware wird im Hintergrund gemessen (BackgroundMonitor.ps1).
    # Der Timer liest nur noch die fertigen Werte - das Fenster friert
    # dadurch nicht mehr ein.

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 500
    $script:ShownPage = $null
    $script:LastSnapshotVersion = -1
    $script:LastStatsUpdate = [datetime]::MinValue

    $timer.Add_Tick({
        try {
            if ($script:ShownPage -ne $script:CurrentPage) {
                $script:ShownPage = $script:CurrentPage
                Show-GamingSuitePage $script:CurrentPage
            }

            try { Invoke-GtBackground } catch { }

            $state = $global:GSXState
            $phoneText = if (-not $state.PhoneEnabled) { "Handy-Zugriff: aus" }
                         elseif ($state.PhoneServerRunning) { "Handy: $script:PhoneAddressText" }
                         elseif ($state.PhoneServerError) { "Handy-Server: Fehler" }
                         else { "Handy-Server startet ..." }
            $status.Text = "GamingSuite X v$Version | " + (Get-Date).ToString("HH:mm:ss") + " | $phoneText"

            if ($null -eq $state.Snapshot) {
                if ($state.LastError) { $status.Text += " | Messfehler: $($state.LastError)" }
                return
            }
            if ($state.Version -eq $script:LastSnapshotVersion) { return }
            $script:LastSnapshotVersion = $state.Version

            $snapshot = $state.Snapshot
            Add-PerformanceLog $snapshot

            if ($script:CurrentPage -eq "Statistics" -and ((Get-Date) - $script:LastStatsUpdate).TotalSeconds -ge 5) {
                Update-StatisticsView
                $script:LastStatsUpdate = Get-Date
            }

            # CPU
            $cpu = $snapshot.CPU
            if ($null -ne $cpu) {
                $cpuTemperature = if ($null -ne $cpu.Temperature) {
                    "$($cpu.Temperature) Grad C"
                }
                else {
                    "nicht verfuegbar"
                }

                $cpuCard.Value.Text =
                    "$($cpu.Name)`n`n" +
                    "Kerne: $($cpu.Cores)`n" +
                    "Threads: $($cpu.Threads)`n" +
                    "Temperatur: $cpuTemperature"

                $cpuCard.Bar.Value = [int][math]::Min(100, [double]$cpu.Load)
                $cpuCard.Percent.Text = "Auslastung: $($cpu.Load)%"
                Add-MonitorValue $cpuMonitor $cpu.Load "CPU"
            }
            else {
                $cpuCard.Value.Text = "CPU-Daten nicht verfuegbar"
                $cpuCard.Bar.Value = 0
                $cpuCard.Percent.Text = ""
            }

            # GPU
            $gpu = $snapshot.GPU
            if ($null -ne $gpu) {
                $gpuTemperature = if ($null -ne $gpu.Temperature) {
                    "$($gpu.Temperature) Grad C"
                }
                else {
                    "nicht verfuegbar"
                }

                $gpuCard.Value.Text =
                    "$($gpu.Name)`n`n" +
                    "VRAM gesamt: $($gpu.VRAM) GB`n" +
                    "VRAM belegt: $(if ($null -ne $gpu.VRAMUsed) { "$($gpu.VRAMUsed) GB" } else { "n/v" })`n" +
                    "Temperatur: $gpuTemperature"

                $gpuCard.Bar.Value = [int][math]::Min(100, [double]$gpu.Usage)
                $usageText = if ($null -ne $gpu.Usage) { "$($gpu.Usage) %" } else { "n/v" }
                $vramText = if ($null -ne $gpu.VRAMUsed) { "$($gpu.VRAMUsed) / $($gpu.VRAM) GB" } else { "$($gpu.VRAM) GB" }
                $gpuCard.Percent.Text = "GPU: $usageText | VRAM: $vramText"
                if ($null -ne $gpu.Usage) { Add-MonitorValue $gpuMonitor $gpu.Usage "GPU" }

                $vramPercent = if ($gpu.VRAM -gt 0) {
                    ($gpu.VRAMUsed / $gpu.VRAM) * 100
                }
                else {
                    0
                }
                Add-MonitorValue $vramMonitor $vramPercent "VRAM"
            }
            else {
                $gpuCard.Value.Text = "GPU-Daten nicht verfuegbar"
                $gpuCard.Bar.Value = 0
                $gpuCard.Percent.Text = ""
            }

            # RAM
            $ram = $snapshot.RAM
            if ($null -ne $ram) {
                $ramCard.Value.Text =
                    "$($ram.Used) GB / $($ram.Total) GB`n`n" +
                    "Frei: $($ram.Free) GB"

                $ramCard.Bar.Value = [math]::Min(100,[int]$ram.Percent)
                $ramCard.Percent.Text =
                    "RAM: $($ram.Percent)% | $($ram.Speed) MHz | $($ram.Modules) Module"
                Add-MonitorValue $ramMonitor $ram.Percent "RAM"
            }
            else {
                $ramCard.Value.Text = "RAM-Daten nicht verfuegbar"
                $ramCard.Bar.Value = 0
                $ramCard.Percent.Text = ""
            }

            # Storage
            $storage = $snapshot.Storage

            $text = ""

            foreach($drive in $storage)
            {
                $text += "$($drive.Name) [$($drive.Type)]  $($drive.Percent)%  ($($drive.Free) GB frei)`n"
            }

            $storageCard.Value.Text = $text

            if($storage -and $storage.Count -gt 0)
            {
                $storageCard.Bar.Value = [math]::Min(100,[int]$storage[0].Percent)
                $storageCard.Percent.Text = "Primaeres Laufwerk: $($storage[0].Percent)% belegt"
            }
            else {
                $storageCard.Value.Text = "Laufwerksdaten nicht verfuegbar"
                $storageCard.Bar.Value = 0
                $storageCard.Percent.Text = ""
            }

            # System
            $sys = $snapshot.System
            if ($null -ne $sys) {
                $uptimeText = "-"
                if ($sys.Uptime) { $uptimeText = "{0}d {1}h {2}m" -f $sys.Uptime.Days, $sys.Uptime.Hours, $sys.Uptime.Minutes }
                $systemCard.Value.Text =
                    "$($sys.ComputerName)`n" +
                    "$($sys.Windows)`n`n" +
                    "Laufzeit: $uptimeText"
                $systemCard.Percent.Text = "Handy / Browser: $script:PhoneAddressText"
            }

            # Network
            $network = $snapshot.Network
            if ($null -ne $network) {
                $networkCard.Value.Text =
                    "Download: $($network.Download.ToString('0.00')) MB/s`n`n" +
                    "Upload: $($network.Upload.ToString('0.00')) MB/s"
                $networkCard.Bar.Value = [math]::Min(100, [int]($network.Download * 10))
                $networkCard.Percent.Text = "Download-Skala: 0 bis 10 MB/s"
                Add-MonitorValue `
                    $networkMonitor `
                    ($network.Download * 10) `
                    "Network" `
                    ("Down: {0:0.00} MB/s" -f $network.Download)
            }
            else {
                $networkCard.Value.Text = "Netzwerkdaten nicht verfuegbar"
                $networkCard.Bar.Value = 0
                $networkCard.Percent.Text = ""
            }

        }
        catch {
            $status.Text = "GamingSuite X v$Version | Fehler beim Aktualisieren: $($_.Exception.Message)"
        }

    })

    # Einheitliches Design fuer alle Steuerelemente
    try { Set-GSXTheme -Parent $form -Colors $Colors } catch { Write-Warning "Design konnte nicht vollstaendig angewendet werden: $_" }

    $timer.Start()

    [void]$form.ShowDialog()
}
