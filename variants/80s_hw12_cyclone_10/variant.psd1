@{
    Name        = '80s_hw12_cyclone_10'
    Title       = 'GottFA80S HW 1.2 mit Cyclone 10 Board (10CL006YE144C8G)'
    BoardId     = '63'           # zweistellig, steht auch in variant_pkg.vhd
    Line        = 'plus'         # files_plus.tcl, Top-Level top\SYS80.vhd (gleiches Top wie PLuS)
    RtlFamily   = 'cyclone_10'      # welche files_<familie>.tcl (lib_cyclone_IV / lib_cyclone_10)
    Options     = @()
    BinFolder   = '80S/HW_1.2/Cyclone_10'
    ReleasePrefix   = 'GottFA80S_'   # GottFA80S_v<BoardId><SW_SUB>.<ext>
    ReleaseArtifact = 'jic'
    Changelog   = '80S\changelog.txt'   # statt PLuS\changelog.txt (release.ps1)
    Dormant     = $false
    VirtualPins = @('Debug[0]', 'Debug[1]', 'Debug[2]', 'FA_RXD', 'FA_TXD', 'FA_CTRL_REQ', 'FLASH_DCLK', 'FLASH_NCS', 'FLASH_ASDO', 'FLASH_DATA0', 'SD_MOSI', 'SD_MISO', 'SD_CLK', 'EE_MOSI', 'EE_MISO', 'EE_CLK')
    Notes       = 'Bisher ausgeliefert als GottFA80S_v612.jic (bin/80S/HW_1.2/Cyclone_10). Im Baumstand NICHT hardwaregetestet.'
}
