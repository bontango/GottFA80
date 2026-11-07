<#
.SYNOPSIS
  Builds the game ROM area for the configuration flash (lib_common\Flash_ROM.vhd,
  HAS_FLASH_ROM, since 07.11.2026). GottFA80 version, after SternFA x.30.

.DESCRIPTION
  The SD card stays the one source of the game data. This script takes an image of the
  whole card and lays the games out in the EPCS16, under the same slot numbers:

      card    sector 660 + n * 32    game n, 16 KByte: 0000h game ROM 1, 0800h game ROM 2,
                                     1000h sound ROM 1, 1800h sound ROM 2,
                                     2000h..3FFFh system ROM (8 KByte)
      flash   080000h                directory, 256 slots x 8 parts x 16 bit (blocks 0..1)
              080000h + b * 800h     block b (2..767), one 2 KByte part

  128 slots (64 games, normal and free play, selection "0" & freeplay & game) x 16 KByte
  = 2 MByte do not fit behind the bitstream (1.5 MByte). But most slots share parts:
  the system ROMs u2u3_80/80a, the "2K" filler blocks, free play changes mostly the sound
  ROMs. So every slot is cut into eight 2 KByte parts, every part is stored once, and
  the directory says which block holds which part of which slot.
  Image v501_FP: 128 slots in 294 blocks (588 KByte).

  A slot is a game when its 6502 reset vector (slot offset 3FFCh/3FFDh) is neither FFFF
  nor 0000. Other slots stay empty, Flash_ROM.vhd then reports error 8 for them.

  No CRC, neither on the card nor in the flash. FA_Control verifies what it writes.

  THE RESULT CONTAINS COPYRIGHTED GAME ROMS. Write it below output_files\ (ignored by
  git) and never into the released files.

  Board v7.1 has no JTAG: the ESP32 writes the ROM area into the EPCS (FA_Control, tile
  09 FPGA, address 0x080000, bits NOT reversed - unlike a .rbf). That is -Bin.

.PARAMETER Image
  Image of a GottFA80 SD card (raw sectors). Default: GottFA80_SD_Image_v501_FP.img
  next to FPGA_source.

.PARAMETER Bin
  The raw ROM area to write: flash 080000h up to the end of the last block.

.PARAMETER Out
  Optional Intel HEX with absolute addresses (for a .jic on boards with JTAG).

.PARAMETER Verify
  Read the result back, rebuild every slot from directory and blocks the way
  Flash_ROM.vhd does and compare it byte for byte with the image.

.EXAMPLE
  .\make_flash_hex.ps1 -Bin ..\variants\plus_hw21x_cyclone_iv_v7_1\output_files\gottfa80_roms.bin -Verify
#>
param(
    [string]$Image = (Join-Path $PSScriptRoot '..\..\GottFA80_SD_Image_v501_FP.img'),
    [string]$Bin,
    [string]$Out,
    [switch]$Verify
)
if (-not $Bin -and -not $Out) { throw 'Give -Bin (raw ROM area for FA_Control) and/or -Out (Intel HEX).' }

$ErrorActionPreference = 'Stop'

# card layout, see lib_common\SD_Card.vhd (sectorcount := gamenumber * 32 + 660)
$FirstSector = 660
$SlotBytes   = 16384      # 32 sectors
$CardSlots   = 128        # "0" & opt_freeplay & game_select
# flash layout, see lib_common\Flash_ROM.vhd (Base_Addr, Block_Count, FIRST_BLOCK)
$FlashBase   = 0x080000
$FlashEnd    = 0x200000   # EPCS16
$BlockBytes  = 2048
$DirSlots    = 256        # 8 bit selection
$Parts       = 8
$DirBlocks   = 2          # 256 * 8 * 2 Byte = 4 KByte
$VecOffset   = 0x3FFC     # 6502 reset vector FFFCh (low byte first)

$MaxBlocks   = ($FlashEnd - $FlashBase) / $BlockBytes   # 768

Add-Type -TypeDefinition @'
using System;
using System.Text;
public static class GottFA80Flash {
    static void Rec(StringBuilder sb, int type, int addr, byte[] d, int off, int len) {
        int sum = len + ((addr >> 8) & 0xFF) + (addr & 0xFF) + type;
        sb.AppendFormat(":{0:X2}{1:X4}{2:X2}", len, addr & 0xFFFF, type);
        for (int i = 0; i < len; i++) { sb.AppendFormat("{0:X2}", d[off + i]); sum += d[off + i]; }
        sb.AppendFormat("{0:X2}\r\n", (-sum) & 0xFF);
    }
    // Intel HEX with type 04 records for the upper address half, absolute addresses.
    public static string Hex(int addr, byte[] d) {
        StringBuilder sb = new StringBuilder();
        int upper = -1;
        for (int p = 0; p < d.Length; p += 16) {
            int a = addr + p;
            if ((a >> 16) != upper) {
                upper = a >> 16;
                Rec(sb, 4, 0, new byte[] { (byte)(upper >> 8), (byte)upper }, 0, 2);
            }
            Rec(sb, 0, a, d, p, Math.Min(16, d.Length - p));
        }
        Rec(sb, 1, 0, new byte[0], 0, 0);
        return sb.ToString();
    }
}
'@

$imgPath = (Resolve-Path $Image).Path
$img = [System.IO.File]::ReadAllBytes($imgPath)
Write-Host "image: $imgPath"

# --- which slots hold a game ---------------------------------------------------------
$games = @{}             # slot -> offset in the image
$empty = @()
for ($n = 0; $n -lt $CardSlots; $n++) {
    $off = ($FirstSector * 512) + ($n * $SlotBytes)
    if ($off + $SlotBytes -gt $img.Length) { $empty += $n; continue }
    $vec = [int]$img[$off + $VecOffset] -bor ([int]$img[$off + $VecOffset + 1] -shl 8)
    if ($vec -eq 0xFFFF -or $vec -eq 0x0000) { $empty += $n; continue }
    $games[$n] = $off
}
if ($games.Count -eq 0) { throw 'No slot with a valid reset vector - is this a GottFA80 card image (16 KByte slots from sector 660)?' }
if ($empty.Count -gt 0) {
    Write-Host ('slots without a reset vector, left empty: {0}' -f ($empty -join ', ')) -ForegroundColor DarkGray
}

# --- directory and blocks ------------------------------------------------------------
$dirBytes = $DirBlocks * $BlockBytes
$dir = New-Object byte[] $dirBytes
for ($i = 0; $i -lt $dirBytes; $i++) { $dir[$i] = 0xFF }         # FFFF = slot empty
$blocks = New-Object System.Collections.Generic.List[int]        # image offset of each data block
$index  = @{}                                                    # part content -> block number
foreach ($n in ($games.Keys | Sort-Object)) {
    $off = $games[$n]
    for ($c = 0; $c -lt $Parts; $c++) {
        $key = [Convert]::ToBase64String($img, $off + $c * $BlockBytes, $BlockBytes)
        if (-not $index.ContainsKey($key)) {
            $blocks.Add($off + $c * $BlockBytes)
            $index[$key] = $DirBlocks + $blocks.Count - 1
        }
        $b = $index[$key]
        $dir[$n * 16 + $c * 2]     = [byte]($b -shr 8)
        $dir[$n * 16 + $c * 2 + 1] = [byte]($b -band 0xFF)
    }
}
if ($DirBlocks + $blocks.Count -gt $MaxBlocks) {
    throw "$($blocks.Count) blocks plus directory do not fit into the EPCS16 (at most $($MaxBlocks - $DirBlocks) blocks)."
}

# --- the ROM area as it goes into the flash from 080000h -------------------------------
$area = New-Object byte[] (($DirBlocks + $blocks.Count) * $BlockBytes)
[Array]::Copy($dir, 0, $area, 0, $dirBytes)
for ($k = 0; $k -lt $blocks.Count; $k++) {
    [Array]::Copy($img, $blocks[$k], $area, ($DirBlocks + $k) * $BlockBytes, $BlockBytes)
}

function Get-FullPath([string]$p) {
    if ([System.IO.Path]::IsPathRooted($p)) { $full = $p }
    else { $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $p)) }
    $d = Split-Path $full
    if (-not (Test-Path $d)) { $null = New-Item -ItemType Directory -Path $d }
    return $full
}
if ($Bin) {
    $binFull = Get-FullPath $Bin
    [System.IO.File]::WriteAllBytes($binFull, $area)
    Write-Host ('written {0} ({1} Byte, FA_Control: address 0x080000, bits not reversed)' -f $binFull, $area.Length)
}
if ($Out) {
    $outFull = Get-FullPath $Out
    [System.IO.File]::WriteAllText($outFull, [GottFA80Flash]::Hex($FlashBase, $area), (New-Object System.Text.ASCIIEncoding))
    Write-Host ('written {0}' -f $outFull)
}
$lastAddr = $FlashBase + $area.Length - 1
Write-Host ('{0} slots, {1} parts ({2} KByte) instead of {3} - flash 080000h..{4:X6}, {5} of {6} blocks free' -f `
    $games.Count, $blocks.Count, ($blocks.Count * 2), ($games.Count * $Parts), $lastAddr,
    ($MaxBlocks - $DirBlocks - $blocks.Count), ($MaxBlocks - $DirBlocks))

# --- read it back --------------------------------------------------------------------
if ($Verify) {
    if ($Bin) { $chk = [System.IO.File]::ReadAllBytes($binFull) } else { $chk = $area }
    $bad = 0
    for ($n = 0; $n -lt $DirSlots; $n++) {
        for ($c = 0; $c -lt $Parts; $c++) {
            $e = $n * 16 + $c * 2
            $b = ([int]$chk[$e] -shl 8) -bor $chk[$e + 1]
            $isEmpty = ($b -lt $DirBlocks) -or ($b -ge $MaxBlocks)
            if (-not $games.ContainsKey($n)) {
                if (-not $isEmpty) { Write-Host ('slot {0,3} part {1}: should be empty, points to block {2}' -f $n, $c, $b) -ForegroundColor Red; $bad++ }
                continue
            }
            if ($isEmpty) { Write-Host ('slot {0,3} part {1}: empty in the flash' -f $n, $c) -ForegroundColor Red; $bad++; continue }
            $src = $games[$n] + $c * $BlockBytes
            $dst = $b * $BlockBytes
            for ($i = 0; $i -lt $BlockBytes; $i++) {
                if ($chk[$dst + $i] -ne $img[$src + $i]) {
                    Write-Host ('slot {0,3} part {1}: differs at {2:X4}' -f $n, $c, ($c * $BlockBytes + $i)) -ForegroundColor Red
                    $bad++; break
                }
            }
        }
    }
    if ($bad -gt 0) { throw "verify: $bad error(s)" }
    Write-Host ('verify: all {0} slots read back identical, {1} directory slots empty' -f $games.Count, ($DirSlots - $games.Count)) -ForegroundColor Green
}
