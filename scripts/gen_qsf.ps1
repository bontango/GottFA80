# gen_qsf.ps1 - erzeugt variants\<name>\SYS80.qsf aus Fragmenten.
#
# Die .qsf wird NICHT von Hand gepflegt. Sie setzt sich zusammen aus
#   scripts\common_header.tcl      globale Assignments, fuer alle Varianten gleich
#   variants\<n>\device.tcl        FAMILY / DEVICE / LAST_QUARTUS_VERSION
#   variants\<n>\variant.psd1      TopEntity, RtlFamily, Options, VirtualPins
#   variants\<n>\pins.tcl          die Pinlagen dieses Boards
#   scripts\files_common.tcl       gemeinsame Quellen beider Linien (lib_common\, variant_pkg)
#   scripts\files_<Line>.tcl       Quellen der Linie samt Top-Level: plus -> top\SYS80.vhd,
#                                  smd -> top\SYS80_80.vhd (GottFA80 HW 1.1)
#   scripts\files_<RtlFamily>.tcl  die Megafunctions dieser FPGA-Familie (lib_cyclone_*\)
#   scripts\files_<Option>.tcl     je Eintrag in Options (pll_civ: PLL des SMD-Boards v4)
#   SDC_FILE                       variants\<n>\SYS80.sdc, wenn vorhanden, sonst lib_common\SYS80.sdc
#
# Warum VIRTUAL_PIN aus variant.psd1: ein deklarierter Ausgangsport ohne Pin-Location
# ist fuer Quartus ein BENUTZTER Pin. RESERVE_ALL_UNUSED_PINS greift dafuer nicht, und
# der Port landet auf einem echten, womoeglich beschalteten Pin der Platine.
# Bei den PLuS-Varianten betrifft das Debug[1..2]: HW2.01 fuehrt sie heraus (PIN_7/PIN_2),
# auf HW2.1x liegen dort Sound/Audio_RX - dort sind sie VIRTUAL_PIN.
#
#   .\gen_qsf.ps1                  alle Varianten schreiben
#   .\gen_qsf.ps1 -Variants plus_hw21x_cyclone_10
#   .\gen_qsf.ps1 -Check           nur vergleichen, nichts schreiben (Exit 1 bei Abweichung)
#   .\gen_qsf.ps1 -Quiet           schreiben, aber nur melden wenn die Datei anders war
#                                  (heisst in der Praxis: Quartus hat aus der IDE reingeschrieben)
param(
    [string[]]$Variants,
    [switch]  $Check,
    [switch]  $Quiet
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarRoot   = Join-Path $RepoRoot 'variants'
$Project   = 'SYS80'
$enc       = New-Object System.Text.UTF8Encoding($false)   # UTF-8 OHNE BOM

function Read-Fragment([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Fragment fehlt: $Path" }
    # Die Kopfkommentare der Fragmente gehoeren nicht in die erzeugte Datei.
    return @(Get-Content $Path | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' })
}

$folders = Get-ChildItem $VarRoot -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'variant.psd1') }
if ($Variants) { $folders = $folders | Where-Object { $Variants -contains $_.Name } }

# Escape-Hatch: eine Variante mit Generated = $false behaelt ihre handgepflegte .qsf.
$folders = $folders | Where-Object {
    $meta = Import-PowerShellDataFile (Join-Path $_.FullName 'variant.psd1')
    -not ($meta.ContainsKey('Generated') -and -not $meta.Generated)
}
if (-not $folders) { throw "keine erzeugbaren Varianten unterhalb $VarRoot" }

$common = Read-Fragment (Join-Path $ScriptDir 'common_header.tcl')
$fail   = $false

foreach ($dir in $folders) {
    $meta = Import-PowerShellDataFile (Join-Path $dir.FullName 'variant.psd1')
    if ($meta.Line -notin @('plus', 'smd')) { throw "$($dir.Name): Line in variant.psd1 muss 'plus' oder 'smd' sein" }
    $out  = New-Object System.Collections.Generic.List[string]

    $out.Add('# ==========================================================================')
    $out.Add('# GENERATED FILE - do not edit.')
    $out.Add('#')
    $out.Add("# Variante : $($meta.Name)")
    $out.Add("# Board    : $($meta.Title)")
    $out.Add('#')
    $out.Add('# Erzeugt von scripts\gen_qsf.ps1 aus')
    $out.Add('#   scripts\common_header.tcl')
    $out.Add("#   variants\$($meta.Name)\device.tcl")
    $out.Add("#   variants\$($meta.Name)\variant.psd1   (VIRTUAL_PIN)")
    $out.Add("#   variants\$($meta.Name)\pins.tcl")
    $out.Add('#   scripts\files_common.tcl')
    $out.Add("#   scripts\files_$($meta.Line).tcl")
    $out.Add("#   scripts\files_$($meta.RtlFamily).tcl")
    foreach ($opt in @($meta.Options)) { if ($opt) { $out.Add("#   scripts\files_$opt.tcl") } }
    $out.Add('#')
    $out.Add('# Aenderungen gehoeren in eines dieser Fragmente, nicht hierher.')
    $out.Add('# ==========================================================================')

    $out.Add('')
    $out.Add('# --- board ---')
    $topEntity = $Project
    if ($meta.TopEntity) { $topEntity = $meta.TopEntity }
    $out.Add("set_global_assignment -name TOP_LEVEL_ENTITY $topEntity")
    Read-Fragment (Join-Path $dir.FullName 'device.tcl') | ForEach-Object { $out.Add($_) }

    $out.Add('')
    $out.Add('# --- shared globals ---')
    $common | ForEach-Object { $out.Add($_) }

    if ($meta.VirtualPins -and @($meta.VirtualPins).Count -gt 0) {
        $out.Add('')
        $out.Add('# --- optionale Top-Level-Ports, die dieses Board nicht hat ---')
        foreach ($p in @($meta.VirtualPins)) {
            $out.Add("set_instance_assignment -name VIRTUAL_PIN ON -to $p")
        }
    }

    $out.Add('')
    $out.Add('# --- pins ---')
    Read-Fragment (Join-Path $dir.FullName 'pins.tcl') | ForEach-Object { $out.Add($_) }

    $out.Add('')
    $out.Add('# --- sources ---')
    Read-Fragment (Join-Path $ScriptDir 'files_common.tcl') | ForEach-Object { $out.Add($_) }
    Read-Fragment (Join-Path $ScriptDir "files_$($meta.Line).tcl") | ForEach-Object { $out.Add($_) }
    Read-Fragment (Join-Path $ScriptDir "files_$($meta.RtlFamily).tcl") | ForEach-Object { $out.Add($_) }
    foreach ($opt in @($meta.Options)) {
        if (-not $opt) { continue }
        Read-Fragment (Join-Path $ScriptDir "files_$opt.tcl") | ForEach-Object { $out.Add($_) }
    }
    # Timing: die gemeinsame .sdc, ausser die Variante bringt eine eigene mit
    # (smd_hw11_cyclone_iv_v4: CPU-Takt aus der PLL statt aus cpu_clk_gen).
    if (Test-Path (Join-Path $dir.FullName "$Project.sdc")) {
        $out.Add("set_global_assignment -name SDC_FILE $Project.sdc")
    } else {
        $out.Add("set_global_assignment -name SDC_FILE ../../lib_common/$Project.sdc")
    }

    $text = ($out -join "`r`n") + "`r`n"
    $qsf  = Join-Path $dir.FullName "$Project.qsf"

    if ($Check) {
        $have = if (Test-Path $qsf) { [System.IO.File]::ReadAllText($qsf) } else { '' }
        if ($have -eq $text) {
            Write-Host ("  {0,-22} .qsf aktuell" -f $meta.Name) -ForegroundColor Green
        } else {
            Write-Host ("  {0,-22} .qsf WEICHT AB" -f $meta.Name) -ForegroundColor Red
            $fail = $true
            Compare-Object ($have -split "`r`n") ($text -split "`r`n") |
                ForEach-Object { Write-Host ("      {0} {1}" -f $_.SideIndicator, $_.InputObject) }
        }
    } else {
        $had = if (Test-Path $qsf) { [System.IO.File]::ReadAllText($qsf) } else { '' }
        [System.IO.File]::WriteAllText($qsf, $text, $enc)
        if ($Quiet) {
            if ($had -ne $text) {
                Write-Host ("  {0,-22} .qsf neu geschrieben - sie war ausserhalb von gen_qsf veraendert" -f $meta.Name) -ForegroundColor Yellow
            }
        } else {
            Write-Host ("  {0,-22} .qsf geschrieben ({1} Zeilen)" -f $meta.Name, $out.Count) -ForegroundColor Green
        }
    }
}

if ($fail) { exit 1 }
