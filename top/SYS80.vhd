-- VHDL implementation of a System80/80A/80B Gottlieb MPU
-- (c)2020 bontango
--
-- This is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.
--
-- Changelog:
-- initial release for GottFA80_PLuS v2.0 based on GottFA80S V501
--
-- for FPGA v3 changes: shared SPI; no Serial
-- v510 inital version for HW 2.1x EP4CE6F17C8
-- v511 output ports corrected for sound/audio_rx
--
-- 04.11.2026 gemeinsamer Sourcebaum: dieses EINE Top-Level gilt fuer alle
-- PLuS-Varianten (variants\plus_*). Board-Unterschiede stehen in
-- variants\<n>\variant_pkg.vhd (BOARD_ID) und pins.tcl, die SW-Ziffer in
-- lib_common\version_pkg.vhd. Anzeige = BOARD_ID & SW_SUB (z.B. "51" & '1').
-- Debug ist jetzt 3 Bit breit (wie HW2.01); HW2.1x fuehrt nur Debug[0] heraus,
-- Debug[1..2] sind dort VIRTUAL_PIN.
--
-- 04.11.2026 Variante plus_hw21x_cyclone_iv_v7 (Cyclone-IV-Board v7 mit ESP32-C3):
-- FA-Control (lib_fa_control, aus SternFA) ueber HAS_ESP32, dafuer ohne integriertes
-- Soundboard (HAS_SOUNDBOARD = false) - beides passt nicht zusammen in den EP4CE6.
-- Ohne ESP ist fa_active konstant '0'; alle Muxe unten fallen dann weg.
--
-- 06.11.2026 Variante plus_hw21x_cyclone_iv_v7_1 (Board v7.1, EP4CE22): FA-Control UND
-- integriertes Soundboard. Das Soundboard hoert unter FA-Control auf die FA-Werte
-- (snd_pa/snd_pb), sonst wie bisher auf die RIOT-Ausgaenge.
--
-- 07.11.2026 80B-Anzeige (HAS_DISP_80B, bisher nur v7_1): Bootanzeige auf der 2x20-
-- Zeichen-Anzeige der 80B-Spiele (lib_common\boot_message_80B.vhd). 80B = Spielauswahl
-- 40..61 (Bounty Hunter .. Night Moves), feststellbar schon vor dem Spielstart. FA-Control
-- meldet dann zwei ASCII-Displays zu 20 Zeichen (zweite Belegung in fa_control) und
-- liest die Anzeige im Monitor mit (lib_common\disp80B_capture.vhd).
--
-- 07.11.2026 Spiel-ROMs aus dem Konfigurationsflash (HAS_FLASH_ROM, bisher nur v7_1),
-- nach SternFA x.30: antwortet keine SD-Karte, laedt lib_common\Flash_ROM.vhd dasselbe
-- Spiel aus dem EPCS16 (ab 0x080000, Verzeichnis + deduplizierte 2-KB-Bloecke).
--
-- 13.11.2026 GottFA80S (HW 1.1 / HW 1.2, variants\80s_*) laeuft jetzt ebenfalls mit diesem
-- Top-Level (vorher eigene Kopien in den flachen Ordnern GottFA80S_*). Dazu kamen:
-- Serial_RX/Serial_TX (USB/ESP-01 auf 80S, logisch unbenutzt, TX auf Ruhepegel) und
-- HAS_SHARED_SPI: HW 1.1 hat getrennte SPI-Busse fuer SD-Karte (SD_*) und EEprom (EE_*),
-- alle anderen Boards den gemeinsamen Bus MOSI/MISO/CLK. Was ein Board nicht hat, ist
-- VIRTUAL_PIN (variant.psd1).

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.version_pkg.all;
use work.variant_pkg.all;

entity SYS80 is
	port(
	   -- the FPGA board
		clk_50	: in std_logic;
		reset_sw	: in std_logic;
		LED_Int 	: out STD_LOGIC;
		LED_SDcard 	: out STD_LOGIC;
		LED_ON 	: out STD_LOGIC;

		-- U4 switchmatrix 8strobe; 8 returns
		U4_PB	:	buffer 	std_logic_vector(7 downto 0);
		U4_PA	:	in 	std_logic_vector(7 downto 0);
		
		-- U5 displays  		
		-- 24 Segments ( seperate because of 80B ) J2 1..24
		-- U5_PB 0..6 & U5_PA 4..6
		disp_segments 	: out 	std_logic_vector(1 to 24);				
		U5_PA				: out std_logic_vector(3 downto 0); -- 16 strobes via decoder
		U5_PA_7			: in std_logic; -- Slam
		U5_PB_7			: out std_logic; -- Switch Enable
		
		-- Solenoids, Lamps & Sound
		U6_PA		: out std_logic_vector(7 downto 0); -- Sols & Sound 8 signals combined			
		U6_PB		: out std_logic_vector(7 downto 0);-- Lamps ( 4 control, 4 latch strobes)		
		
		-- SPI SD card & EEprom
		CS_SDcard	: 	buffer 	std_logic;
		CS_EEprom	: 	buffer 	std_logic;
		MOSI			: 	out 	std_logic;
		MISO			: 	in 	std_logic;
		CLK			: 	out 	std_logic;
		-- getrennte SPI-Busse (nur GottFA80S HW 1.1, HAS_SHARED_SPI = false)
		SD_MOSI		: 	out 	std_logic;
		SD_MISO		: 	in 	std_logic;
		SD_CLK		: 	out 	std_logic;
		EE_MOSI		: 	out 	std_logic;
		EE_MISO		: 	in 	std_logic;
		EE_CLK		: 	out 	std_logic;

		-- DIp Switch Game selectOptions
		DIP_Strobe	:	out 	std_logic_vector(3 downto 0);
		DIP_Return	:	in 	std_logic_vector(3 downto 0);
		myTest		: 	in 	std_logic;
		
		-- Sound
		Audio_RX			: 	buffer 	std_logic;
		Sound 			: 	buffer 	std_logic;

		-- debug
		Debug			:	out 	std_logic_vector(2 downto 0);

		-- serial (USB oder ESP-01), nur GottFA80S; logisch unbenutzt
		Serial_RX		: 	in 	std_logic;
		Serial_TX		: 	out 	std_logic;

		-- FA-Control: ESP32-C3 auf X7 des Cyclone-IV-Boards v7 (HAS_ESP32).
		-- Auf allen anderen Boards VIRTUAL_PIN (variant.psd1).
		FA_RXD			:	in		std_logic;	-- R3, vom TX des ESP
		FA_TXD			:	out	std_logic;	-- T2, zum RX des ESP
		FA_CTRL_REQ		:	in		std_logic;	-- N3, active low, Weak-Pull-up

		-- Konfigurationsflash EPCS16 als zweite Quelle der Spiel-ROMs (HAS_FLASH_ROM,
		-- lib_common\Flash_ROM.vhd). v7_1: DCLK H1, nCSO D2, ASDO C1, DATA0 H2 als
		-- User-I/O (device.tcl). Auf allen anderen Boards VIRTUAL_PIN (variant.psd1).
		FLASH_DCLK		:	out	std_logic;
		FLASH_NCS		:	out	std_logic;
		FLASH_ASDO		:	out	std_logic;	-- Daten ins Flash
		FLASH_DATA0		:	in		std_logic	-- Daten aus dem Flash

		);
end SYS80;


architecture rtl of SYS80 is

signal cpu_clk		: std_logic; -- 895 kHz CPU clock
signal reset_l	 	: std_logic := '0';
signal game_reset_l	: std_logic;	-- reset_l, plus gehalten solange FA-Control die Kontrolle hat
signal reset_sw_stable	:	std_logic; 
signal Counter : integer range 0 to 15 := 0;

-- CPU 6502
signal cpu_addr		: std_logic_vector(15 downto 0);
signal cpu_din			: std_logic_vector(7 downto 0);
signal cpu_dout		: std_logic_vector(7 downto 0);
signal cpu_wr_n		: std_logic := '1';
signal phi2				: std_logic;
signal cpu_irq_n		: std_logic;

--  5101 RAM
signal r5101_dout_4bit 	: std_logic_vector(3 downto 0);	  
signal r5101_dout_8bit 	: std_logic_vector(7 downto 0);	  
signal r5101_cs		: std_logic;

-- ROM
signal game_rom_dout  : std_logic_vector(7 downto 0);
signal game_rom2_dout  : std_logic_vector(7 downto 0);
signal system_rom_dout  : std_logic_vector(7 downto 0);

-- RIOT U4 Switch Matrix
signal U4_RAM_cs  		: std_logic;
signal U4_IO_cs  			: std_logic;
signal U4_RAM_dout		: std_logic_vector(7 downto 0);
signal U4_IO_dout			: std_logic_vector(7 downto 0);
signal U4_pa_in			: std_logic_vector(7 downto 0);
signal SW_Freeplay		: std_logic_vector(7 downto 0):="00000000";
--signal U4_pa_out		: std_logic_vector(7 downto 0);
--signal U4_pb_in			: std_logic_vector(7 downto 0);
--signal U4_pb_out			: std_logic_vector(7 downto 0);
signal U4_irq_n			: std_logic;

-- trigger
signal game_over_relay			: std_logic;
signal clk_Z1			: std_logic;
signal clk_Z3			: std_logic;
-- Eingang des integrierten Soundboards: RIOT U6, unter FA-Control die FA-Werte
signal snd_pa			: std_logic_vector(7 downto 0);
signal snd_pb			: std_logic_vector(7 downto 0);
signal snd_game_running	: std_logic;
signal test_sw			: std_logic;
signal credit_sw			: std_logic;


-- RIOT U5 Display Control
signal U5_RAM_cs  		: std_logic;
signal U5_IO_cs  			: std_logic;
signal U5_RAM_dout		: std_logic_vector(7 downto 0);
signal U5_IO_dout			: std_logic_vector(7 downto 0);
--signal U5_pa_in			: std_logic_vector(7 downto 0):="11111111";
signal U5_pa_out		: std_logic_vector(7 downto 0);
--signal U5_pb_in			: std_logic_vector(7 downto 0);
signal U5_pb_out			: std_logic_vector(7 downto 0);
signal U5_irq_n			: std_logic;
signal not80B				: std_logic:='0'; --default we have 80B system
signal segments_80B 		: std_logic_vector(1 to 24);				
signal segments_80 		: std_logic_vector(1 to 24);			
signal bm_segments 		: std_logic_vector(1 to 24);			
signal Din_Seg_A			: std_logic_vector(3 downto 0);	
signal Din_Seg_B			: std_logic_vector(3 downto 0);	
signal Din_Seg_C			: std_logic_vector(3 downto 0);	
signal bm_digit_strobe	: std_logic_vector(3 downto 0);
-- 80B-Bootanzeige (HAS_DISP_80B)
signal sys80B				: std_logic;	-- Spielauswahl ist ein 80B-Spiel (40..61)
signal show80B				: std_logic;	-- boot_message_80B treibt die Anzeige
signal bm80B_segments	: std_logic_vector(1 to 24);
signal bm80B_row1			: string(1 to 20);
signal bm80B_row2			: string(1 to 20);
signal bm80B_err2			: string(1 to 20);
signal sd_err_cmd			: std_logic_vector(3 downto 0);	-- SD-Diagnose (SD_Card v053)
signal sd_err_rx			: std_logic_vector(55 downto 0);
signal fa_txt1				: string(1 to 20);	-- FA-Control Display 0 (Zeile 1)
signal fa_txt2				: string(1 to 20);	-- FA-Control Display 1 (Zeile 2)

-- RIOT U& Solenoid & Lamp Control
signal U6_RAM_cs  		: std_logic;
signal U6_IO_cs  			: std_logic;
signal U6_RAM_dout		: std_logic_vector(7 downto 0);
signal U6_IO_dout			: std_logic_vector(7 downto 0);
--signal U6_pa_in			: std_logic_vector(7 downto 0);
signal U6_pa_out		: std_logic_vector(7 downto 0);
--signal U6_pb_in			: std_logic_vector(7 downto 0);
signal U6_pb_out			: std_logic_vector(7 downto 0);
signal U6_irq_n			: std_logic;

-- address decoding helper
signal game_rom_cs		: std_logic;
signal game_rom2_cs		: std_logic;
signal game_rom_addr	:  std_logic_vector(10 downto 0);
signal game_rom2_addr	:  std_logic_vector(10 downto 0);
signal system_rom_cs		: std_logic;
signal system_rom_addr	:  std_logic_vector(12 downto 0);

-- SD card
signal address_sd_card	:  std_logic_vector(13 downto 0);
signal data_sd_card	:  std_logic_vector(7 downto 0);
signal wr_rom			:  std_logic;
signal wr_game_rom			:  std_logic;
signal wr_game_rom2			:  std_logic;
signal wr_system_rom			:  std_logic;
signal SDcard_MOSI	:	std_logic; 
signal SDcard_CLK		:	std_logic; 
signal SDcard_error	:	std_logic;
-- Ausgaenge von SD_Card; address_sd_card/data_sd_card/wr_rom/reset_l/SDcard_error sind
-- seit HAS_FLASH_ROM die zwischen SD und Flash gemuxten Signale
signal sd_address		:  std_logic_vector(13 downto 0);
signal sd_data			:  std_logic_vector(7 downto 0);
signal sd_wr_rom		:  std_logic;
signal sd_cpu_reset_l	:  std_logic;
signal sd_error		:  std_logic;
signal sd_no_card		:  std_logic;	-- SD-Initialisierung gescheitert -> Flash
signal use_flash		:  std_logic := '0';	-- Spiel-ROMs kommen aus dem Flash (nur gen_flash_rom treibt es;
										-- ohne HAS_FLASH_ROM ungetrieben und ungelesen, keine Meldung)

-- EEprom we use 128Bytes
signal address_eeprom	:  std_logic_vector(6 downto 0);
signal data_eeprom	:  std_logic_vector(7 downto 0);
signal wr_ram			:  std_logic;
signal EEprom_MOSI	:	std_logic; 
signal EEprom_CLK		:	std_logic;
-- MISO je Teilnehmer: gemeinsamer Bus (HAS_SHARED_SPI) oder getrennte Busse (80S HW 1.1)
signal sd_spi_miso	:	std_logic;
signal ee_spi_miso	:	std_logic;
signal EEprom_active	:	std_logic; 

-- init & boot message helper
signal game_running		: 	std_logic:= '0';
signal game_dig0			:  character;
signal game_dig1			:  character;
signal game_dig2			:  character;
signal g_opt_dig0			:  character;
signal g_opt_dig1			:  character;
signal sb_opt_dig0			:  character;
signal sb_opt_dig1			:  character;

-- dip games select and options
signal readingdips	: 	std_logic:= '1';
signal game_select 		:  std_logic_vector(5 downto 0);				
signal game_option		: 	std_logic_vector(1 to 6);
signal sb_option		: 	std_logic_vector(1 to 4);
		
-- diff
signal sim_coin		: 	std_logic:= '0';
signal slam				: 	std_logic;
signal lamp_ds 		:  std_logic_vector(3 downto 0);		
signal late80B			: std_logic:='0'; --default we have not a late 80B system with bigger rom

-- game options
signal opt_freeplay				: 	std_logic;
signal opt_init_nvram				: 	std_logic;
signal opt_slam_fix_open			: 	std_logic;
signal opt_slam_fix_close		: 	std_logic;

-- soundboard
-- ROM
signal soundrom1_dout	:	std_logic_vector(7 downto 0);
signal soundrom2_dout	: 	std_logic_vector(7 downto 0);	
	
signal 	Sound_S1			: std_logic;
signal 	Sound_S2			: std_logic;
signal 	Sound_S4			: std_logic;
signal 	Sound_S8			: std_logic;
signal 	Sound_S16		: std_logic;
	
-- address decoding helper
signal soundrom1_cs		: std_logic;
signal soundrom2_cs		: std_logic;
signal sb_rom1_addr	:  std_logic_vector(10 downto 0);
signal sb_rom2_addr	:  std_logic_vector(10 downto 0);
signal soundrom1_addr	:  std_logic_vector(10 downto 0);
signal soundrom2_addr	:  std_logic_vector(10 downto 0);
signal wr_soundrom1		: std_logic;
signal wr_soundrom2		: std_logic;

------------------------------------------------------------------------------
-- FA-Control (HAS_ESP32): lib_common\fa_sys80.vhd (seit 16.11.2026 ausgelagert, gemeinsam
-- mit dem SMD-Top). Nummerierung und Belegung stehen dort. Die fa_*-Signale unten sind
-- seine Ausgaenge; fa_u6a/fa_u6b haben die Bedeutung der RIOT-Ports (vor den Invertern
-- unten), damit die Ausgangspfade dieselben bleiben wie im Spiel.
------------------------------------------------------------------------------
-- Nibble als Hex-Zeichen (SD-Diagnose auf der 80B-Anzeige)
function hexc(n : std_logic_vector(3 downto 0)) return character is
	constant H : string(1 to 16) := "0123456789ABCDEF";
begin
	return H(to_integer(unsigned(n)) + 1);
end function;

signal fa_active		: std_logic;
signal fa_u6a			: std_logic_vector(7 downto 0);
signal fa_u6b			: std_logic_vector(7 downto 0);
signal fa_sw_strobe	: std_logic_vector(7 downto 0);
signal fa_disp1		: string(1 to 7);
signal fa_disp2		: string(1 to 7);
signal fa_disp3		: string(1 to 7);
signal fa_disp4		: string(1 to 7);
signal u4_pb_out		: std_logic_vector(7 downto 0);
signal fa_sim_ret		: std_logic_vector(7 downto 0);	-- simulierte Schalter der gestrobten Spalte
signal bm_display1	: string(1 to 7);
signal bm_display2	: string(1 to 7);
signal bm_display3	: string(1 to 7);
signal bm_display4	: string(1 to 7);
signal bm_error4		: string(1 to 7);


begin

-- LEDs GottFA80
LED_Int <= not game_running;
LED_SDcard <= SDcard_error;
LED_ON <= '0'; --RTH

-- Debug war bisher nie zugewiesen (Warning 10541, implizit '0'); jetzt explizit.
Debug <= (others => '0');
-- Serial (nur GottFA80S): wie in den alten 80S-Ordnern ohne Funktion, TX auf UART-Ruhepegel
Serial_TX <= '1';


----------------------
-- assign options
----------------------
opt_freeplay				<= not game_option(1);
opt_init_nvram				<= not game_option(2);
opt_slam_fix_open			<= not game_option(3);
opt_slam_fix_close		<= not game_option(4);


----------------------
-- boot message
----------------------
BM: entity work.boot_message
port map(
	clk_in		=> cpu_clk, 	
	-- Control/Data Signals,
   show  => (not game_running) or fa_active,
	SD_error => not SDcard_error,
	-- output
	bm_digit_strobe	=> bm_digit_strobe,
	bm_segments => bm_segments,
	-- input (display data); unter FA-Control die Ziffern des Hosts
	display1	=> bm_display1,
	display2	=> bm_display2,
	display3	=> bm_display3,
	display4	=> bm_display4,
	error_disp4 => bm_error4,
	status_d	=> "       "
	);

bm_display1 <= fa_disp1 when fa_active = '1' else "    " & BOARD_ID & SW_SUB;  -- SW VERSION: variant_pkg + version_pkg
bm_display2 <= fa_disp2 when fa_active = '1' else "    " & game_dig2 & game_dig1 & game_dig0;
bm_display3 <= fa_disp3 when fa_active = '1' else " 050963";
bm_display4 <= fa_disp4 when fa_active = '1' else " " & g_opt_dig1 & g_opt_dig0 & "  " & sb_opt_dig1 & sb_opt_dig0;
bm_error4   <= fa_disp4 when fa_active = '1' else "0000000";

----------------------
-- boot message 80B (2 x 20 Zeichen, Rockwell 10941), nur mit HAS_DISP_80B.
-- 80B laesst sich vor dem Spielstart nur an der Spielauswahl erkennen (not80B unten
-- gilt erst, wenn das Spiel laeuft): 40 Bounty Hunter .. 61 Night Moves laut
-- GottFA80games_v501; 62/63 (Amazon Hunt II/III) sind 80A. Gleiche Reihenfolge im
-- Freeplay-Satz. Waehrend die DIPs gelesen werden, ist game_select nicht gueltig.
----------------------
sys80B <= '1' when HAS_DISP_80B and to_integer(unsigned(not game_select)) >= 40
                   and to_integer(unsigned(not game_select)) <= 61 else '0';
show80B <= sys80B and not readingdips and ((not game_running) or fa_active or not SDcard_error);

gen_disp80b: if HAS_DISP_80B generate
	signal d80_data  : std_logic_vector(7 downto 0);
	signal d80_ld1   : std_logic;
	signal d80_ld2   : std_logic;
	signal d80_reset : std_logic;
begin
	-- je 20 Zeichen: "GOTTFA80 PLUS   V812" bzw. "GOTTFA80S       V545" (BOOT_NAME_80B) / "GAME 040 OPT00 SB00 " / SD-Fehler s. bm80B_err2
	bm80B_row1 <= fa_txt1 when fa_active = '1' else BOOT_NAME_80B & "V" & BOARD_ID & SW_SUB;
	bm80B_row2 <= fa_txt2 when fa_active = '1' else
	              -- ROM aus dem Konfigurationsflash (HAS_FLASH_ROM): "GAME 040 FLASH ROM  "
	              "GAME " & game_dig2 & game_dig1 & game_dig0 & " FLASH ROM  " when use_flash = '1' else
	              "GAME " & game_dig2 & game_dig1 & game_dig0 & " OPT" & g_opt_dig1 & g_opt_dig0 &
	              " SB" & sb_opt_dig1 & sb_opt_dig0 & " ";
	-- SD-Fehler mit Diagnose: "SD E4 FF01FFFFFF05FF" = Blinkcode und die 7 Byte des
	-- Antwortfensters (Byte 7..13 nach dem Befehl, SD_Card v053)
	-- Flash-Fehler (Slot nicht im Flash): "FLASH ERR GAME 040  "
	-- 13.11.2026: antwortet gar nichts (alle 7 Byte FF, typisch ohne Karte) Klartext
	-- "GAME 040 NO SD CARD ", die Diagnosebytes nur, wenn eine Karte etwas antwortet.
	bm80B_err2 <= "FLASH ERR GAME " & game_dig2 & game_dig1 & game_dig0 & "  " when use_flash = '1' else
	              "GAME " & game_dig2 & game_dig1 & game_dig0 & " NO SD CARD " when sd_err_rx = x"FFFFFFFFFFFFFF" else
	              "SD E" & hexc(sd_err_cmd) & " " &
	              hexc(sd_err_rx(55 downto 52)) & hexc(sd_err_rx(51 downto 48)) &
	              hexc(sd_err_rx(47 downto 44)) & hexc(sd_err_rx(43 downto 40)) &
	              hexc(sd_err_rx(39 downto 36)) & hexc(sd_err_rx(35 downto 32)) &
	              hexc(sd_err_rx(31 downto 28)) & hexc(sd_err_rx(27 downto 24)) &
	              hexc(sd_err_rx(23 downto 20)) & hexc(sd_err_rx(19 downto 16)) &
	              hexc(sd_err_rx(15 downto 12)) & hexc(sd_err_rx(11 downto 8)) &
	              hexc(sd_err_rx(7 downto 4))   & hexc(sd_err_rx(3 downto 0));

	BM80B: entity work.boot_message_80B
	generic map(
		CLK_HZ => 50000000
		)
	port map(
		clk_in     => clk_50,
		show       => show80B,
		SD_error   => not SDcard_error,
		data       => d80_data,
		LD1        => d80_ld1,
		LD2        => d80_ld2,
		D_Reset    => d80_reset,
		row1       => bm80B_row1,
		row2       => bm80B_row2,
		error_row2 => bm80B_err2
		);

	-- J2 wie segments_80B (unten): D0..D3 = 2,6,7,1  D4..D7 = 10,14,15,9
	-- LD1 = 8, LD2 = 16, Reset = 24; die uebrigen Leitungen bleiben low.
	BM80B_J2: process(d80_data, d80_ld1, d80_ld2, d80_reset)
	begin
		bm80B_segments     <= (others => '0');
		bm80B_segments(2)  <= d80_data(0);
		bm80B_segments(6)  <= d80_data(1);
		bm80B_segments(7)  <= d80_data(2);
		bm80B_segments(1)  <= d80_data(3);
		bm80B_segments(10) <= d80_data(4);
		bm80B_segments(14) <= d80_data(5);
		bm80B_segments(15) <= d80_data(6);
		bm80B_segments(9)  <= d80_data(7);
		bm80B_segments(8)  <= d80_ld1;
		bm80B_segments(16) <= d80_ld2;
		bm80B_segments(24) <= d80_reset;
	end process;
end generate;

gen_no_disp80b: if not HAS_DISP_80B generate
	bm80B_segments <= (others => '0');
end generate;

----------------------
-- try anti thunk at boot
----------------------
AT: entity work.anti_thunk
port map(
	clk_in		=> cpu_clk, 	
	-- Control/Data Signals,
   is_active  => not game_running,
	-- output
	lamp_ds => lamp_ds
	);
	
----------------------
-- read the dips
----------------------
RDIPS: entity work.read_the_dips
port map(
	clk_in		=> cpu_clk, 	
	i_Rst_L  => reset_sw_stable,     -- FPGA Reset   
   readingdips	=> readingdips,
	--output 
	game_select	=> game_select,
	game_option	=> game_option,
	sb_option => sb_option,
	-- strobes
	strobes => DIP_Strobe,
	-- returns
	returns => DIP_Return
	);
	

CONVG: entity work.byte_to_ascii
port map(
	clk_in	=> clk_50, 		
	mybyte	=> "1" & not opt_freeplay & game_select,
	dig0_ascii => game_dig0,
	dig1_ascii => game_dig1,
	dig2_ascii => game_dig2
	);
	
CONVO: entity work.byte_to_ascii
port map(
	clk_in	=> clk_50, 		
	mybyte	=> "11" & game_option(6) & game_option(5) & game_option(4) & game_option(3) & game_option(2) & game_option(1),
	dig0_ascii => g_opt_dig0,
	dig1_ascii => g_opt_dig1,
	dig2_ascii => open
	);
	
CONVS: entity work.byte_to_ascii
port map(
	clk_in	=> clk_50, 		
	mybyte	=> "1111" & sb_option(4) & sb_option(3) & sb_option(2) & sb_option(1),
	dig0_ascii => sb_opt_dig0,
	dig1_ascii => sb_opt_dig1,
	dig2_ascii => open
	);
		
-- RIOT IRQ outputs all assert CPU IRQ input
cpu_irq_n <= U4_irq_n and U5_irq_n and U6_irq_n;

-- Reset des Spielkerns (6502, RIOTs U4/U5/U6, game_running). Wie auf der Original-
-- MPU haengen CPU und RIOTs am selben Reset: unter FA-Control wird der ganze Kern
-- angehalten, nach der Freigabe startet er wie beim Einschalten (Ausgaenge bleiben
-- sicher, bis game_running wieder steht). Vorher lief nur die CPU neu an und fand
-- RIOTs im alten Zustand vor - das Spiel lief danach nicht sauber (kein Attract).
-- Ohne ESP ist fa_active '0', game_reset_l also gleich reset_l.
game_reset_l <= reset_l and not fa_active;
--cpu_irq_n <= '1';

-- general assigments
phi2 <= not cpu_clk;

-- slam
slam <= '0' when opt_slam_fix_open = '1' else --slam open for late 80B games
		  '1' when opt_slam_fix_close = '1' else -- slam fix closed
		  U5_PA_7; --real slam

---------------------
-- shared SPI bus (HAS_SHARED_SPI) bzw. getrennte Busse (GottFA80S HW 1.1)
----------------------
gen_shared_spi: if HAS_SHARED_SPI generate
	--SD card only at start of game
	MOSI <= SDcard_MOSI when reset_l = '0' else EEprom_MOSI;
	CLK <= SDcard_CLK when reset_l = '0' else EEprom_CLK;
	sd_spi_miso <= MISO;
	ee_spi_miso <= MISO;
	SD_MOSI <= '0';
	SD_CLK  <= '0';
	EE_MOSI <= '0';
	EE_CLK  <= '0';
end generate gen_shared_spi;

gen_split_spi: if not HAS_SHARED_SPI generate
	SD_MOSI <= SDcard_MOSI;
	SD_CLK  <= SDcard_CLK;
	EE_MOSI <= EEprom_MOSI;
	EE_CLK  <= EEprom_CLK;
	sd_spi_miso <= SD_MISO;
	ee_spi_miso <= EE_MISO;
	MOSI <= '0';
	CLK  <= '0';
end generate gen_split_spi;

---------------------
-- count ints
-- indicate game running or not
---------------------
COUNT_INTS: entity work.count_to_zero
port map(   
   Clock => clk_50,
	count =>"11111111",
	d_in => cpu_irq_n,
	d_out => game_running,
	clear => game_reset_l
	);
 
---------------------
-- detection game over relay (Q1)
----------------------
clk_Z1 <= '1' when U6_pb_out(7 downto 4) = "0001" else '0'; --DS1

sn74175_Game_O: entity work.sn74175 
port map(   
   Clock => clk_50,
	clk => clk_Z1,
	clear	=> '1',
	D => U6_pb_out(3 downto 0),
	Q => open,
	Qn(0) => game_over_relay
);

 
---------------------
-- SD card stuff
----------------------
SD_CARD: entity work.SD_Card
port map(
	--no_of_sectors => x"20", -- 32 sectors per rom
	--
	i_clk		=> clk_50,	
	-- Control/Data Signals,
   i_Rst_L  => not readingdips,     -- FPGA Reset & dip read finished
	-- PMOD SPI Interface
   o_SPI_Clk  => SDcard_CLK,
   i_SPI_MISO => sd_spi_miso,
   o_SPI_MOSI => SDcard_MOSI,
   o_SPI_CS_n => CS_SDcard,	
	-- selection
	selection => "0" & opt_freeplay & not game_select,
	-- data
	address_sd_card => sd_address,
	data_sd_card => sd_data,
	wr_rom => sd_wr_rom,
	-- control CPU
	cpu_reset_l => sd_cpu_reset_l,
	-- feedback
	SDcard_error => sd_error,
	err_cmd => sd_err_cmd,
	err_rx  => sd_err_rx,
	o_no_card => sd_no_card
	);

---------------------
-- Spiel-ROMs aus dem Konfigurationsflash (HAS_FLASH_ROM, bisher nur v7_1), nach SternFA
-- x.30: antwortet keine SD-Karte (sd_no_card), laedt Flash_ROM dasselbe Spiel aus dem
-- EPCS16 ab 0x080000 (Verzeichnis + 2-KB-Bloecke, scripts\make_flash_hex.ps1, ueber
-- FA_Control geschrieben) und uebernimmt Schreibport, CPU-Start und Fehler-LED.
-- Die vorhandenen Namen (address_sd_card, wr_rom, reset_l, SDcard_error) sind ab hier
-- die gemuxten Signale.
---------------------
gen_flash_rom: if HAS_FLASH_ROM generate
	signal fl_address    : std_logic_vector(13 downto 0);
	signal fl_data       : std_logic_vector(7 downto 0);
	signal fl_wr_rom     : std_logic;
	signal fl_cpu_reset_l: std_logic;
	signal fl_error      : std_logic;
begin
	use_flash <= sd_no_card;

	FLASH_ROM: entity work.Flash_ROM
	port map(
		i_Clk        => clk_50,
		i_Rst_L      => sd_no_card,
		o_Flash_Clk  => FLASH_DCLK,
		o_Flash_CS_n => FLASH_NCS,
		o_Flash_MOSI => FLASH_ASDO,
		i_Flash_MISO => FLASH_DATA0,
		selection    => "0" & opt_freeplay & not game_select,
		address_rom  => fl_address,
		data_rom     => fl_data,
		wr_rom       => fl_wr_rom,
		cpu_reset_l  => fl_cpu_reset_l,
		Flash_error  => fl_error,
		flash_empty  => open
		);

	address_sd_card <= fl_address     when use_flash = '1' else sd_address;
	data_sd_card    <= fl_data        when use_flash = '1' else sd_data;
	wr_rom          <= fl_wr_rom      when use_flash = '1' else sd_wr_rom;
	reset_l         <= fl_cpu_reset_l when use_flash = '1' else sd_cpu_reset_l;
	SDcard_error    <= fl_error       when use_flash = '1' else sd_error;
end generate;

gen_no_flash_rom: if not HAS_FLASH_ROM generate
	FLASH_DCLK      <= '0';
	FLASH_NCS       <= '1';
	FLASH_ASDO      <= '0';
	address_sd_card <= sd_address;
	data_sd_card    <= sd_data;
	wr_rom          <= sd_wr_rom;
	reset_l         <= sd_cpu_reset_l;
	SDcard_error    <= sd_error;
end generate;

------------------
-- ROMs ----------
-- moved to RAM, initial 16KByte read from SD
-- one file of 16Kbyte for all Gottlieb Variants
-- one file of 16Kbyte for all Gottlieb Variants
-- lower half is game rom and need to be copied to 8KByte blocks
-- upper half is system rom
-- need to be mapped to MPU memory  address range
------------------
					
-- address selection	
-- read from SD when wr_rom == 1
-- else map to address room

-- content of game rom is read from first 2K of SD
wr_game_rom <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="000" )) else '0';
game_rom_addr <=  --2K
	address_sd_card(10 downto 0) when wr_game_rom = '1' else
	cpu_addr(10 downto 0);

-- content of extended game rom (late 80B games) is read from second 2K of SD
wr_game_rom2 <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="001" )) else '0';
game_rom2_addr <=  --2K
	address_sd_card(10 downto 0) when wr_game_rom2 = '1' else
	cpu_addr(10 downto 0);
		
-- content of sound rom 1 is read from third 2K of SD
wr_soundrom1 <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="010" )) else '0';
sb_rom1_addr <=  --2K
	address_sd_card(10 downto 0) when wr_soundrom1 = '1' else soundrom1_addr;

-- content of sound rom 2 is read from fourth 2K of SD
wr_soundrom2 <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="011" )) else '0';
sb_rom2_addr <=  --2K
	address_sd_card(10 downto 0) when wr_soundrom2 = '1' else soundrom2_addr;
	
-- content of system rom is read from second 8K of SD	
wr_system_rom <= '1' when ((wr_rom='1') and (address_sd_card(13) = '1' )) else '0';
system_rom_addr <= --8K
	address_sd_card(12 downto 0) when wr_system_rom = '1' else
	cpu_addr(12 downto 0);

	
-- Address decoding here, 
-- 0x0000-0x07FF	RIOTS RAM and I/O
-- used: A13 | A12 | A11 | A10 | A9 | A8 | A7
--         0x800 blocks  | n.u.|rs_n|  RIOT sel
--
-- U4 Memory (RIOT) - 0x0000 - 0x007F
U4_RAM_cs 	<= '1' when cpu_addr(13 downto 7) ="0000000" else '0';
-- U5 Memory (RIOT) - 0x0080 - 0x00FF
U5_RAM_cs 	<= '1' when cpu_addr(13 downto 7) ="0000001" else '0';
-- U6 Memory (RIOT) - 0x0100 - 0x017F
U6_RAM_cs 	<= '1' when cpu_addr(13 downto 7) ="0000010" else '0';
-- Not Used - 0x0180 - 0x01FF (Test Fixture)
--
-- U4 Registers - 0x0200 - 0x027F
U4_IO_cs 	<= '1' when cpu_addr(13 downto 7) ="0000100" else '0';
-- U5 Registers - 0x0280 - 0x02FF
U5_IO_cs 	<= '1' when cpu_addr(13 downto 7) ="0000101" else '0';
-- U6 Registers - 0x0300 - 0x037F
U6_IO_cs 	<= '1' when cpu_addr(13 downto 7) ="0000110" else '0';
-- 0x0800-0x0FFF	"001" not used
--
-- 0x1000-0x17FF	"010" Game Rom
game_rom_cs	<= '1' when cpu_addr(13 downto 11) ="010" else '0';
-- 0x1800-0x1FFF	"011" Z5 (5101)
r5101_cs <= '1' when cpu_addr(13 downto 11) ="011" else '0';	
-- 0x2000-0x27FF	"100" SYSTEM ROM
-- 0x2800-0x2FFF	"101" SYSTEM ROM
-- 0x3000-0x37FF	"110" SYSTEM ROM
-- 0x3800-0x3FFF	"111" SYSTEM ROM
system_rom_cs <= cpu_addr(13);
-- late 80B games only when selected
late80B <= '1' when game_select(5 downto 3) = "000" else '0'; --all games after Robo War (GAME SELECT IS NEGATED)
game_rom2_cs	<= '1' when cpu_addr(13 downto 11) ="010" and cpu_addr(15) = '1' and late80B='1' else '0';


-- Bus control
cpu_din <= 
	game_rom2_dout when game_rom2_cs='1' else -- late 80B overwrites selection 
	U4_RAM_dout when U4_RAM_cs='1' else
	U5_RAM_dout when U5_RAM_cs='1' else
	U6_RAM_dout when U6_RAM_cs='1' else
	U4_IO_dout when U4_IO_cs='1'  else
	U5_IO_dout when U5_IO_cs='1'  else
	U6_IO_dout when U6_IO_cs='1'  else		
	game_rom_dout when game_rom_cs='1' else
	--"1111" & r5101_dout_4bit when r5101_cs='1' else	
	cpu_dout(7 downto 4) & r5101_dout_4bit when r5101_cs='1' else	
	system_rom_dout when system_rom_cs='1' else
	x"FF";

---------------------
-- U4
-- Switches
----------------------
META2: entity work.Cross_Slow_To_Fast_Clock_Bus
port map(
   i_D => U4_PA,
	o_Q => U4_pa_in,
   i_Fast_Clk => cpu_clk
	);

-- simulate left coin ( strobe 1 / return 7 )
Freeplay: process(sim_coin, U4_PB, opt_freeplay)
 begin 
    if (( sim_coin = '1') and (U4_PB(1) = '1') and (opt_freeplay = '1')) then
		SW_Freeplay(7) <= '1';
	 else	
		SW_Freeplay(7) <= '0';
	end if;	
 end process;  
	
-- detect credit and test_switch for trigger
-- due to iverters on the borad switch is active when both strobe and return are HIGH
-- switch enable for dips need to be low, Gottlieb does check dips when not in game!?
--credit_sw <=   U4_pa_in(7) and U4_PB(4) and not U5_pb_out(7);  -- credit switch is strobe 4 and return 7 and not dip switch active
detect_credit_sw_trigger: entity work.detect_sw_trigger
port map(
	clk    => cpu_clk,
	sw_strobe => U4_PB(4),
	sw_return => U4_pa_in(7),
	sw_enable => U5_pb_out(7),
	trigger => credit_sw,	
	rst 	=> game_running
);

detect_credit_sw: entity work.detect_sw
port map(
	clk    => cpu_clk,
	sw_strobe => U4_PB(4),
	sw_return => U4_pa_in(7),
	sw_enable => U5_pb_out(7),
	short_push => open,
	long_push => sim_coin,
	rst 	=> game_running
);

--test_sw   <= 	U4_pa_in(7) and U4_PB(0) and not U5_pb_out(7); -- test switch is strobe 0 and return 7 and not dip switch active
detect_test_sw: entity work.detect_sw
port map(
	clk    => cpu_clk,
	sw_strobe => U4_PB(0),
	sw_return => U4_pa_in(7),
	sw_enable => U5_pb_out(7),
	short_push => test_sw,
	long_push => open,
	rst 	=> game_running
);

--------------------------------------------------
-- U5
-- display 
--------------------------------------------------
U5_PB_7 <= '1' when fa_active = '1' else not U5_pb_out(7); --switch enable (FA: Matrix, keine DIPs)

-- determine if we have a 80B system -> no strobes on U5 PA0 .. PA3
COUNT_STROBES: entity work.count_to_zero
port map(   
   Clock => clk_50,
	count =>"00001111",
	d_in => U5_pa_out(1), --count only one of  signals				   
	d_out => not80B,
	clear => reset_l
	);

--------------------------------------------------
-- 80B display routines	
--------------------------------------------------
segments_80B(8) <= not U5_pb_out(4); --LD1
segments_80B(16) <= not U5_pb_out(5); --LD2
segments_80B(24) <= not U5_pb_out(6); --Reset
-- D0 ... D4
sn74175_80B_1: entity work.sn74175 
port map(   
   Clock => clk_50,
	clk => U5_pa_out(4),
	clear	=> reset_l,
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn(0) => segments_80B(2),
	Qn(1) => segments_80B(6),
	Qn(2) => segments_80B(7),
	Qn(3) => segments_80B(1)
);
sn74175_80B_2: entity work.sn74175 
port map(   
   Clock => clk_50,
	clk => U5_pa_out(5),
	clear	=> reset_l,
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn(0) => segments_80B(10),
	Qn(1) => segments_80B(14),
	Qn(2) => segments_80B(15),
	Qn(3) => segments_80B(9)
);

--------------------------------------------------
-- 80/80A display routines	
--------------------------------------------------
--digit strobes
U5_PA(3 downto 0) <= U5_pa_out(3 downto 0) when game_running='1' and fa_active='0' else bm_digit_strobe;

-- assign display segments dependent on display type		
disp_segments <= 
--	segments_80B when not80B = '0' else	
--	bm_segments when game_running = '0' else --and U5_pb_out(6) = '1' else  --RTH
--	segments_80;
	bm80B_segments when show80B = '1' else	-- 80B-Spiel: Bootanzeige 2x20 (nur HAS_DISP_80B)
	bm_segments when ( game_running = '0' and U5_pb_out(6) = '1') or SDcard_error = '0' or fa_active = '1' else  --RTH
	segments_80 when not80B = '1' else
   segments_80B;	

	
--segments
sn74175_80_1: entity work.sn74175 
port map(   
	Clock => clk_50,
	clk => U5_pa_out(4),
	clear	=> '1',
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn => Din_Seg_A
);
sn74175_80_2: entity work.sn74175 
port map(   
	Clock => clk_50,
	clk => U5_pa_out(5),
	clear	=> '1',
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn => Din_Seg_B
);
sn74175_80_3: entity work.sn74175 
port map(   
	Clock => clk_50,
	clk => U5_pa_out(6),
	clear	=> '1',
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn => Din_Seg_C
);


sn7448_1: entity work.sn7448
port map(   
	Din 	=> Din_Seg_A,
	Dout  => segments_80(1 to 7)
);
segments_80(8) <= not U5_pb_out(4);

sn7448_2: entity work.sn7448
port map(   
	Din 	=> Din_Seg_B,
	Dout  => segments_80(9 to 15)
);
segments_80(16) <= not U5_pb_out(5);

sn7448_3: entity work.sn7448
port map(   
	Din 	=> Din_Seg_C,
	Dout  => segments_80(17 to 23)
);
segments_80(24) <= not U5_pb_out(6);


--------------------------------------------------
-- solenoids & lamps
--------------------------------------------------
-- unter FA-Control dieselben Pfade, gespeist aus fa_u6a/fa_u6b (RIOT-Bedeutung)
U6_PA(4 downto 0) <= not fa_u6a(4 downto 0) when fa_active='1' else
                     not U6_pa_out(4 downto 0) when game_running='1' else "00000"; --sound AND Z31
U6_PA(7 downto 5) <= fa_u6a(7 downto 5) when fa_active='1' else
                     U6_pa_out(7 downto 5) when game_running='1' else "111"; -- decoder enable and Sol9
U6_PB(3 downto 0) <= not fa_u6b(3 downto 0) when fa_active='1' else
                     not U6_pb_out(3 downto 0) when game_running='1' else "1111"; -- thunk prevention (inverter)
U6_PB(7 downto 4) <= fa_u6b(7 downto 4) when fa_active='1' else
                     U6_pb_out(7 downto 4)when reset_l='1' else lamp_ds; -- thunk prevention
	
-- cpu clock 892Khz
clock_gen: entity work.cpu_clk_gen 
port map(   
	clk_in => clk_50,
	cpu_clk_out	=> cpu_clk
);


U1: entity work.T65 -- 6502 
port map(
	Mode    			=> "00",
	Res_n   			=> game_reset_l,	-- FA-Control haelt den Spielkern an
	Enable  			=> '1',
	Clk     			=> cpu_clk,
	Rdy     			=> '1',
	Abort_n 			=> '1',
	IRQ_n   			=> cpu_irq_n,
	NMI_n   			=> '1',
	SO_n    			=> '1',
	R_W_n 			=> cpu_wr_n,
	A(15 downto 0)	=> cpu_addr,       
	DI     			=> cpu_din,
	DO    			=> cpu_dout
	);
		

	----------------------
-- read eeprom, read/write to ram
----------------------
EEprom: entity work.EEprom
port map(
	i_clk => clk_50,
	address_eeprom	=> address_eeprom,
	data_eeprom	=> data_eeprom,
	wr_ram => wr_ram,
	q_ram => r5101_dout_8bit,
	-- Control/Data Signals,
   --i_Rst_L  => reset_sw_stable,     -- FPGA Reset   
	i_Rst_L  => reset_l,
	-- PMOD SPI Interface
   o_SPI_Clk  => EEprom_CLK,
   i_SPI_MISO => ee_spi_miso,
   o_SPI_MOSI => EEprom_MOSI,
   o_SPI_CS_n => CS_EEprom,
	-- selection
	selection => not game_select,
	-- write trigger
	w_trigger(3) => game_over_relay,
	w_trigger(2) => test_sw,
	w_trigger(1) => credit_sw,
	w_trigger(0) => not game_option(1), -- as trigger for testing	
	-- init trigger (no read, RAM will be zero)
	i_init_Flag => not opt_init_nvram, -- 0 if Dip is set 
	-- signal to outside
	is_active => EEprom_active
	);	
	
----------------------
-- 5101 ram (dual port)
----------------------
Z5: entity work.R5101 -- 5101 RAM 128Byte (256 * 4bit) 
	port map(
		address_a	=> cpu_addr(7 downto 0),
		address_b   => address_eeprom,
		clock			=> clk_50,
		data_a		=> cpu_dout (3 DOWNTO 0), -- Gottlieb use the lower 4 bits
		data_b		=> data_eeprom, --8bit
		wren_a 		=> r5101_cs and not cpu_wr_n,
		wren_b 		=> wr_ram,
		q_a			=> r5101_dout_4bit,
		q_b			=> r5101_dout_8bit
);
	
	
U4_RAM: entity work.RIOT_RAM
port map(
	address	=> cpu_addr(7 DOWNTO 0),
	clock		=> clk_50, 
	data		=>  cpu_dout (7 DOWNTO 0),
	wren 		=> U4_RAM_cs and not cpu_wr_n,
	q			=> U4_RAM_dout
);	
U4_IO: entity work.R6532  -- Switchmatrx
port map(
	phi2   => phi2,
   rst_n  => game_reset_l,
   cs     => U4_IO_cs,
   rw_n   => cpu_wr_n,
	irq_n  => U4_irq_n,
	
   add    => cpu_addr(4 downto 0),
   din	 => cpu_dout,
	dout	 => U4_IO_dout,
		
	pa_in	 => U4_pa_in or SW_Freeplay or fa_sim_ret,
   pa_out => open,
   pb_in  => "00000000",
	pb_out => u4_pb_out
 );
-- Schalter-Strobes: unter FA-Control aus FA_STROBES
U4_PB <= fa_sw_strobe when fa_active = '1' else u4_pb_out;

U5_RAM: entity work.RIOT_RAM
port map(
	address	=> cpu_addr(7 DOWNTO 0),
	clock		=> clk_50, 
	data		=>  cpu_dout (7 DOWNTO 0),
	wren 		=> U5_RAM_cs and not cpu_wr_n,
	q			=> U5_RAM_dout
);  
U5_IO: entity work.R6532  -- Display Control
port map(
	phi2   => phi2,
   rst_n  => game_reset_l,
   cs     => U5_IO_cs,
   rw_n   => cpu_wr_n,
	irq_n  => U5_irq_n,
	
   add    => cpu_addr(4 downto 0),
   din	 => cpu_dout,
	dout	 => U5_IO_dout,
			
	pa_in	 => slam & "0000000",
   pa_out => U5_pa_out,
   pb_in  => "00000000",
	pb_out => U5_pb_out
 );
  
U6_RAM: entity work.RIOT_RAM
port map(
	address	=> cpu_addr(7 DOWNTO 0),
	clock		=> clk_50, 
	data		=>  cpu_dout (7 DOWNTO 0),
	wren 		=> U6_ram_cs and not cpu_wr_n,
	q			=> U6_RAM_dout
);
U6_IO: entity work.R6532  -- Solenoid & Lamp Control
port map(
	phi2   => phi2,
   rst_n  => game_reset_l,
   cs     => U6_IO_cs,
   rw_n   => cpu_wr_n,
	irq_n  => U6_irq_n,
	
   add    => cpu_addr(4 downto 0),
   din	 => cpu_dout,
	dout	 => U6_IO_dout,
		
	pa_in	 => "00000000",
   pa_out => U6_pa_out,
   pb_in  => "00000000",
	pb_out => U6_pb_out
 );  

GAME: entity work.GAME_ROM -- Game ROM 2KByte
port map(
	address	=> game_rom_addr,  -- 10 downto 0
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_game_rom,	
	q			=> game_rom_dout
	);

GAME2: entity work.GAME_ROM -- extended Game ROM 2KByte or late 80B games
port map(
	address	=> game_rom2_addr,  -- 10 downto 0
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_game_rom2,	
	q			=> game_rom2_dout
	);
	
SYSTEM: entity work.SYSTEM_ROM -- System ROM 8KByte
port map(
	address	=> system_rom_addr, -- 12 downto 0
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_system_rom,	
	q	=> system_rom_dout
	);
	
-- soundrom1 for MA219/MA309
-- soundrom for MA55 and others	
SOUNDROM1: entity work.GAME_ROM -- ROM 2KByte
port map(
	address	=> sb_rom1_addr,  -- 10 downto 0
	clock		=> clk_50, 
	data 		=> data_sd_card,
	wren 		=> wr_soundrom1,
	q			=> soundrom1_dout
	);

-- soundrom2 for MA219/MA309
-- maskrom (R6530 internal) for MA55 and others	
SOUNDROM2: entity work.GAME_ROM -- ROM 2KByte
port map(
	address	=> sb_rom2_addr,  -- 10 downto 0
	clock		=> clk_50, 
	data 		=> data_sd_card,
	wren 		=> wr_soundrom2,
	q			=> soundrom2_dout
	);
	
	
META1: entity work.Cross_Slow_To_Fast_Clock
port map(
   i_D => reset_sw,
	o_Q => reset_sw_stable,
   i_Fast_Clk => cpu_clk
	); 

	
-- Eingang des integrierten Soundboards: unter FA-Control die FA-Werte (RIOT-Bedeutung,
-- wie U6_pa_out/U6_pb_out), sonst die RIOT-Ausgaenge. Ohne ESP ist fa_active '0' und
-- beides faellt in der Synthese auf die RIOT-Ausgaenge zurueck.
snd_pa <= fa_u6a when fa_active='1' else U6_pa_out;
snd_pb <= fa_u6b when fa_active='1' else U6_pb_out;
-- Der Kern steht unter FA-Control im Reset (game_running = 0); das Soundboard und sein
-- DFPlayer-UART sollen trotzdem laufen.
snd_game_running <= game_running or fa_active;

--integrated soundboard											Sound#3 by pushing test button
Sound_S1 <= ((not snd_pa(0) and not snd_pa(4))) when mytest='1' else '1';
Sound_S2 <= ((not snd_pa(1) and not snd_pa(4))) when mytest='1' else '1';
Sound_S4 <= ((not snd_pa(2) and not snd_pa(4))) when mytest='1' else '0';
Sound_S8 <= ((not snd_pa(3) and not snd_pa(4))) when mytest='1' else '0';


---------------------
-- detection Sound16 (Q10)
----------------------
clk_Z3 <= '1' when snd_pb(7 downto 4) = "0011" else '0'; --DS3

sn74175_Sound16: entity work.sn74175 
port map(   
   Clock => clk_50,
	clk => clk_Z3,
	clear	=> '1',
	D => snd_pb(3 downto 0),
	--Q => open,
	Q(1) => Sound_S16
);


------------------------------------------------------------------------------
-- Integriertes Soundboard (GOSOF80). Auf dem v7-Board (FA-Control) abgeschaltet:
-- beides zusammen passt nicht in den EP4CE6. Die Sound-Leitungen U6 PA0..4 gehen
-- trotzdem an den Stecker - ein vorhandenes Original-Soundboard bekommt sie.
-- Board v7.1 (EP4CE22) hat beides; unter FA-Control spielt es die FA-Sounds (snd_pa).
------------------------------------------------------------------------------
gen_no_soundboard: if not HAS_SOUNDBOARD generate
	Sound          <= '0';
	Audio_RX       <= '1';				-- UART-Ruhepegel zum DFPlayer
	soundrom1_addr <= (others => '0');
	soundrom2_addr <= (others => '0');
end generate;

gen_soundboard: if HAS_SOUNDBOARD generate
SOUNDBOARD: entity work.gosof80
generic map(
		HAS_VOTRAX => HAS_VOTRAX
)
port map(
		clk_50	=> clk_50,
		cpu_clk  => cpu_clk,
		reset_l	=> reset_l,
		game_running => snd_game_running,
		test	=> '1', --myTest,
		Audio_O	=> sound,
		
		-- Sound input S1,S2,S4,S8,S16
		-- initial low due to 2803A on input of Gosof80
		Sound_Meta(0) => Sound_S1,
		Sound_Meta(1) => Sound_S2,
		Sound_Meta(2) => Sound_S4,
		Sound_Meta(3) => Sound_S8,
		Sound_Meta(4) => Sound_S16,
		
		--Soundboard Options S1 DIPs 1..6
		SB_Opt => sb_option(1) & sb_option(2) & sb_option,
		
		--switches	:	
		game_sel	=> not game_select,
		--option   => sb_option,
		
		-- DFPlayer
		DFP_tx	=> Audio_RX,
		
		--module
		soundrom1_addr => soundrom1_addr,
		soundrom2_addr => soundrom2_addr,
		soundrom1_dout => soundrom1_dout,
		soundrom2_dout => soundrom2_dout

	);
end generate;

------------------------------------------------------------------------------
-- FA-Control. Die Muxe oben sind bewusst unbedingt: ohne ESP ist fa_active die
-- Konstante '0', und die Synthese entfernt sie wieder.
------------------------------------------------------------------------------
gen_fa_control: if HAS_ESP32 generate
FA: entity work.fa_sys80
generic map(
	VERSION      => BOARD_ID & SW_SUB,	-- z.B. "815"
	HAS_DISP_80B => HAS_DISP_80B
	)
port map(
	clk_50       => clk_50,
	reset        => not reset_sw_stable,
	FA_RXD       => FA_RXD,
	FA_TXD       => FA_TXD,
	FA_CTRL_REQ  => FA_CTRL_REQ,
	U4_PB        => U4_PB,
	U4_pa_in     => U4_pa_in,
	U5_pa_out    => U5_pa_out,
	U5_pb_out    => U5_pb_out,
	U6_pa_out    => U6_pa_out,
	U6_pb_out    => U6_pb_out,
	game_running => game_running,
	not80B       => not80B,
	sys80B       => sys80B,
	segments_80B => segments_80B,
	game_dig2    => game_dig2,
	game_dig1    => game_dig1,
	game_dig0    => game_dig0,
	active       => fa_active,
	u6a          => fa_u6a,
	u6b          => fa_u6b,
	sw_strobe    => fa_sw_strobe,
	sim_ret      => fa_sim_ret,
	disp1        => fa_disp1,
	disp2        => fa_disp2,
	disp3        => fa_disp3,
	disp4        => fa_disp4,
	txt1         => fa_txt1,
	txt2         => fa_txt2
	);
end generate;

------------------------------------------------------------------------------
-- Boards ohne ESP32. FA_TXD hat hier keinen Pin (VIRTUAL_PIN), muss aber
-- getrieben sein; '1' ist der Ruhepegel einer UART-Leitung.
------------------------------------------------------------------------------
gen_no_fa_control: if not HAS_ESP32 generate
	fa_active    <= '0';
	FA_TXD       <= '1';
	fa_u6a       <= (others => '1');
	fa_u6b       <= (others => '0');
	fa_sw_strobe <= (others => '0');
	fa_sim_ret   <= (others => '0');
	fa_disp1     <= "       ";
	fa_disp2     <= "       ";
	fa_disp3     <= "       ";
	fa_disp4     <= "       ";
	-- fa_txt1/2 liest nur boot_message_80B (HAS_DISP_80B)
	nofa_txt: if HAS_DISP_80B generate
		fa_txt1  <= (others => ' ');
		fa_txt2  <= (others => ' ');
	end generate;
end generate;

end rtl;
		
