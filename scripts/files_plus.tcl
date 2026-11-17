# files_plus.tcl - Quellen nur der PLuS-Linie (Line = 'plus' in variant.psd1),
# seit 13.11.2026 auch der GottFA80S-Boards (variants\80s_*).
# Pfade sind relativ zum Projektverzeichnis variants\<n>\.
set_global_assignment -name VHDL_FILE ../../lib_common/uart_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/attract.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/dac.vhd
set_global_assignment -name VHDL_FILE "../../lib_common/Votrax-SC01.vhd"
# Votrax-SC-01-Emulation (Kopie aus Gosof80), gebaut nur mit HAS_VOTRAX (gen_votrax in
# GOSOF80.vhd). In jeder PLuS-Variante gelistet, aus demselben Grund wie lib_fa_control.
set_global_assignment -name VHDL_FILE ../../lib_common/votrax/votrax_tables_pkg.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/votrax/votrax_sc01.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/DFPlayer_Mini_CMD.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/GOSOF80.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/Flash_ROM.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/read_the_dips.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/disp80B_capture.vhd
# FA-Control (lib_fa_control, Kopie aus SternFA rtl/fa_control). In JEDER PLuS-Variante
# gelistet, gebaut nur mit HAS_ESP32: Quartus loest Entities auch im nicht genommenen
# generate-Zweig auf (Error 10481).
set_global_assignment -name VHDL_FILE ../../lib_fa_control/fa_control_pkg.vhd
set_global_assignment -name VHDL_FILE ../../lib_fa_control/uart_rx.vhd
set_global_assignment -name VHDL_FILE ../../lib_fa_control/uart_tx.vhd
set_global_assignment -name VHDL_FILE ../../lib_fa_control/fa_control.vhd
# FA-Block des Tops (seit 16.11.2026 ausgelagert, gemeinsam mit dem SMD-Top Board v7.1)
set_global_assignment -name VHDL_FILE ../../lib_common/fa_sys80.vhd
set_global_assignment -name VHDL_FILE ../../top/SYS80.vhd
