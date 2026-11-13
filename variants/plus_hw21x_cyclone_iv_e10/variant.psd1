@{
    Name        = 'plus_hw21x_cyclone_iv_e10'
    Title       = 'GottFA80 PLuS HW 2.1x mit Cyclone IV Board, Probebau EP4CE10E22C8 mit Votrax-Emulation'
    BoardId     = '91'           # Platzhalter, nicht vergeben - steht auch in variant_pkg.vhd
    Line        = 'plus'         # files_plus.tcl, Top-Level top\SYS80.vhd
    RtlFamily   = 'cyclone_iv'      # welche files_<familie>.tcl (lib_cyclone_IV / lib_cyclone_10)
    Options     = @()
    BinFolder   = 'PLuS/HW2.1x/Cyclone_IV_E10'
    ReleasePrefix   = 'GottFA80_PLuS_'   # GottFA80_PLuS_v<BoardId><SW_SUB>.<ext>
    ReleaseArtifact = 'jic'
    Dormant     = $true          # Probebau: nicht in check.ps1 (ohne -All) und nicht in release.ps1
    VirtualPins = @('Debug[0]', 'Debug[1]', 'Debug[2]', 'FA_RXD', 'FA_TXD', 'FA_CTRL_REQ', 'Serial_RX', 'Serial_TX', 'SD_MOSI', 'SD_MISO', 'SD_CLK', 'EE_MOSI', 'EE_MISO', 'EE_CLK')
    Notes       = 'Probebau 13.11.2026: plus_hw21x_cyclone_iv mit EP4CE10E22C8 (gleiches Die/Pinout wie EP4CE6 im E144) und HAS_VOTRAX (Votrax-SC-01-Emulation aus Gosof80). Pins unveraendert. NICHT hardwaregetestet, kein Release.'
}
