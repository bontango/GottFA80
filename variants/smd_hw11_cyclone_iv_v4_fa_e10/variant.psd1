@{
    Name        = 'smd_hw11_cyclone_iv_v4_fa_e10'
    Title       = 'GottFA80 HW 1.1 SMD Board v4.x, Probesynthese FA-Control ueber vJTAG (EP4CE10E22C8)'
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
    Notes       = 'Probesynthese 17.11.2026 fuer Stufe 3 von FA-Control ueber Virtual JTAG: smd_hw11_cyclone_iv_v4_vj plus FA-Control (HAS_ESP32, fa_sys80) mit virtuellen FA-Pins, Chip EP4CE10E22C8. Voller Funktionsumfang wie v7_1. Ergebnis: 8103/10320 LE (79 %), Slack 0,135. Ersetzt fa_vjtag_link noch nicht. Konzept: N:\Projekte\misc\USB_BLASTER_DIY\ESP32-C3_EVALUIERUNG.md Abschnitt 15.'
}