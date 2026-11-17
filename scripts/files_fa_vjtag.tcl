# files_fa_vjtag.tcl - Option 'fa_vjtag' (variant.psd1): FA-Control ueber Virtual JTAG
# (HAS_FA_VJTAG, 17.11.2026). Braucht zusaetzlich Option 'fa_control' (fa_sys80, UARTs).
# top\SYS80_80.vhd instanziiert fa_vjtag_link als COMPONENT.
set_global_assignment -name VHDL_FILE ../../lib_common/fa_vjtag_link.vhd
