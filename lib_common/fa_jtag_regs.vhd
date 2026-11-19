-- fa_jtag_regs.vhd - FA-Control "lite": Registerbank ueber Virtual JTAG
-- (c)2026 bontango, GPL v3 wie der Rest des Projekts.
--
-- 19.11.2026  Ersetzt fuer die JTAG-Piggyback-Boards die Kette
--             fa_vjtag_link (vJTAG -> FIFO -> UART) -> fa_control (UART -> LISY-Parser).
--             Das LISY-Protokoll spricht jetzt der ESP32 selbst (FA_Control lisy_emul.c);
--             das FPGA liefert nur noch Register zum Lesen und Schreiben.
--             Konzept und Zahlen: N:\Projekte\misc\USB_BLASTER_DIY\ESP32-C3_EVALUIERUNG.md, 15.11.
--
-- Projektunabhaengig. Was hinter den Adressen steckt, legt der Kleber des Projekts fest
-- (GottFA80: lib_common\fa_lite_sys80.vhd).
--
-- VIR (sld_ir_width = 2; der Hub meldet n = 4, s. EVALUIERUNG 15.3):
--   "00"  BYPASS     1 Bit
--   "01"  REG       16 Bit  TDI: [7:0] Schreibdaten, [14:8] Adresse, [15] schreiben
--                           TDO: [7:0] Lesedaten der Adresse aus dem VORIGEN Update,
--                                [8] Steuerbit, [9] lebt (Totmann nicht abgelaufen)
--                           Ein Burst ueber n Adressen braucht also n + 1 Scans.
--   "10"  KENNUNG   32 Bit  Generic ID ("FAR" & BOARD_ID), Schreiben wirkt nicht
--   "11"  STEUERUNG  8 Bit  TDO [0] = Steuerbit (1 = Uebernahme gewuenscht)
--                           TDI [0] = neuer Wert, [1] = schreiben (ohne Bit 1 nur lesen)
-- Bit 0 wird zuerst geschoben (LSB first). Wie fa_vjtag_link, nur VIR "01" ist neu.
--
-- Taktuebergang: TCK laeuft nur, waehrend der ESP schiebt. Schreib- und Lese-Ereignisse
-- gehen als Toggle (2 FF) in den Systemtakt. Adresse und Daten stehen dann seit dem
-- Update still und aendern sich fruehestens mit dem naechsten Update (>= 16 TCK spaeter),
-- werden im Systemtakt also sicher uebernommen. Alle Ausgaenge ausser rd_addr/tck
-- gehoeren zum Systemtakt.
--
-- rd_addr/rd_data: Lesemux des Klebers, kombinatorisch, abgetastet in Capture-DR (TCK).
-- Die Quellen sind Register im Systemtakt; ein Byte kann beim Abtasten halb alt, halb
-- neu sein. Fuer den Monitor ohne Belang (jedes Bit fuer sich ist gueltig).
--
-- Totmann: Kommt DEADMAN_MS lang kein Update auf REG und kein Schreiben auf STEUERUNG,
-- loescht das Modul das Steuerbit und nimmt alive weg (ESP abgestuerzt, Kabel gezogen).
--
-- VHDL-93.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity fa_jtag_regs is
	generic(
		ID         : std_logic_vector(31 downto 0);
		CLK_HZ     : integer := 50000000;
		DEADMAN_MS : integer := 2000
		);
	port(
		clk        : in  std_logic;		-- Systemtakt (50 MHz)
		-- Lesen (TCK-Seite)
		tck_out    : out std_logic;		-- fuer synchrone Lesespeicher des Klebers
		rd_addr    : out std_logic_vector(6 downto 0);	-- TCK-Bereich
		rd_data    : in  std_logic_vector(7 downto 0);
		-- Systemtakt
		rd_stb     : out std_logic;		-- 1 Takt: Adresse rd_addr_s wurde abgeholt
		rd_addr_s  : out std_logic_vector(6 downto 0);
		wr_stb     : out std_logic;		-- 1 Takt: wr_data nach wr_addr schreiben
		wr_addr    : out std_logic_vector(6 downto 0);
		wr_data    : out std_logic_vector(7 downto 0);
		ctrl       : out std_logic;		-- Steuerbit (Uebernahme gewuenscht)
		alive      : out std_logic		-- Aktivitaet innerhalb DEADMAN_MS
		);
end entity fa_jtag_regs;

architecture rtl of fa_jtag_regs is

	constant DEADMAN_CYC : integer := CLK_HZ / 1000 * DEADMAN_MS;

	-- vJTAG
	signal tck, tdi, tdo  : std_logic;
	signal ir_in          : std_logic_vector(1 downto 0);
	signal st_cdr, st_sdr, st_udr : std_logic;

	-- TCK-Seite
	signal sr             : std_logic_vector(31 downto 0) := (others => '0');
	signal byp            : std_logic := '0';
	signal addr_t         : std_logic_vector(6 downto 0) := (others => '0');
	signal waddr_t        : std_logic_vector(6 downto 0) := (others => '0');
	signal wdata_t        : std_logic_vector(7 downto 0) := (others => '0');
	signal w_tog          : std_logic := '0';
	signal r_tog          : std_logic := '0';
	signal c_val          : std_logic := '0';
	signal c_tog          : std_logic := '0';
	signal act_tog        : std_logic := '0';
	signal ctrl_t1, ctrl_t2   : std_logic := '0';
	signal alive_t1, alive_t2 : std_logic := '0';

	-- Systemtakt
	signal w1, w2, w3     : std_logic := '0';
	signal r1, r2, r3     : std_logic := '0';
	signal c1, c2, c3     : std_logic := '0';
	signal a1, a2, a3     : std_logic := '0';
	signal ctrl_r         : std_logic := '0';
	signal alive_r        : std_logic := '0';
	signal dead_cnt       : integer range 0 to DEADMAN_CYC := DEADMAN_CYC;

	signal is_byp         : std_logic;

begin

	VJ: sld_virtual_jtag
	generic map(
		sld_auto_instance_index => "YES",
		sld_instance_index      => 0,
		sld_ir_width            => 2
		)
	port map(
		tck               => tck,
		tdi               => tdi,
		tdo               => tdo,
		ir_in             => ir_in,
		ir_out            => "00",
		virtual_state_cdr => st_cdr,
		virtual_state_sdr => st_sdr,
		virtual_state_udr => st_udr
		);

	tck_out <= tck;
	rd_addr <= addr_t;
	is_byp  <= '1' when ir_in = "00" else '0';

	TCK_SIDE: process(tck)
	begin
		if rising_edge(tck) then
			ctrl_t1  <= ctrl_r;   ctrl_t2  <= ctrl_t1;
			alive_t1 <= alive_r;  alive_t2 <= alive_t1;

			if st_cdr = '1' then
				byp <= '0';
				case ir_in is
					when "01" =>
						sr    <= (31 downto 10 => '0') & alive_t2 & ctrl_t2 & rd_data;
						r_tog <= not r_tog;		-- Adresse addr_t abgeholt
					when "10" =>
						sr <= ID;
					when "11" =>
						sr <= (31 downto 1 => '0') & ctrl_t2;
					when others =>
						null;
				end case;
			elsif st_sdr = '1' then
				case ir_in is
					when "01"   => sr(15 downto 0) <= tdi & sr(15 downto 1);
					when "10"   => sr <= tdi & sr(31 downto 1);
					when "11"   => sr(7 downto 0)  <= tdi & sr(7 downto 1);
					when others => byp <= tdi;
				end case;
			end if;

			if st_udr = '1' then
				if ir_in = "01" then
					act_tog <= not act_tog;
					addr_t  <= sr(14 downto 8);
					if sr(15) = '1' then
						waddr_t <= sr(14 downto 8);
						wdata_t <= sr(7 downto 0);
						w_tog   <= not w_tog;
					end if;
				elsif ir_in = "11" and sr(1) = '1' then
					act_tog <= not act_tog;
					c_val   <= sr(0);
					c_tog   <= not c_tog;
				end if;
			end if;
		end if;
	end process;

	tdo <= byp when is_byp = '1' else sr(0);

	SYS_SIDE: process(clk)
	begin
		if rising_edge(clk) then
			w1 <= w_tog;    w2 <= w1;  w3 <= w2;
			r1 <= r_tog;    r2 <= r1;  r3 <= r2;
			c1 <= c_tog;    c2 <= c1;  c3 <= c2;
			a1 <= act_tog;  a2 <= a1;  a3 <= a2;

			wr_stb <= w2 xor w3;
			if w2 /= w3 then
				wr_addr <= waddr_t;
				wr_data <= wdata_t;
			end if;
			rd_stb <= r2 xor r3;
			if r2 /= r3 then
				rd_addr_s <= addr_t;
			end if;

			if a2 /= a3 then
				dead_cnt <= 0;
			elsif dead_cnt /= DEADMAN_CYC then
				dead_cnt <= dead_cnt + 1;
			end if;
			if dead_cnt = DEADMAN_CYC then
				alive_r <= '0';
			else
				alive_r <= '1';
			end if;
			if c2 /= c3 then
				ctrl_r <= c_val;
			elsif dead_cnt = DEADMAN_CYC then
				ctrl_r <= '0';
			end if;
		end if;
	end process;

	ctrl  <= ctrl_r;
	alive <= alive_r;

end architecture rtl;
