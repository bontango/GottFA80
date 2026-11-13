-- variant_pkg.vhd - Konstanten der Variante plus_hw21x_cyclone_iv_v7_1
-- GottFA80 PLuS HW 2.1x mit Cyclone IV Board v7.1 (EP4CE22F17C8, ESP32-C3 auf X7)
--
-- Anzeige der SW-Version beim Booten = BOARD_ID & SW_SUB (lib_common\version_pkg.vhd).
-- BOARD_ID ist zweistellig: 1. Ziffer FPGA-Board (5 = Cyclone IV v4, 6 = Cyclone 10,
-- 7 = Cyclone IV v7 mit ESP32, 8 = Cyclone IV v7.1 mit EP4CE22 und ESP32),
-- 2. Ziffer Platinenstand (0 = HW 2.0x, 1 = HW 2.1x).
--
-- v7.1: der EP4CE22 hat Platz fuer FA-Control UND das integrierte Soundboard.
package variant_pkg is
	constant BOARD_ID : string(1 to 2) := "81";
	-- ESP32-C3 mit FA-Control (lib_fa_control). Nur die Cyclone-IV-Boards v7/v7.1 tragen ihn.
	constant HAS_ESP32 : boolean := true;
	-- Integriertes Soundboard GOSOF80 (lib_common\GOSOF80.vhd).
	constant HAS_SOUNDBOARD : boolean := true;
	-- 80B-Anzeige (2x20 Zeichen): Bootanzeige boot_message_80B, unter FA-Control zwei
	-- ASCII-Displays, Monitor liest die Anzeige mit (disp80B_capture). Seit 07.11.2026.
	constant HAS_DISP_80B : boolean := true;
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
