-- variant_pkg.vhd - Konstanten der Variante 80s_hw12_cyclone_iv
-- GottFA80S HW 1.2 mit Cyclone IV Board v4 (EP4CE6E22C8)
-- Seit 13.11.2026 im gemeinsamen Baum (vorher flacher Ordner GottFA80S_HW1.2_Cyclone_IV_v4).
--
-- Anzeige der SW-Version beim Booten = BOARD_ID & SW_SUB (lib_common\version_pkg.vhd).
-- BOARD_ID ist zweistellig: 1. Ziffer FPGA-Board (5 = Cyclone IV v4, 6 = Cyclone 10,
-- 7/8 = Cyclone IV v7/v7.1 mit ESP32), 2. Ziffer Platinenstand (0 = PLuS HW 2.0x,
-- 1 = PLuS HW 2.1x, 2 = GottFA80S HW 1.1, 3 = GottFA80S HW 1.2). Die alten 80S-Nummern
-- 501/511/512/612 kollidierten mit PLuS, deshalb neue IDs.
package variant_pkg is
	constant BOARD_ID : string(1 to 2) := "53";
	-- ESP32-C3 mit FA-Control (lib_fa_control). Nur das Cyclone-IV-Board v7 traegt ihn.
	constant HAS_ESP32 : boolean := false;
	-- Integriertes Soundboard GOSOF80 (lib_common\GOSOF80.vhd).
	constant HAS_SOUNDBOARD : boolean := true;
	-- 80B-Anzeige (boot_message_80B / FA-Control ASCII), bisher nur v7_1 - s. top\SYS80.vhd.
	constant HAS_DISP_80B : boolean := true;
	-- Spiel-ROMs aus dem Konfigurationsflash (lib_common\Flash_ROM.vhd), wenn keine SD-Karte
	-- antwortet. Braucht die AS-Pins DCLK/nCSO/ASDO/DATA0 als User-I/O. Seit 07.11.2026.
	constant HAS_FLASH_ROM : boolean := false;
	-- Gemeinsamer SPI-Bus MOSI/MISO/CLK fuer SD-Karte und EEprom. false nur bei GottFA80S
	-- HW 1.1 (getrennte Busse SD_*/EE_*), s. top\SYS80.vhd. Seit 13.11.2026.
	constant HAS_SHARED_SPI : boolean := true;
	-- Zeile 1 der 80B-Bootanzeige (HAS_DISP_80B), davor "V" & BOARD_ID & SW_SUB = 20 Zeichen.
	-- PLuS "GOTTFA80 PLUS   ", GottFA80S "GOTTFA80S       " (13.11.2026).
	constant BOOT_NAME_80B : string(1 to 16) := "GOTTFA80S       ";
	-- Votrax-SC-01-Emulation im Soundboard (lib_common\votrax, Kopie aus Gosof80): MA-216-Spiele
	-- sprechen dann immer ueber die Emulation. Braucht ~2.430 LE und 15 M9K - passt nicht in
	-- EP4CE6/10CL006, Probebau auf EP4CE10 (plus_hw21x_cyclone_iv_e10). Seit 13.11.2026.
	constant HAS_VOTRAX : boolean := false;
end package variant_pkg;
