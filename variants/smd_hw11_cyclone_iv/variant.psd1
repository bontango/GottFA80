@{
    Name        = 'smd_hw11_cyclone_iv'
    Title       = 'GottFA80 HW 1.1 SMD mit Cyclone IV Board v3.x (EP4CE6F17C8)'
    BoardId     = '2'            # eine Ziffer, steht auch in variant_pkg.vhd
    Line        = 'smd'          # files_smd.tcl, Top-Level top\SYS80_80.vhd
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_iv'      # welche files_<familie>.tcl (lib_cyclone_II / _IV / _10)
    Options     = @('fa_lite')
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_'   # GottFA80_v110_v<BoardId><SW_SUB_80>.jic
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'Ab 306: FA-Control lite ueber Virtual JTAG (HAS_FA_LITE, Kennung FAR2) - JTAG-Piggyback genuegt; nicht hardwaregetestet. Vorher ausgeliefert als GottFA80_v110_v203.jic. Vorher Ordner GottFA80_HW1.1SMD_Cyclone_IV_v3 (Board v3.x, EP4CE6 im F17-Gehaeuse) - benannt wie BallyFA hw1_cyclone_iv. 80B-Bootanzeige wie PLuS v7_1 seit 12.11.2026.'
}
