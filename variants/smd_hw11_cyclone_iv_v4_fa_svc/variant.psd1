@{
    Name        = 'smd_hw11_cyclone_iv_v4_fa_svc'
    Title       = 'GottFA80 HW 1.1 SMD, FA-Control-Service-Design ueber vJTAG (EP4CE6E22C8)'
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
    Notes       = 'Probe 17.11.2026: FA_SPAR = 4 = Service-Design, volle Steuerung mit 80B-Text OHNE Spiel (kein SD-/Flash-Lader, reset_l bleibt 0, CPU/RIOTs/ROMs/EEPROM fallen weg). Zum Nachladen ins SRAM ueber das JTAG-Piggyback (FA_Control Menue 09 FPGA). Kennung FAS + BOARD_ID.'
}