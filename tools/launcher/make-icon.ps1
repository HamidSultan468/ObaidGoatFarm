# Generates tangent.ico (multi-size, PNG-compressed entries) for the desktop
# shortcut. Brand colors from app/lib/core/theme/app_colors.dart.
# Usage: powershell -ExecutionPolicy Bypass -File tools\launcher\make-icon.ps1
Add-Type -AssemblyName System.Drawing

$outPath = Join-Path $PSScriptRoot 'tangent.ico'
$sizes = @(256, 128, 64, 48, 32, 24, 16)

function New-RoundedRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function New-Sparkle([float]$cx, [float]$cy, [float]$r) {
    # Four-point star, like the app's auto_graph logo sparkles.
    $inner = $r * 0.28
    $pts = @()
    for ($i = 0; $i -lt 8; $i++) {
        $angle = [Math]::PI / 4 * $i - [Math]::PI / 2
        $len = if ($i % 2 -eq 0) { $r } else { $inner }
        $pts += New-Object System.Drawing.PointF(($cx + $len * [Math]::Cos($angle)), ($cy + $len * [Math]::Sin($angle)))
    }
    return , $pts
}

# $maskable: full-bleed square background with the artwork inside the
# central 80% "safe zone", as required for PWA maskable icons.
function New-IconPng([int]$size, [bool]$maskable = $false) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $s = [float]$size
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(0, 0)), (New-Object System.Drawing.PointF($s, $s)),
        [System.Drawing.Color]::FromArgb(255, 0x1E, 0x3A, 0x6D), [System.Drawing.Color]::FromArgb(255, 0x10, 0x1C, 0x3A))
    if ($maskable) {
        $g.FillRectangle($grad, 0, 0, $s, $s)
        $g.TranslateTransform($s * 0.1, $s * 0.1)
        $g.ScaleTransform(0.8, 0.8)
    } else {
        $pad = [Math]::Max(0.5, $s * 0.03)
        $bg = New-RoundedRect $pad $pad ($s - 2 * $pad) ($s - 2 * $pad) ($s * 0.22)
        $g.FillPath($grad, $bg)
    }

    # Rising trend line with an arrow head (growth / money), white.
    $stroke = [Math]::Max(1.6, $s * 0.085)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, $stroke)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $line = @(
        (New-Object System.Drawing.PointF(($s * 0.20), ($s * 0.72))),
        (New-Object System.Drawing.PointF(($s * 0.40), ($s * 0.52))),
        (New-Object System.Drawing.PointF(($s * 0.54), ($s * 0.64))),
        (New-Object System.Drawing.PointF(($s * 0.78), ($s * 0.38)))
    )
    $g.DrawLines($pen, $line)
    $head = @(
        (New-Object System.Drawing.PointF(($s * 0.80), ($s * 0.33))),
        (New-Object System.Drawing.PointF(($s * 0.80), ($s * 0.50))),
        (New-Object System.Drawing.PointF(($s * 0.64), ($s * 0.36)))
    )
    $g.FillPolygon([System.Drawing.Brushes]::White, $head)

    # Sparkles in the accent blue (dropped at 16px where they'd be noise).
    if ($size -ge 24) {
        $accent = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0x4F, 0x8E, 0xF7))
        $g.FillPolygon($accent, (New-Sparkle ($s * 0.30) ($s * 0.30) ($s * 0.13)))
        $g.FillPolygon([System.Drawing.Brushes]::White, (New-Sparkle ($s * 0.48) ($s * 0.21) ($s * 0.075)))
    }

    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return , $ms.ToArray()
}

# ICO container: header, one 16-byte directory entry per image, then PNG data.
$images = @($sizes | ForEach-Object { , (New-IconPng $_) })
$out = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter($out)
$w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }  # 0 means 256
    $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([UInt16]1); $w.Write([UInt16]32)
    $w.Write([UInt32]$images[$i].Length); $w.Write([UInt32]$offset)
    $offset += $images[$i].Length
}
foreach ($img in $images) { $w.Write($img) }
$w.Flush()
[System.IO.File]::WriteAllBytes($outPath, $out.ToArray())

Write-Output "Wrote $outPath ($($out.Length) bytes, sizes: $($sizes -join ', '))"

# The same artwork for the Flutter web app (favicon, PWA icons), so the
# desktop shortcut, the app window and the taskbar all show one icon.
$webDir = Join-Path $PSScriptRoot '..\..\app\web'
if (Test-Path $webDir) {
    $webIcons = @(
        @{ File = 'favicon.png'; Size = 32; Maskable = $false },
        @{ File = 'icons\Icon-192.png'; Size = 192; Maskable = $false },
        @{ File = 'icons\Icon-512.png'; Size = 512; Maskable = $false },
        @{ File = 'icons\Icon-maskable-192.png'; Size = 192; Maskable = $true },
        @{ File = 'icons\Icon-maskable-512.png'; Size = 512; Maskable = $true }
    )
    foreach ($icon in $webIcons) {
        $target = Join-Path $webDir $icon.File
        [System.IO.File]::WriteAllBytes($target, (New-IconPng $icon.Size $icon.Maskable))
        Write-Output "Wrote $target"
    }
}
