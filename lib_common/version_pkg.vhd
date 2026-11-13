-- version_pkg.vhd - Software-Ziffern, gemeinsam fuer alle Varianten einer Linie.
--
-- PLuS: angezeigte Version = BOARD_ID (variants\<n>\variant_pkg.vhd, zweistellig) & SW_SUB.
-- Ein Release aendert NUR diese Ziffer, alle Boards folgen:
--   HW2.01 Cyclone IV -> 50x, HW2.1x Cyclone IV -> 51x, HW2.1x Cyclone 10 -> 61x
--
-- Stand 04.11.2026: 1 (= ausgelieferte v501 / v511 / v611).
-- Stand 07.11.2026: 2 (SD_Card v052 Warmstart-Fix, 80B-Anzeige v7_1), noch nicht released.
package version_pkg is
	-- PLuS (top\SYS80.vhd)
	constant SW_SUB : character := '2';
	-- GottFA80 HW 1.1 SMD (top\SYS80_80.vhd): Anzeige = BOARD_ID (eine Ziffer) & SW_SUB_80,
	-- Cyclone II -> 1xx, Cyclone IV Board v3.x -> 2xx, Cyclone IV Board v4.x -> 3xx,
	-- Cyclone 10 -> 4xx. Stand 12.11.2026: "03" (= ausgelieferte v103/v203/v303/v403a).
	-- Stand 13.11.2026: "04" (80B-Bootanzeige, SD-Diagnose / NO SD CARD, Optionsziffern,
	-- SD_Card v052..v055), noch nicht released. Getestet: smd_hw11_cyclone_10 (Ralf).
	constant SW_SUB_80 : string(1 to 2) := "04";
end package version_pkg;
