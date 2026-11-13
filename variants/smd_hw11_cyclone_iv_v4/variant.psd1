@{
    Name        = 'smd_hw11_cyclone_iv_v4'
    Title       = 'GottFA80 HW 1.1 SMD mit Cyclone IV Board v4.x (EP4CE6E22C8)'
    BoardId     = '3'            # eine Ziffer, steht auch in variant_pkg.vhd
    Line        = 'smd'          # files_smd.tcl, Top-Level top\SYS80_80.vhd
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_iv'      # welche files_<familie>.tcl (lib_cyclone_II / _IV / _10)
    Options     = @('pll_civ')
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_'   # GottFA80_v110_v<BoardId><SW_SUB_80>.jic
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @('FLASH_DCLK', 'FLASH_NCS', 'FLASH_ASDO', 'FLASH_DATA0')
    Notes       = 'Ausgeliefert als GottFA80_v110_v303.jic. CPU-Takt aus der PLL cpu_clock_gen, 80B-Bootanzeige wie PLuS v7_1 (seit 12.11.2026, nicht hardwaregetestet). Eigene SYS80.sdc (kein cpu_clk_gen-Takt).'
}
