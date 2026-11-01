# set-version.ps1 - Assign a unique version before EVERY build.
#
# Why: Android package manager / app stores (Yingyongbao etc.) decide "is this
# an update" by versionCode. If it never changes, the platform may treat the
# install as the same build (caching/optimization), so a rebuilt APK can look
# like it "did not update". Every build must therefore get a fresh version.
#
#   versionName = 0.1.0-<yyyyMMddHHmm>   (human readable: date + time)
#   versionCode = <unix seconds>          (monotonic, unique, <= 2100000000)
#
# Unix seconds is monotonic and stays under Android's 2100000000 limit until
# year 2036, so versionCode always increases across builds.
#
# Usage:  pwsh -File scripts\set-version.ps1     (also called by build scripts)
$ErrorActionPreference = 'Stop'

# Note: Join-Path with multiple positional args is PowerShell Core only;
# use nested calls for Windows PowerShell 5.1 compatibility.
$pubspec = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') 'app\pubspec.yaml')).Path

$now = [DateTimeOffset]::Now
$ymdhm = $now.ToString('yyyyMMddHHmm')
$unix = $now.ToUnixTimeSeconds()
$newVersion = "0.1.0-$ymdhm+$unix"

# Guard: Android versionCode must be a positive int <= 2100000000.
if ($unix -le 0 -or $unix -gt 2100000000) {
    throw "versionCode out of range: $unix"
}

# Read as UTF-8 (pubspec has Chinese comments) and replace only the version line.
$content = [System.IO.File]::ReadAllText($pubspec, [System.Text.Encoding]::UTF8)
$updated = [regex]::Replace($content, '(?m)^version:\s*.*$', "version: $newVersion")
if ($updated -eq $content) {
    throw "version line not found in $pubspec"
}

# Write back as UTF-8 without BOM (matches pubspec convention).
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($pubspec, $updated, $utf8NoBom)

Write-Output "version -> $newVersion  (versionName=0.1.0-$ymdhm, versionCode=$unix)"
