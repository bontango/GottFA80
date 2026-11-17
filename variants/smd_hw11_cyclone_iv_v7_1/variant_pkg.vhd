-- variant_pkg.vhd - Konstanten der Variante smd_hw11_cyclone_iv_v7_1
-- GottFA80 HW 1.1 SMD mit Cyclone IV Board v7.1 (EP4CE22F17C8, ESP32-C3 auf X7)
--
-- Anzeige der SW-Version beim Booten = BOARD_ID & SW_SUB_80 (lib_common\version_pkg.vhd).
-- BOARD_ID ist bei GottFA80 HW 1.1 (SMD) EINE Ziffer: 1 = Cyclone II, 2 = Cyclone IV Board v3.x,
-- 3 = Cyclone IV Board v4.x, 4 = Cyclone 10, 8 = Cyclone IV Board v7.1 mit ESP32 (wie die
-- erste Ziffer von PLuS v7_1 = 81x). Ausgewertet in top\SYS80_80.vhd.
package variant_pkg is
	constant BOARD_ID : string(1 to 1) := "8";
	-- Zweites Spiel-ROM (2 KB) fuer die spaeten 80B-Spiele. Nicht auf Cyclone II (Speicher).
	constant HAS_LATE80B : boolean := true;
	-- CPU-Takt aus der PLL cpu_clock_gen (lib_cyclone_IV) statt aus cpu_clk_gen.
	constant HAS_PLL_CLK : boolean := false;
	-- 80B-Bootanzeige 2x20 Zeichen (lib_common\boot_message_80B.vhd) wie PLuS v7_1; unter
	-- FA-Control zwei ASCII-Displays, der Monitor liest die Anzeige mit (disp80B_capture).
	constant HAS_DISP_80B : boolean := true;
	-- Spiel-ROMs aus dem Konfigurationsflash (lib_common\Flash_ROM.vhd), wenn keine SD-Karte
	-- antwortet. AS-Pins DCLK/nCSO/ASDO/DATA0 als User-I/O (device.tcl, pins.tcl). Ohne JTAG
	-- kommt gottfa80_roms.bin ueber FA-Control an 0x080000 (wie PLuS v7_1).
	constant HAS_FLASH_ROM : boolean := true;
	-- ESP32-C3 mit FA-Control (lib_common\fa_sys80.vhd). Nur das Cyclone-IV-Board v7.1 traegt ihn
	-- (smd_hw11_cyclone_iv_v7_1). Seit 16.11.2026.
	constant HAS_ESP32 : boolean := true;
	-- Virtual-JTAG-Testknoten (lib_common\vjtag_probe.vhd), Stufe 1 von FA-Control ueber JTAG.
	-- Nur die ruhende Variante smd_hw11_cyclone_iv_v4_vj. Seit 17.11.2026.
	constant HAS_VJTAG_PROBE : boolean := false;
	-- FA-Control ueber Virtual JTAG (lib_common\fa_vjtag_link.vhd, Option fa_vjtag): ESP32 auf dem
	-- JTAG-Piggyback an P5 statt auf X7, keine FA-Pins. Seit 17.11.2026, nur Probevarianten.
	constant HAS_FA_VJTAG : boolean := false;
	-- Umfang von FA-Control (fa_sys80): 0 = voll, 1 = nur Monitor, 2 = nur Steuerung ohne 80B-Text,
	-- 3 = nur Monitor ohne 80B-Text. Sparversionen fuer EP4CE6/10CL006 (EVALUIERUNG 15.7).
	constant FA_SPAR : integer := 0;
end package variant_pkg;