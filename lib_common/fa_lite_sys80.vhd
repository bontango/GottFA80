-- fa_lite_sys80.vhd - FA-Control "lite" fuer GottFA80 (Gottlieb System 80/80A/80B)
-- (c)2026 bontango, GPL v3 wie der Rest des Projekts.
--
-- 19.11.2026  Gegenstueck zu fa_sys80.vhd fuer FA-Control ueber Virtual JTAG
--             (lib_common\fa_jtag_regs.vhd). KEIN LISY-Parser mehr im FPGA: der ESP32
--             (FA_Control main\lisy_emul.c) spricht LISY und bedient dafuer die Register
--             unten. Konzept und Zahlen: ESP32-C3_EVALUIERUNG.md, Abschnitt 15.11.
--
-- Was im FPGA bleibt, ist nur das, was mit 50 MHz am Spiel mitlesen oder treiben muss:
--   Monitor  : Lampen-Schatten der 74175, Spulen/Sound aus U6 PA, "gesehen"-Bits,
--              Schalter, BCD-Displays aus U5 (MON_DISP), 80B-Zeilen (disp80B_capture_ram).
--              Unveraendert aus fa_sys80.vhd uebernommen.
--   Steuerung: Schalter-Strobes (1 ms je Strobe), u6a/u6b ROH (RIOT-Bedeutung) - die
--              Lampen-Latch-Folge, die 74139-Codes und die Sound-Bits rechnet der ESP -,
--              ein Spulenpuls mit ms-Zaehler, 28 BCD-Ziffern fuer boot_message und der
--              J2-Bus der 80B-Anzeige roh (der Rockwell 10941 haelt seinen Text selbst).
--   Schalter simulieren: 4 Slots (Strobe, Return) statt 78 Bits.
-- Nummerierung, Bitbedeutungen und Monitor-Layout wie fa_sys80.vhd (dort im Kopf).
--
-- REGISTER (Adresse 7 Bit)
--   Lesen
--     0x00        Projektcode 0x01 = GottFA80
--     0x01..0x3E  Monitorbytes 1..62, Layout wie fa_sys80 (Opcode 110). Bei sys80B kommen
--                 die Bytes 23..62 aus dem 80B-Mitleser, sonst 23..40 BCD, 41..62 = 0.
--     0x40..0x42  Version, drei ASCII-Ziffern (VERSION)
--     0x43..0x45  Spielnummer, drei ASCII-Ziffern
--     0x46        Status: bit0 game_running, bit1 aktiv, bit2 sys80B, bit3 not80B,
--                 bit4 Puls laeuft
--     0x47        Faehigkeiten: bit0 80B-Anzeige (HAS_DISP_80B)
--   Schreiben (wirken erst unter Uebernahme, ausser den Sim-Slots)
--     0x40        u6a Grundwert (RIOT U6 PA), Ruhe = 0xFF (Decoder aus, Sound aus, SOL9 aus)
--     0x41        u6b (RIOT U6 PB, FEED/LD der Lampen-Latches)
--     0x43        J2-Daten D0..D7; loest LD1/LD2 nach 0x44 aus (2 us Vorlauf, 10 us Puls)
--     0x44        J2-Steuerung: bit0 LD1 ausloesen, bit1 LD2 ausloesen, bit2 D_Reset-Pegel
--                 (Leitung, 0 = Reset aktiv)
--     0x46        u6a-Wert waehrend des Pulses
--     0x47        Pulsdauer in ms, startet den Puls (0 = Puls abbrechen)
--     0x48..0x4B  Sim-Slot 0..3: bit7 gueltig, bit5..3 Strobe (U4 PB), bit2..0 Return
--     0x50..0x5D  BCD Spieler 1..4: Byte k = Ziffer 2k (High-Nibble) und 2k+1 (Low),
--                 Ziffer 7*(Spieler-1) + i, i = 0 links, >= 0xA = dunkel
-- Uebernahme: Steuerbit von fa_jtag_regs. Faellt es (ESP, Totmann), gehen alle
-- Schreibregister auf Ruhe. Sim-Slots gelten nur ohne Uebernahme und solange alive.
-- VHDL-93.

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.fa_control_pkg.all;	-- fa_nibble_array_t (lib_fa_control/fa_control_pkg.vhd)

entity fa_lite_sys80 is
	generic(
		VERSION      : string(1 to 3);
		HAS_DISP_80B : boolean
		);
	port(
		clk_50       : in  std_logic;
		reset        : in  std_logic;	-- high aktiv
		-- fa_jtag_regs
		tck          : in  std_logic;
		rd_addr      : in  std_logic_vector(6 downto 0);	-- TCK-Bereich
		rd_data      : out std_logic_vector(7 downto 0);
		rd_stb       : in  std_logic;
		rd_addr_s    : in  std_logic_vector(6 downto 0);
		wr_stb       : in  std_logic;
		wr_addr      : in  std_logic_vector(6 downto 0);
		wr_data      : in  std_logic_vector(7 downto 0);
		ctrl         : in  std_logic;
		alive        : in  std_logic;
		-- Spiel, nur gelesen
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
		-- an das Top
		active       : out std_logic;
		u6a          : out std_logic_vector(7 downto 0);
		u6b          : out std_logic_vector(7 downto 0);
		sw_strobe    : out std_logic_vector(7 downto 0);
		sim_ret      : out std_logic_vector(7 downto 0);
		disp1        : out string(1 to 7);
		disp2        : out string(1 to 7);
		disp3        : out string(1 to 7);
		disp4        : out string(1 to 7);
		j2_en        : out std_logic;	-- '1' = J2 aus j2_seg (80B unter Uebernahme)
		j2_seg       : out std_logic_vector(1 to 24)
		);
end fa_lite_sys80;

architecture rtl of fa_lite_sys80 is

constant FA_N_SW		: integer := 78;
constant ALPHA_W		: integer := 20;
constant MON_N			: integer := 62;	-- groesste Monitorlaenge (80B)
constant US_CYC		: integer := 50;	-- Takte je us

function char2byte(c : character) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(character'pos(c), 8));
end function;

function nib2char(n : std_logic_vector(3 downto 0)) return character is
begin
	if unsigned(n) < 10 then
		return character'val(48 + to_integer(unsigned(n)));
	end if;
	return ' ';		-- >= 0xA = dunkel
end function;

signal fa_active		: std_logic;
signal fa_sw_state	: std_logic_vector(FA_N_SW - 1 downto 0) := (others => '0');
signal fa_sim_ret		: std_logic_vector(7 downto 0);
signal fa_sw_strobe	: std_logic_vector(7 downto 0);
signal sw_cnt			: integer range 0 to 49999 := 0;
signal sw_slot			: integer range 0 to 7 := 0;

-- Schreibregister (Systemtakt)
signal u6a_base		: std_logic_vector(7 downto 0) := x"FF";
signal u6b_r			: std_logic_vector(7 downto 0) := (others => '0');
signal pls_val			: std_logic_vector(7 downto 0) := x"FF";
signal pls_run			: std_logic := '0';
signal pls_left		: integer range 0 to 255 := 0;
signal ms_div			: integer range 0 to 49999 := 0;
type slot_t is array (0 to 3) of std_logic_vector(7 downto 0);
signal sim_slot		: slot_t := (others => (others => '0'));
signal bcd				: fa_nibble_array_t(0 to 27) := (others => "1111");
signal j2_data			: std_logic_vector(7 downto 0) := (others => '0');
signal j2_sel			: std_logic_vector(1 downto 0) := "00";
signal j2_rst			: std_logic := '1';
signal j2_cnt			: integer range 0 to 13 * US_CYC := 13 * US_CYC;	-- Ende = ruhig
signal j2_ld1, j2_ld2	: std_logic := '0';
signal fa_u6a			: std_logic_vector(7 downto 0);

-- Monitor (aus fa_sys80.vhd)
signal mon_data   : std_logic_vector(8 * MON_N + 7 downto 0);
signal mon_bcd    : std_logic_vector(8 * 40 + 7 downto 8 * 23);
type mon_seq_t is array (0 to 35) of integer range -1 to 31;
constant MON_SEQ : mon_seq_t := (
	0, 1, 2, 3,
	4, 5, 6, 7, 8, 9, 10, -1,
	11, 12, 13, 14, 15, 16, 17, -1,
	18, 19, 20, 21, 22, 23, 24, -1,
	25, 26, 27, 28, 29, 30, 31, -1);
signal mon_dig    : fa_nibble_array_t(0 to 31) := (others => "1111");
signal mon_lamps  : std_logic_vector(47 downto 0) := (others => '0');
signal mon_b_q    : std_logic_vector(7 downto 0) := (others => '0');
signal mon_b_qq   : std_logic_vector(7 downto 0) := (others => '0');
signal mon_pa_q   : std_logic_vector(6 downto 0) := (others => '0');
signal mon_pa_qq  : std_logic_vector(6 downto 0) := (others => '0');
signal mon_pa_l   : std_logic_vector(6 downto 0) := (others => '0');
signal mon_pb_q   : std_logic_vector(6 downto 0) := (others => '0');
signal mon_pb_qq  : std_logic_vector(6 downto 0) := (others => '0');
signal mon_strb   : std_logic_vector(3 downto 0) := (others => '0');
signal mon_va     : std_logic_vector(3 downto 0) := (others => '1');
signal mon_vb     : std_logic_vector(3 downto 0) := (others => '1');
signal mon_vc     : std_logic_vector(3 downto 0) := (others => '1');
signal mon_got    : std_logic_vector(2 downto 0) := (others => '0');
signal mon_blk    : std_logic := '0';
signal mon_eff_a  : std_logic_vector(7 downto 0);
signal mon_sol    : std_logic_vector(8 downto 0);
signal mon_sol_x  : std_logic_vector(8 downto 0) := (others => '0');
signal mon_snd    : std_logic_vector(4 downto 0);
signal mon_snd_x  : std_logic_vector(4 downto 0) := (others => '0');
signal row_q      : std_logic_vector(7 downto 0);	-- 80B-Zeichen (TCK)
signal row_addr   : integer range 0 to 39;
signal status     : std_logic_vector(7 downto 0);
type byte_arr_t is array (0 to MON_N) of std_logic_vector(7 downto 0);
signal mon_arr    : byte_arr_t;

begin

fa_active <= ctrl;

------------------------------------------------------------------------------
-- Schreibregister
------------------------------------------------------------------------------
WR_REGS: process(clk_50)
	variable a : integer range 0 to 127;
begin
	if rising_edge(clk_50) then
		a := to_integer(unsigned(wr_addr));

		-- ms-Takt fuer den Spulenpuls
		if ms_div = 49999 then
			ms_div <= 0;
			if pls_run = '1' then
				if pls_left <= 1 then
					pls_run <= '0';
				else
					pls_left <= pls_left - 1;
				end if;
			end if;
		else
			ms_div <= ms_div + 1;
		end if;

		-- J2-Ladepuls: 2 us Daten stabil, 10 us LD high, 1 us Nachlauf
		if j2_cnt < 13 * US_CYC then
			j2_cnt <= j2_cnt + 1;
		end if;
		if j2_cnt >= 2 * US_CYC and j2_cnt < 12 * US_CYC then
			j2_ld1 <= j2_sel(0);
			j2_ld2 <= j2_sel(1);
		else
			j2_ld1 <= '0';
			j2_ld2 <= '0';
		end if;

		if wr_stb = '1' then
			if a = 16#40# then u6a_base <= wr_data; end if;
			if a = 16#41# then u6b_r    <= wr_data; end if;
			if a = 16#43# then j2_data  <= wr_data; j2_cnt <= 0; end if;
			if a = 16#44# then j2_sel   <= wr_data(1 downto 0); j2_rst <= wr_data(2); end if;
			if a = 16#46# then pls_val  <= wr_data; end if;
			if a = 16#47# then
				ms_div   <= 0;
				pls_left <= to_integer(unsigned(wr_data));
				if wr_data = x"00" then pls_run <= '0'; else pls_run <= '1'; end if;
			end if;
			for k in 0 to 3 loop
				if a = 16#48# + k then sim_slot(k) <= wr_data; end if;
			end loop;
			for k in 0 to 13 loop
				if a = 16#50# + k then
					bcd(2 * k)     <= wr_data(7 downto 4);
					bcd(2 * k + 1) <= wr_data(3 downto 0);
				end if;
			end loop;
		end if;

		-- Sim-Slots nur ohne Uebernahme und solange der ESP lebt (wie sim_r in fa_control)
		if fa_active = '1' or alive = '0' then
			sim_slot <= (others => (others => '0'));
		end if;

		-- Uebernahme vorbei (oder Reset): alles in Ruhe
		if fa_active = '0' or reset = '1' then
			u6a_base <= x"FF";
			u6b_r    <= (others => '0');
			pls_run  <= '0';
			bcd      <= (others => "1111");
			j2_data  <= (others => '0');
			j2_sel   <= "00";
			j2_rst   <= '1';
			j2_cnt   <= 13 * US_CYC;
		end if;
	end if;
end process;

fa_u6a <= pls_val when pls_run = '1' else u6a_base;

-- 80B unter Uebernahme: J2 wie BM80B_J2 im Top (D0..D3 = 2,6,7,1  D4..D7 = 10,14,15,9,
-- LD1 = 8, LD2 = 16, Reset = 24)
j2_en <= '1' when HAS_DISP_80B and fa_active = '1' and sys80B = '1' else '0';
J2_MAP: process(j2_data, j2_ld1, j2_ld2, j2_rst)
begin
	j2_seg     <= (others => '0');
	j2_seg(2)  <= j2_data(0);
	j2_seg(6)  <= j2_data(1);
	j2_seg(7)  <= j2_data(2);
	j2_seg(1)  <= j2_data(3);
	j2_seg(10) <= j2_data(4);
	j2_seg(14) <= j2_data(5);
	j2_seg(15) <= j2_data(6);
	j2_seg(9)  <= j2_data(7);
	j2_seg(8)  <= j2_ld1;
	j2_seg(16) <= j2_ld2;
	j2_seg(24) <= j2_rst;
end process;

-- BCD-Ziffern fuer boot_message (display(1) links)
disp1 <= nib2char(bcd(0))  & nib2char(bcd(1))  & nib2char(bcd(2))  & nib2char(bcd(3))  & nib2char(bcd(4))  & nib2char(bcd(5))  & nib2char(bcd(6));
disp2 <= nib2char(bcd(7))  & nib2char(bcd(8))  & nib2char(bcd(9))  & nib2char(bcd(10)) & nib2char(bcd(11)) & nib2char(bcd(12)) & nib2char(bcd(13));
disp3 <= nib2char(bcd(14)) & nib2char(bcd(15)) & nib2char(bcd(16)) & nib2char(bcd(17)) & nib2char(bcd(18)) & nib2char(bcd(19)) & nib2char(bcd(20));
disp4 <= nib2char(bcd(21)) & nib2char(bcd(22)) & nib2char(bcd(23)) & nib2char(bcd(24)) & nib2char(bcd(25)) & nib2char(bcd(26)) & nib2char(bcd(27));

------------------------------------------------------------------------------
-- Schalter (aus fa_sys80.vhd)
------------------------------------------------------------------------------
-- Simulierte Schalter: Slot (Strobe s, Return r) liegt auf Return r, solange das Spiel
-- Strobe s treibt. Vor dem RIOT geodert, nicht waehrend die DIPs gelesen werden.
SIM_RET_MUX: process(sim_slot, U4_PB, U5_pb_out)
	variable v : std_logic_vector(7 downto 0);
	variable s : integer range 0 to 7;
	variable r : integer range 0 to 7;
begin
	v := (others => '0');
	if U5_pb_out(7) = '0' then
		for k in 0 to 3 loop
			s := to_integer(unsigned(sim_slot(k)(5 downto 3)));
			r := to_integer(unsigned(sim_slot(k)(2 downto 0)));
			if sim_slot(k)(7) = '1' and U4_PB(s) = '1' then
				v(r) := '1';
			end if;
		end loop;
	end if;
	fa_sim_ret <= v;
end process;

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

FA_SWITCHES: process(clk_50)
begin
	if rising_edge(clk_50) then
		if U5_pb_out(7) = '0' or fa_active = '1' then
			for s in 0 to 7 loop
				if U4_PB(s) = '1' then
					for r in 0 to 7 loop
						fa_sw_state(10 * s + r) <= U4_pa_in(r) or fa_sim_ret(r);
					end loop;
				end if;
			end loop;
		end if;
	end if;
end process;

------------------------------------------------------------------------------
-- Monitor (aus fa_sys80.vhd, unveraendert bis auf die Loeschquittung)
------------------------------------------------------------------------------
MON_LAMP_SHADOW: process(clk_50)
	variable feed : integer range 0 to 15;
begin
	if rising_edge(clk_50) then
		if fa_active = '1' then
			mon_b_q <= u6b_r;
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

mon_eff_a <= fa_u6a when fa_active = '1' else U6_pa_out;

MON_COILS: process(mon_eff_a, game_running, fa_active)
	variable s : std_logic_vector(8 downto 0);
begin
	s := (others => '0');
	if game_running = '1' or fa_active = '1' then
		if mon_eff_a(5) = '0' then
			case mon_eff_a(1 downto 0) is
				when "11"   => s(0) := '1';
				when "10"   => s(1) := '1';
				when "01"   => s(2) := '1';
				when others => s(3) := '1';
			end case;
		end if;
		if mon_eff_a(6) = '0' then
			case mon_eff_a(3 downto 2) is
				when "11"   => s(4) := '1';
				when "10"   => s(5) := '1';
				when "01"   => s(6) := '1';
				when others => s(7) := '1';
			end case;
		end if;
		s(8) := not mon_eff_a(7);
	end if;
	mon_sol <= s;
end process;

mon_snd(3 downto 0) <= not mon_eff_a(3 downto 0)
                       when mon_eff_a(4) = '0' and (game_running = '1' or fa_active = '1')
                       else "0000";
mon_snd(4) <= mon_lamps(9) when not80B = '1' else mon_lamps(4);

-- Spulen und Sound halten, bis ihr Byte abgeholt ist (rd_stb = Capture-DR dieser Adresse)
MON_PULSES: process(clk_50)
	variable a : integer range 0 to 127;
begin
	if rising_edge(clk_50) then
		a := to_integer(unsigned(rd_addr_s));
		if rd_stb = '1' and a = 10 then
			mon_sol_x(7 downto 0) <= mon_sol(7 downto 0);
		else
			mon_sol_x(7 downto 0) <= mon_sol_x(7 downto 0) or mon_sol(7 downto 0);
		end if;
		if rd_stb = '1' and a = 11 then
			mon_sol_x(8) <= mon_sol(8);
		else
			mon_sol_x(8) <= mon_sol_x(8) or mon_sol(8);
		end if;
		if rd_stb = '1' and a = 12 then
			mon_snd_x <= mon_snd;
		else
			mon_snd_x <= mon_snd_x or mon_snd;
		end if;
	end if;
end process;

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
			if mon_pa_q(3 downto 0) /= mon_strb then
				if g(0) = '1' then da := va; else da := "1111"; end if;
				if g(1) = '1' then db := vb; else db := "1111"; end if;
				if g(2) = '1' then dc := vc; else dc := "1111"; end if;
				s := to_integer(unsigned(mon_strb));
				if g(0) = '1' or b = '1' then
					case s is
						when 0 to 5  => mon_dig(4 + 6 - s)   <= da;
						when 15      => mon_dig(4)           <= da;
						when 6 to 12 => mon_dig(11 + 12 - s) <= da;
						when others  => null;
					end case;
				end if;
				if g(1) = '1' or b = '1' then
					case s is
						when 0 to 5  => mon_dig(18 + 6 - s)  <= db;
						when 15      => mon_dig(18)          <= db;
						when 6 to 12 => mon_dig(25 + 12 - s) <= db;
						when others  => null;
					end case;
				end if;
				if g(2) = '1' or b = '1' then
					case s is
						when 12 to 15 => mon_dig(15 - s) <= dc;
						when others   => null;
					end case;
				end if;
				g := "000"; b := '0';
				mon_strb <= mon_pa_q(3 downto 0);
			end if;
			rise := mon_pa_q(6 downto 4) and not mon_pa_l(6 downto 4);
			if rise = "111" and mon_pb_q(3 downto 0) = "1111" then
				b := '1';
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

mon_disp_pack: for n in 0 to 35 generate
	pad: if MON_SEQ(n) < 0 generate
		mon_bcd(8 * (23 + n / 2) + 7 - 4 * (n mod 2) downto 8 * (23 + n / 2) + 4 - 4 * (n mod 2)) <= "1111";
	end generate;
	dig: if MON_SEQ(n) >= 0 generate
		mon_bcd(8 * (23 + n / 2) + 7 - 4 * (n mod 2) downto 8 * (23 + n / 2) + 4 - 4 * (n mod 2)) <= mon_dig(MON_SEQ(n));
	end generate;
end generate;

-- Monitorbytes 0..40 (0 = Projektcode); 41..62 kommen nur bei sys80B aus row_q
mon_data(7 downto 0)     <= x"01";
mon_data(15 downto 8)    <= "0000" & '1' & '0' & fa_active & game_running;	-- bit3: simulierbar
mon_data(63 downto 16)   <= mon_lamps;
mon_data(79 downto 64)   <= "0000000" & mon_sol;
mon_data(95 downto 80)   <= "0000000" & mon_sol_x;
mon_data(103 downto 96)  <= "000" & mon_snd_x;
mon_data(183 downto 104) <= "00" & fa_sw_state;
mon_data(8 * 40 + 7 downto 8 * 23) <= mon_bcd;
mon_data(8 * MON_N + 7 downto 8 * 41) <= (others => '0');
mon_split: for k in 0 to MON_N generate
	mon_arr(k) <= mon_data(8 * k + 7 downto 8 * k);
end generate;

-- 80B-Zeilen: Bytes 23..42 = Zeile 1, 43..62 = Zeile 2 -> Adresse 0..39 im Mitleser
gen_cap: if HAS_DISP_80B generate
	row_addr <= to_integer(unsigned(rd_addr)) - 23
	            when unsigned(rd_addr) >= 23 and unsigned(rd_addr) <= 62 else 0;
	CAP80B: entity work.disp80B_capture_ram
	port map(
		clk     => clk_50,
		data    => segments_80B(9) & segments_80B(15) & segments_80B(14) & segments_80B(10) &
		           segments_80B(1) & segments_80B(7) & segments_80B(6) & segments_80B(2),
		LD1     => segments_80B(8),
		LD2     => segments_80B(16),
		D_Reset => segments_80B(24),
		rclk    => tck,
		raddr   => row_addr,
		q       => row_q
		);
end generate;
gen_no_cap: if not HAS_DISP_80B generate
	row_q <= x"20";
end generate;

status <= "000" & pls_run & not80B & sys80B & fa_active & game_running;

-- Lesemux (TCK tastet ab)
RD_MUX: process(rd_addr, mon_arr, row_q, sys80B, status, game_dig2, game_dig1, game_dig0)
	variable a : integer range 0 to 127;
begin
	a := to_integer(unsigned(rd_addr));
	rd_data <= x"00";
	if a <= MON_N then
		if sys80B = '1' and HAS_DISP_80B and a >= 23 then
			rd_data <= row_q;
		else
			rd_data <= mon_arr(a);
		end if;
	else
		case a is
			when 16#40# => rd_data <= char2byte(VERSION(1));
			when 16#41# => rd_data <= char2byte(VERSION(2));
			when 16#42# => rd_data <= char2byte(VERSION(3));
			when 16#43# => rd_data <= char2byte(game_dig2);
			when 16#44# => rd_data <= char2byte(game_dig1);
			when 16#45# => rd_data <= char2byte(game_dig0);
			when 16#46# => rd_data <= status;
			when 16#47# =>
				if HAS_DISP_80B then rd_data <= x"01"; else rd_data <= x"00"; end if;
			when others => null;
		end case;
	end if;
end process;

active    <= fa_active;
u6a       <= fa_u6a;
u6b       <= u6b_r;
sw_strobe <= fa_sw_strobe;
sim_ret   <= fa_sim_ret;

end rtl;
