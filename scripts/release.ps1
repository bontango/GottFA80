# release.ps1 - Varianten bauen, die .jic nach bin\ legen, changelog fortschreiben.
#
#   .\release.ps1 -Note "kurz, was diese Version aendert"
#   .\release.ps1 -Note "..." -Variants plus_hw21x_cyclone_10
#   .\release.ps1 -Note "..." -Force        vorhandene Datei ueberschreiben
#
# Die Versionsnummer setzt sich zusammen aus variants\<n>\variant.psd1 (BoardId, identisch
# mit BOARD_ID in variant_pkg.vhd) und der Software-Konstante der Linie in
# lib_common\version_pkg.vhd. Ein Release aendert genau EINE Konstante, alle Boards der
# Linie folgen:
#   PLuS (Line = plus): BoardId zweistellig & SW_SUB (eine Ziffer)
#                       bin\<BinFolder>\GottFA80_PLuS_v<BoardId><SW_SUB>.jic|.rbf
#   SMD  (Line = smd) : BoardId eine Ziffer & SW_SUB_80 (zwei Ziffern)
#                       bin\v110\GottFA80_v110_v<BoardId><SW_SUB_80>.jic|.pof
# Der Dateiname beginnt mit ReleasePrefix aus variant.psd1. -Variants mit Varianten
# BEIDER Linien in einem Lauf geht nicht (zwei Changelogs, zwei Versionsstaende).
#
# bin\ ist (Stand 11/2026) NICHT im Git-Repo - die Releases liegen nur auf dem
# Netzlaufwerk und auf lisy.dev/swrep.
param(
    [Parameter(Mandatory)][string]$Note,
    [string[]]$Variants,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarRoot   = Join-Path $RepoRoot 'variants'
$BinRoot   = Join-Path $RepoRoot 'bin'
$Project   = 'SYS80'

$verSrc = Get-Content (Join-Path $RepoRoot 'lib_common\version_pkg.vhd') -Raw
if ($verSrc -notmatch "SW_SUB\s*:\s*character\s*:=\s*'(\d)'") { throw 'SW_SUB nicht in lib_common\version_pkg.vhd gefunden' }
$subPlus = $Matches[1]
if ($verSrc -notmatch 'SW_SUB_80\s*:\s*string\(1 to 2\)\s*:=\s*"(\d\d)"') { throw 'SW_SUB_80 nicht in lib_common\version_pkg.vhd gefunden' }
$subSmd = $Matches[1]

# je Linie: Versionskonstante, Laenge der BoardId, Changelog
$LineInfo = @{
    plus = @{ Sub = $subPlus; IdLen = 2; Log = 'PLuS\changelog.txt' }
    smd  = @{ Sub = $subSmd;  IdLen = 1; Log = 'v110\Changelog.txt' }
}

$dirs = Get-ChildItem $VarRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'variant.psd1') }
if ($Variants) { $dirs = $dirs | Where-Object { $Variants -contains $_.Name } }
else {
    $dirs = $dirs | Where-Object {
        $m = Import-PowerShellDataFile (Join-Path $_.FullName 'variant.psd1')
        -not $m.Dormant
    }
}
if (-not $dirs) { throw 'keine Varianten zu releasen' }

$lines = @($dirs | ForEach-Object { (Import-PowerShellDataFile (Join-Path $_.FullName 'variant.psd1')).Line } | Sort-Object -Unique)
if ($lines.Count -ne 1) { throw "Varianten aus mehreren Linien ($($lines -join ', ')) - bitte mit -Variants je Linie getrennt releasen." }
$line = $LineInfo[$lines[0]]

$done = @()
foreach ($dir in $dirs) {
    $meta = Import-PowerShellDataFile (Join-Path $dir.FullName 'variant.psd1')
    $pkg  = Get-Content (Join-Path $dir.FullName 'variant_pkg.vhd') -Raw
    $n = $line.IdLen
    if ($pkg -notmatch "BOARD_ID\s*:\s*string\(1 to $n\)\s*:=\s*`"(\d{$n})`"") { throw "BOARD_ID (string(1 to $n)) fehlt in $($dir.Name)\variant_pkg.vhd" }
    if ($Matches[1] -ne $meta.BoardId) { throw "$($dir.Name): BoardId in variant.psd1 ($($meta.BoardId)) <> variant_pkg.vhd ($($Matches[1]))" }
    if (-not $meta.ReleasePrefix) { throw "$($dir.Name): ReleasePrefix fehlt in variant.psd1" }

    $ver  = "$($meta.BoardId)$($line.Sub)"
    $ext  = $meta.ReleaseArtifact
    $target = Join-Path $BinRoot ($meta.BinFolder -replace '/', '\')
    if (-not (Test-Path $target)) { New-Item -ItemType Directory $target | Out-Null }
    $dest = Join-Path $target "$($meta.ReleasePrefix)v$ver.$ext"

    if ((Test-Path $dest) -and -not $Force) {
        throw "$dest gibt es schon. SW_SUB bzw. SW_SUB_80 in lib_common\version_pkg.vhd hochziehen oder -Force benutzen."
    }

    & (Join-Path $ScriptDir 'build.ps1') $dir.Name
    $src = Join-Path $dir.FullName "output_files\$Project.$ext"
    if (-not (Test-Path $src)) { throw "Artefakt fehlt: $src" }
    Copy-Item $src $dest -Force

    $sha = (Get-FileHash $dest -Algorithm SHA256).Hash.Substring(0, 16)
    $done += [pscustomobject]@{ Variant = $dir.Name; Version = $ver; File = "$($meta.BinFolder)/$(Split-Path $dest -Leaf)"; Sha = $sha }
}

# Ein Changelog je Linie: PLuS bin\PLuS\changelog.txt (aeltere Eintraege in
# bin\PLuS\HW2.1x\changelog.txt), SMD bin\v110\Changelog.txt.
$log   = Join-Path $BinRoot $line.Log
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$head  = (($done | Sort-Object Version | ForEach-Object { "v$($_.Version)" }) -join '/')
$lines = @('', "-- $head $Note", "   $stamp")
foreach ($d in ($done | Sort-Object Variant)) {
    $lines += "   {0,-22} {1,-4} {2}  sha256:{3}" -f $d.Variant, $d.Version, $d.File, $d.Sha
}
Add-Content -Path $log -Value $lines -Encoding UTF8

$done | Format-Table -AutoSize
Write-Host "In $log fortgeschrieben." -ForegroundColor Green
Write-Host "Nicht vergessen: in VARIANTEN.md eintragen, welche Variante tatsaechlich auf Hardware getestet wurde." -ForegroundColor Yellow
