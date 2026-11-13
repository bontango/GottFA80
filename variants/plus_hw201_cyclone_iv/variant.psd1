@{
    Name        = 'plus_hw201_cyclone_iv'
    Title       = 'GottFA80 PLuS HW 2.01 mit Cyclone IV Board (EP4CE6E22C8)'
    BoardId     = '50'           # zweistellig, steht auch in variant_pkg.vhd
    Line        = 'plus'         # files_plus.tcl, Top-Level top\SYS80.vhd
    RtlFamily   = 'cyclone_iv'      # welche files_<familie>.tcl (lib_cyclone_IV / lib_cyclone_10)
    Options     = @()
    BinFolder   = 'PLuS/HW2.0x/Cyclone_IV'
    ReleasePrefix   = 'GottFA80_PLuS_'   # GottFA80_PLuS_v<BoardId><SW_SUB>.<ext>
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @('Debug[0]', 'FA_RXD', 'FA_TXD', 'FA_CTRL_REQ', 'Serial_RX', 'Serial_TX', 'SD_MOSI', 'SD_MISO', 'SD_CLK', 'EE_MOSI', 'EE_MISO', 'EE_CLK')
    Notes       = 'Ausgeliefert als GottFA80_PLuS_v501.jic (bin\PLuS\HW2.0x\Cyclone_IV). Bis 04.11.2026 nicht in Git - die Historie beginnt mit dem Umbau, Sicherung: archive\GottFA80_PLuS_HW201_Cyclone_IV_v4_2026-11-04.zip. Fuehrt Debug[0..2] auf PIN_11/7/2 heraus; Sound PIN_75, Audio_RX PIN_85.'
}
