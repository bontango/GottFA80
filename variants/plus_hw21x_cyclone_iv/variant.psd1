@{
    Name        = 'plus_hw21x_cyclone_iv'
    Title       = 'GottFA80 PLuS HW 2.1x mit Cyclone IV Board (EP4CE6E22C8)'
    BoardId     = '51'           # zweistellig, steht auch in variant_pkg.vhd
    Line        = 'plus'         # files_plus.tcl, Top-Level top\SYS80.vhd
    RtlFamily   = 'cyclone_iv'      # welche files_<familie>.tcl (lib_cyclone_IV / lib_cyclone_10)
    Options     = @()
    BinFolder   = 'PLuS/HW2.1x/Cyclone_IV'
    ReleasePrefix   = 'GottFA80_PLuS_'   # GottFA80_PLuS_v<BoardId><SW_SUB>.<ext>
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @('Debug[0]', 'Debug[1]', 'Debug[2]', 'FA_RXD', 'FA_TXD', 'FA_CTRL_REQ', 'Serial_RX', 'Serial_TX', 'SD_MOSI', 'SD_MISO', 'SD_CLK', 'EE_MOSI', 'EE_MISO', 'EE_CLK')
    Notes       = 'Ausgeliefert als GottFA80_PLuS_v511.jic. Kein Debug-Pin herausgefuehrt: Debug[0] seit 13.11.2026 VIRTUAL_PIN (PIN_11 neben DCLK, Error 169182), Debug[1..2] virtuell, weil PIN_7/PIN_2 hier Sound/Audio_RX sind (Korrektur v511).'
}
