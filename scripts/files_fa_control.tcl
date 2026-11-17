# files_fa_control.tcl - Option 'fa_control' (variant.psd1) fuer SMD-Varianten mit ESP32
# (Board v7.1, HAS_ESP32). Pfade sind relativ zum Projektverzeichnis variants\<n>\.
#
# Die PLuS-Linie listet diese Dateien in files_plus.tcl. Die SMD-Linie bekommt sie nur
# ueber diese Option: smd_hw11_cyclone_ii baut mit Quartus 13.0sp1 und soll die
# FA-Control-Quellen nicht mitparsen. Dafuer instanziiert top\SYS80_80.vhd fa_sys80 als
# COMPONENT - eine Component im nicht genommenen generate-Zweig braucht keine Entity
# (anders als 'entity work.', Error 10481).
set_global_assignment -name VHDL_FILE ../../lib_fa_control/fa_control_pkg.vhd
set_global_assignment -name VHDL_FILE ../../lib_fa_control/uart_rx.vhd
set_global_assignment -name VHDL_FILE ../../lib_fa_control/uart_tx.vhd
set_global_assignment -name VHDL_FILE ../../lib_fa_control/fa_control.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/disp80B_capture.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/fa_sys80.vhd