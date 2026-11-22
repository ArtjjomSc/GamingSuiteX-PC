# ==========================================================
# GamingSuite X - QR-Code fuer die Handy-Adresse
# Kleiner QR-Encoder (Byte-Modus, Fehlerkorrektur L, Version 1-5),
# damit man die Web-App einfach mit der Handy-Kamera oeffnen kann.
# Keine externen Bibliotheken, keine Internetverbindung.
# ==========================================================

$script:GSXQrOk = $false
if (-not ('GSXQr' -as [type])) {
    try {
        Add-Type -ReferencedAssemblies System.Drawing -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Text;

public static class GSXQr
{
    static readonly int[] DataCw = { 0, 19, 34, 55, 80, 108 };
    static readonly int[] EcCw   = { 0, 7, 10, 15, 20, 26 };
    static readonly int[] AlignP = { 0, 0, 18, 22, 26, 30 };
    static int[] Exp = new int[512];
    static int[] Log = new int[256];

    static GSXQr()
    {
        int x = 1;
        for (int i = 0; i < 255; i++)
        {
            Exp[i] = x; Log[x] = i; x <<= 1;
            if ((x & 0x100) != 0) x ^= 0x11D;
        }
        for (int i = 255; i < 512; i++) Exp[i] = Exp[i - 255];
    }

    static int GMul(int a, int b)
    {
        if (a == 0 || b == 0) return 0;
        return Exp[Log[a] + Log[b]];
    }

    static int[] ReedSolomon(List<int> data, int n)
    {
        int[] g = new int[] { 1 };
        for (int i = 0; i < n; i++)
        {
            int[] ng = new int[g.Length + 1];
            for (int j = 0; j < g.Length; j++)
            {
                ng[j] ^= g[j];
                ng[j + 1] ^= GMul(g[j], Exp[i]);
            }
            g = ng;
        }
        int[] res = new int[n];
        foreach (int d in data)
        {
            int f = d ^ res[0];
            for (int j = 0; j < n - 1; j++) res[j] = res[j + 1];
            res[n - 1] = 0;
            for (int j = 0; j < n; j++) res[j] ^= GMul(g[j + 1], f);
        }
        return res;
    }

    static bool MaskBit(int mk, int r, int c)
    {
        switch (mk)
        {
            case 0: return (r + c) % 2 == 0;
            case 1: return r % 2 == 0;
            case 2: return c % 3 == 0;
            case 3: return (r + c) % 3 == 0;
            case 4: return ((r / 2) + (c / 3)) % 2 == 0;
            case 5: return (r * c) % 2 + (r * c) % 3 == 0;
            case 6: return ((r * c) % 2 + (r * c) % 3) % 2 == 0;
            default: return ((r + c) % 2 + (r * c) % 3) % 2 == 0;
        }
    }

    static int FormatBits(int mk)
    {
        int d = (1 << 3) | mk;          // Fehlerkorrektur L = 01
        int v = d << 10;
        for (int i = 14; i >= 10; i--)
            if (((v >> i) & 1) != 0) v ^= 0x537 << (i - 10);
        return ((d << 10) | v) ^ 0x5412;
    }

    public static bool[,] Encode(string text)
    {
        byte[] b = Encoding.UTF8.GetBytes(text);
        int ver = 0;
        for (int v = 1; v <= 5; v++)
            if (4 + 8 + 8 * b.Length <= DataCw[v] * 8) { ver = v; break; }
        if (ver == 0) throw new ArgumentException("Text zu lang fuer QR-Code");

        List<int> bits = new List<int>();
        Action<int, int> put = delegate (int val, int n)
        {
            for (int i = n - 1; i >= 0; i--) bits.Add((val >> i) & 1);
        };
        put(4, 4); put(b.Length, 8);
        foreach (byte c in b) put(c, 8);
        int cap = DataCw[ver] * 8;
        int term = Math.Min(4, cap - bits.Count);
        for (int i = 0; i < term; i++) bits.Add(0);
        while (bits.Count % 8 != 0) bits.Add(0);

        List<int> cw = new List<int>();
        for (int i = 0; i < bits.Count; i += 8)
        {
            int val = 0;
            for (int j = 0; j < 8; j++) val = (val << 1) | bits[i + j];
            cw.Add(val);
        }
        int p = 0;
        while (cw.Count < DataCw[ver]) { cw.Add(p % 2 == 0 ? 0xEC : 0x11); p++; }
        List<int> all = new List<int>(cw);
        all.AddRange(ReedSolomon(cw, EcCw[ver]));

        int size = 17 + 4 * ver;
        bool[,] m = new bool[size, size];
        bool[,] f = new bool[size, size];

        int[][] finders = new int[][] { new int[] { 0, 0 }, new int[] { 0, size - 7 }, new int[] { size - 7, 0 } };
        foreach (int[] fp in finders)
        {
            for (int r = -1; r < 8; r++)
                for (int c = -1; c < 8; c++)
                {
                    int rr = fp[0] + r, cc = fp[1] + c;
                    if (rr < 0 || rr >= size || cc < 0 || cc >= size) continue;
                    bool inside = r >= 0 && r <= 6 && c >= 0 && c <= 6;
                    bool dark = inside && (r == 0 || r == 6 || c == 0 || c == 6 || (r >= 2 && r <= 4 && c >= 2 && c <= 4));
                    m[rr, cc] = dark; f[rr, cc] = true;
                }
        }
        for (int i = 8; i < size - 8; i++)
        {
            m[6, i] = (i % 2 == 0); f[6, i] = true;
            m[i, 6] = (i % 2 == 0); f[i, 6] = true;
        }
        if (AlignP[ver] > 0)
        {
            int a = AlignP[ver];
            for (int r = -2; r <= 2; r++)
                for (int c = -2; c <= 2; c++)
                {
                    m[a + r, a + c] = Math.Max(Math.Abs(r), Math.Abs(c)) != 1;
                    f[a + r, a + c] = true;
                }
        }
        m[size - 8, 8] = true; f[size - 8, 8] = true;
        for (int i = 0; i < 9; i++) { f[8, i] = true; f[i, 8] = true; }
        for (int i = 0; i < 8; i++) { f[8, size - 1 - i] = true; f[size - 1 - i, 8] = true; }

        List<int> dbits = new List<int>();
        foreach (int c in all)
            for (int i = 7; i >= 0; i--) dbits.Add((c >> i) & 1);
        int k = 0; bool up = true;
        for (int col = size - 1; col > 0; col -= 2)
        {
            if (col == 6) col--;
            for (int t = 0; t < size; t++)
            {
                int r = up ? size - 1 - t : t;
                for (int dc = 0; dc < 2; dc++)
                {
                    int c = col - dc;
                    if (f[r, c]) continue;
                    m[r, c] = k < dbits.Count && dbits[k] == 1;
                    k++;
                }
            }
            up = !up;
        }

        bool[,] best = null; int bestPen = int.MaxValue;
        for (int mk = 0; mk < 8; mk++)
        {
            bool[,] q = (bool[,])m.Clone();
            for (int r = 0; r < size; r++)
                for (int c = 0; c < size; c++)
                    if (!f[r, c] && MaskBit(mk, r, c)) q[r, c] = !q[r, c];
            int fb = FormatBits(mk);
            for (int i = 0; i < 15; i++)
            {
                bool bit = ((fb >> i) & 1) == 1;
                if (i < 6) q[i, 8] = bit;
                else if (i == 6) q[7, 8] = bit;
                else if (i == 7) q[8, 8] = bit;
                else if (i == 8) q[8, 7] = bit;
                else q[8, 14 - i] = bit;
                if (i < 8) q[8, size - 1 - i] = bit;
                else q[size - 15 + i, 8] = bit;
            }
            q[size - 8, 8] = true;
            int pen = Penalty(q, size);
            if (pen < bestPen) { bestPen = pen; best = q; }
        }
        return best;
    }

    static int Penalty(bool[,] q, int size)
    {
        int pen = 0;
        bool[] pat = { true, false, true, true, true, false, true };
        for (int pass = 0; pass < 2; pass++)
        {
            for (int a = 0; a < size; a++)
            {
                int run = 1;
                for (int i = 1; i < size; i++)
                {
                    bool cur = pass == 0 ? q[a, i] : q[i, a];
                    bool prev = pass == 0 ? q[a, i - 1] : q[i - 1, a];
                    if (cur == prev) run++;
                    else { if (run >= 5) pen += run - 2; run = 1; }
                }
                if (run >= 5) pen += run - 2;
                for (int i = 0; i < size - 6; i++)
                {
                    bool match = true;
                    for (int j = 0; j < 7; j++)
                    {
                        bool v = pass == 0 ? q[a, i + j] : q[i + j, a];
                        if (v != pat[j]) { match = false; break; }
                    }
                    if (match) pen += 40;
                }
            }
        }
        int dark = 0;
        for (int r = 0; r < size; r++)
            for (int c = 0; c < size; c++)
            {
                if (q[r, c]) dark++;
                if (r < size - 1 && c < size - 1 && q[r, c] == q[r, c + 1] && q[r, c] == q[r + 1, c] && q[r, c] == q[r + 1, c + 1]) pen += 3;
            }
        pen += Math.Abs(dark * 20 / (size * size) - 10) * 10;
        return pen;
    }

    public static Bitmap Render(string text, int pixelSize)
    {
        bool[,] q = Encode(text);
        int n = q.GetLength(0);
        int border = 4;
        int px = (n + 2 * border) * pixelSize;
        Bitmap bmp = new Bitmap(px, px);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.White);
            for (int r = 0; r < n; r++)
                for (int c = 0; c < n; c++)
                    if (q[r, c])
                        g.FillRectangle(Brushes.Black, (c + border) * pixelSize, (r + border) * pixelSize, pixelSize, pixelSize);
        }
        return bmp;
    }
}
'@
        $script:GSXQrOk = $true
    }
    catch {
        $script:GSXQrOk = $false
    }
}
else { $script:GSXQrOk = $true }

function New-GSXQrImage {
    param([string]$Text, [int]$PixelSize = 5)
    if (-not $script:GSXQrOk -or -not $Text) { return $null }
    try { return [GSXQr]::Render($Text, $PixelSize) } catch { return $null }
}
