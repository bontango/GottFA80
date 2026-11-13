# GottFA80

VHDL re-implementation of the **Gottlieb System 80 / 80A / 80B** pinball MPU on an
Altera/Intel FPGA – 6502 CPU (T65), RIOTs, displays, solenoids, lamps, NVRAM (EEPROM),
game roms from SD card; on the PLuS boards also an integrated sound board (GOSOF80,
DFPlayer Mini).

This repository was called `GottFA80_PLuS` until November 2026 and held only the PLuS
boards; it now carries the GottFA80 HW 1.1 (SMD) and the GottFA80S boards as well.
Hardware and background: <https://lisy.dev/> · releases: <https://lisy.dev/swrep/GottFA80>

## Boards

### GottFA80 PLuS (top level `top/SYS80.vhd`)

| Variant | Board | Device | Version shown | Release |
|---|---|---|---|---|
| `plus_hw201_cyclone_iv` | GottFA80 PLuS HW 2.01, Cyclone IV | `EP4CE6E22C8` | `50x` | `GottFA80_PLuS_v501.jic` |
| `plus_hw21x_cyclone_iv` | GottFA80 PLuS HW 2.1x, Cyclone IV | `EP4CE6E22C8` | `51x` | `GottFA80_PLuS_v511.jic` |
| `plus_hw21x_cyclone_10` | GottFA80 PLuS HW 2.1x, Cyclone 10 | `10CL006YE144C8G` | `61x` | `GottFA80_PLuS_v611.jic` |
| `plus_hw21x_cyclone_iv_v7` | GottFA80 PLuS HW 2.1x, Cyclone IV board v7 (ESP32-C3) | `EP4CE6F17C8` | `71x` | `GottFA80_PLuS_v711.rbf` |
| `plus_hw21x_cyclone_iv_v7_1` | GottFA80 PLuS HW 2.1x, Cyclone IV board v7.1 (ESP32-C3) | `EP4CE22F17C8` | `81x` | `GottFA80_PLuS_v811.rbf` (untested) |

### GottFA80S (same top level `top/SYS80.vhd`)

| Variant | Board | Device | Version shown | Last release (old numbering) |
|---|---|---|---|---|
| `80s_hw10_cyclone_iv` | GottFA80S HW 1.1 modified (CS_SDcard wired to pin 42, game ROMs from the config flash), Cyclone IV board v4 | `EP4CE6E22C8` | `54x` | – (new, untested) |
| `80s_hw11_cyclone_iv` | GottFA80S HW 1.1, Cyclone IV board v4 | `EP4CE6E22C8` | `52x` | `GottFA80S_v501.jic` |
| `80s_hw12_cyclone_iv` | GottFA80S HW 1.2, Cyclone IV board v4 | `EP4CE6E22C8` | `53x` | `GottFA80S_v512.jic` |
| `80s_hw12_cyclone_10` | GottFA80S HW 1.2, Cyclone 10 | `10CL006YE144C8G` | `63x` | `GottFA80S_v612.jic` |

The GottFA80S boards differ from PLuS only in their pinout, a serial port (USB / ESP-01,
currently unused) and, on HW 1.1, separate SPI buses for SD card and EEPROM
(`HAS_SHARED_SPI = false`). Since November 2026 they share the PLuS top level and thus show
the game number at boot with three digits (including the freeplay bit) as PLuS does. Their old version numbers
(501/511/512/612) collided with PLuS, so they got new board IDs (52, 53, 63).

### GottFA80 HW 1.1 SMD (top level `top/SYS80_80.vhd`)

| Variant | Board | Device | Version shown | Release |
|---|---|---|---|---|
| `smd_hw11_cyclone_ii` | GottFA80 HW 1.1 SMD, Cyclone II | `EP2C5T144C8` | `1xx` | `GottFA80_v110_v103.pof` |
| `smd_hw11_cyclone_iv` | GottFA80 HW 1.1 SMD, Cyclone IV board v3.x | `EP4CE6F17C8` | `2xx` | `GottFA80_v110_v203.jic` |
| `smd_hw11_cyclone_iv_v4` | GottFA80 HW 1.1 SMD, Cyclone IV board v4.x | `EP4CE6E22C8` | `3xx` | `GottFA80_v110_v303.jic` |
| `smd_hw11_cyclone_10` | GottFA80 HW 1.1 SMD, Cyclone 10 | `10CL006YE144C8G` | `4xx` | `GottFA80_v110_v403a.jic` |

The SMD boards have no sound board, a smaller DIP matrix (2 strobes, 5 returns) and three
FPGA board LEDs, so they have their own top level. The Cyclone II board has no second game
ROM for the late 80B games (not enough memory) and builds with Quartus 13.0sp1. The Cyclone
IV board v4.x takes the CPU clock from a PLL.

Within each line all boards share **one** top level and one source tree; both lines share
`lib_common/`. What differs per board are the pin locations (`variants/<name>/pins.tcl`),
the device and a few constants (`variants/<name>/variant_pkg.vhd`).

`plus_hw21x_cyclone_iv_v7` carries **FA-Control** (`lib_fa_control/`, a LISY API slave for
the ESP32-C3 web interface) and therefore has **no integrated sound board** – both do not
fit into the EP4CE6 together. Board v7 has no JTAG header; it is programmed through the
ESP32, the release artifact is the `.rbf`.

`plus_hw21x_cyclone_iv_v7_1` is board v7.1 with the larger **EP4CE22** and carries both
FA-Control and the integrated sound board; under FA-Control the sound board plays the sounds
FA-Control sends. On the EP4CE22 the balls A8/A9 are clock inputs only, so the switch strobes
`U4_PB[7]`/`U4_PB[5]` moved to N14/R16 and the board needs **two wire bridges**
(P2-8 to P3-16, P2-3 to P3-14, see `variants/plus_hw21x_cyclone_iv_v7_1/pins.tcl`).
Programming through the ESP32 needs an FA-Control firmware that knows the EP4CE22.

The version shown at boot is `BOARD_ID & SW_SUB`: the two leading digits identify the
board (`variants/<name>/variant_pkg.vhd`; first digit FPGA family, second digit board
revision), the last digit is the common software version (`lib_common/version_pkg.vhd`).
A release changes exactly one digit, and all boards follow. The SMD boards show
`BOARD_ID & SW_SUB_80`: one digit for the board (1 Cyclone II, 2 Cyclone IV v3.x,
3 Cyclone IV v4.x, 4 Cyclone 10) and two software digits.

## Layout

```
top/SYS80.vhd          top level of the PLuS and GottFA80S boards
top/SYS80_80.vhd       top level of the GottFA80 HW 1.1 (SMD) boards
lib_common/            all shared modules, version_pkg.vhd, SYS80.sdc
lib_cyclone_II/        megafunctions for Cyclone II     (identical entity names)
lib_cyclone_IV/        megafunctions for Cyclone IV E   (identical entity names)
lib_cyclone_10/        megafunctions for Cyclone 10 LP  (identical entity names)
lib_fa_control/        FA-Control (LISY API slave), built only where HAS_ESP32
variants/<name>/       variant_pkg.vhd, variant.psd1, device.tcl, pins.tcl,
                       SYS80.qpf, SYS80.cof, SYS80.qsf (GENERATED)
scripts/               gen_qsf.ps1  check.ps1  build.ps1  release.ps1  baseline.csv
                       common_header.tcl  files_common.tcl  files_plus.tcl  files_smd.tcl
                       files_<family>.tcl  files_pll_civ.tcl
```

## Building

Quartus Prime Lite **22.1std** (Cyclone IV E and Cyclone 10 LP); the Cyclone II board needs
Quartus II **13.0sp1** Web Edition. The scripts pick the version from the device family.

```powershell
powershell -File scripts\build.ps1 plus_hw21x_cyclone_10      # .sof + .jic
powershell -File scripts\check.ps1 -Full                      # all boards vs. baseline
```

Or open `variants/<name>/SYS80.qpf` in the Quartus GUI. **Do not edit `SYS80.qsf`** –
it is generated by `scripts/gen_qsf.ps1` from the fragments listed in its header. Pin
changes go into `pins.tcl`, file list changes into `scripts/files_*.tcl`. See
`WORKFLOW.md`.

## History

Until November 2026 each board was a separate Quartus project folder
(`GottFA80_PLuS_HW201_Cyclone_IV_v4`, `GottFA80_PLuS_HW21x_Cyclone_IV_v4`,
`GottFA80_PLuS_HW21x_Cyclone_10`). The HW 2.01 folder was never in this repository and
had fallen behind: its released `v501` still contains sound board GOSOF 3.96, the HW 2.1x
releases `v511`/`v611` contain GOSOF 3.97 with attract mode. Since the merge all boards
build the same sources; HW 2.01 gets GOSOF 3.97 with its next release.

The four GottFA80 HW 1.1 (SMD) folders (`GottFA80_HW1.1SMD_Cyclone_II`, `…_Cyclone_IV_v3`,
`…_Cyclone_IV_v4`, `…_Cyclone_10`) followed in November 2026; their history in this
repository starts there. The three 22.1 boards build the same sources as before. The
Cyclone II board used to carry its own, older copies of most modules and now uses
`lib_common/` like the others – its next release changes behaviour and needs testing on
hardware.

The three GottFA80S folders (`GottFA80S_HW1.1_Cyclone_IV_v4`, `GottFA80S_HW1.2_Cyclone_IV_v4`,
`GottFA80S_HW1.2_Cyclone_10`) followed on 13 November 2026, also with their history starting
here. They had their own copies of the PLuS top level; now they use it directly. The HW 1.1
folder no longer built (its project file lacked two sources GOSOF80 needs).

## License

GPL v3 or later, see the source file headers. (c) bontango, <https://lisy.dev/>
