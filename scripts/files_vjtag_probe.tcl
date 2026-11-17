# files_vjtag_probe.tcl - Option 'vjtag_probe' (variant.psd1): Virtual-JTAG-Testknoten,
# Stufe 1 von "FA-Control ueber Virtual JTAG" (17.11.2026). Nur smd_hw11_cyclone_iv_v4_vj.
# top\SYS80_80.vhd instanziiert vjtag_probe als COMPONENT (HAS_VJTAG_PROBE), darum muss die
# Datei in den anderen Varianten nicht gelistet sein.
set_global_assignment -name VHDL_FILE ../../lib_common/vjtag_probe.vhd
