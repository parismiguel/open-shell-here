# Generates icon.png (and icon-256.png) for the Marketplace listing.
#
# Draws a terminal window with a ">_" prompt, rendered with GDI+ so there are
# no external dependencies (no ImageMagick, no node canvas, no design tool).
#
# Run in PowerShell:
#   .\generate-icon.ps1
#
# Requires Windows PowerShell 5.1+ (System.Drawing).

[CmdletBinding()]
param(
    [int] $PrimarySize = 128,
    [int] $LargeSize = 256
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# VS Code palette so the icon looks at home next to the editor.
$BackgroundColor = [System.Drawing.Color]::FromArgb(255, 0x1E, 0x1E, 0x1E)
$AccentColor     = [System.Drawing.Color]::FromArgb(255, 0x00, 0x7A, 0xCC)
$PromptColor     = [System.Drawing.Color]::FromArgb(255, 0xD4, 0xD4, 0xD4)

function New-RoundedRectPath {
    param(
        [single] $X, [single] $Y,
        [single] $Width, [single] $Height,
        [single] $Radius
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $Radius * 2

    $path.AddArc($X, $Y, $d, $d, 180, 90)
    $path.AddArc(($X + $Width - $d), $Y, $d, $d, 270, 90)
    $path.AddArc(($X + $Width - $d), ($Y + $Height - $d), $d, $d, 0, 90)
    $path.AddArc($X, ($Y + $Height - $d), $d, $d, 90, 90)
    $path.CloseFigure()

    return $path
}

function New-IconBitmap {
    param([int] $Size)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)

    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # Work in a 128-unit design space and scale, so both sizes stay identical.
    $scale = $Size / 128.0
    $g.ScaleTransform($scale, $scale)

    # Window background with rounded corners.
    $bgPath = New-RoundedRectPath -X 6 -Y 10 -Width 116 -Height 108 -Radius 14
    $bgBrush = New-Object System.Drawing.SolidBrush $BackgroundColor
    $g.FillPath($bgBrush, $bgPath)

    # Accent title bar, clipped to the rounded top of the window.
    $saved = $g.Save()
    $g.SetClip($bgPath)
    $accentBrush = New-Object System.Drawing.SolidBrush $AccentColor
    $g.FillRectangle($accentBrush, 6, 10, 116, 22)
    $g.Restore($saved)

    # Three title-bar dots, in the spirit of a terminal window.
    $dotBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0x3C, 0x3C, 0x3C))
    foreach ($cx in 22, 36, 50) {
        $g.FillEllipse($dotBrush, $cx, 17, 8, 8)
    }

    # The ">_" prompt.
    $pen = New-Object System.Drawing.Pen $PromptColor, 11
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $chevron = @(
        (New-Object System.Drawing.PointF(38, 56)),
        (New-Object System.Drawing.PointF(64, 76)),
        (New-Object System.Drawing.PointF(38, 96))
    )
    $g.DrawLines($pen, [System.Drawing.PointF[]]$chevron)

    # Cursor underscore.
    $g.DrawLine($pen, 76, 96, 96, 96)

    $g.Dispose()
    return $bmp
}

$targets = @(
    @{ Size = $PrimarySize; Path = Join-Path $PSScriptRoot 'icon.png' },
    @{ Size = $LargeSize; Path = Join-Path $PSScriptRoot 'icon-256.png' }
)

foreach ($target in $targets) {
    $bitmap = New-IconBitmap -Size $target.Size
    try {
        $bitmap.Save($target.Path, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host ("Wrote {0} ({1}x{1})" -f $target.Path, $target.Size) -ForegroundColor Green
    }
    finally {
        $bitmap.Dispose()
    }
}

Write-Host ''
Write-Host 'Done. Add this to package.json:' -ForegroundColor Cyan
Write-Host '  "icon": "icon.png"'