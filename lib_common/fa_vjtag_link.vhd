-- fa_vjtag_link.vhd - FA-Control ueber Virtual JTAG (Stufe 3 von "FA-Control ueber JTAG")
-- (c)2026 bontango, GPL v3 wie der Rest des Projekts.
--
-- 17.11.2026  Konzept: N:\Projekte\misc\USB_BLASTER_DIY\ESP32-C3_EVALUIERUNG.md, Abschnitt 15.4-15.6.
--
-- Ein Adapter, der fuer fa_control so aussieht wie die drei FA-Pins des ESP32 auf X7:
-- fa_rxd (seriell zum FA, 115200 Baud), fa_txd (seriell vom FA), fa_ctrl_req (active low).
-- Auf der anderen Seite haengt ein sld_virtual_jtag-Knoten; der ESP32 auf dem
-- JTAG-Piggyback (Stecker P5) tauscht darueber Bytes aus. fa_control bleibt unveraendert.
--
-- VIR (sld_ir_width = 2; der Hub meldet trotzdem n = 4, s. EVALUIERUNG 15.3):
--   "00"  BYPASS     1 Bit
--   "01"  DATEN     16 Bit  TDI: [7:0] Byte zum FA, [8] tx_valid
--                           TDO: [7:0] Byte vom FA, [8] rx_valid, [9] tx_afull
--                           Capture holt ein Byte vom FA (falls da), Update schreibt das
--                           eingeschobene Byte (bei tx_valid) in den Puffer zum FA.
--   "10"  KENNUNG   32 Bit  Generic ID, Schreiben wirkt nicht
--   "11"  STEUERUNG  8 Bit  TDO [0] = CTRL_REQ (1 = Uebernahme gewuenscht)
--                           TDI [0] = neuer Wert, [1] = schreiben (ohne Bit 1 nur lesen)
-- Bit 0 wird zuerst geschoben (LSB first).
--
-- Totmann: Kommt DEADMAN_MS lang kein Update auf DATEN und kein Schreiben auf STEUERUNG, loescht das Modul
-- CTRL_REQ selbst (ESP abgestuerzt, Kabel gezogen). Test-Logic-Reset loescht es NICHT -
-- der ESP beendet jede Sitzung mit TLR.
--
-- Taktuebergang: TCK laeuft nur, waehrend der ESP schiebt. Beide Richtungen gehen ueber je
-- ein Toggle-Paar (Anforderung/Quittung, 2 FF Synchronisation) und einen FIFO im Systemtakt
-- (abgeleiteter RAM, kein dcfifo - so braucht das Modul kein intended_device_family und
-- laeuft unveraendert auf Cyclone IV E und Cyclone 10 LP). Der ESP muss zwischen den Scans
-- ein paar Takte in Run-Test/Idle geben, damit die Flags auf der TCK-Seite nachziehen.
-- tx_afull meldet, dass im Puffer zum FA nur noch wenig Platz ist; ab dann keine Bytes mehr
-- senden, bis es wieder 0 ist (die naechsten AFULL_MARGIN Bytes gehen noch sicher hinein).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity fa_vjtag_link is
	generic(
		ID           : std_logic_vector(31 downto 0);
		CLKS_PER_BIT : integer := 434;		-- 50 MHz / 115200 Baud, wie fa_control
		CLK_HZ       : integer := 50000000;
		DEADMAN_MS   : integer := 2000
		);
	port(
		clk          : in  std_logic;		-- 50 MHz
		fa_rxd       : out std_logic;		-- an fa_control.rxd (wie FA_RXD-Pin)
		fa_txd       : in  std_logic;		-- von fa_control.txd
		fa_ctrl_req  : out std_logic		-- an fa_control.ctrl_req, active low
		);
end entity fa_vjtag_link;

architecture rtl of fa_vjtag_link is

	constant AW           : integer := 8;		-- 256 Byte je Richtung, ein M9K
	constant AFULL_MARGIN : integer := 32;
	constant DEADMAN_CYC  : integer := CLK_HZ / 1000 * DEADMAN_MS;

	type ram_t is array (0 to 2**AW - 1) of std_logic_vector(7 downto 0);

	-- vJTAG
	signal tck, tdi, tdo  : std_logic;
	signal ir_in          : std_logic_vector(1 downto 0);
	signal st_cdr, st_sdr, st_udr : std_logic;

	-- TCK-Seite
	signal sr             : std_logic_vector(31 downto 0) := (others => '0');
	signal byp            : std_logic := '0';
	signal m_tog_t1, m_tog_t2 : std_logic := '0';	-- Mailbox-Toggle, in TCK synchronisiert
	signal m_seen         : std_logic := '0';		-- Quittung zum Systemtakt
	signal t_byte         : std_logic_vector(7 downto 0) := (others => '0');
	signal t_tog          : std_logic := '0';		-- neues Byte zum FA
	signal t_ack_t1, t_ack_t2 : std_logic := '0';
	signal afull_t1, afull_t2 : std_logic := '0';
	signal ctrl_t1, ctrl_t2   : std_logic := '0';
	signal c_val          : std_logic := '0';
	signal c_tog          : std_logic := '0';
	signal act_tog        : std_logic := '0';		-- jedes Update auf DATEN/STEUERUNG

	-- Systemtakt-Seite
	signal m_byte         : std_logic_vector(7 downto 0) := (others => '0');	-- Mailbox zum ESP
	signal m_tog          : std_logic := '0';
	signal m_ack1, m_ack2 : std_logic := '0';
	signal t_tog1, t_tog2 : std_logic := '0';
	signal t_ack          : std_logic := '0';
	signal c_tog1, c_tog2, c_tog3 : std_logic := '0';
	signal act1, act2, act3       : std_logic := '0';
	signal ctrl           : std_logic := '0';
	signal dead_cnt       : integer range 0 to DEADMAN_CYC := 0;
	signal afull          : std_logic := '0';

	-- FIFO ESP -> FA (Systemtakt)
	signal tx_ram         : ram_t;
	signal tx_wa, tx_ra   : unsigned(AW - 1 downto 0) := (others => '0');
	signal tx_q           : std_logic_vector(7 downto 0);
	signal tx_data        : std_logic_vector(7 downto 0) := (others => '0');
	signal tx_pend       : std_logic := '0';
	signal tx_dv          : std_logic := '0';
	signal tx_busy        : std_logic := '0';
	signal tx_active      : std_logic;
	signal tx_done        : std_logic;

	-- FIFO FA -> ESP (Systemtakt)
	signal rx_ram         : ram_t;
	signal rx_wa, rx_ra   : unsigned(AW - 1 downto 0) := (others => '0');
	signal rx_q           : std_logic_vector(7 downto 0);
	signal rx_pend        : std_logic := '0';
	signal rx_dv          : std_logic;
	signal rx_byte        : std_logic_vector(7 downto 0);

	signal is_byp         : std_logic;

begin

	------------------------------------------------------------------------------
	-- Virtual-JTAG-Knoten, TCK-Seite
	------------------------------------------------------------------------------
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

	is_byp <= '1' when ir_in = "00" else '0';

	TCK_SIDE: process(tck)
		variable rx_valid : std_logic;
	begin
		if rising_edge(tck) then
			-- Synchronisation aus dem Systemtakt
			m_tog_t1 <= m_tog;   m_tog_t2 <= m_tog_t1;
			t_ack_t1 <= t_ack;   t_ack_t2 <= t_ack_t1;
			afull_t1 <= afull;   afull_t2 <= afull_t1;
			ctrl_t1  <= ctrl;    ctrl_t2  <= ctrl_t1;

			if st_cdr = '1' then
				byp <= '0';
				case ir_in is
					when "01" =>
						rx_valid := m_tog_t2 xor m_seen;
						sr <= (31 downto 10 => '0') & afull_t2 & rx_valid & m_byte;
						if rx_valid = '1' then
							m_seen <= m_tog_t2;			-- Byte abgeholt, Quittung
						end if;
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
					-- Neues Byte nur, wenn das vorige quittiert ist; sonst verworfen
					-- (kommt bei beachtetem tx_afull nicht vor).
					if sr(8) = '1' and t_tog = t_ack_t2 then
						t_byte <= sr(7 downto 0);
						t_tog  <= not t_tog;
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

	------------------------------------------------------------------------------
	-- Systemtakt: ESP -> FA
	------------------------------------------------------------------------------
	TX_FIFO_RAM: process(clk)
	begin
		if rising_edge(clk) then
			if t_tog2 /= t_ack and (tx_wa + 1) /= tx_ra then
				tx_ram(to_integer(tx_wa)) <= t_byte;
			end if;
			tx_q <= tx_ram(to_integer(tx_ra));
		end if;
	end process;

	TX_CTRL: process(clk)
		variable used : unsigned(AW - 1 downto 0);
	begin
		if rising_edge(clk) then
			t_tog1 <= t_tog;  t_tog2 <= t_tog1;
			-- Byte aus der TCK-Seite in den FIFO (wartet, solange er voll ist)
			if t_tog2 /= t_ack and (tx_wa + 1) /= tx_ra then
				tx_wa <= tx_wa + 1;
				t_ack <= t_tog2;
			end if;
			used := tx_wa - tx_ra;
			if used >= 2**AW - 1 - AFULL_MARGIN then
				afull <= '1';
			else
				afull <= '0';
			end if;

			-- FIFO -> UART_TX: Lesen anstossen, einen Takt spaeter senden
			tx_dv <= '0';
			if tx_pend = '1' then
				-- tx_q gilt nur in diesem Takt (danach liest der RAM schon die naechste
				-- Adresse), UART_TX uebernimmt aber erst mit dem folgenden: festhalten.
				tx_data <= tx_q;
				tx_pend <= '0';
				tx_dv   <= '1';
				tx_busy <= '1';
			elsif tx_busy = '0' and tx_done = '0' and tx_wa /= tx_ra then
				tx_ra   <= tx_ra + 1;
				tx_pend <= '1';
			end if;
			if tx_done = '1' then
				tx_busy <= '0';
			end if;
		end if;
	end process;

	U_TX: entity work.uart_tx
	generic map(g_CLKS_PER_BIT => CLKS_PER_BIT)
	port map(
		i_Clk       => clk,
		i_TX_DV     => tx_dv,
		i_TX_Byte   => tx_data,
		o_TX_Active => tx_active,
		o_TX_Serial => fa_rxd,
		o_TX_Done   => tx_done
		);

	------------------------------------------------------------------------------
	-- Systemtakt: FA -> ESP
	------------------------------------------------------------------------------
	U_RX: entity work.uart_rx
	generic map(g_CLKS_PER_BIT => CLKS_PER_BIT)
	port map(
		i_Clk       => clk,
		i_RX_Serial => fa_txd,
		o_RX_DV     => rx_dv,
		o_RX_Byte   => rx_byte
		);

	RX_FIFO_RAM: process(clk)
	begin
		if rising_edge(clk) then
			if rx_dv = '1' and (rx_wa + 1) /= rx_ra then
				rx_ram(to_integer(rx_wa)) <= rx_byte;
			end if;
			rx_q <= rx_ram(to_integer(rx_ra));
		end if;
	end process;

	RX_CTRL: process(clk)
	begin
		if rising_edge(clk) then
			m_ack1 <= m_seen;  m_ack2 <= m_ack1;
			if rx_dv = '1' and (rx_wa + 1) /= rx_ra then
				rx_wa <= rx_wa + 1;			-- voll: Byte geht verloren (256 Byte Puffer)
			end if;
			-- Mailbox leer (vom ESP quittiert) und FIFO nicht leer: naechstes Byte holen
			if rx_pend = '1' then
				rx_pend <= '0';
				m_byte  <= rx_q;
				m_tog   <= not m_tog;
			elsif m_tog = m_ack2 and rx_wa /= rx_ra then
				rx_ra   <= rx_ra + 1;
				rx_pend <= '1';
			end if;
		end if;
	end process;

	------------------------------------------------------------------------------
	-- Systemtakt: Steuerbit mit Totmann
	------------------------------------------------------------------------------
	CTRL_P: process(clk)
	begin
		if rising_edge(clk) then
			c_tog1 <= c_tog;  c_tog2 <= c_tog1;  c_tog3 <= c_tog2;
			act1   <= act_tog; act2  <= act1;    act3   <= act2;
			if act2 /= act3 then
				dead_cnt <= 0;
			elsif dead_cnt /= DEADMAN_CYC then
				dead_cnt <= dead_cnt + 1;
			end if;
			if c_tog2 /= c_tog3 then
				ctrl <= c_val;
			elsif dead_cnt = DEADMAN_CYC then
				ctrl <= '0';
			end if;
		end if;
	end process;

	fa_ctrl_req <= not ctrl;

end architecture rtl;
