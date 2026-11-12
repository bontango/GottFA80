# build.ps1 - eine Variante voll compilieren und die .jic erzeugen.
#
#   .\build.ps1 plus_hw21x_cyclone_iv
#   .\build.ps1 plus_hw21x_cyclone_10 -NoJic
#
# quartus_cpf laeuft mit dem VARIANTENORDNER als Arbeitsverzeichnis - deshalb sind
# die Pfade in SYS80.cof relativ dazu (output_files/SYS80.sof). Die alten flachen
# Projektordner hatten gar keine .cof (die .jic entstand in der IDE); die .cof der
# 80S-Variante zeigte absolut auf ihren eigenen Ordner - beim Kopieren haette man damit
# die .sof des falschen Boards gebrannt.
param(
    [Parameter(Mandatory, Position = 0)][string]$Variant,
    [switch]$NoGen,
    [switch]$NoJic
)

$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$VarDir     = Join-Path (Join-Path $RepoRoot 'variants') $Variant
$Project    = 'SYS80'

# Quartus-Version je FPGA-Familie wie in check.ps1: Cyclone II nur mit 13.0sp1.
$QuartusBin = [ordered]@{
    'Cyclone II' = 'C:\altera\13.0sp1\quartus\bin64'
    'DEFAULT'    = 'C:\intelFPGA_lite\22.1std\quartus\bin64'
}

if (-not (Test-Path $VarDir)) { throw "unbekannte Variante: $Variant" }

if (-not $NoGen) { & (Join-Path $ScriptDir 'gen_qsf.ps1') -Variants $Variant -Quiet }

$family = if ((Get-Content (Join-Path $VarDir "$Project.qsf") -Raw) -match '-name FAMILY\s+"?([^"\r\n]+)"?') { $Matches[1].Trim() } else { '' }
$bin    = if ($QuartusBin.Contains($family)) { $QuartusBin[$family] } else { $QuartusBin['DEFAULT'] }

$meta = Import-PowerShellDataFile (Join-Path $VarDir 'variant.psd1')
Write-Host "Baue $Variant - $($meta.Title)" -ForegroundColor Cyan

Push-Location $VarDir
try {
    # KEIN 2>&1 auf quartus_*.exe (PowerShell 5.1 macht aus der TBBmalloc-Notiz auf
    # stderr einen Fehler). $LASTEXITCODE ist die verlaessliche Auskunft.
    & "$bin\quartus_sh.exe" --flow compile $Project
    if ($LASTEXITCODE -ne 0) { throw "quartus_sh --flow compile ist fehlgeschlagen ($LASTEXITCODE)" }

    $sof = Join-Path $VarDir "output_files\$Project.sof"
    if (-not (Test-Path $sof)) { throw "keine .sof erzeugt: $sof" }
    "  {0}  {1:N0} Byte" -f (Split-Path $sof -Leaf), (Get-Item $sof).Length

    # Board v7 (kein JTAG): Release ist die .rbf, die der Assembler ueber
    # GENERATE_RBF_FILE (device.tcl) selbst schreibt. Pruefen, dass sie aus DIESEM
    # Compile stammt - eine alte .rbf neben einer neuen .sof waere ein falsches Release.
    if ($meta.ReleaseArtifact -eq 'rbf') {
        $rbf = Join-Path $VarDir "output_files\$Project.rbf"
        if (-not (Test-Path $rbf)) { throw "keine .rbf erzeugt: $rbf (GENERATE_RBF_FILE in device.tcl?)" }
        if ((Get-Item $rbf).LastWriteTime -lt (Get-Item $sof).LastWriteTime.AddSeconds(-60)) { throw ".rbf ist aelter als die .sof: $rbf" }
        "  {0}  {1:N0} Byte" -f (Split-Path $rbf -Leaf), (Get-Item $rbf).Length
    }

    # Cyclone II (smd_hw11_cyclone_ii): die .pof schreibt der Assembler selbst
    # (USE_CONFIGURATION_DEVICE ON, EPCS4). Gleiche Pruefung wie bei der .rbf.
    if ($meta.ReleaseArtifact -eq 'pof') {
        $pof = Join-Path $VarDir "output_files\$Project.pof"
        if (-not (Test-Path $pof)) { throw "keine .pof erzeugt: $pof" }
        if ((Get-Item $pof).LastWriteTime -lt (Get-Item $sof).LastWriteTime.AddSeconds(-60)) { throw ".pof ist aelter als die .sof: $pof" }
        # Geraetetypische Groesse: 524.508 B (wie GottFA80_v110_v103.pof).
        "  {0}  {1:N0} Byte" -f (Split-Path $pof -Leaf), (Get-Item $pof).Length
    }

    if (-not $NoJic -and $meta.ReleaseArtifact -eq 'jic') {
        & "$bin\quartus_cpf.exe" -c "$Project.cof"
        if ($LASTEXITCODE -ne 0) { throw "quartus_cpf ist fehlgeschlagen ($LASTEXITCODE)" }
        $jic = Join-Path $VarDir "output_files\$Project.jic"
        if (-not (Test-Path $jic)) { throw "keine .jic erzeugt: $jic" }
        # Geraetetypische Groesse (EPCS16): Cyclone IV 2.097.375 B, Cyclone 10 2.097.377 B.
        "  {0}  {1:N0} Byte" -f (Split-Path $jic -Leaf), (Get-Item $jic).Length
    }
}
finally { Pop-Location }

Write-Host "fertig." -ForegroundColor Green
