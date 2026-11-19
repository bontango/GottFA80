@{
    Name        = 'smd_hw11_cyclone_10_fa_lite'
    Title       = 'GottFA80 HW 1.1 SMD mit Cyclone 10 Board (10CL006YE144C8G), FA-Control lite'
    BoardId     = '4'            # eine Ziffer, steht auch in variant_pkg.vhd
    Line        = 'smd'          # files_smd.tcl, Top-Level top\SYS80_80.vhd
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_10'      # welche files_<familie>.tcl (lib_cyclone_II / _IV / _10)
    Options     = @('fa_lite')
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_falite_'   # GottFA80_v110_v<BoardId><SW_SUB_80>.jic
    ReleaseArtifact = 'jic'
    Dormant     = $true          # Probe, wird nicht released
    VirtualPins = @()
    Notes       = 'Probe 19.11.2026: smd_hw11_cyclone_10 + FA-Control lite (HAS_FA_LITE, Kennung FAR4), ersetzt smd_hw11_cyclone_10_fa/_fa_svc. Nicht hardwaregetestet (offen: USER0/USER1 und Hub am 10CL006).'
}
