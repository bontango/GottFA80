@{
    Name        = 'smd_hw11_cyclone_iv_v4_vj'
    Title       = 'GottFA80 HW 1.1 SMD mit Cyclone IV Board v4.x (EP4CE6E22C8) + Virtual-JTAG-Testknoten'
    BoardId     = '3'            # wie smd_hw11_cyclone_iv_v4, steht auch in variant_pkg.vhd
    Line        = 'smd'          # files_smd.tcl, Top-Level top\SYS80_80.vhd
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_iv'
    Options     = @('pll_civ', 'vjtag_probe')
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_vj_'
    ReleaseArtifact = 'jic'
    Dormant     = $true          # Testvariante, wird nicht released
    VirtualPins = @()
    Notes       = 'Stufe 1 von FA-Control ueber Virtual JTAG (17.11.2026): smd_hw11_cyclone_iv_v4 plus Testknoten lib_common\vjtag_probe.vhd (HAS_VJTAG_PROBE). Test vom PC mit scripts\vjtag_test.tcl. Konzept: N:\Projekte\misc\USB_BLASTER_DIY\ESP32-C3_EVALUIERUNG.md Abschnitt 15.'
}
