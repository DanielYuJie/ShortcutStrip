# 生成 Verticons 风格图标：白色圆底，按图标类型自动选择处理方式
# 模式 A：圆底 + 原色图标（彩色不透明/彩色透明）
# 模式 B：圆底 + 深灰字形（白色字形、透明底）
# 模式 C：圆底 + 深灰字形（白底深字，按亮度反推字形）
# 模式 D：不画圆底，直接用白色字形（白字形但面积太大，挖空/反色都会糊）
param(
    [string]$SkinDir = 'D:\Users\lyj\Documents\Rainmeter\Skins\ShortcutDock'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public class JumboIcon3 {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct SHFILEINFO {
        public IntPtr hIcon; public int iIcon; public uint dwAttributes;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string szDisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=80)]  public string szTypeName;
    }
    [ComImport, Guid("46EB5926-582E-4017-9FDF-E8998DAA0950"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IImageList {
        [PreserveSig] int Add(IntPtr hbmImage, IntPtr hbmMask, ref int pi);
        [PreserveSig] int ReplaceIcon(int i, IntPtr hicon, ref int pi);
        [PreserveSig] int SetOverlayImage(int iImage, int iOverlay);
        [PreserveSig] int Replace(int i, IntPtr hbmImage, IntPtr hbmMask);
        [PreserveSig] int AddMasked(IntPtr hbmImage, int crMask, ref int pi);
        [PreserveSig] int Draw(IntPtr pimldp);
        [PreserveSig] int Remove(int i);
        [PreserveSig] int GetIcon(int i, int flags, ref IntPtr picon);
    }
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    static extern IntPtr SHGetFileInfo(string path, uint attr, ref SHFILEINFO sfi, uint cb, uint flags);
    [DllImport("shell32.dll")]
    static extern int SHGetImageList(int iImageList, ref Guid riid, out IntPtr ppv);

    public static Icon Get(string path) {
        SHFILEINFO sfi = new SHFILEINFO();
        uint size = (uint)Marshal.SizeOf(sfi);
        IntPtr r = SHGetFileInfo(path, 0, ref sfi, size, 0x000000100);
        if (r == IntPtr.Zero) return null;
        IntPtr list;
        Guid iid = new Guid("46EB5926-582E-4017-9FDF-E8998DAA0950");
        if (SHGetImageList(0x4, ref iid, out list) != 0) return null;
        IImageList il = (IImageList)Marshal.GetObjectForIUnknown(list);
        IntPtr h = IntPtr.Zero;
        if (il.GetIcon(sfi.iIcon, 0x1, ref h) != 0 || h == IntPtr.Zero) return null;
        return (Icon)Icon.FromHandle(h).Clone();
    }
}
"@ -ReferencedAssemblies System.Drawing

# 读显示名（用于首字兜底图标）
$names = @{}
$cardIni = Join-Path (Split-Path $SkinDir -Parent) 'ShortcutDock\ShortcutDock.ini'
if (Test-Path $cardIni) {
    $ci = [System.IO.File]::ReadAllLines($cardIni, [System.Text.Encoding]::Unicode)
    $cid = $null
    foreach ($cl in $ci) {
        if ($cl -match '^\[mT(\d+)\]$') { $cid = [int]$Matches[1] }
        elseif ($cl -match '^Text=(.+)$' -and $cid) { $names[$cid] = $Matches[1]; $cid = $null }
    }
}

$linksDir = Join-Path $SkinDir '@Resources\Links'
$outDir   = Join-Path $SkinDir '@Resources\Badges'
Remove-Item $outDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $outDir | Out-Null
$ws = New-Object -ComObject WScript.Shell

$sheetCell = 56; $sheetGap = 8; $sheetCols = 16
$rows = [Math]::Ceiling(78 / $sheetCols)
$sheet = New-Object System.Drawing.Bitmap -ArgumentList (10 + $sheetCols * ($sheetCell + $sheetGap)), (10 + $rows * ($sheetCell + $sheetGap))
$sg = [System.Drawing.Graphics]::FromImage($sheet)
$sg.Clear([System.Drawing.Color]::FromArgb(255, 22, 24, 29))
$sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$sg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

function New-LetterBadge([string]$name) {
    $canvas = New-Object System.Drawing.Bitmap -ArgumentList 96, 96, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $brush = New-Object System.Drawing.SolidBrush -ArgumentList ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
    $g.FillEllipse($brush, 2, 2, 92, 92)
    $brush.Dispose()
    $txt = if ($name -match '^[A-Za-z]') { $name.Substring(0, [Math]::Min(2, $name.Length)).ToUpper() } else { $name.Substring(0, 1) }
    $font = New-Object System.Drawing.Font -ArgumentList 'Microsoft YaHei UI', 38, ([System.Drawing.FontStyle]::Bold)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    $tb = New-Object System.Drawing.SolidBrush -ArgumentList ([System.Drawing.Color]::FromArgb(255, 52, 57, 68))
    $g.DrawString($txt, $font, $tb, (New-Object System.Drawing.RectangleF -ArgumentList 0, 0, 96, 96), $fmt)
    $tb.Dispose(); $font.Dispose(); $g.Dispose()
    return $canvas
}

function New-DiscCanvas([string]$mode, [System.Drawing.Bitmap]$src) {
    $canvas = New-Object System.Drawing.Bitmap -ArgumentList 96, 96, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    if ($mode -eq 'D') {   # 直接白字形，无圆底
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($src, 12, 12, 72, 72)
        $g.Dispose()
        return $canvas
    }

    if ($mode -eq 'E') {   # 深色圆底 + 原图（白字形也能看见）
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $brush = New-Object System.Drawing.SolidBrush -ArgumentList ([System.Drawing.Color]::FromArgb(255, 42, 46, 55))
        $g.FillEllipse($brush, 2, 2, 92, 92)
        $brush.Dispose()
        $g.DrawImage($src, 16, 16, 64, 64)
        $g.Dispose()
        return $canvas
    }

    # 把图标统一绘制到 96 画布，方便按像素处理
    $tmp = New-Object System.Drawing.Bitmap -ArgumentList 96, 96, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $tg = [System.Drawing.Graphics]::FromImage($tmp)
    $tg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    if ($mode -eq 'A') { $tg.DrawImage($src, 16, 16, 64, 64) }
    elseif ($mode -eq 'B') { $tg.DrawImage($src, 22, 22, 52, 52) }
    else { $tg.DrawImage($src, 16, 16, 64, 64) }   # C：64px 取亮度
    $tg.Dispose()

    $r = 45.0; $cx0 = 47.5; $cy0 = 47.5
    for ($y = 0; $y -lt 96; $y++) {
        for ($x = 0; $x -lt 96; $x++) {
            $dx = $x - $cx0; $dy = $y - $cy0
            $d = [Math]::Sqrt($dx * $dx + $dy * $dy)
            $cover = [Math]::Min(1.0, [Math]::Max(0.0, ($r + 0.8 - $d) / 1.6))
            if ($cover -le 0) { continue }
            $p = $tmp.GetPixel($x, $y)
            if ($mode -eq 'A') {
                $canvas.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 255, 255, 255))
            } elseif ($mode -eq 'B') {
                $ia = $p.A / 255.0
                $rr = [int](255 * (1 - $ia) + 56 * $ia)
                $gg = [int](255 * (1 - $ia) + 60 * $ia)
                $bb = [int](255 * (1 - $ia) + 70 * $ia)
                $canvas.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int](255 * $cover), $rr, $gg, $bb))
            } else {
                $lum = (0.2126 * $p.R + 0.7152 * $p.G + 0.0722 * $p.B) / 255.0
                $ga = [Math]::Min(1.0, [Math]::Max(0.0, (0.75 - $lum) / 0.35)) * ($p.A / 255.0)
                $rr = [int](255 * (1 - $ga) + 56 * $ga)
                $gg = [int](255 * (1 - $ga) + 60 * $ga)
                $bb = [int](255 * (1 - $ga) + 70 * $ga)
                $canvas.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int](255 * $cover), $rr, $gg, $bb))
            }
        }
    }
    $tmp.Dispose()

    if ($mode -eq 'A') {
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($src, 16, 16, 64, 64)
        $g.Dispose()
    }
    return $canvas
}

$modeCount = @{ A = 0; B = 0; C = 0; D = 0 }
$n = 0
Get-ChildItem $linksDir -Filter *.lnk | Sort-Object Name | ForEach-Object {
    $n++
    $id = $_.BaseName
    $sc = $ws.CreateShortcut($_.FullName)
    $target = $sc.TargetPath
    $ico = $null
    try { if ($target) { $ico = [JumboIcon3]::Get($target) } } catch { }
    if (-not $ico) { try { if ($target -and (Test-Path $target)) { $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($target) } } catch { } }
    if (-not $ico) { return }

    $outPath = Join-Path $outDir "B$id.png"
    if ((Test-Path $outPath) -and ((Get-Item $outPath).LastWriteTime -ge $lnk.LastWriteTime)) {
        $cached = [System.Drawing.Bitmap]::FromFile($outPath)
        $cx0 = 10 + (($n - 1) % $sheetCols) * ($sheetCell + $sheetGap)
        $cy0 = 10 + [Math]::Floor(($n - 1) / $sheetCols) * ($sheetCell + $sheetGap)
        $sg.DrawImage($cached, $cx0, $cy0, $sheetCell, $sheetCell)
        $cached.Dispose(); $ico.Dispose()
        return
    }
    $src = $ico.ToBitmap()

    # 统计：透明比例 / 亮部均值 / 字形覆盖率
    $trans = 0; $tot = 0; $lumSum = 0; $lumN = 0; $cov = 0
    for ($sy = 0; $sy -lt $src.Height; $sy += 4) {
        for ($sx = 0; $sx -lt $src.Width; $sx += 4) {
            $tot++
            $pp = $src.GetPixel($sx, $sy)
            if ($pp.A -lt 20) { $trans++ }
            elseif ($pp.A -gt 200) {
                $lumSum += (0.2126 * $pp.R + 0.7152 * $pp.G + 0.0722 * $pp.B)
                $lumN++
            }
        }
    }
    for ($sy = 0; $sy -lt $src.Height; $sy += 4) {
        for ($sx = 0; $sx -lt $src.Width; $sx += 4) { if ($src.GetPixel($sx, $sy).A -gt 128) { $cov++ } }
    }
    $transFrac = $trans / [double]$tot
    $glyphCov = $cov / [double]$tot
    $meanLum = if ($lumN -gt 0) { $lumSum / $lumN } else { 0 }

    # 依次尝试模式，取第一个「有对比度」的结果（A→B→C→D）
    $canvas = $null
    foreach ($tryMode in @('A', 'B', 'C', 'E')) {
        $cand = New-DiscCanvas $tryMode $src
        # 计算不透明像素的亮度标准差（太低 = 糊成一团 / 空白）
        $vals = New-Object System.Collections.ArrayList
        for ($y = 0; $y -lt 96; $y += 2) {
            for ($x = 0; $x -lt 96; $x += 2) {
                $pp = $cand.GetPixel($x, $y)
                if ($pp.A -gt 200) { [void]$vals.Add(0.2126 * $pp.R + 0.7152 * $pp.G + 0.0722 * $pp.B) }
            }
        }
        $std = 0
        if ($vals.Count -gt 20) {
            $m = ($vals | Measure-Object -Average).Average
            $std = [Math]::Sqrt((($vals | ForEach-Object { ($_ - $m) * ($_ - $m) }) | Measure-Object -Average).Average)
        }
        if ($std -ge 26 -or $tryMode -eq 'E') {
            $canvas = $cand
            $mode = $tryMode
            break
        }
        $cand.Dispose()
    }
    # 信息量太低（近乎纯色圆）→ 用名字首字兜底
    $vals2 = New-Object System.Collections.ArrayList
    for ($iy = 8; $iy -lt 88; $iy += 2) {
        for ($ix = 8; $ix -lt 88; $ix += 2) {
            $pp = $canvas.GetPixel($ix, $iy)
            if ($pp.A -gt 200) { [void]$vals2.Add(0.2126 * $pp.R + 0.7152 * $pp.G + 0.0722 * $pp.B) }
        }
    }
    $std2 = 0
    if ($vals2.Count -gt 20) {
        $m2 = ($vals2 | Measure-Object -Average).Average
        $std2 = [Math]::Sqrt((($vals2 | ForEach-Object { ($_ - $m2) * ($_ - $m2) }) | Measure-Object -Average).Average)
    }
    if ($std2 -lt 22) {
        $nm = $names[$n]
        if (-not $nm) { $nm = $id }
        $canvas.Dispose()
        $canvas = New-LetterBadge $nm
        $mode = 'F'
    }
    $modeCount[$mode]++

    $canvas.Save((Join-Path $outDir "B$id.png"), [System.Drawing.Imaging.ImageFormat]::Png)

    $cx = 10 + (($n - 1) % $sheetCols) * ($sheetCell + $sheetGap)
    $cy = 10 + [Math]::Floor(($n - 1) / $sheetCols) * ($sheetCell + $sheetGap)
    $sg.DrawImage($canvas, $cx, $cy, $sheetCell, $sheetCell)

    $canvas.Dispose(); $src.Dispose(); $ico.Dispose()
}
$sg.Dispose()
$sheetPath = 'C:\Users\lyj\Documents\deepseek-harness\default-workspace\ShortcutDock\badges-sheet.png'
$sheet.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
"生成: $n 个  模式分布: A=$($modeCount.A) B=$($modeCount.B) C=$($modeCount.C) D=$($modeCount.D)"
"预览: $sheetPath"
