@{
    Name        = 'smd_hw11_cyclone_iv_v4_fa'
    Title       = 'GottFA80 HW 1.1 SMD Board v4.x, Probesynthese FA-Control ueber vJTAG (EP4CE6E22C8, Sparversionen)'
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
    Notes       = 'Probesynthese 17.11.2026 fuer Stufe 3 von FA-Control ueber Virtual JTAG: smd_hw11_cyclone_iv_v4_vj plus FA-Control (HAS_ESP32, fa_sys80) mit virtuellen FA-Pins, Chip EP4CE6E22C8. Voll passt nicht (Error 170011). Sparversionen ueber Generics FA_MON/FA_CTRL/FA_80B_TXT in fa_sys80 (Defaults im Quelltext umstellen): Monitor 6037 LE (96 %), Monitor ohne 80B-Text 5787 (92 %), Steuerung ohne 80B-Text 6022 (96 %), Steuerung mit 80B-Text passt nicht. Zahlen: EVALUIERUNG Abschnitt 15.7. Ersetzt fa_vjtag_link noch nicht. Konzept: N:\Projekte\misc\USB_BLASTER_DIY\ESP32-C3_EVALUIERUNG.md Abschnitt 15.'
}