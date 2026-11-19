@{
    Name        = 'smd_hw11_cyclone_iv_v4'
    Title       = 'GottFA80 HW 1.1 SMD mit Cyclone IV Board v4.x (EP4CE6E22C8)'
    BoardId     = '3'            # eine Ziffer, steht auch in variant_pkg.vhd
    Line        = 'smd'          # files_smd.tcl, Top-Level top\SYS80_80.vhd
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_iv'      # welche files_<familie>.tcl (lib_cyclone_II / _IV / _10)
    Options     = @('pll_civ', 'fa_lite')
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_'   # GottFA80_v110_v<BoardId><SW_SUB_80>.jic
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'Ab 306: FA-Control lite ueber Virtual JTAG (HAS_FA_LITE, Kennung FAR3) - JTAG-Piggyback an P5 genuegt, kein SRAM-Laden. Vorher ausgeliefert als GottFA80_v110_v303/305.jic. CPU-Takt aus der PLL cpu_clock_gen, 80B-Bootanzeige wie PLuS v7_1 (seit 12.11.2026, nicht hardwaregetestet). Eigene SYS80.sdc (kein cpu_clk_gen-Takt).'
}
