# device.tcl - was fuer DIESES Board gilt, ausser den Pinlagen.
# Wird von scripts\gen_qsf.ps1 in SYS80.qsf eingesetzt. Handgepflegt.
#
# Board v7.1 hat keinen JTAG-Stecker: programmiert wird ueber den ESP32 auf X7
# (FA-Control, Kachel 09 FPGA, oder POST /api/fpgaup). Release ist deshalb die .rbf.
# FA-Control braucht dafuer das E22-Leer-Design (as_release_e22). Wie plus_hw21x_cyclone_iv_v7_1.
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE22F17C8
set_global_assignment -name LAST_QUARTUS_VERSION "22.1std.2 Lite Edition"
set_global_assignment -name GENERATE_RBF_FILE ON

# AS-Pins nach der Konfiguration als User-I/O: Flash_ROM.vhd liest die Spiel-ROMs aus dem
# EPCS16 (HAS_FLASH_ROM). RESERVE_ASDO steht schon in scripts\common_header.tcl.
set_global_assignment -name RESERVE_DATA0_AFTER_CONFIGURATION "USE AS REGULAR IO"
# C1 ist ASDO und DATA1 zugleich - ohne diese Zeile belegt Quartus C1 doppelt (Error 176310)
set_global_assignment -name RESERVE_DATA1_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_FLASH_NCE_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_DCLK_AFTER_CONFIGURATION "USE AS REGULAR IO"