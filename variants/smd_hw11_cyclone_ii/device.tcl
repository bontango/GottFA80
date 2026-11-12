# device.tcl - was fuer DIESES Board gilt, ausser den Pinlagen.
# Wird von scripts\gen_qsf.ps1 in SYS80.qsf eingesetzt. Handgepflegt.
# Cyclone II kennt nur Quartus 13.0sp1 (C:\altera\13.0sp1) - check.ps1/build.ps1 waehlen die Version ueber FAMILY.
set_global_assignment -name FAMILY "Cyclone II"
set_global_assignment -name DEVICE EP2C5T144C8
set_global_assignment -name LAST_QUARTUS_VERSION "13.0 SP1"
