@{
    Name        = 'smd_hw11_cyclone_10'
    Title       = 'GottFA80 HW 1.1 SMD mit Cyclone 10 Board (10CL006YE144C8G)'
    BoardId     = '4'            # eine Ziffer, steht auch in variant_pkg.vhd
    Line        = 'smd'          # files_smd.tcl, Top-Level top\SYS80_80.vhd
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_10'      # welche files_<familie>.tcl (lib_cyclone_II / _IV / _10)
    Options     = @()
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_'   # GottFA80_v110_v<BoardId><SW_SUB_80>.jic
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'Ausgeliefert als GottFA80_v110_v403a.jic.'
}
