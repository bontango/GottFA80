# files_fa_lite.tcl - Option 'fa_lite' (variant.psd1): FA-Control "lite" ueber Virtual JTAG
# (HAS_FA_LITE, 19.11.2026). Ohne fa_control/UARTs: der ESP32 spricht LISY selbst.
# top\SYS80_80.vhd instanziiert fa_jtag_regs und fa_lite_sys80 als COMPONENT.
# fa_control_pkg nur fuer den Typ fa_nibble_array_t.
set_global_assignment -name VHDL_FILE ../../lib_fa_control/fa_control_pkg.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/disp80B_capture_ram.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/fa_jtag_regs.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/fa_lite_sys80.vhd
