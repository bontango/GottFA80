@{
    Name        = 'smd_hw11_cyclone_iv_v4_fa_ctrl'
    Title       = 'GottFA80 HW 1.1 SMD Board v4.x, FA-Control ueber vJTAG, Sparversion Steuerung (EP4CE6E22C8)'
    BoardId     = '3'
    Line        = 'smd'
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_iv'
    Options     = @('pll_civ', 'fa_control', 'fa_vjtag')
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_fa_'
    ReleaseArtifact = 'jic'
    Dormant     = $true          # Probesynthese, wird nicht released
    VirtualPins = @()
    Notes       = 'Probe 17.11.2026: wie smd_hw11_cyclone_iv_v4_fa, aber FA_SPAR = 2 (nur Steuerung, ohne 80B-Text). Gedacht zum Nachladen ins SRAM ueber das JTAG-Piggyback; im EPCS bleibt die Monitor-Version.'
}