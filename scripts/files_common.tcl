# files_common.tcl - Quellen, die JEDE Variante braucht (PLuS und SMD).
# Pfade sind relativ zum Projektverzeichnis variants\<n>\.
# Kein SEARCH_PATH: jede Datei steht explizit hier - eine neue .vhd kann so nicht
# in einer Variante fehlen. Packages zuerst.
#
# Was nur eine Linie braucht, steht in files_plus.tcl bzw. files_smd.tcl (Schluessel
# Line in variant.psd1), samt Top-Level. Getrennt, weil die Cyclone-II-Variante mit
# Quartus 13.0sp1 baut und die PLuS-/FA-Control-Quellen dort nicht mitparsen soll.
# Die .sdc setzt gen_qsf.ps1 selbst ein (lib_common\SYS80.sdc oder variants\<n>\SYS80.sdc).
set_global_assignment -name VHDL_FILE ../../lib_common/T65/T65_Pack.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/version_pkg.vhd
set_global_assignment -name VHDL_FILE variant_pkg.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/anti_thunk.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/EEprom.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/T65/T65_MCode.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/T65/T65_ALU.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/T65/T65.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SPI_Master.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SN74175.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SN7448_GTB.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SN7448.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/slow_to_fast_clock_bus.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/slow_to_fast_clock.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SD_Card.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/R6532.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/detect_sw_trigger.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/detect_sw.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/cpu_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/count_to_zero.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/byte_to_ascii.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/boot_message.vhd
# 80B-Bootanzeige: gebaut nur mit HAS_DISP_80B (PLuS v7_1, SMD Board v4), gelistet ueberall -
# Quartus loest Entities auch im nicht genommenen generate-Zweig auf (Error 10481).
set_global_assignment -name VHDL_FILE ../../lib_common/boot_message_80B.vhd
