-- variant_pkg.vhd - Konstanten der Variante smd_hw11_cyclone_iv_v4_fa_lite
-- GottFA80 HW 1.1 SMD mit Cyclone IV Board v4.x (EP4CE6E22C8) und FA-Control "lite" ueber
-- Virtual JTAG (HAS_FA_LITE, 19.11.2026): Registerbank statt LISY-Parser, keine FA-Pins.
--
-- Anzeige der SW-Version beim Booten = BOARD_ID & SW_SUB_80 (lib_common\version_pkg.vhd).
-- BOARD_ID ist bei GottFA80 HW 1.1 (SMD) EINE Ziffer: 1 = Cyclone II, 2 = Cyclone IV Board v3.x,
-- 3 = Cyclone IV Board v4.x, 4 = Cyclone 10. Ausgewertet in top\SYS80_80.vhd.
package variant_pkg is
	constant BOARD_ID : string(1 to 1) := "3";
	-- Zweites Spiel-ROM (2 KB) fuer die spaeten 80B-Spiele. Nicht auf Cyclone II (Speicher).
	constant HAS_LATE80B : boolean := true;
	-- CPU-Takt aus der PLL cpu_clock_gen (lib_cyclone_IV) statt aus cpu_clk_gen.
	constant HAS_PLL_CLK : boolean := true;
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
	-- Nur die ruhende Variante smd_hw11_cyclone_iv_v4_fa. Seit 17.11.2026.
	constant HAS_VJTAG_PROBE : boolean := false;
	-- FA-Control "lite" ueber Virtual JTAG (lib_common\fa_jtag_regs.vhd + fa_lite_sys80.vhd,
	-- Option fa_lite): kein LISY-Parser im FPGA, der ESP32 spricht LISY. Ruhende Varianten
	-- smd_hw11_cyclone_iv_v4_fa_lite/smd_hw11_cyclone_10_fa_lite, seit 306 smd_hw11_cyclone_iv_v4. Seit 19.11.2026.
	constant HAS_FA_LITE : boolean := true;
end package variant_pkg;
