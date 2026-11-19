-- variant_pkg.vhd - Konstanten der Variante smd_hw11_cyclone_10
-- GottFA80 HW 1.1 SMD mit Cyclone 10 Board (10CL006YE144C8G)
--
-- Anzeige der SW-Version beim Booten = BOARD_ID & SW_SUB_80 (lib_common\version_pkg.vhd).
-- BOARD_ID ist bei GottFA80 HW 1.1 (SMD) EINE Ziffer: 1 = Cyclone II, 2 = Cyclone IV Board v3.x,
-- 3 = Cyclone IV Board v4.x, 4 = Cyclone 10. Ausgewertet in top\SYS80_80.vhd.
package variant_pkg is
	constant BOARD_ID : string(1 to 1) := "4";
	-- Zweites Spiel-ROM (2 KB) fuer die spaeten 80B-Spiele. Nicht auf Cyclone II (Speicher).
	constant HAS_LATE80B : boolean := true;
	-- CPU-Takt aus der PLL cpu_clock_gen (lib_cyclone_IV) statt aus cpu_clk_gen.
	constant HAS_PLL_CLK : boolean := false;
	-- 80B-Bootanzeige 2x20 Zeichen (lib_common\boot_message_80B.vhd) wie PLuS v7_1.
	constant HAS_DISP_80B : boolean := true;
	-- Spiel-ROMs aus dem Konfigurationsflash (lib_common\Flash_ROM.vhd), wenn keine SD-Karte
	-- antwortet. Braucht die AS-Pins DCLK/nCSO/ASDO/DATA0 als User-I/O (device.tcl, pins.tcl)
	-- und gottfa80_roms.jic. Seit 13.11.2026 (Cyclone II: nicht moeglich, DCLK/DATA0 fest).
	constant HAS_FLASH_ROM : boolean := true;
	-- ESP32-C3 mit FA-Control (lib_common\fa_sys80.vhd). Nur das Cyclone-IV-Board v7.1 traegt ihn
	-- (smd_hw11_cyclone_iv_v7_1). Seit 16.11.2026.
	constant HAS_ESP32 : boolean := false;
	-- Virtual-JTAG-Testknoten (lib_common\vjtag_probe.vhd), Stufe 1 von FA-Control ueber JTAG.
	-- Nur die ruhende Variante smd_hw11_cyclone_iv_v4_vj. Seit 17.11.2026.
	constant HAS_VJTAG_PROBE : boolean := false;
	-- FA-Control ueber Virtual JTAG (lib_common\fa_vjtag_link.vhd, Option fa_vjtag): ESP32 auf dem
	-- JTAG-Piggyback an P5 statt auf X7, keine FA-Pins. Seit 17.11.2026, nur Probevarianten.
	constant HAS_FA_VJTAG : boolean := true;
	-- Umfang von FA-Control (fa_sys80): 0 = voll, 1 = nur Monitor, 2 = nur Steuerung ohne 80B-Text,
	-- 3 = nur Monitor ohne 80B-Text. Sparversionen fuer EP4CE6/10CL006 (EVALUIERUNG 15.7).
	constant FA_SPAR : integer := 1;
	-- FA-Control "lite" ueber Virtual JTAG (lib_commona_jtag_regs.vhd + fa_lite_sys80.vhd,
	-- Option fa_lite): kein LISY-Parser im FPGA, der ESP32 spricht LISY. Nur die ruhende
	-- Variante smd_hw11_cyclone_iv_v4_fa_lite. Seit 19.11.2026.
	constant HAS_FA_LITE : boolean := false;
end package variant_pkg;
