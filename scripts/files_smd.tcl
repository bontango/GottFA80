# files_smd.tcl - Quellen nur der GottFA80-HW-1.1-Linie (SMD, Line = 'smd' in variant.psd1).
# Pfade sind relativ zum Projektverzeichnis variants\<n>\.
#
# read_the_dips_80.vhd (Entity read_the_dips_80 seit 13.11.2026, 2 Strobes / 5 Returns statt
# der PLuS-Matrix) braucht nur diese Linie.
set_global_assignment -name VHDL_FILE ../../lib_common/read_the_dips_80.vhd
set_global_assignment -name VHDL_FILE ../../top/SYS80_80.vhd
