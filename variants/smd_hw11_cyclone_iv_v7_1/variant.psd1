@{
    Name        = 'smd_hw11_cyclone_iv_v7_1'
    Title       = 'GottFA80 HW 1.1 SMD mit Cyclone IV Board v7.1 (EP4CE22F17C8, ESP32-C3 auf X7)'
    BoardId     = '8'            # eine Ziffer, steht auch in variant_pkg.vhd
    Line        = 'smd'          # files_smd.tcl, Top-Level top\SYS80_80.vhd
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_iv'
    # FA-Control-Quellen (lib_fa_control, fa_sys80) nur hier: files_fa_control.tcl
    Options     = @('fa_control')
    BinFolder   = 'v110/Cyclone_IV_v7_1'
    # Board v7.1 hat keinen JTAG-Stecker; die .rbf (GENERATE_RBF_FILE in device.tcl)
    # wird ueber den ESP32 geschrieben. build.ps1 prueft, dass sie frisch ist.
    ReleasePrefix   = 'GottFA80_v110_'   # GottFA80_v110_v<BoardId><SW_SUB_80>.rbf
    ReleaseArtifact = 'rbf'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'Neu 16.11.2026: SMD-Platine HW 1.1 auf Board v7.1 (EP4CE22) mit FA-Control (HAS_ESP32, lib_common\fa_sys80.vhd wie PLuS v7_1). Pins aus smd_hw11_cyclone_iv (v3 = v7 am Header) plus Neubelegung v7.1; keine Drahtbruecken (A8/A9 sind bei SMD Eingaenge). NICHT hardwaregetestet.'
}