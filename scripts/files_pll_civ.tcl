# files_pll_civ.tcl - Option 'pll_civ': PLL cpu_clock_gen (lib_cyclone_IV) fuer HAS_PLL_CLK.
# Nur smd_hw11_cyclone_iv_v4. top\SYS80_80.vhd instanziiert die PLL als Komponente, darum
# muss sie in den anderen Varianten nicht gelistet sein (es gibt sie dort auch nicht).
set_global_assignment -name QIP_FILE ../../lib_cyclone_IV/cpu_clock_gen.qip
