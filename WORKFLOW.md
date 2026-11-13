# Arbeitsweise im gemeinsamen Sourcebaum (GottFA80)

Zwei Linien in einem Baum: **PLuS** (`variants/plus_*`, Top-Level `top/SYS80.vhd`) und
**GottFA80 HW 1.1 SMD** (`variants/smd_hw11_*`, Top-Level `top/SYS80_80.vhd`, seit
12.11.2026). Welche Linie, steht als `Line` in `variants/<n>/variant.psd1`.
**GottFA80S** (`variants/80s_*`, seit 13.11.2026) gehört zur Linie `plus`: gleiches Top-Level,
nur eigene Pins, `BOARD_ID`, `ReleasePrefix = 'GottFA80S_'` und Changelog `bin/80S/changelog.txt`.

## Was ändern → wo

| Ich will … | Datei |
|---|---|
| Logik ändern (PLuS und 80S) | `top/SYS80.vhd`, `lib_common/*.vhd` |
| Logik ändern (SMD) | `top/SYS80_80.vhd`, `lib_common/*.vhd` |
| eine neue `.vhd` hinzufügen | Datei nach `lib_common/` **und** Eintrag in `scripts/files_common.tcl` (beide Linien), `files_plus.tcl` oder `files_smd.tcl` |
| eine Board-Eigenschaft schalten | Konstante in `variants/<n>/variant_pkg.vhd` + paarweises `if … generate` im Top-Level |
| einen Pin eines Boards verlegen | `variants/<n>/pins.tcl` |
| einen Port nur auf einem Board haben | Port ins Top-Level, auf den anderen Boards in `variant.psd1` → `VirtualPins` |
| eine globale Quartus-Einstellung | `scripts/common_header.tcl` |
| Gerät/Familie | `variants/<n>/device.tcl` |
| Timing-Constraints | `lib_common/SYS80.sdc` (gilt für alle, außer eine Variante hat eine eigene `variants/<n>/SYS80.sdc` – derzeit nur `smd_hw11_cyclone_iv_v4`) |
| Megafunction (ROM/RAM) neu erzeugen | in `lib_cyclone_IV/`, `lib_cyclone_10/` **und** (falls SMD sie nutzt) `lib_cyclone_II/` mit Quartus 13.0sp1, Entity-Namen gleich lassen |
| Release PLuS | `SW_SUB` in `lib_common/version_pkg.vhd` +1, dann `scripts/release.ps1 -Note "…" -Variants plus_…` |
| Release 80S | gleiches `SW_SUB` wie PLuS; `scripts/release.ps1 -Note "…" -Variants 80s_…` (oder zusammen mit `plus_…`, je ein Changelog-Eintrag) |
| Release SMD | `SW_SUB_80` in `lib_common/version_pkg.vhd` +1, dann `scripts/release.ps1 -Note "…" -Variants smd_…` |

**`variants/<n>/SYS80.qsf` nie von Hand ändern.** Schreibt Quartus aus der IDE etwas
hinein (Pin Planner, Settings-Dialog), meldet `gen_qsf.ps1 -Quiet` das beim nächsten
`check.ps1`/`build.ps1` und überschreibt es. Die Änderung dann ins passende Fragment
übertragen.

## Ablauf einer Änderung

```powershell
cd N:\Projekte\FPGA System80\FPGA_source
powershell -File scripts\check.ps1            # schnell: nur Synthese aller Boards
powershell -File scripts\check.ps1 -Full      # voll, mit Slack und .sof
powershell -File scripts\build.ps1 plus_hw21x_cyclone_iv   # .sof + .jic eines Boards
```

`check.ps1` vergleicht mit `scripts/baseline.csv` (Synthese-Zahlen Comb/Reg/Mem exakt,
Slack mit Toleranz 1,5 ns und Boden 0,05 ns). Eine **gewollte** Änderung: Zahlen in
`baseline.csv` nachziehen und in der Note-Spalte begründen.

Exit-Codes: 0 sauber · 1 Buildfehler · 2 Abweichung von der Baseline.

## Release

Je Linie getrennt – `release.ps1` lehnt eine Auswahl aus beiden Linien ab.

1. `lib_common/version_pkg.vhd`: `SW_SUB` (PLuS, eine Ziffer) bzw. `SW_SUB_80` (SMD, zwei
   Ziffern) hochzählen.
2. `powershell -File scripts\release.ps1 -Note "was sich ändert" -Variants <die Boards der Linie>`
   → baut sie und legt `bin/<BinFolder>/<ReleasePrefix>v<BoardId><Sub>.<ext>` ab:
   PLuS `bin/PLuS/…/GottFA80_PLuS_v512.jic`, SMD `bin/v110/GottFA80_v110_v204.jic` bzw. `.pof`.
   80S `bin/80S/HW_1.2/Cyclone_IV/GottFA80S_v532.jic`.
   Schreibt `bin/PLuS/changelog.txt`, `bin/80S/changelog.txt` (Schlüssel `Changelog` in
   `variant.psd1`) bzw. `bin/v110/Changelog.txt` mit SHA-256 fort.
3. In `VARIANTEN.md` eintragen, welches Board **auf Hardware** getestet wurde.

## Die alten Projektordner

`GottFA80_PLuS_HW201_Cyclone_IV_v4`, `GottFA80_PLuS_HW21x_Cyclone_IV_v4`,
`GottFA80_PLuS_HW21x_Cyclone_10` liegen nur noch als Backup auf dem Netzlaufwerk und
sind seit 04.11.2026 nicht mehr im Repo. **Dort nicht mehr bauen oder ändern.**
HW201 baut dort ohnehin nicht mehr (siehe `VARIANTEN.md`).

Ebenso die SMD-Ordner `GottFA80_HW1.1SMD_Cyclone_II`, `…_Cyclone_IV_v3`, `…_Cyclone_IV_v4`,
`…_Cyclone_10` seit 12.11.2026 (Sicherung `archive/<Ordner>_2026-11-12.zip`).
`GottFA80_HW1.1SMD_Cyclone_IV_v3_MPF` ist ein Duplikat von v3 und wurde nicht übernommen.

Ebenso die GottFA80S-Ordner `GottFA80S_HW1.1_Cyclone_IV_v4`, `GottFA80S_HW1.2_Cyclone_IV_v4`,
`GottFA80S_HW1.2_Cyclone_10` seit 13.11.2026 (Sicherung `archive/<Ordner>_2026-11-13.zip`).
Sie zeigen weiter per `../lib_common` auf den Baum – eine Änderung dort wirkt also auch in
diesen Ordnern, ist aber kein Grund mehr, sie gegenzuprüfen. Damit ist kein flacher Ordner mehr aktiv.

## Fallstricke

- In Windows PowerShell 5.1 kein `2>&1` (und kein `*>`) auf `quartus_*.exe` bzw. auf
  Skripte, die es aufrufen – die TBBmalloc-Notiz auf stderr wird sonst zum Fehler.
- Textersetzungen nicht mit `sed -i` aus der Git-Bash (zerstört CRLF), sondern
  PowerShell `[System.IO.File]::WriteAllText` mit `UTF8Encoding($false)`.
- `else generate` gibt es in VHDL-93 nicht; Generate-Labels ändern Hierarchienamen,
  auf die die `.sdc` zeigt (`cpu_clk_gen:clock_gen|cpu_clk_out`). Deshalb steht
  `clock_gen` in `top/SYS80_80.vhd` außerhalb jedes Generate.
- Die `.sdc` wirkt auch auf die **Synthese** (timing-gesteuert): Der False-Path auf
  `boot_message:BM|Din_Seg*` kostet bei den SMD-Boards +5 Register. Instanznamen, auf die
  die `.sdc` zeigt, nicht umbenennen.
- Cyclone II baut mit Quartus 13.0sp1: Dort wirkt `VIRTUAL_PIN` nicht, und Quellen müssen
  VHDL-93 bleiben. Nach Änderungen in `files_common.tcl`-Modulen `check.ps1 -Variants
  smd_hw11_cyclone_ii` laufen lassen.
