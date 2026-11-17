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
-- V0.1 initial release
-- V0.2 optimized based on BallyFA
-- V0.3 SD card roms added
-- V0.4 EEprom nvram added
-- V0.5 nvram dual port, eeprom routine added
-- V0.6 nvram safe when sol 9 is activated
-- V0.61 slow to fast clock for switches added
-- V0.62 added credit and testswitch detection (for trigger nvram)
-- V0.63 added SD card read check
-- V0.63 added check of game over relay (for trigger nvram)
-- V0.7 trigger for nvram/eeprom now testswitch, credit switch and game over relay
-- V0.8 init of solenoids corrected (delayed start of control through PRG )
-- V0.9 sound init 
-- V0.91 fixded 80B detection
-- V0.92
	-- trigger for eeprom fixed
	-- optional freeplay ( press and hold credit button will simulate coin)
	-- eliminated additional clocks ( was: rising_edge)
-- V0.93 bug with '1' on display 1 & 2 fixed
-- V.094 bug with '1' on status display fixed (segments == 0 while game not running)
--
-- V0.95 13.03.2021  sd_card.vhd new version to support more SD card types
-- V0.96 10.07.2021  added delay for credit switch detection to ensure nvram is saved at the right time for 80B
--						   adapted boot message to v3.10
-- V0.97 31.10.2021  force 80B by default
-- V0.98 09.01.2022  deleted '80B force' (problems with 80/80A) and reactivated SD Error LED

--
-- NEW PLuS 19.04.2022
-- some ports moved compared to v1.0 (Assigments)
-- dip switch extension with strobe/return ('read_the_dips')
-- eeprom.vhd 0.3a used (automatic write with initial)
-- slam handling adopted from v4.x
--
-- adapted to v1.1 SMD (only pin assigments changed)
-- V0.99 11.09.2022 PB0..3 initially 1 to prevent thunk
-- V1.00 02.10.2022 slam and thunk bug resolved
-- V1.01 09.10.2022 anti thunk period until rest_l=1
-- 
-- V2.02 11.05.2023 adapted to Cyclone IV and late 80B games
-- v2.03 04.06.2025 added Freeplay roms, convert to lib
--
-- 12.11.2026 common top level of all GottFA80 HW 1.1 (SMD) boards, taken from
--            GottFA80_HW1.1SMD_Cyclone_IV_v3 (v203). What differs per board comes from
--            variants\<n>\variant_pkg.vhd:
--              BOARD_ID       first digit of the version shown at boot (1..4)
--              HAS_LATE80B    second game ROM for the late 80B games (not on Cyclone II,
--                             no memory left)
--              HAS_PLL_CLK    CPU clock (c0) from the PLL cpu_clock_gen (c1 = 80 kHz unused)
--                             (Cyclone IV board v4.x) instead of cpu_clk_gen
--              HAS_DISP_80B   80B boot message on the alphanumeric display, as PLuS v7_1
--            The software digits come from lib_common\version_pkg.vhd (SW_SUB_80).
--            The PLuS boards have their own top level top\SYS80.vhd.
--
-- 16.11.2026 FA-Control (HAS_ESP32) for the Cyclone IV board v7.1 (EP4CE22, ESP32-C3 on X7,
--            variant smd_hw11_cyclone_iv_v7_1, BOARD_ID 8): the same block as the PLuS
--            board v7_1 (lib_common\fa_sys80.vhd). Under FA control the game core (6502,
--            RIOTs, game_running) is held in reset and the outputs come from FA control;
--            all muxes below fall away without ESP (fa_active is the constant '0').
--
-- 17.11.2026 HAS_VJTAG_PROBE (only the dormant variant smd_hw11_cyclone_iv_v4_vj): a Virtual
--            JTAG test node (lib_common\vjtag_probe.vhd) without any connection to the game.
--            Step 1 of "FA control over Virtual JTAG" (ESP32 on the JTAG header P5).
--
-- 17.11.2026 HAS_FA_VJTAG + FA_SPAR (dormant probe variants only): FA control without FA pins,
--            lib_common\fa_vjtag_link.vhd feeds fa_sys80 over Virtual JTAG. FA_SPAR selects
--            a reduced FA control (monitor or control only) for EP4CE6/10CL006.

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.variant_pkg.all;
use work.version_pkg.all;

entity SYS80_80 is
	port(
	   -- the FPGA board
		clk_50	: in std_logic;
		reset_sw	: in std_logic;
		LED_0 	: out STD_LOGIC;						
		LED_1 	: out STD_LOGIC;
		LED_2 	: out STD_LOGIC;		
		
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
		
		-- DIp Switch Game selectOptions
		-- game_select	:	in 	std_logic_vector(5 downto 0);		
		-- DIp Switch Game selectOptions
		--game_option	:	in 	std_logic_vector(1 to 2);
		-- PLuS: 10 possible Switches via 2xStrobes and 5xReturns
		
		DIP_Strobe	:	out 	std_logic_vector(1 downto 0);
		DIP_Return	:	in 	std_logic_vector(4 downto 0);
		myTest		: 	in 	std_logic;
		
		-- LEDs on GottFA
		LED_SDcard	: 	out 	std_logic;
		LED_Int		: 	out 	std_logic;

		-- configuration flash EPCS16 as second source of the game ROMs (HAS_FLASH_ROM,
		-- lib_common\Flash_ROM.vhd); AS pins as user I/O (device.tcl). VIRTUAL_PIN on the
		-- boards without flash loader (variant.psd1), high impedance there.
		FLASH_DCLK		:	out	std_logic;
		FLASH_NCS		:	out	std_logic;
		FLASH_ASDO		:	out	std_logic;	-- data into the flash
		FLASH_DATA0		:	in		std_logic;	-- data out of the flash

		-- FA control: ESP32-C3 on X7 of the Cyclone IV board v7.1 (HAS_ESP32), one bit each
		-- (pins FA_RXD[0] etc.). Without ESP the ports have NO bits (null range), so no pin
		-- is created: the Cyclone II board has all 89 I/O in use and Quartus 13 ignores
		-- VIRTUAL_PIN there (Error 176205 when these were plain std_logic ports).
		FA_RXD			:	in		std_logic_vector(boolean'pos(HAS_ESP32) - 1 downto 0);	-- R3, from the TX of the ESP
		FA_TXD			:	out	std_logic_vector(boolean'pos(HAS_ESP32) - 1 downto 0);	-- T2, to the RX of the ESP
		FA_CTRL_REQ		:	in		std_logic_vector(boolean'pos(HAS_ESP32) - 1 downto 0)	-- N3, active low, weak pull-up
		);
end SYS80_80;


architecture rtl of SYS80_80 is

-- PLL of the Cyclone IV board v4.x (lib_cyclone_IV\cpu_clock_gen, only listed for
-- that board via scripts\files_pll_civ.tcl). Instantiated as a COMPONENT on purpose:
-- with 'entity work.' Quartus would resolve it in the generate branch that is not
-- taken as well (Error 10481), and Cyclone 10 / Cyclone II have no such PLL.
component cpu_clock_gen
	port(
		inclk0	: in std_logic := '0';
		c0			: out std_logic;
		c1			: out std_logic
	);
end component;

-- FA control (lib_common\fa_sys80.vhd, HAS_ESP32). Also a COMPONENT on purpose: its sources
-- (lib_fa_control) are only listed for the ESP boards (Option 'fa_control',
-- scripts\files_fa_control.tcl), Cyclone II / Quartus 13 does not parse them.
component fa_sys80
	generic(
		VERSION      : string(1 to 3);
		HAS_DISP_80B : boolean;
		FA_MON       : boolean := true;
		FA_CTRL      : boolean := true;
		FA_80B_TXT   : boolean := true
		);
	port(
		clk_50       : in  std_logic;
		reset        : in  std_logic;
		FA_RXD       : in  std_logic;
		FA_TXD       : out std_logic;
		FA_CTRL_REQ  : in  std_logic;
		U4_PB        : in  std_logic_vector(7 downto 0);
		U4_pa_in     : in  std_logic_vector(7 downto 0);
		U5_pa_out    : in  std_logic_vector(7 downto 0);
		U5_pb_out    : in  std_logic_vector(7 downto 0);
		U6_pa_out    : in  std_logic_vector(7 downto 0);
		U6_pb_out    : in  std_logic_vector(7 downto 0);
		game_running : in  std_logic;
		not80B       : in  std_logic;
		sys80B       : in  std_logic;
		segments_80B : in  std_logic_vector(1 to 24);
		game_dig2    : in  character;
		game_dig1    : in  character;
		game_dig0    : in  character;
		active       : out std_logic;
		u6a          : out std_logic_vector(7 downto 0);
		u6b          : out std_logic_vector(7 downto 0);
		sw_strobe    : out std_logic_vector(7 downto 0);
		sim_ret      : out std_logic_vector(7 downto 0);
		disp1        : out string(1 to 7);
		disp2        : out string(1 to 7);
		disp3        : out string(1 to 7);
		disp4        : out string(1 to 7);
		txt1         : out string(1 to 20);
		txt2         : out string(1 to 20)
		);
end component;

-- Virtual JTAG test node (HAS_VJTAG_PROBE). A COMPONENT for the same reason as fa_sys80:
-- its source is only listed with Option 'vjtag_probe' (scripts\files_vjtag_probe.tcl).
component vjtag_probe
	generic(
		ID : std_logic_vector(31 downto 0)
		);
end component;

-- FA control over Virtual JTAG (HAS_FA_VJTAG): looks like the three FA pins to fa_sys80.
-- A COMPONENT as well: its source is only listed with Option 'fa_vjtag'.
component fa_vjtag_link
	generic(
		ID           : std_logic_vector(31 downto 0);
		CLKS_PER_BIT : integer := 434;
		CLK_HZ       : integer := 50000000;
		DEADMAN_MS   : integer := 2000
		);
	port(
		clk          : in  std_logic;
		fa_rxd       : out std_logic;
		fa_txd       : in  std_logic;
		fa_ctrl_req  : out std_logic
		);
end component;

-- FA_SPAR = 4: service design, FA control (incl. 80B text) without the game (see SD card)
constant FA_SERVICE : boolean := FA_SPAR = 4;

-- third ID character of fa_vjtag_link from FA_SPAR: 'L' full, 'M' monitor, 'C' control,
-- 'S' service (control without game)
function fa_kind_byte(spar : integer) return std_logic_vector is
begin
	if spar = 4 then
		return x"53";	-- 'S'
	elsif spar = 2 then
		return x"43";	-- 'C'
	elsif spar = 1 or spar = 3 then
		return x"4D";	-- 'M'
	end if;
	return x"4C";		-- 'L'
end function;

signal cpu_clk		: std_logic; -- 895 kHz CPU clock
signal cpu_clk_div	: std_logic; -- from cpu_clk_gen
signal cpu_clk_pll	: std_logic; -- from the PLL (HAS_PLL_CLK)
signal reset_l	 	: std_logic;
signal game_reset_l	: std_logic;	-- reset_l, plus held while FA control has control
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
-- 80B boot message (HAS_DISP_80B)
signal sys80B				: std_logic;	-- game selection is an 80B game (40..61)
signal show80B				: std_logic;	-- boot_message_80B drives the display
signal bm80B_segments	: std_logic_vector(1 to 24);

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
-- outputs of SD_Card; address_sd_card/data_sd_card/wr_rom/reset_l/SDcard_error are the
-- signals muxed between SD card and flash (HAS_FLASH_ROM)
signal sd_address		:  std_logic_vector(13 downto 0);
signal sd_data			:  std_logic_vector(7 downto 0);
signal sd_wr_rom		:  std_logic;
signal sd_cpu_reset_l	:  std_logic;
signal sd_error		:  std_logic;
signal sd_no_card		:  std_logic;	-- SD init failed -> flash
signal use_flash		:  std_logic;	-- game ROMs come from the flash
signal sd_err_cmd			: std_logic_vector(3 downto 0);	-- SD diagnosis (SD_Card v053)
signal sd_err_rx			: std_logic_vector(55 downto 0);

-- EEprom we use 128Bytes
signal address_eeprom	:  std_logic_vector(6 downto 0);
signal data_eeprom	:  std_logic_vector(7 downto 0);
signal wr_ram			:  std_logic;
signal EEprom_MOSI	:	std_logic; 
signal EEprom_CLK		:	std_logic; 
signal EEprom_active	:	std_logic; 

-- init & boot message helper
signal game_running		: 	std_logic:= '0';
signal dig0_ascii			:  character;
signal dig1_ascii			:  character;
signal dig2_ascii			:  character;
signal g_opt_dig0			:  character;	-- game options (DIPs) for the boot message, as PLuS
signal g_opt_dig1			:  character;

-- dip games select and options
signal readingdips	: 	std_logic:= '1';
signal game_select 		:  std_logic_vector(5 downto 0);				
signal game_option		: 	std_logic_vector(1 to 4);
		
-- diff
signal sim_coin		: 	std_logic:= '0';
signal slam				: 	std_logic;
signal lamp_ds 		:  std_logic_vector(3 downto 0);		
signal late80B			: std_logic:='0'; --default we have not a late 80B system with bigger rom

-- FA control (HAS_ESP32), outputs of fa_sys80; fa_u6a/fa_u6b have the meaning of the RIOT
-- ports (before the inverters below), so the output paths stay the same as in the game.
signal fa_active		: std_logic;
signal fa_u6a			: std_logic_vector(7 downto 0);
signal fa_u6b			: std_logic_vector(7 downto 0);
signal fa_sw_strobe	: std_logic_vector(7 downto 0);
signal fa_sim_ret		: std_logic_vector(7 downto 0);	-- simulated switches of the strobed column
signal fa_disp1		: string(1 to 7);
signal fa_disp2		: string(1 to 7);
signal fa_disp3		: string(1 to 7);
signal fa_disp4		: string(1 to 7);
signal fa_txt1			: string(1 to 20);	-- FA control display 0 (80B row 1)
signal fa_txt2			: string(1 to 20);	-- FA control display 1 (80B row 2)
signal u4_pb_out		: std_logic_vector(7 downto 0);
signal bm_display1	: string(1 to 7);
signal bm_display2	: string(1 to 7);
signal bm_display3	: string(1 to 7);
signal bm_display4	: string(1 to 7);
signal bm_error4		: string(1 to 7);

-- nibble as hex character (SD diagnosis on the 80B boot message), copy of top\SYS80.vhd
function hexc(n : std_logic_vector(3 downto 0)) return character is
	constant H : string(1 to 16) := "0123456789ABCDEF";
begin
	return H(to_integer(unsigned(n)) + 1);
end function;

-- game options
signal opt_freeplay				: 	std_logic;
signal opt_init_nvram				: 	std_logic;
signal opt_slam_fix_open			: 	std_logic;
signal opt_slam_fix_close		: 	std_logic;

begin

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
	-- input (display data); under FA control the digits of the host
	display1	=> bm_display1,
	display2	=> bm_display2,
	display3	=> bm_display3,
	display4	=> bm_display4,
	error_disp4 => bm_error4,
	status_d	=> "       "
	);

bm_display1 <= fa_disp1 when fa_active = '1' else "    " & BOARD_ID & SW_SUB_80;  -- e.g. "    203"
bm_display2 <= fa_disp2 when fa_active = '1' else "    " & dig2_ascii & dig1_ascii & dig0_ascii;
bm_display3 <= fa_disp3 when fa_active = '1' else " 050963";
bm_display4 <= fa_disp4 when fa_active = '1' else " " & g_opt_dig1 & g_opt_dig0 & "    ";  -- game options, as PLuS (no SB options)
bm_error4   <= fa_disp4 when fa_active = '1' else "0000000";

----------------------
-- boot message 80B (2 x 20 characters, Rockwell 10941), only with HAS_DISP_80B.
-- Same scheme as the PLuS board v7_1 (top\SYS80.vhd): before the game starts 80B can only
-- be told from the game selection (not80B below is valid once the game runs):
-- 40 Bounty Hunter .. 61 Night Moves; 62/63 (Amazon Hunt II/III) are 80A. While the DIPs
-- are read game_select is not valid. As long as show80B = '1' the module drives the whole
-- J2 bus (data, LD1, LD2, reset); during the game J2 belongs to the RIOT again.
-- 12.11.2026: up to then (and in the released v303) only LD1 came from the module, and it
-- did so during the game as well - row 1 of an 80B display got no load pulse from the game.
----------------------
sys80B <= '1' when HAS_DISP_80B and to_integer(unsigned(not game_select)) >= 40
                   and to_integer(unsigned(not game_select)) <= 61 else '0';
show80B <= sys80B and not readingdips and ((not game_running) or fa_active or not SDcard_error);

gen_disp80b: if HAS_DISP_80B generate
	signal d80_data  : std_logic_vector(7 downto 0);
	signal d80_ld1   : std_logic;
	signal d80_ld2   : std_logic;
	signal d80_reset : std_logic;
	signal d80_err2  : string(1 to 20);
	signal d80_row1  : string(1 to 20);
	signal d80_row2  : string(1 to 20);
begin
	-- row 2: game and options, or "GAME 040 FLASH ROM  " when the ROMs come from the flash
	-- under FA control (HAS_ESP32) both rows come from the host
	d80_row1 <= fa_txt1 when fa_active = '1' else "GOTTFA80        V" & BOARD_ID & SW_SUB_80;
	d80_row2 <= fa_txt2 when fa_active = '1' else
	            "GAME " & dig2_ascii & dig1_ascii & dig0_ascii & " FA SERVICE " when FA_SERVICE else
	            "GAME " & dig2_ascii & dig1_ascii & dig0_ascii & " FLASH ROM  " when use_flash = '1' else
	            "GAME " & dig2_ascii & dig1_ascii & dig0_ascii & " OPT" & g_opt_dig1 & g_opt_dig0 & "      ";
	-- error row as PLuS v7_1: flash error (slot not in the flash) "FLASH ERR GAME 040  ";
	-- SD: no answer at all (all 7 bytes FF, typically no card) -> "GAME 040 NO SD CARD ",
	-- otherwise the diagnosis "SD E4 FF01FFFFFF05FF" = blink code and the 7 bytes of the
	-- response window (byte 7..13 after the command, SD_Card v053)
	d80_err2 <= "FLASH ERR GAME " & dig2_ascii & dig1_ascii & dig0_ascii & "  " when use_flash = '1' else
	            "GAME " & dig2_ascii & dig1_ascii & dig0_ascii & " NO SD CARD " when sd_err_rx = x"FFFFFFFFFFFFFF" else
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
		-- 20 characters each: "GOTTFA80        V303" / "GAME 040 OPT00      "
		row1       => d80_row1,
		row2       => d80_row2,
		error_row2 => d80_err2
		);

	-- J2 as segments_80B (below): D0..D3 = 2,6,7,1  D4..D7 = 10,14,15,9
	-- LD1 = 8, LD2 = 16, Reset = 24; the other lines stay low.
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
end generate gen_disp80b;

gen_no_disp80b: if not HAS_DISP_80B generate
	bm80B_segments <= (others => '0');
end generate gen_no_disp80b;

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
RDIPS: entity work.read_the_dips_80
port map(
	clk_in		=> cpu_clk, 	
	i_Rst_L  => reset_sw_stable,     -- FPGA Reset   
   readingdips	=> readingdips,
	--output 
	game_select	=> game_select,
	game_option	=> game_option,
	-- strobes
	dipstrobe1 => DIP_Strobe(0),
	dipstrobe2 => DIP_Strobe(1),
	-- input
	return1 => DIP_Return(0),
	return2 => DIP_Return(1),
	return3 => DIP_Return(2),
	return4 => DIP_Return(3),
	return5 => DIP_Return(4)
	);
	

CONVB: entity work.byte_to_ascii
port map(
	clk_in	=> clk_50, 		
	mybyte	=> "11" & game_select,
	dig0_ascii => dig0_ascii,
	dig1_ascii => dig1_ascii,
	dig2_ascii => dig2_ascii
	);

-- game options for the boot message (as PLuS CONVO, but 4 option DIPs)
CONVO: entity work.byte_to_ascii
port map(
	clk_in	=> clk_50,
	mybyte	=> "1111" & game_option(4) & game_option(3) & game_option(2) & game_option(1),
	dig0_ascii => g_opt_dig0,
	dig1_ascii => g_opt_dig1,
	dig2_ascii => open
	);


-- LEDs FPGA board
LED_0 <= not EEprom_active;
LED_1 <= '1'; --OFF
LED_2 <= reset_l; 

-- LEDs GottFA80
LED_Int <= not game_running;
LED_SDcard <= SDcard_error;
	
-- RIOT IRQ outputs all assert CPU IRQ input
cpu_irq_n <= U4_irq_n and U5_irq_n and U6_irq_n;		
--cpu_irq_n <= '1';

-- general assigments
phi2 <= not cpu_clk;

-- slam
slam <= '0' when game_option(3) = '0' else --slam open for late 80B games
		  '1' when game_option(4) = '0' else -- slam fix closed
		  U5_PA_7; --real slam

---------------------
-- shared SPI bus
----------------------
--MOSI <= SDcard_MOSI when CS_SDcard = '0' else EEprom_MOSI;
--CLK <= SDcard_CLK when CS_SDcard = '0' else EEprom_CLK;
--SD card only at start of game
MOSI <= SDcard_MOSI when reset_l = '0' else EEprom_MOSI;
CLK <= SDcard_CLK when reset_l = '0' else EEprom_CLK;


---------------------
-- FA control holds the whole game core (6502, RIOTs U4/U5/U6, game_running) in reset,
-- afterwards the game starts again as after power-on (as PLuS v7/v7_1).
-- Without ESP fa_active is '0', so game_reset_l equals reset_l.
---------------------
game_reset_l <= reset_l and not fa_active;

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
-- dfetectio game over relay (Q1)
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
-- FA service design (FA_SPAR = 4): no game at all. Without SD and flash loader reset_l
-- stays '0', so the 6502, the RIOTs, the ROM RAMs and the EEPROM never leave reset and
-- synthesis removes them - room for full FA control with 80B text on EP4CE6/10CL006.
----------------------
gen_no_sd_card: if FA_SERVICE generate
	SDcard_CLK     <= '0';
	SDcard_MOSI    <= '0';
	CS_SDcard      <= '1';
	sd_address     <= (others => '0');
	sd_data        <= (others => '0');
	sd_wr_rom      <= '0';
	sd_cpu_reset_l <= '0';
	sd_error       <= '1';		-- active low: no error (the boot message would show "SD E0 ...")
	sd_err_cmd     <= (others => '0');
	sd_err_rx      <= (others => '0');
	sd_no_card     <= '0';
end generate gen_no_sd_card;

gen_sd_card: if not FA_SERVICE generate
SD_CARD: entity work.SD_Card
port map(
	--
	i_clk		=> clk_50,	
	-- Control/Data Signals,
   i_Rst_L  => not readingdips,     -- FPGA Reset & dip read finished
	-- PMOD SPI Interface
   o_SPI_Clk  => SDcard_CLK,
   i_SPI_MISO => MISO,
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
	-- diagnosis for the 80B boot message (SD_Card v053)
	err_cmd => sd_err_cmd,
	err_rx  => sd_err_rx,
	o_no_card => sd_no_card
	);
end generate gen_sd_card;

---------------------
-- Game ROMs from the configuration flash (HAS_FLASH_ROM, 13.11.2026), as PLuS v7_1
-- (top\SYS80.vhd): if no SD card answers (sd_no_card), lib_common\Flash_ROM.vhd loads
-- the same slot from the EPCS16 (from 0x080000, directory + deduplicated 2 KByte blocks,
-- written by scripts\make_flash_hex.ps1 into gottfa80_roms.jic) and takes over ROM write
-- port, CPU reset and the error signal.
---------------------
gen_flash_rom: if HAS_FLASH_ROM and not FA_SERVICE generate
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
end generate gen_flash_rom;

-- Without the flash loader the FLASH_* outputs are high impedance, not driven: Quartus 13
-- (smd_hw11_cyclone_ii) does not know VIRTUAL_PIN and puts these ports on free pins.
gen_no_flash_rom: if not (HAS_FLASH_ROM and not FA_SERVICE) generate
	use_flash       <= '0';
	FLASH_DCLK      <= 'Z';
	FLASH_NCS       <= 'Z';
	FLASH_ASDO      <= 'Z';
	address_sd_card <= sd_address;
	data_sd_card    <= sd_data;
	wr_rom          <= sd_wr_rom;
	reset_l         <= sd_cpu_reset_l;
	SDcard_error    <= sd_error;
end generate gen_no_flash_rom;

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
-- RTH TODO 2 games with 4K game prom existing! NOT with CycloneII, no memory 

-- content of game rom is read from first 2K of SD
wr_game_rom <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="000" )) else '0';
game_rom_addr <=  --2K
	address_sd_card(10 downto 0) when wr_game_rom = '1' else
	cpu_addr(10 downto 0);

-- content of extended game rom (late 80B games) is read from second 2K of SD
-- (HAS_LATE80B: address mux and GAME2 are in gen_late80B further down)

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
game_rom2_cs	<= '1' when HAS_LATE80B and cpu_addr(13 downto 11) ="010" and cpu_addr(15) = '1' and late80B='1' else '0';


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
U5_PB_7 <= '1' when fa_active = '1' else not U5_pb_out(7); --switch enable (FA: matrix, no DIPs)

-- determine if we have a 80B system -> no strobes on U5 PA0 .. PA3
COUNT_STROBES: entity work.count_to_zero
port map(   
   Clock => clk_50,
	count =>"00001111",
	d_in => U5_pa_out(1), --count only one of  signals				   
	d_out => not80B,
	clear => reset_l
	);

-- assign display segments dependent on display type		
-- zero in case of
disp_segments <=
   -- segments_80B when not80B = '0' else
	bm80B_segments when show80B = '1' else	-- 80B game: boot message 2x20 (only HAS_DISP_80B)
	bm_segments when (game_running = '0' and U5_pb_out(6) = '1') or fa_active = '1' else  --RTH
	segments_80 when not80B = '1' else
   segments_80B;	

--	disp_segments( 1 to 8) <= data_sd_card;  --RTH debug
--DEBUG RTH
--segments_80(1) <= not80B;
--segments_80(2) <= U4_PB(0);
--segments_80(3) <= test_sw;
--segments_80(4) <= U4_pa_in(7) and U4_PB(0) and not U5_pb_out(7);
--segments_80(3) <= credit_sw;
--segments_80(3) <= test_sw;
--segments_80(4) <= 
--credit_sw <=   U4_pa_in(7) and not U4_PB(4) and not U5_pb_out(7);  -- credit switch is strobe 4 and return 7 and not dip switch active
	
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
-- under FA control the same paths, fed from fa_u6a/fa_u6b (RIOT meaning)
U6_PA(4 downto 0) <= not fa_u6a(4 downto 0) when fa_active='1' else
                     not U6_pa_out(4 downto 0) when game_running='1' else "00000"; --sound AND Z31
U6_PA(7 downto 5) <= fa_u6a(7 downto 5) when fa_active='1' else
                     U6_pa_out(7 downto 5) when game_running='1' else "111"; -- decoder enable and Sol9
U6_PB(3 downto 0) <= not fa_u6b(3 downto 0) when fa_active='1' else
                     not U6_pb_out(3 downto 0) when game_running='1' else "1111"; -- thunk prevention (inverter)
U6_PB(7 downto 4) <= fa_u6b(7 downto 4) when fa_active='1' else
                     U6_pb_out(7 downto 4)when reset_l='1' else lamp_ds; -- thunk prevention
	
-- cpu clock 892Khz
-- clock_gen stays OUTSIDE any generate: lib_common\SYS80.sdc names it
-- (cpu_clk_gen:clock_gen|cpu_clk_out), a generate label would change that path silently.
-- With HAS_PLL_CLK its output is unused and synthesis removes it.
clock_gen: entity work.cpu_clk_gen
port map(
	clk_in => clk_50,
	cpu_clk_out	=> cpu_clk_div
);

gen_pll: if HAS_PLL_CLK generate
PLL: cpu_clock_gen
port map(
	inclk0 => clk_50,
	c0	    => cpu_clk_pll,
	c1		 => open	-- 80 kHz, was the clock of boot_message_80B until 12.11.2026
);
end generate gen_pll;
gen_no_pll: if not HAS_PLL_CLK generate
	cpu_clk_pll <= '0';
end generate gen_no_pll;

cpu_clk <= cpu_clk_pll when HAS_PLL_CLK else cpu_clk_div;


U1: entity work.T65 -- 6502 
port map(
	Mode    			=> "00",
	Res_n   			=> game_reset_l,	-- FA control holds the game core
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
   i_SPI_MISO => MISO,
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
	i_init_Flag => game_option(2), -- 0 if Dip is set 
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
		
	pa_in	 => U4_pa_in or SW_Freeplay or fa_sim_ret,	-- simulated switches (FA monitor)
   pa_out => open,
   pb_in  => "00000000",
	pb_out => u4_pb_out
 );

-- switch strobes: under FA control from fa_sys80
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

gen_late80B: if HAS_LATE80B generate
wr_game_rom2 <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="001" )) else '0';
game_rom2_addr <=  --2K
	address_sd_card(10 downto 0) when wr_game_rom2 = '1' else
	cpu_addr(10 downto 0);
GAME2: entity work.GAME_ROM -- extended Game ROM 2KByte or late 80B games
port map(
	address	=> game_rom2_addr,  -- 10 downto 0
	clock		=> clk_50,
	data => data_sd_card,
	wren => wr_game_rom2,
	q			=> game_rom2_dout
	);
end generate gen_late80B;
gen_no_late80B: if not HAS_LATE80B generate
	game_rom2_dout <= x"FF";
end generate gen_no_late80B;
	
SYSTEM: entity work.SYSTEM_ROM -- System ROM 8KByte
port map(
	address	=> system_rom_addr, -- 12 downto 0
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_system_rom,	
	q	=> system_rom_dout
	);
	
META1: entity work.Cross_Slow_To_Fast_Clock
port map(
   i_D => reset_sw,
	o_Q => reset_sw_stable,
   i_Fast_Clk => cpu_clk
	);

------------------------------------------------------------------------------
-- FA control (HAS_ESP32, Cyclone IV board v7.1): lib_common\fa_sys80.vhd, the same block
-- as PLuS v7/v7_1. The muxes above are written unconditionally on purpose: without ESP
-- fa_active is the constant '0' and synthesis removes them again.
------------------------------------------------------------------------------
gen_fa_control: if HAS_ESP32 or HAS_FA_VJTAG generate
	signal fa_rxd_s : std_logic;
	signal fa_txd_s : std_logic;
	signal fa_req_s : std_logic;
begin
-- the FA ports are one bit wide here; a loop instead of FA_RXD(0), so that no static index
-- into the null range shows up on the boards without ESP
fa_io: for i in FA_RXD'range generate
	fa_rxd_s       <= FA_RXD(i);
	FA_TXD(i)      <= fa_txd_s;
	fa_req_s       <= FA_CTRL_REQ(i);
end generate fa_io;

-- FA control over Virtual JTAG (ESP32 on the JTAG piggyback at P5, no FA pins).
-- ID "FA" & kind & BOARD_ID: kind L = full, M = monitor only (FA_SPAR 1/3), C = control
-- only (FA_SPAR 2), e.g. "FAM3" = 0x46414D33. FA_Control shows it in menu 09 FPGA.
-- The test node vjtag_probe says "GF8x".
gen_fa_vjtag: if HAS_FA_VJTAG generate
VJL: fa_vjtag_link
	generic map(
		ID => x"4641" & fa_kind_byte(FA_SPAR) & std_logic_vector(to_unsigned(character'pos(BOARD_ID(1)), 8))
		)
	port map(
		clk          => clk_50,
		fa_rxd       => fa_rxd_s,
		fa_txd       => fa_txd_s,
		fa_ctrl_req  => fa_req_s
		);
end generate gen_fa_vjtag;

FA: fa_sys80
generic map(
	VERSION      => BOARD_ID & SW_SUB_80,	-- e.g. "805"
	HAS_DISP_80B => HAS_DISP_80B,
	-- FA_SPAR (variant_pkg): 0 full, 1 monitor only, 2 control only without 80B text,
	-- 3 monitor only without 80B text, 4 service: control with 80B text, no game
	FA_MON       => FA_SPAR = 0 or FA_SPAR = 1 or FA_SPAR = 3,
	FA_CTRL      => FA_SPAR = 0 or FA_SPAR = 2 or FA_SPAR = 4,
	FA_80B_TXT   => FA_SPAR = 0 or FA_SPAR = 1 or FA_SPAR = 4
	)
port map(
	clk_50       => clk_50,
	reset        => not reset_sw_stable,
	FA_RXD       => fa_rxd_s,
	FA_TXD       => fa_txd_s,
	FA_CTRL_REQ  => fa_req_s,
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
	game_dig2    => dig2_ascii,
	game_dig1    => dig1_ascii,
	game_dig0    => dig0_ascii,
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
end generate gen_fa_control;

------------------------------------------------------------------------------
-- Boards without ESP32. The FA ports have no bits there (see entity), nothing to drive.
------------------------------------------------------------------------------
gen_no_fa_control: if not (HAS_ESP32 or HAS_FA_VJTAG) generate
	fa_active    <= '0';
	fa_u6a      <= (others => '1');
	fa_u6b       <= (others => '0');
	fa_sw_strobe <= (others => '0');
	fa_sim_ret   <= (others => '0');
	fa_disp1     <= "       ";
	fa_disp2     <= "       ";
	fa_disp3     <= "       ";
	fa_disp4     <= "       ";
	fa_txt1      <= (others => ' ');
	fa_txt2      <= (others => ' ');
end generate gen_no_fa_control;

------------------------------------------------------------------------------
-- Virtual JTAG test node (HAS_VJTAG_PROBE, step 1 of FA control over JTAG). No ports:
-- it talks only to the SLD hub that Quartus inserts. ID = "GF8" & BOARD_ID, e.g. "GF83".
------------------------------------------------------------------------------
gen_vjtag_probe: if HAS_VJTAG_PROBE generate
VJP: vjtag_probe
	generic map(
		ID => x"474638" & std_logic_vector(to_unsigned(character'pos(BOARD_ID(1)), 8))
		);
end generate gen_vjtag_probe;

end rtl;
		