@{
    Name        = 'smd_hw11_cyclone_iv_v4_fa_lite'
    Title       = 'GottFA80 HW 1.1 SMD Board v4.x, FA-Control lite ueber vJTAG (EP4CE6E22C8, voller Umfang)'
    BoardId     = '3'
    Line        = 'smd'
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_iv'
    Options     = @('pll_civ', 'fa_lite')
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_falite_'
    ReleaseArtifact = 'jic'
    Dormant     = $true          # Probesynthese, wird nicht released
    VirtualPins = @()
    Notes       = 'Probe 19.11.2026: FA-Control lite. Registerbank ueber Virtual JTAG (lib_common\fa_jtag_regs.vhd) + GottFA80-Kleber (lib_common\fa_lite_sys80.vhd), kein fa_control/LISY-Parser im FPGA - den spricht der ESP32 (FA_Control main\lisy_emul.c). Monitor, Steuerung und 80B-Text in einem Design. Kennung FAR3. Konzept und Zahlen: N:\Projekte\misc\USB_BLASTER_DIY\ESP32-C3_EVALUIERUNG.md Abschnitt 15.11.'
}
