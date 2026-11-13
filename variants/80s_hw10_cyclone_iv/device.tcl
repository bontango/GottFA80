# device.tcl - was fuer DIESES Board gilt, ausser den Pinlagen.
# Wird von scripts\gen_qsf.ps1 in SYS80.qsf eingesetzt. Handgepflegt.
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6E22C8
set_global_assignment -name LAST_QUARTUS_VERSION "22.1std.2 Lite Edition"

# AS-Pins nach der Konfiguration als User-I/O (HAS_FLASH_ROM). RESERVE_ASDO steht in scripts\common_header.tcl.
set_global_assignment -name RESERVE_DATA0_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_DATA1_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_FLASH_NCE_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_DCLK_AFTER_CONFIGURATION "USE AS REGULAR IO"
