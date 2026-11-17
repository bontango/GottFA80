

#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {clk_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk_50}]

#**************************************************************
# Create Generated Clock
#**************************************************************

# smd_hw11_cyclone_iv_v4: CPU-Takt kommt aus der PLL (derive_pll_clocks), cpu_clk_gen ist
# wegsynthetisiert - der generierte Takt haette kein Ziel.
#create_generated_clock -name {cpu_clk_out} -source [get_ports {clk_50}] -divide_by 56 -master_clock {clk_50} [get_registers {cpu_clk_gen:clock_gen|cpu_clk_out}] 


derive_pll_clocks -create_base_clocks

derive_clock_uncertainty

# clk_50 -> Segmentregister der 80A-Bootanzeige (boot_message, cpu_clk): dort kommen nur
# Anzeigetexte an (Version, Spielnummer, Optionen, FA-Host-Ziffern), quasistatisch.
# Der Hold-Wert dieser Uebergaenge hing allein von der Platzierung ab (v7_1,
# 07.11.2026: -0,5 bis -0,9 ns, wechselnde Pfade).
set_false_path -from [get_clocks {clk_50}] -to [get_registers -nowarn {boot_message:BM|Din_Seg*}]
