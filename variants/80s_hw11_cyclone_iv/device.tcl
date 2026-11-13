# device.tcl - was fuer DIESES Board gilt, ausser den Pinlagen.
# Wird von scripts\gen_qsf.ps1 in SYS80.qsf eingesetzt. Handgepflegt.
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6E22C8
set_global_assignment -name LAST_QUARTUS_VERSION "22.1std.2 Lite Edition"

# Fitter-Seed 2 (13.11.2026): mit HAS_DISP_80B landet Seed 1 bei Hold -0,640 ns im Soundboard
# (SB_RAM -> T65 BusB, clk_50 -> cpu_clk_out). Seeds 2..5 alle um +0,14 ns.
set_global_assignment -name SEED 2
