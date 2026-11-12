@{
    Name        = 'plus_hw21x_cyclone_iv_v7_1'
    Title       = 'GottFA80 PLuS HW 2.1x mit Cyclone IV Board v7.1 (EP4CE22F17C8, ESP32-C3 auf X7)'
    BoardId     = '81'           # zweistellig, steht auch in variant_pkg.vhd
    Line        = 'plus'         # files_plus.tcl, Top-Level top\SYS80.vhd
    RtlFamily   = 'cyclone_iv'
    Options     = @()
    BinFolder   = 'PLuS/HW2.1x/Cyclone_IV_v7_1'
    # Board v7.1 hat wie v7 keinen JTAG-Stecker; die .rbf (GENERATE_RBF_FILE in device.tcl)
    # wird ueber den ESP32 geschrieben. build.ps1 prueft, dass sie frisch ist.
    ReleasePrefix   = 'GottFA80_PLuS_'   # GottFA80_PLuS_v<BoardId><SW_SUB>.<ext>
    ReleaseArtifact = 'rbf'
    Dormant     = $false
    # Debug[1..2] wie auf HW2.1x nicht herausgefuehrt; FA_* liegen auf echten Pins.
    VirtualPins = @('Debug[1]', 'Debug[2]')
    Notes       = 'Neu 06.11.2026: Board v7.1 mit EP4CE22 - FA-Control (HAS_ESP32) UND integriertes Soundboard (HAS_SOUNDBOARD). Pins aus v7 plus Neubelegung v7.1 (Piggyback-Doku 12.7); U4_PB[7]/[5] wegen der Takteingaenge A8/A9 auf N14/R16, dafuer zwei Drahtbruecken (pins.tcl). NICHT hardwaregetestet.'
}
