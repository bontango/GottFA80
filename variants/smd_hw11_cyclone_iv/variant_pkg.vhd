-- variant_pkg.vhd - Konstanten der Variante smd_hw11_cyclone_iv
-- GottFA80 HW 1.1 SMD mit Cyclone IV Board v3.x (EP4CE6F17C8)
--
-- Anzeige der SW-Version beim Booten = BOARD_ID & SW_SUB_80 (lib_common\version_pkg.vhd).
-- BOARD_ID ist bei GottFA80 HW 1.1 (SMD) EINE Ziffer: 1 = Cyclone II, 2 = Cyclone IV Board v3.x,
-- 3 = Cyclone IV Board v4.x, 4 = Cyclone 10. Ausgewertet in top\SYS80_80.vhd.
package variant_pkg is
	constant BOARD_ID : string(1 to 1) := "2";
	-- Zweites Spiel-ROM (2 KB) fuer die spaeten 80B-Spiele. Nicht auf Cyclone II (Speicher).
	constant HAS_LATE80B : boolean := true;
	-- CPU-Takt und 80 kHz aus der PLL cpu_clock_gen (lib_cyclone_IV) statt aus cpu_clk_gen.
	constant HAS_PLL_CLK : boolean := false;
	-- 80B-Bootanzeige (lib_common\boot_message_80B.vhd), braucht HAS_PLL_CLK (80 kHz).
	constant HAS_DISP_80B : boolean := false;
end package variant_pkg;
