-- variant_pkg.vhd - Konstanten der Variante plus_hw21x_cyclone_iv
-- GottFA80 PLuS HW 2.1x mit Cyclone IV Board (EP4CE6E22C8)
--
-- Anzeige der SW-Version beim Booten = BOARD_ID & SW_SUB (lib_common\version_pkg.vhd).
-- BOARD_ID ist zweistellig: 1. Ziffer FPGA-Board (5 = Cyclone IV v4, 6 = Cyclone 10,
-- 7 = Cyclone IV v7 mit ESP32), 2. Ziffer Platinenstand (0 = HW 2.0x, 1 = HW 2.1x).
package variant_pkg is
	constant BOARD_ID : string(1 to 2) := "51";
	-- ESP32-C3 mit FA-Control (lib_fa_control). Nur das Cyclone-IV-Board v7 traegt ihn.
	constant HAS_ESP32 : boolean := false;
	-- Integriertes Soundboard GOSOF80 (lib_common\GOSOF80.vhd).
	constant HAS_SOUNDBOARD : boolean := true;
	-- 80B-Anzeige (boot_message_80B / FA-Control ASCII), bisher nur v7_1 - s. top\SYS80.vhd.
	constant HAS_DISP_80B : boolean := false;
	-- Spiel-ROMs aus dem Konfigurationsflash (lib_common\Flash_ROM.vhd), wenn keine SD-Karte
	-- antwortet. Braucht die AS-Pins DCLK/nCSO/ASDO/DATA0 als User-I/O. Seit 07.11.2026.
	constant HAS_FLASH_ROM : boolean := true;
	-- Gemeinsamer SPI-Bus MOSI/MISO/CLK fuer SD-Karte und EEprom. false nur bei GottFA80S
	-- HW 1.1 (getrennte Busse SD_*/EE_*), s. top\SYS80.vhd. Seit 13.11.2026.
	constant HAS_SHARED_SPI : boolean := true;
	-- Zeile 1 der 80B-Bootanzeige (HAS_DISP_80B), davor "V" & BOARD_ID & SW_SUB = 20 Zeichen.
	-- PLuS "GOTTFA80 PLUS   ", GottFA80S "GOTTFA80S       " (13.11.2026).
	constant BOOT_NAME_80B : string(1 to 16) := "GOTTFA80 PLUS   ";
end package variant_pkg;
