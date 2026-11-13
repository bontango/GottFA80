@{
    Name        = '80s_hw10_cyclone_iv'
    Title       = 'GottFA80S HW 1.1 umgebaut (CS_SDcard an PIN_42) mit Cyclone IV Board v4 (EP4CE6E22C8)'
    BoardId     = '54'           # zweistellig, steht auch in variant_pkg.vhd
    Line        = 'plus'         # files_plus.tcl, Top-Level top\SYS80.vhd (gleiches Top wie PLuS)
    RtlFamily   = 'cyclone_iv'      # welche files_<familie>.tcl (lib_cyclone_IV / lib_cyclone_10)
    Options     = @()
    BinFolder   = '80S/HW_1.0/Cyclone_IV'
    ReleasePrefix   = 'GottFA80S_'   # GottFA80S_v<BoardId><SW_SUB>.<ext>
    ReleaseArtifact = 'jic'
    Changelog   = '80S\changelog.txt'   # statt PLuS\changelog.txt (release.ps1)
    Dormant     = $false
    VirtualPins = @('Debug[0]', 'Debug[1]', 'Debug[2]', 'FA_RXD', 'FA_TXD', 'FA_CTRL_REQ', 'MOSI', 'MISO', 'CLK')
    Notes       = 'Seit 13.11.2026. GottFA80S HW 1.1 mit Drahtbruecke: CS_SDcard von PIN_11 (neben DCLK, Error 169182) auf PIN_42, Serial_RX (ungenutzter Eingang) auf PIN_11. Dafuer HAS_FLASH_ROM (Spiel-ROMs aus dem EPCS16, gottfa80_roms.jic). SD_MISO (PIN_24, Takteingang) hat keinen internen Pull-up - externen vorsehen. Sonst wie 80s_hw11_cyclone_iv. HW-getestet 13.11.2026 (Ralf, Monte Carlo, Stand 9f74715): Flash-ROMs mit und ohne SD-Karte, 80B-Bootanzeige GOTTFA80S.'
}
