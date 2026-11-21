# ==========================================================
# GamingSuite X
# UI Controls v11.2 - modernes Design (Karten, Balken, Navigation, Listen)
# ==========================================================
# Eigene WinForms-Steuerelemente in C# (C# 5, wie von Windows PowerShell 5.1
# kompiliert). Schlaegt das Kompilieren fehl, nutzt die Oberflaeche
# automatisch die Standard-Steuerelemente ($script:GSXUiOk = $false).

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:GSXUiOk = $false
$script:GSXUiError = $null

$gsxControlsSource = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class GSXDraw
{
    public static GraphicsPath Round(Rectangle r, int radius)
    {
        GraphicsPath p = new GraphicsPath();
        int d = Math.Max(1, Math.Min(radius * 2, Math.Min(r.Width, r.Height)));
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }
}

// Abgerundete Karte mit Rahmen
public class GSXCard : Panel
{
    private int _radius = 16;
    private Color _fill = Color.FromArgb(21, 26, 35);
    private Color _border = Color.FromArgb(38, 45, 58);

    public int Radius { get { return _radius; } set { _radius = value; Invalidate(); } }
    public Color FillColor { get { return _fill; } set { _fill = value; Invalidate(); } }
    public Color BorderColor { get { return _border; } set { _border = value; Invalidate(); } }

    public GSXCard()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
        using (GraphicsPath p = GSXDraw.Round(r, _radius))
        using (SolidBrush b = new SolidBrush(_fill))
        using (Pen pen = new Pen(_border, 1f))
        {
            g.FillPath(b, p);
            g.DrawPath(pen, p);
        }
        base.OnPaint(e);
    }
}

// Runder Fortschrittsbalken (kompatibel zu ProgressBar: Minimum/Maximum/Value)
public class GSXBar : Control
{
    private int _min = 0;
    private int _max = 100;
    private int _value = 0;
    private Color _track = Color.FromArgb(38, 45, 58);
    private Color _bar = Color.FromArgb(74, 222, 128);
    private bool _auto = true;

    public int Minimum { get { return _min; } set { _min = value; Invalidate(); } }
    public int Maximum { get { return _max; } set { _max = value; Invalidate(); } }
    public int Value
    {
        get { return _value; }
        set { _value = Math.Max(_min, Math.Min(_max, value)); Invalidate(); }
    }
    public Color TrackColor { get { return _track; } set { _track = value; Invalidate(); } }
    public Color BarColor { get { return _bar; } set { _bar = value; Invalidate(); } }
    public bool AutoColor { get { return _auto; } set { _auto = value; Invalidate(); } }

    public GSXBar()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(BackColor);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        int h = Math.Max(2, Height - 1);
        Rectangle track = new Rectangle(0, 0, Width - 1, h);
        using (GraphicsPath p = GSXDraw.Round(track, h / 2))
        using (SolidBrush b = new SolidBrush(_track))
        {
            g.FillPath(b, p);
        }

        double frac = (_max > _min) ? (double)(_value - _min) / (_max - _min) : 0.0;
        int w = (int)Math.Round((Width - 1) * frac);
        if (w <= 0) return;
        if (w < h) w = h;

        Color c = _bar;
        if (_auto)
        {
            double pct = frac * 100.0;
            if (pct >= 90) c = Color.FromArgb(248, 113, 113);
            else if (pct >= 75) c = Color.FromArgb(251, 191, 36);
        }
        using (GraphicsPath p = GSXDraw.Round(new Rectangle(0, 0, w, h), h / 2))
        using (SolidBrush b = new SolidBrush(c))
        {
            g.FillPath(b, p);
        }
    }
}

// Navigations-Button mit Symbol (Segoe MDL2 Assets) und Akzentbalken
public class GSXNavButton : Button
{
    private bool _hover;
    private bool _active;
    private string _icon = "";

    public string Icon { get { return _icon; } set { _icon = value; Invalidate(); } }
    public bool Active { get { return _active; } set { _active = value; Invalidate(); } }
    public Color AccentColor = Color.FromArgb(74, 222, 128);
    public Color HoverColor = Color.FromArgb(26, 32, 43);
    public Color ActiveBackColor = Color.FromArgb(22, 38, 32);
    public Color DimColor = Color.FromArgb(156, 163, 175);

    public GSXNavButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.UserPaint, true);
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        Cursor = Cursors.Hand;
        TabStop = false;
    }

    protected override void OnMouseEnter(EventArgs e) { _hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { _hover = false; Invalidate(); base.OnMouseLeave(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        Color parentBack = (Parent != null) ? Parent.BackColor : BackColor;
        g.Clear(parentBack);
        g.SmoothingMode = SmoothingMode.AntiAlias;

        Color bg = _active ? ActiveBackColor : (_hover ? HoverColor : parentBack);
        using (GraphicsPath p = GSXDraw.Round(new Rectangle(0, 0, Width - 1, Height - 1), 10))
        using (SolidBrush b = new SolidBrush(bg))
        {
            g.FillPath(b, p);
        }
        if (_active)
        {
            using (SolidBrush b = new SolidBrush(AccentColor))
            {
                g.FillRectangle(b, 0, 12, 4, Math.Max(4, Height - 24));
            }
        }

        Color fg = _active ? AccentColor : (_hover ? ForeColor : DimColor);
        using (Font iconFont = new Font("Segoe MDL2 Assets", 13f))
        {
            TextRenderer.DrawText(g, _icon, iconFont, new Rectangle(12, 0, 32, Height), fg,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }
        TextRenderer.DrawText(g, Text, Font, new Rectangle(52, 0, Width - 58, Height), fg,
            TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
    }
}

// ListView mit dunkler Kopfzeile
public class GSXListView : ListView
{
    public Color HeaderBackColor = Color.FromArgb(16, 20, 28);
    public Color HeaderForeColor = Color.FromArgb(156, 163, 175);
    public Color HeaderLineColor = Color.FromArgb(38, 45, 58);
    private Font _headerFont;

    public GSXListView()
    {
        OwnerDraw = true;
        DoubleBuffered = true;
    }

    protected override void OnDrawColumnHeader(DrawListViewColumnHeaderEventArgs e)
    {
        if (_headerFont == null) _headerFont = new Font(Font, FontStyle.Bold);
        using (SolidBrush b = new SolidBrush(HeaderBackColor))
        {
            e.Graphics.FillRectangle(b, e.Bounds);
        }
        using (Pen p = new Pen(HeaderLineColor))
        {
            e.Graphics.DrawLine(p, e.Bounds.Left, e.Bounds.Bottom - 1, e.Bounds.Right, e.Bounds.Bottom - 1);
        }
        Rectangle r = new Rectangle(e.Bounds.X + 6, e.Bounds.Y, Math.Max(0, e.Bounds.Width - 8), e.Bounds.Height);
        TextRenderer.DrawText(e.Graphics, e.Header.Text, _headerFont, r, HeaderForeColor,
            TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
    }

    protected override void OnDrawItem(DrawListViewItemEventArgs e) { e.DrawDefault = true; }
    protected override void OnDrawSubItem(DrawListViewSubItemEventArgs e) { e.DrawDefault = true; }
}

// Dunkle Fenster-Titelleiste (Windows 10 2004+ / Windows 11)
public static class GSXWindow
{
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    public static void DarkTitleBar(IntPtr hwnd)
    {
        try
        {
            int on = 1;
            if (DwmSetWindowAttribute(hwnd, 20, ref on, 4) != 0)
            {
                DwmSetWindowAttribute(hwnd, 19, ref on, 4);
            }
        }
        catch { }
    }
}
"@

try {
    if (-not ('GSXCard' -as [type])) {
        Add-Type -TypeDefinition $gsxControlsSource -ReferencedAssemblies System.Windows.Forms, System.Drawing -ErrorAction Stop
    }
    $script:GSXUiOk = $true
}
catch {
    $script:GSXUiError = $_.Exception.Message
    Write-Warning "Modernes Design nicht verfuegbar, nutze Standard-Steuerelemente: $($script:GSXUiError)"
}

# ----------------------------------------------------------
# Fabrik-Funktionen (mit Rueckfall auf Standard-Controls)
# ----------------------------------------------------------

function New-GSXCard {
    param($Fill, $Border, [int]$Radius = 16)
    if ($script:GSXUiOk) {
        $c = New-Object GSXCard
        $c.FillColor = $Fill
        $c.BorderColor = $Border
        $c.Radius = $Radius
        return $c
    }
    $p = New-Object System.Windows.Forms.Panel
    $p.BackColor = $Fill
    return $p
}

function New-GSXBar {
    if ($script:GSXUiOk) { return (New-Object GSXBar) }
    return (New-Object System.Windows.Forms.ProgressBar)
}

function New-GSXListView {
    if ($script:GSXUiOk) { return (New-Object GSXListView) }
    return (New-Object System.Windows.Forms.ListView)
}

function New-GSXNavButton {
    param([string]$Icon)
    if ($script:GSXUiOk) {
        $b = New-Object GSXNavButton
        $b.Icon = $Icon
        return $b
    }
    return (New-Object System.Windows.Forms.Button)
}

function Get-GSXCardFill {
    param($Control)
    if ($script:GSXUiOk -and $Control -is [GSXCard]) { return $Control.FillColor }
    return $null
}

# Einheitliches Aussehen fuer alle Steuerelemente (rekursiv)
function Set-GSXTheme {
    param($Parent, $Colors, $CardFill = $null)

    foreach ($c in @($Parent.Controls)) {
        $fill = $CardFill
        $own = Get-GSXCardFill $c
        if ($own) { $fill = $own }
        elseif (-not $script:GSXUiOk -and $c -is [System.Windows.Forms.Panel] -and $c.BackColor -eq $Colors.Card) { $fill = $Colors.Card }

        $typeName = $c.GetType().Name
        switch ($typeName) {
            'GSXNavButton' { }
            'Button' {
                $c.FlatStyle = 'Flat'
                $c.FlatAppearance.BorderSize = 1
                $c.FlatAppearance.BorderColor = $Colors.Border
                $c.Cursor = [System.Windows.Forms.Cursors]::Hand
                if ($c.BackColor -eq $Colors.Card -or $c.BackColor -eq [System.Drawing.SystemColors]::Control) {
                    $c.BackColor = $Colors.Button
                    $c.ForeColor = $Colors.Text
                }
                elseif ($c.BackColor.GetBrightness() -gt 0.45) {
                    $c.ForeColor = $Colors.Background   # helle Buttons -> dunkle Schrift
                    $c.FlatAppearance.BorderColor = $c.BackColor
                }
                else {
                    $c.FlatAppearance.BorderColor = $c.BackColor
                }
                $c.FlatAppearance.MouseOverBackColor = [System.Windows.Forms.ControlPaint]::Light($c.BackColor, 0.15)
                $c.FlatAppearance.MouseDownBackColor = [System.Windows.Forms.ControlPaint]::Dark($c.BackColor, 0.05)
            }
            'Label' { if ($fill) { $c.BackColor = $fill } }
            'CheckBox' {
                $c.FlatStyle = 'Flat'
                $c.ForeColor = $Colors.Text
                if ($fill) { $c.BackColor = $fill }
            }
            'GSXBar' {
                $c.BackColor = if ($fill) { $fill } else { $Parent.BackColor }
            }
            'TextBox' {
                $c.BorderStyle = 'None'
            }
            'ListBox' {
                $c.BorderStyle = 'None'
            }
            'GSXListView' {
                $c.BorderStyle = 'None'
                if ($c.Columns.Count -gt 0) { $c.Columns[$c.Columns.Count - 1].Width = -2 }   # letzte Spalte fuellt die Breite
            }
        }

        if ($c.Controls.Count -gt 0) { Set-GSXTheme -Parent $c -Colors $Colors -CardFill $fill }
    }
}
