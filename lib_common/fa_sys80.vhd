-- fa_sys80.vhd - FA-Control fuer GottFA80 (Gottlieb System 80/80A/80B)
-- (c)2026 bontango, GPL v3 wie der Rest des Projekts.
--
-- 16.11.2026 aus top\SYS80.vhd (gen_fa_control) ausgelagert, damit das PLuS-Top
-- (top\SYS80.vhd, Board v7/v7_1) und das SMD-Top (top\SYS80_80.vhd, Board v7.1) denselben
-- Block benutzen. Der Rumpf ist unveraendert uebernommen; neu sind nur die Ports.
-- Instanziiert wird das Modul nur mit HAS_ESP32 (variant_pkg), die Muxe auf die
-- Spielausgaenge bleiben im jeweiligen Top.
--
-- Nummerierung wie LISY80 (lisy80.c):
--   Lampen 0..47  = Transistor Q1..Q48: Q = 4*(FEED-1) + LD-Bit, FEED 1..12 auf
--                   U6 PB7..4, LD1..4 auf U6 PB3..0 (Q1 Game-Over-Relais, Q2 Tilt,
--                   Q3 Muenzsperre, Sound16 = Q10 bei 80/80A, Q5 bei 80B).
--   Spulen 1..9   = SOL1..9: zwei 74LS139 an U6 PA (AB1 = PA1..0, AB2 = PA3..2,
--                   I1G = PA5, I2G = PA6, low aktiv; AB 3/2/1/0 = SOL1/2/3/4 bzw.
--                   5/6/7/8) und SOL9 = PA7 (Spule an bei PA7 = '0').
--                   Je Decoder kann nur EINE Spule gleichzeitig an sein.
--   Schalter      = 10 * (U4 PB-Bit) + (U4 PA-Bit), 0..77, N_SW = 78 mit Luecken.
--                   Test = 07, Replay/Credit = 47 wie in LISY80.
--   Sound 0..15   = U6 PA3..0 negiert bei PA4 = '0' (Z31). Waehrend ein Sound
--                   ansteht, sind die Spulendecoder abgeschaltet (gemeinsame Leitungen).
--   Displays 1..4 = Spieler, 7 Stellen, ueber boot_message (80/80A, BCD).
--                   Display 0 (Status) wird angenommen, aber nicht angezeigt.
--                   80B-Spiel (sys80B, nur mit HAS_DISP_80B): stattdessen Display 0/1 =
--                   Zeile 1/2 der alphanumerischen Anzeige, je 20 Zeichen ASCII (LISY-Typ 5),
--                   ueber boot_message_80B. Monitor dann 62 statt 40 Byte.
-- u6a/u6b haben die Bedeutung der RIOT-Ports (vor den Invertern im Top), damit die
-- Ausgangspfade dieselben bleiben wie im Spiel.

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.fa_control_pkg.all;	-- fa_nibble_array_t, lib_fa_control/

entity fa_sys80 is
	generic(
		-- Version fuer FA-Control (ver_main/sub1/sub2), drei Ziffern wie die Bootanzeige:
		-- PLuS BOARD_ID & SW_SUB ("815"), SMD BOARD_ID & SW_SUB_80 ("805")
		VERSION      : string(1 to 3);
		HAS_DISP_80B : boolean		-- 80B: zwei ASCII-Zeilen statt BCD (variant_pkg)
		);
	port(
		clk_50       : in  std_logic;
		reset        : in  std_logic;	-- high aktiv (Reset-Taste, entprellt)
		-- ESP32-C3 auf X7
		FA_RXD       : in  std_logic;
		FA_TXD       : out std_logic;
		FA_CTRL_REQ  : in  std_logic;
		-- Spiel, nur gelesen
		U4_PB        : in  std_logic_vector(7 downto 0);	-- Schalter-Strobes am Ausgang
		U4_pa_in     : in  std_logic_vector(7 downto 0);	-- Schalter-Returns
		U5_pa_out    : in  std_logic_vector(7 downto 0);
		U5_pb_out    : in  std_logic_vector(7 downto 0);
		U6_pa_out    : in  std_logic_vector(7 downto 0);
		U6_pb_out    : in  std_logic_vector(7 downto 0);
		game_running : in  std_logic;
		not80B       : in  std_logic;
		sys80B       : in  std_logic;
		segments_80B : in  std_logic_vector(1 to 24);	-- J2 des Spiels (Mitleser 80B)
		game_dig2    : in  character;	-- Spielnummer wie auf der Bootanzeige
		game_dig1    : in  character;
		game_dig0    : in  character;
		-- an das Top
		active       : out std_logic;	-- FA-Control hat die Kontrolle
		u6a          : out std_logic_vector(7 downto 0);	-- RIOT-Bedeutung
		u6b          : out std_logic_vector(7 downto 0);
		sw_strobe    : out std_logic_vector(7 downto 0);
		sim_ret      : out std_logic_vector(7 downto 0);	-- simulierte Schalter der gestrobten Spalte
		disp1        : out string(1 to 7);
		disp2        : out string(1 to 7);
		disp3        : out string(1 to 7);
		disp4        : out string(1 to 7);
		txt1         : out string(1 to 20);	-- 80B Zeile 1 (nur HAS_DISP_80B)
		txt2         : out string(1 to 20)
		);
end fa_sys80;

architecture rtl of fa_sys80 is

constant FA_N_LAMPS	: integer := 48;
constant FA_N_SOL		: integer := 9;
constant FA_N_SW		: integer := 78;
constant FA_N_DISP	: integer := 5;
constant FA_DIGITS	: integer := 7;
constant ALPHA_W		: integer := 20;	-- Zeichen je Zeile der 80B-Anzeige

function isel(c : boolean; a, b : integer) return integer is
begin
	if c then
		return a;
	end if;
	return b;
end function;

function byte2char(b : std_logic_vector(7 downto 0)) return character is
begin
	return character'val(to_integer(unsigned(b)));
end function;

function char2byte(c : character) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(character'pos(c), 8));
end function;

signal fa_txt			: fa_byte_array_t(0 to isel(HAS_DISP_80B, 2, 0) * ALPHA_W);
signal fa_active		: std_logic;
signal fa_sw_state	: std_logic_vector(FA_N_SW - 1 downto 0) := (others => '0');
signal fa_lamp_ovr	: std_logic_vector(FA_N_LAMPS - 1 downto 0);
signal fa_sol_ovr		: std_logic_vector(FA_N_SOL - 1 downto 0);
signal fa_disp_ovr	: fa_nibble_array_t(0 to FA_N_DISP * FA_DIGITS - 1);
signal fa_snd_ovr		: std_logic_vector(3 downto 0);
signal fa_snd_en		: std_logic;
signal fa_u6a			: std_logic_vector(7 downto 0);
signal fa_u6b			: std_logic_vector(7 downto 0);
signal fa_sw_strobe	: std_logic_vector(7 downto 0);
signal fa_sim_ret		: std_logic_vector(7 downto 0);
signal fa_disp1		: string(1 to 7);
signal fa_disp2		: string(1 to 7);
signal fa_disp3		: string(1 to 7);
signal fa_disp4		: string(1 to 7);
signal fa_txt1			: string(1 to 20);
signal fa_txt2			: string(1 to 20);

-- Ab hier wie bis 16.11.2026 in top\SYS80.vhd (gen_fa_control)
	signal lamp_cnt   : integer range 0 to 4999 := 0;	-- 100 us je Phase
	signal lamp_phase : integer range 0 to 2 := 0;
	signal lamp_latch : integer range 1 to 12 := 1;
	signal sw_cnt     : integer range 0 to 49999 := 0;	-- 1 ms je Strobe
	signal sw_slot    : integer range 0 to 7 := 0;
	signal game_bcd   : std_logic_vector(11 downto 0);

	-- Monitor (Opcode 0x6E, FA-Control ab 1.25), Byte k der Antwort =
	-- mon_data(8k+7 downto 8k). Laenge folgt aus der Bestueckung
	-- (fa_connect_monitor_len): 1 + 6 + 2*2 + 1 + 10 + (2 + 4*4) = 40.
	--   1      Flags: bit0 Spiel laeuft, bit1 FA-Control aktiv (Attract/Sim: 0)
	--   2..7   Lampen 0..47 (Q1..Q48), LSB von Byte 2 = Lampe 0
	--   8..9   Spulen 1..9 jetzt (bit0 = Spule 1)
	--   10..11 Spulen gesehen seit dem letzten Abholen
	--   12     Sound gesehen seit dem letzten Abholen: bit0..3 = S1/S2/S4/S8, bit4 = S16
	--   13..22 Schalter wie Opcode 0x28 (10 * PB + PA)
	--   23..40 Displays 0..4 (Status 4, Spieler je 7 Stellen + 1 dunkles Fuellnibble),
	--          zwei Ziffern je Byte, linke Ziffer im High-Nibble, >= 0xA = dunkel
	-- 80B-Spiel (sys80B): Displays 0/1 = Zeile 1/2 mit je 20 ASCII-Zeichen, ein Byte je
	-- Stelle, linkes Zeichen zuerst: Bytes 23..42 und 43..62, Laenge 62.
	constant FA_MON_BYTES : integer := isel(HAS_DISP_80B, 22 + 2 * ALPHA_W, 40);
	signal mon_len_s  : integer range 0 to 255;
	signal mon_bcd    : std_logic_vector(8 * 40 + 7 downto 8 * 23);	-- Displays 80/80A
	signal mon_row1   : string(1 to ALPHA_W);	-- 80B, mitgelesen
	signal mon_row2   : string(1 to ALPHA_W);
	type mon_seq_t is array (0 to 35) of integer range -1 to 31;
	-- Ziffer n der Displayfolge -> Index in mon_dig (-1 = Fuellnibble)
	constant MON_SEQ : mon_seq_t := (
		0, 1, 2, 3,                          -- Status
		4, 5, 6, 7, 8, 9, 10, -1,            -- Spieler 1
		11, 12, 13, 14, 15, 16, 17, -1,      -- Spieler 2
		18, 19, 20, 21, 22, 23, 24, -1,      -- Spieler 3
		25, 26, 27, 28, 29, 30, 31, -1);     -- Spieler 4
	signal mon_data   : std_logic_vector(8 * FA_MON_BYTES + 7 downto 0);
	signal mon_rd     : std_logic;
	signal mon_idx    : integer range 0 to 255;
	signal mon_dig    : fa_nibble_array_t(0 to 31) := (others => "1111");
	signal mon_lamps  : std_logic_vector(47 downto 0) := (others => '0');
	signal mon_b_q    : std_logic_vector(7 downto 0) := (others => '0');
	signal mon_b_qq   : std_logic_vector(7 downto 0) := (others => '0');
	signal mon_pa_q   : std_logic_vector(6 downto 0) := (others => '0');	-- U5 PA, doppelt abgetastet
	signal mon_pa_qq  : std_logic_vector(6 downto 0) := (others => '0');
	signal mon_pa_l   : std_logic_vector(6 downto 0) := (others => '0');	-- letzter stabiler Wert
	signal mon_pb_q   : std_logic_vector(6 downto 0) := (others => '0');	-- U5 PB
	signal mon_pb_qq  : std_logic_vector(6 downto 0) := (others => '0');
	signal mon_strb   : std_logic_vector(3 downto 0) := (others => '0');	-- Strobe, fuer den gesammelt wird
	signal mon_va     : std_logic_vector(3 downto 0) := (others => '1');	-- gesammelt: Latch A
	signal mon_vb     : std_logic_vector(3 downto 0) := (others => '1');	-- Latch B
	signal mon_vc     : std_logic_vector(3 downto 0) := (others => '1');	-- Latch C
	signal mon_got    : std_logic_vector(2 downto 0) := (others => '0');	-- A/B/C mit echtem Wert
	signal mon_blk    : std_logic := '0';										-- Austasten gesehen
	signal mon_eff_a  : std_logic_vector(7 downto 0);
	signal mon_sol    : std_logic_vector(8 downto 0);
	signal mon_sol_x  : std_logic_vector(8 downto 0) := (others => '0');
	signal mon_snd    : std_logic_vector(4 downto 0);
	signal mon_snd_x  : std_logic_vector(4 downto 0) := (others => '0');
	signal fa_sim_sw  : std_logic_vector(FA_N_SW - 1 downto 0);

	function dig2bcd(c : character) return std_logic_vector is
	begin
		if c >= '0' and c <= '9' then
			return std_logic_vector(to_unsigned(character'pos(c) - 48, 4));
		end if;
		return "0000";
	end function;

	function nib2char(n : std_logic_vector(3 downto 0)) return character is
	begin
		if unsigned(n) < 10 then
			return character'val(48 + to_integer(unsigned(n)));
		end if;
		return ' ';		-- >= 0xA = dunkel
	end function;

begin

FAC: entity work.fa_control
generic map(
	CLKS_PER_BIT => 434,		-- 50 MHz / 115200 Baud
	HW_NAME      => "GottFA80",
	API_VER      => "0.12",
	N_LAMPS      => FA_N_LAMPS,
	N_SOL        => FA_N_SOL,
	N_SOUNDS     => 16,
	N_SW         => FA_N_SW,
	N_DISP       => FA_N_DISP,
	DISP_TYPE    => 1,		-- BCD7
	DISP_DIGITS  => (4, 7, 7, 7, 7, 0, 0),
	MAX_LAMPS    => FA_N_LAMPS,
	MAX_SOL      => FA_N_SOL,
	MAX_SW       => FA_N_SW,
	MAX_DIGITS   => FA_DIGITS,
	GAME_DIGITS  => 3,		-- FA-Control legt Namen/ROMs unter GottFA80/<nnn> ab
	MON_BYTES    => FA_MON_BYTES,
	HAS_SIM_SW   => true,		-- Opcode 0x6F, Schalter simulieren im Monitor-Modus
	-- 80B: zwei ASCII-Zeilen zu 20 Zeichen statt der BCD-Displays (disp_alt = sys80B)
	ALT_N_DISP      => isel(HAS_DISP_80B, 2, 0),
	ALT_DISP_TYPE   => 5,		-- ASCII
	ALT_DISP_DIGITS => (ALPHA_W, ALPHA_W, 0, 0, 0, 0, 0),
	ALT_MAX_DIGITS  => ALPHA_W
	)
port map(
	clk         => clk_50,
	reset       => reset,
	rxd         => FA_RXD,
	txd         => FA_TXD,
	ctrl_req    => FA_CTRL_REQ,
	ctrl_allow  => '1',		-- wie GottFA1 v7: Freigabe allein ueber ctrl_req
	ctrl_active => fa_active,
	ver_main    => dig2bcd(VERSION(1)),
	ver_sub1    => dig2bcd(VERSION(2)),
	ver_sub2    => dig2bcd(VERSION(3)),
	game_info   => game_bcd,
	sw_state    => fa_sw_state,
	lamp_ovr    => fa_lamp_ovr,
	sol_ovr     => fa_sol_ovr,
	disp_ovr    => fa_disp_ovr,
	snd_ovr     => fa_snd_ovr,
	snd_en      => fa_snd_en,
	mon_data    => mon_data,
	mon_rd      => mon_rd,
	mon_idx     => mon_idx,
	mon_len     => mon_len_s,
	sim_sw      => fa_sim_sw,
	disp_alt    => sys80B,
	disp_txt    => fa_txt
	);

mon_len_s <= 22 + 2 * ALPHA_W when sys80B = '1' else 40;

-- 80B: Zeichen des Hosts, Display 0 = Zeile 1, Display 1 = Zeile 2, linkes Zeichen zuerst
gen_fa_txt: if HAS_DISP_80B generate
	fa_txt_conv: for i in 1 to ALPHA_W generate
		fa_txt1(i) <= byte2char(fa_txt(i - 1));
		fa_txt2(i) <= byte2char(fa_txt(ALPHA_W + i - 1));
	end generate;

	-- Was das Spiel an die 80B-Anzeige schickt, fuer den Monitor
	CAP80B: entity work.disp80B_capture
	port map(
		clk     => clk_50,
		data    => segments_80B(9) & segments_80B(15) & segments_80B(14) & segments_80B(10) &
		           segments_80B(1) & segments_80B(7) & segments_80B(6) & segments_80B(2),
		LD1     => segments_80B(8),
		LD2     => segments_80B(16),
		D_Reset => segments_80B(24),
		row1    => mon_row1,
		row2    => mon_row2
		);
end generate;

-- Ohne HAS_DISP_80B bleiben mon_row1/2 unbenutzt (weder getrieben noch gelesen);
-- fa_txt1/2 treibt dann gen_no_txt unten mit Leerzeichen.

-- Simulierte Schalter (Opcode 0x6F, nur im Monitor-Modus, fa_control loescht sie
-- unter Kontrolle und nach 2 s ohne Byte): Schalter 10*s + r liegt auf Return r,
-- solange das Spiel Strobe s (U4 PB) treibt. Vor dem RIOT geodert - kann also nur
-- schliessen, nie einen echten Schalter verdecken. Nicht waehrend das Spiel ueber
-- Switch-Enable die DIPs liest (U5 PB7 = '1').
SIM_RET_MUX: process(fa_sim_sw, U4_PB, U5_pb_out)
	variable v : std_logic_vector(7 downto 0);
begin
	v := (others => '0');
	if U5_pb_out(7) = '0' then
		for s in 0 to 7 loop
			if U4_PB(s) = '1' then
				for r in 0 to 7 loop
					v(r) := v(r) or fa_sim_sw(10 * s + r);
				end loop;
			end if;
		end loop;
	end if;
	fa_sim_ret <= v;
end process;

-- Spielnummer wie auf der Bootanzeige (Spieler 2)
game_bcd <= dig2bcd(game_dig2) & dig2bcd(game_dig1) & dig2bcd(game_dig0);

-- Displays: LISY-Ziffer 0 ist die LINKE, boot_message zeigt display(1) links.
fa_disp1 <= nib2char(fa_disp_ovr(1*FA_DIGITS+0)) & nib2char(fa_disp_ovr(1*FA_DIGITS+1)) & nib2char(fa_disp_ovr(1*FA_DIGITS+2)) &
            nib2char(fa_disp_ovr(1*FA_DIGITS+3)) & nib2char(fa_disp_ovr(1*FA_DIGITS+4)) & nib2char(fa_disp_ovr(1*FA_DIGITS+5)) &
            nib2char(fa_disp_ovr(1*FA_DIGITS+6));
fa_disp2 <= nib2char(fa_disp_ovr(2*FA_DIGITS+0)) & nib2char(fa_disp_ovr(2*FA_DIGITS+1)) & nib2char(fa_disp_ovr(2*FA_DIGITS+2)) &
            nib2char(fa_disp_ovr(2*FA_DIGITS+3)) & nib2char(fa_disp_ovr(2*FA_DIGITS+4)) & nib2char(fa_disp_ovr(2*FA_DIGITS+5)) &
            nib2char(fa_disp_ovr(2*FA_DIGITS+6));
fa_disp3 <= nib2char(fa_disp_ovr(3*FA_DIGITS+0)) & nib2char(fa_disp_ovr(3*FA_DIGITS+1)) & nib2char(fa_disp_ovr(3*FA_DIGITS+2)) &
            nib2char(fa_disp_ovr(3*FA_DIGITS+3)) & nib2char(fa_disp_ovr(3*FA_DIGITS+4)) & nib2char(fa_disp_ovr(3*FA_DIGITS+5)) &
            nib2char(fa_disp_ovr(3*FA_DIGITS+6));
fa_disp4 <= nib2char(fa_disp_ovr(4*FA_DIGITS+0)) & nib2char(fa_disp_ovr(4*FA_DIGITS+1)) & nib2char(fa_disp_ovr(4*FA_DIGITS+2)) &
            nib2char(fa_disp_ovr(4*FA_DIGITS+3)) & nib2char(fa_disp_ovr(4*FA_DIGITS+4)) & nib2char(fa_disp_ovr(4*FA_DIGITS+5)) &
            nib2char(fa_disp_ovr(4*FA_DIGITS+6));

-- Lampen: je 74175 (FEED 1..12) erst LD mit FEED 0, dann FEED = n, dann wieder
-- FEED 0, LD bleibt stehen - so passt es zu jeder Taktflanke. RIOT-Bedeutung:
-- LD = '1' ist "an" (lisy80_coil_handler_b), invertiert wird beim Ausgang oben.
FA_LAMPS: process(clk_50)
	variable nib : std_logic_vector(3 downto 0);
begin
	if rising_edge(clk_50) then
		nib := (others => '0');
		for i in 0 to 11 loop
			if lamp_latch = i + 1 then
				nib := fa_lamp_ovr(4 * i + 3 downto 4 * i);
			end if;
		end loop;
		if lamp_cnt = 4999 then
			lamp_cnt <= 0;
			if lamp_phase = 2 then
				lamp_phase <= 0;
				if lamp_latch = 12 then
					lamp_latch <= 1;
				else
					lamp_latch <= lamp_latch + 1;
				end if;
			else
				lamp_phase <= lamp_phase + 1;
			end if;
		else
			lamp_cnt <= lamp_cnt + 1;
		end if;
		case lamp_phase is
			when 0 =>      fa_u6b <= "0000" & nib;
			when 1 =>      fa_u6b(7 downto 4) <= std_logic_vector(to_unsigned(lamp_latch, 4));
			when others => fa_u6b(7 downto 4) <= "0000";
		end case;
	end if;
end process;

-- Spulen und Sound auf U6 PA (RIOT-Bedeutung, s. Konstantenblock).
FA_SOL: process(fa_sol_ovr, fa_snd_ovr, fa_snd_en)
	variable a : std_logic_vector(7 downto 0);
begin
	a := "01111111";			-- Decoder aus, Sound aus, AB = 11
	a(7) := not fa_sol_ovr(8);		-- SOL9: an bei PA7 = '0'
	if fa_snd_en = '1' then
		a(3 downto 0) := not fa_snd_ovr;	-- Z31 freigegeben, Sound negiert
		a(4) := '0';
	else
		-- Decoder 1: SOL1..4 (AB1 = 3..0), kleinste Nummer gewinnt
		if    fa_sol_ovr(0) = '1' then a(1 downto 0) := "11"; a(5) := '0';
		elsif fa_sol_ovr(1) = '1' then a(1 downto 0) := "10"; a(5) := '0';
		elsif fa_sol_ovr(2) = '1' then a(1 downto 0) := "01"; a(5) := '0';
		elsif fa_sol_ovr(3) = '1' then a(1 downto 0) := "00"; a(5) := '0';
		end if;
		-- Decoder 2: SOL5..8 (AB2 = 3..0)
		if    fa_sol_ovr(4) = '1' then a(3 downto 2) := "11"; a(6) := '0';
		elsif fa_sol_ovr(5) = '1' then a(3 downto 2) := "10"; a(6) := '0';
		elsif fa_sol_ovr(6) = '1' then a(3 downto 2) := "01"; a(6) := '0';
		elsif fa_sol_ovr(7) = '1' then a(3 downto 2) := "00"; a(6) := '0';
		end if;
	end if;
	fa_u6a <= a;
end process;

-- Schalter-Strobes bei angehaltener CPU: ein Strobe je Millisekunde.
FA_STROBES: process(clk_50)
begin
	if rising_edge(clk_50) then
		if sw_cnt = 49999 then
			sw_cnt <= 0;
			if sw_slot = 7 then
				sw_slot <= 0;
			else
				sw_slot <= sw_slot + 1;
			end if;
		else
			sw_cnt <= sw_cnt + 1;
		end if;
		for s in 0 to 7 loop
			if sw_slot = s then
				fa_sw_strobe(s) <= '1';
			else
				fa_sw_strobe(s) <= '0';
			end if;
		end loop;
	end if;
end process;

-- Schalterzustand, immer gelesen (FA-Control zeigt ihn auch ohne Uebernahme):
-- wer auch strobt, die Returns eines aktiven Strobes werden uebernommen. Nicht,
-- solange das Spiel ueber Switch-Enable die DIPs liest (U5 PB7 = '1').
FA_SWITCHES: process(clk_50)
begin
	if rising_edge(clk_50) then
		if U5_pb_out(7) = '0' or fa_active = '1' then
			for s in 0 to 7 loop
				if U4_PB(s) = '1' then
					for r in 0 to 7 loop
						fa_sw_state(10 * s + r) <= U4_pa_in(r) or fa_sim_ret(r);	-- Monitor zeigt simulierte mit
					end loop;
				end if;
			end loop;
		end if;
	end if;
end process;

------------------------------------------------------------------------------
-- Monitor: der Istzustand, gelesen ohne Uebernahme und ohne etwas anzufassen.
-- Quelle sind die RIOT-Werte (bzw. unter FA-Control fa_u6a/fa_u6b), also dieselben
-- Werte, die LISY80 auswertet. RIOT-Ausgaenge wechseln mit cpu_clk; sie werden
-- zweimal abgetastet und muessen uebereinstimmen.
------------------------------------------------------------------------------
-- Lampen: Schatten der 74175. Solange FEED = n (1..12) steht, wird LD uebernommen.
MON_LAMP_SHADOW: process(clk_50)
	variable feed : integer range 0 to 15;
begin
	if rising_edge(clk_50) then
		if fa_active = '1' then
			mon_b_q <= fa_u6b;
		else
			mon_b_q <= U6_pb_out;
		end if;
		mon_b_qq <= mon_b_q;
		if mon_b_q = mon_b_qq and (game_running = '1' or fa_active = '1') then
			feed := to_integer(unsigned(mon_b_q(7 downto 4)));
			for i in 0 to 11 loop
				if feed = i + 1 then
					mon_lamps(4 * i + 3 downto 4 * i) <= mon_b_q(3 downto 0);
				end if;
			end loop;
		end if;
	end if;
end process;

-- Spulen und Sound aus U6 PA wie lisy80_coil_handler_a.
mon_eff_a <= fa_u6a when fa_active = '1' else U6_pa_out;

MON_COILS: process(mon_eff_a, game_running, fa_active)
	variable s : std_logic_vector(8 downto 0);
begin
	s := (others => '0');
	if game_running = '1' or fa_active = '1' then
		if mon_eff_a(5) = '0' then		-- I1G: Decoder 1 (SOL1..4)
			case mon_eff_a(1 downto 0) is
				when "11"   => s(0) := '1';
				when "10"   => s(1) := '1';
				when "01"   => s(2) := '1';
				when others => s(3) := '1';
			end case;
		end if;
		if mon_eff_a(6) = '0' then		-- I2G: Decoder 2 (SOL5..8)
			case mon_eff_a(3 downto 2) is
				when "11"   => s(4) := '1';
				when "10"   => s(5) := '1';
				when "01"   => s(6) := '1';
				when others => s(7) := '1';
			end case;
		end if;
		s(8) := not mon_eff_a(7);		-- SOL9 hat einen Inverter dahinter
	end if;
	mon_sol <= s;
end process;

-- Sound S1..S8 = PA3..0 negiert bei PA4 = '0'; S16 = Lampe Q10 (80/80A) bzw. Q5 (80B).
mon_snd(3 downto 0) <= not mon_eff_a(3 downto 0)
                       when mon_eff_a(4) = '0' and (game_running = '1' or fa_active = '1')
                       else "0000";
mon_snd(4) <= mon_lamps(9) when not80B = '1' else mon_lamps(4);

-- Spulen und Sound dauern Millisekunden, der Host fragt alle 500 ms: jeden Puls
-- halten, bis sein Byte gesendet ist. Setzen gewinnt gegen Loeschen.
MON_PULSES: process(clk_50)
begin
	if rising_edge(clk_50) then
		if mon_rd = '1' and mon_idx = 10 then
			mon_sol_x(7 downto 0) <= mon_sol(7 downto 0);
		else
			mon_sol_x(7 downto 0) <= mon_sol_x(7 downto 0) or mon_sol(7 downto 0);
		end if;
		if mon_rd = '1' and mon_idx = 11 then
			mon_sol_x(8) <= mon_sol(8);
		else
			mon_sol_x(8) <= mon_sol_x(8) or mon_sol(8);
		end if;
		if mon_rd = '1' and mon_idx = 12 then
			mon_snd_x <= mon_snd;
		else
			mon_snd_x <= mon_snd_x or mon_snd;
		end if;
	end if;
end process;

-- Displays (nur 80/80A, BCD), ausgewertet wie lisy80_display_handler_bcd (LISY80):
-- Ein Port-A-Schreibzugriff setzt den Digit-Strobe s = U5 PA3..0 und laedt mit der
-- steigenden Flanke von PA4/5/6 die 74175-Latches A/B/C mit U5 PB3..0 (= Din_Seg).
-- Das Spiel tastet je Digit aus, indem es alle drei Latches GLEICHZEITIG mit 15
-- laedt - diesen Schritt nicht als Ziffer nehmen. Frueher wurde Din_Seg bei jedem
-- Takt kopiert; der Monitor zeigte dann meist "dunkel" und nur zufaellig eine Ziffer.
-- Gesammelt wird je Strobe, geschrieben beim Wechsel auf den naechsten Strobe:
-- echter Wert vor "nur ausgetastet" (= 15) vor "nichts gesehen" (alter Wert bleibt).
-- PB4/5/6 = 0 ist die direkt geschaltete Mittel-/Eins-Leitung ("h-line"), wie LISY
-- als Ziffer 1. Zuordnung wie boot_message.vhd:
--   A: s 15, 5..0 = Spieler 1 links..rechts,  s 12..6 = Spieler 2 links..rechts
--   B: dieselben Strobes fuer Spieler 3 bzw. 4
--   C: s 15..12 = Status links..rechts (Reihenfolge an der Anlage ungeprueft)
-- Unter FA-Control bleiben die zuletzt gelesenen Ziffern stehen.
MON_DISP: process(clk_50)
	variable s    : integer range 0 to 15;
	variable rise : std_logic_vector(2 downto 0);
	variable g    : std_logic_vector(2 downto 0);
	variable b    : std_logic;
	variable va, vb, vc : std_logic_vector(3 downto 0);
	variable da, db, dc : std_logic_vector(3 downto 0);
begin
	if rising_edge(clk_50) then
		mon_pa_q  <= U5_pa_out(6 downto 0);
		mon_pa_qq <= mon_pa_q;
		mon_pb_q  <= U5_pb_out(6 downto 0);
		mon_pb_qq <= mon_pb_q;
		if mon_pa_q = mon_pa_qq and mon_pb_q = mon_pb_qq and mon_pa_q /= mon_pa_l
		   and game_running = '1' and fa_active = '0' and not80B = '1' then
			mon_pa_l <= mon_pa_q;
			g := mon_got; b := mon_blk; va := mon_va; vb := mon_vb; vc := mon_vc;

			-- Strobe gewechselt: Gesammeltes dem vorigen Strobe zuschreiben
			if mon_pa_q(3 downto 0) /= mon_strb then
				if g(0) = '1' then da := va; else da := "1111"; end if;
				if g(1) = '1' then db := vb; else db := "1111"; end if;
				if g(2) = '1' then dc := vc; else dc := "1111"; end if;
				s := to_integer(unsigned(mon_strb));
				if g(0) = '1' or b = '1' then
					case s is
						when 0 to 5  => mon_dig(4 + 6 - s)   <= da;	-- Spieler 1, Stelle 1..6
						when 15      => mon_dig(4)           <= da;	-- Spieler 1, Stelle 0
						when 6 to 12 => mon_dig(11 + 12 - s) <= da;	-- Spieler 2
						when others  => null;
					end case;
				end if;
				if g(1) = '1' or b = '1' then
					case s is
						when 0 to 5  => mon_dig(18 + 6 - s)  <= db;	-- Spieler 3
						when 15      => mon_dig(18)          <= db;
						when 6 to 12 => mon_dig(25 + 12 - s) <= db;	-- Spieler 4
						when others  => null;
					end case;
				end if;
				if g(2) = '1' or b = '1' then
					case s is
						when 12 to 15 => mon_dig(15 - s) <= dc;		-- Status
						when others   => null;
					end case;
				end if;
				g := "000"; b := '0';
				mon_strb <= mon_pa_q(3 downto 0);
			end if;

			-- Latch-Flanken dieses Schreibzugriffs
			rise := mon_pa_q(6 downto 4) and not mon_pa_l(6 downto 4);
			if rise = "111" and mon_pb_q(3 downto 0) = "1111" then
				b := '1';									-- Austasten
			else
				if rise(0) = '1' then va := mon_pb_q(3 downto 0); g(0) := '1'; end if;
				if rise(1) = '1' then vb := mon_pb_q(3 downto 0); g(1) := '1'; end if;
				if rise(2) = '1' then vc := mon_pb_q(3 downto 0); g(2) := '1'; end if;
			end if;
			if mon_pb_q(4) = '0' then va := "0001"; g(0) := '1'; end if;
			if mon_pb_q(5) = '0' then vb := "0001"; g(1) := '1'; end if;
			if mon_pb_q(6) = '0' then vc := "0001"; g(2) := '1'; end if;

			mon_got <= g; mon_blk <= b; mon_va <= va; mon_vb <= vb; mon_vc <= vc;
		end if;
	end if;
end process;

mon_data(7 downto 0)     <= x"00";		-- Byte 0 ist die Laenge, sendet fa_control
-- bit3: Schalter simulierbar (HAS_SIM_SW, Freigabe = ctrl_allow, hier immer '1')
mon_data(15 downto 8)    <= "0000" & '1' & '0' & fa_active & game_running;
mon_data(63 downto 16)   <= mon_lamps;
mon_data(79 downto 64)   <= "0000000" & mon_sol;
mon_data(95 downto 80)   <= "0000000" & mon_sol_x;
mon_data(103 downto 96)  <= "000" & mon_snd_x;
mon_data(183 downto 104) <= "00" & fa_sw_state;

mon_disp_pack: for n in 0 to 35 generate
	pad: if MON_SEQ(n) < 0 generate
		mon_bcd(8 * (23 + n / 2) + 7 - 4 * (n mod 2) downto 8 * (23 + n / 2) + 4 - 4 * (n mod 2)) <= "1111";
	end generate;
	dig: if MON_SEQ(n) >= 0 generate
		mon_bcd(8 * (23 + n / 2) + 7 - 4 * (n mod 2) downto 8 * (23 + n / 2) + 4 - 4 * (n mod 2)) <= mon_dig(MON_SEQ(n));
	end generate;
end generate;

-- Bytes 23..: BCD-Displays (80/80A) oder bei sys80B die beiden Zeilen als ASCII
-- (FA_MON_BYTES = 62). Ohne HAS_DISP_80B wie vorher.
gen_mon_bcd: if not HAS_DISP_80B generate
	mon_data(8 * 40 + 7 downto 8 * 23) <= mon_bcd;
end generate;
gen_mon_80b: if HAS_DISP_80B generate
	mon_disp_bcd: for k in 23 to 40 generate
		mon_data(8 * k + 7 downto 8 * k) <= char2byte(mon_row1(k - 22)) when sys80B = '1'
		                                    else mon_bcd(8 * k + 7 downto 8 * k);
	end generate;
	mon_disp_alpha1: for k in 41 to 42 generate
		mon_data(8 * k + 7 downto 8 * k) <= char2byte(mon_row1(k - 22));
	end generate;
	mon_disp_alpha2: for k in 43 to 22 + 2 * ALPHA_W generate
		mon_data(8 * k + 7 downto 8 * k) <= char2byte(mon_row2(k - 42));
	end generate;
end generate;

-- Ohne HAS_DISP_80B liest das Top txt1/2 nicht; Ports trotzdem treiben.
gen_no_txt: if not HAS_DISP_80B generate
	fa_txt1 <= (others => ' ');
	fa_txt2 <= (others => ' ');
end generate;

active    <= fa_active;
u6a       <= fa_u6a;
u6b       <= fa_u6b;
sw_strobe <= fa_sw_strobe;
sim_ret   <= fa_sim_ret;
disp1     <= fa_disp1;
disp2     <= fa_disp2;
disp3     <= fa_disp3;
disp4     <= fa_disp4;
txt1      <= fa_txt1;
txt2      <= fa_txt2;

end rtl;
