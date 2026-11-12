# files_cyclone_ii.tcl - Megafunctions der Familie (lib_cyclone_II\), Quartus 13.0sp1.
# Uebernommen am 12.11.2026 aus GottFA80_HW1.1SMD_Cyclone_II. Gegenueber lib_cyclone_IV
# nur Generatorstil 13.0 (Komponentendeklaration, Portreihenfolge) und das fehlende
# read_during_write_mode_port_a/_b (13.0-Default NEW_DATA_NO_NBE_READ = derselbe Wert).
# Kein SB_RAM: das braucht nur das PLuS-Soundboard.
set_global_assignment -name QIP_FILE ../../lib_cyclone_II/SYSTEM_ROM.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_II/RIOT_RAM.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_II/R5101.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_II/GAME_ROM.qip
