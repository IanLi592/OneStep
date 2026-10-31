# make-icons.ps1 - Generate app icons from the source logo.
# Output: Android mipmap PNGs (48/72/96/144/192) + Windows multi-size .ico + design/icons/*.
# ASCII-only script (no non-ASCII) to avoid encoding issues under Windows PowerShell 5.1.
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$root       = 'D:\projects\Onestep'
$srcPath    = Join-Path $root 'design\logo-source.jpg'
$designOut  = Join-Path $root 'design\icons'
$androidRes = Join-Path $root 'app\android\app\src\main\res'
$winIco     = Join-Path $root 'app\windows\runner\resources\app_icon.ico'

if (!(Test-Path $srcPath)) { Write-Output "ERROR missing source: $srcPath"; exit 1 }
New-Item -ItemType Directory -Force -Path $designOut | Out-Null

# ---- 1) load source ----
$orig = [System.Drawing.Image]::FromFile($srcPath)
Write-Output ("source: {0}x{1}" -f $orig.Width, $orig.Height)

# ---- 2) detect the teal square bounding box on a downscaled copy (fast) ----
$sw = 384
$sh = [int][math]::Round($orig.Height * $sw / $orig.Width)
$small = New-Object System.Drawing.Bitmap($sw, $sh)
$g = [System.Drawing.Graphics]::FromImage($small)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($orig, 0, 0, $sw, $sh)
$g.Dispose()

$rect = New-Object System.Drawing.Rectangle(0, 0, $sw, $sh)
$ld = $small.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ls = $ld.Stride
$lbytes = New-Object byte[] ($ls * $sh)
[System.Runtime.InteropServices.Marshal]::Copy($ld.Scan0, $lbytes, 0, $lbytes.Length)
$small.UnlockBits($ld)
$small.Dispose()

$minX = $sw; $maxX = -1; $minY = $sh; $maxY = -1
for ($y = 0; $y -lt $sh; $y++) {
  for ($x = 0; $x -lt $sw; $x++) {
    $o = $y * $ls + $x * 4
    $B = $lbytes[$o]; $G = $lbytes[$o + 1]; $R = $lbytes[$o + 2]
    # teal-ish (dark green-blue): R low, G/B mid, G+B dominated
    if ($R -lt 110 -and $G -ge 55 -and $G -le 155 -and $B -ge 55 -and $B -le 165 -and (($G + $B) -gt ($R * 2))) {
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
if ($maxX -lt 0) { Write-Output 'ERROR teal square not detected'; exit 1 }

$scaleX = $orig.Width / $sw
$scaleY = $orig.Height / $sh
# expand 4px outward so the rounded-corner AA edge is included; flood fill clears white later
$cropX = [int][math]::Floor($minX * $scaleX) - 4
$cropY = [int][math]::Floor($minY * $scaleY) - 4
$cropW = [int][math]::Ceiling(($maxX - $minX + 1) * $scaleX) + 8
$cropH = [int][math]::Ceiling(($maxY - $minY + 1) * $scaleY) + 8
if ($cropX -lt 0) { $cropW += $cropX; $cropX = 0 }
if ($cropY -lt 0) { $cropH += $cropY; $cropY = 0 }
if (($cropX + $cropW) -gt $orig.Width)  { $cropW = $orig.Width - $cropX }
if (($cropY + $cropH) -gt $orig.Height) { $cropH = $orig.Height - $cropY }
Write-Output ("crop: x={0} y={1} w={2} h={3}" -f $cropX, $cropY, $cropW, $cropH)

# ---- 3) crop from original at full resolution ----
$cropRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
$cropped = New-Object System.Drawing.Bitmap($cropW, $cropH)
$g2 = [System.Drawing.Graphics]::FromImage($cropped)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.DrawImage($orig, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$orig.Dispose()

# ---- 4) master 512x512 with transparent corners (flood fill from 4 corners) ----
$masterSize = 512
$master = New-Object System.Drawing.Bitmap($masterSize, $masterSize)
$g3 = [System.Drawing.Graphics]::FromImage($master)
$g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g3.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g3.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$g3.DrawImage($cropped, 0, 0, $masterSize, $masterSize)
$g3.Dispose()
$cropped.Dispose()

$mrect = New-Object System.Drawing.Rectangle(0, 0, $masterSize, $masterSize)
$md = $master.LockBits($mrect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$mstride = $md.Stride
$mbytes = New-Object byte[] ($mstride * $masterSize)
[System.Runtime.InteropServices.Marshal]::Copy($md.Scan0, $mbytes, 0, $mbytes.Length)

$visited = New-Object bool[] ($masterSize * $masterSize)
$stack = New-Object System.Collections.Stack
$stack.Push(0)
$stack.Push($masterSize - 1)
$stack.Push(($masterSize - 1) * $masterSize)
$stack.Push(($masterSize - 1) * $masterSize + $masterSize - 1)
while ($stack.Count -gt 0) {
  $n = [int]$stack.Pop()
  $py = [int][math]::Floor($n / $masterSize)
  $px = $n - ($py * $masterSize)
  if ($visited[$n]) { continue }
  $visited[$n] = $true
  $o = $py * $mstride + ($px * 4)
  # near-white test (threshold 150): keeps solid teal edge, clears white margin + AA fringe
  if ($mbytes[$o] -gt 150 -and $mbytes[$o + 1] -gt 150 -and $mbytes[$o + 2] -gt 150) {
    $mbytes[$o + 3] = 0
    if ($px -gt 0) { $stack.Push($n - 1) }
    if ($px -lt ($masterSize - 1)) { $stack.Push($n + 1) }
    if ($py -gt 0) { $stack.Push($n - $masterSize) }
    if ($py -lt ($masterSize - 1)) { $stack.Push($n + $masterSize) }
  }
}
[System.Runtime.InteropServices.Marshal]::Copy($mbytes, 0, $md.Scan0, $mbytes.Length)
$master.UnlockBits($md)

$masterPath = Join-Path $designOut 'icon-512.png'
$master.Save($masterPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output ("master saved: {0}" -f $masterPath)

# ---- helper: resize from master (keeps alpha) ----
function New-Sized([System.Drawing.Bitmap]$srcBmp, [int]$size) {
  $b = New-Object System.Drawing.Bitmap($size, $size)
  $gg = [System.Drawing.Graphics]::FromImage($b)
  $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $gg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $gg.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $gg.DrawImage($srcBmp, 0, 0, $size, $size)
  $gg.Dispose()
  return $b
}

# ---- 5) Android mipmap PNGs ----
$androidMap = @{
  'mipmap-mdpi'    = 48
  'mipmap-hdpi'    = 72
  'mipmap-xhdpi'   = 96
  'mipmap-xxhdpi'  = 144
  'mipmap-xxxhdpi' = 192
}
foreach ($k in $androidMap.Keys) {
  $dir = Join-Path $androidRes $k
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $size = $androidMap[$k]
  $b = New-Sized $master $size
  $p = Join-Path $dir 'ic_launcher.png'
  $b.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
  Write-Output ("android: {0}\ic_launcher.png ({1}px)" -f $k, $size)
}

# ---- 6) Windows multi-size .ico (PNG-encoded entries) ----
$icoSizes = @(16, 24, 32, 48, 64, 128, 256)
$pngMap = @{}
foreach ($s in $icoSizes) {
  $b = New-Sized $master $s
  $p = Join-Path $designOut ("icon-{0}.png" -f $s)
  $b.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
  $pngMap[$s] = [System.IO.File]::ReadAllBytes($p)
}

$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([uint16]0)                 # reserved
$bw.Write([uint16]1)                 # type = icon
$bw.Write([uint16]$icoSizes.Count)   # count
$offset = 6 + (16 * $icoSizes.Count)
foreach ($s in $icoSizes) {
  $len = $pngMap[$s].Length
  if ($s -ge 256) { $dim = 0 } else { $dim = [byte]$s }
  $bw.Write([byte]$dim)              # width
  $bw.Write([byte]$dim)              # height
  $bw.Write([byte]0)                 # colors
  $bw.Write([byte]0)                 # reserved
  $bw.Write([uint16]1)               # planes
  $bw.Write([uint16]32)              # bitcount
  $bw.Write([uint32]$len)            # bytes in image
  $bw.Write([uint32]$offset)         # offset
  $offset += $len
}
foreach ($s in $icoSizes) { $bw.Write($pngMap[$s]) }
[System.IO.File]::WriteAllBytes($winIco, $ms.ToArray())
$bw.Close()
$ms.Dispose()
$master.Dispose()
Write-Output ("windows: {0}" -f $winIco)

Write-Output 'DONE'
exit 0
