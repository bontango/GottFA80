@{
    Name        = 'smd_hw11_cyclone_10_fa_svc'
    Title       = 'GottFA80 HW 1.1 SMD, FA-Control-Service-Design ueber vJTAG (10CL006YE144C8G)'
    BoardId     = '4'            # eine Ziffer, steht auch in variant_pkg.vhd
    Line        = 'smd'          # files_smd.tcl, Top-Level top\SYS80_80.vhd
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_10'      # welche files_<familie>.tcl (lib_cyclone_II / _IV / _10)
    Options     = @('fa_control', 'fa_vjtag')
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_'   # GottFA80_v110_v<BoardId><SW_SUB_80>.jic
    ReleaseArtifact = 'jic'
    Dormant     = $true
    VirtualPins = @()
    Notes       = 'Probe 17.11.2026: FA_SPAR = 4 = Service-Design, volle Steuerung mit 80B-Text OHNE Spiel (kein SD-/Flash-Lader, reset_l bleibt 0, CPU/RIOTs/ROMs/EEPROM fallen weg). Zum Nachladen ins SRAM ueber das JTAG-Piggyback (FA_Control Menue 09 FPGA). Kennung FAS + BOARD_ID.'
}
