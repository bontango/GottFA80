-- vjtag_probe.vhd - Virtual-JTAG-Testknoten (Stufe 1 von "FA-Control ueber Virtual JTAG")
--
-- 17.11.2026  Konzept: N:\Projekte\misc\USB_BLASTER_DIY\ESP32-C3_EVALUIERUNG.md, Abschnitt 15.
--
-- Ein sld_virtual_jtag-Knoten ohne Verbindung zum Rest des Designs. Er dient nur dazu, den Weg
-- ESP32 -> JTAG (P5) -> SLD-Hub -> Knoten an der echten Hardware zu pruefen, zuerst vom PC
-- (quartus_stp, scripts\vjtag_test.tcl), dann vom ESP32 aus. Quartus fuegt den Hub selbst ein.
--
-- VIR (sld_ir_width = 2):
--   "00"  BYPASS   1 Bit
--   "01"  SCRATCH 32 Bit  Capture liefert den zuletzt geschriebenen Wert, Update uebernimmt den
--                         eingeschobenen (Rueckkanal). Nach dem Einschalten 0.
--   "10"  ID      32 Bit  Capture liefert den Generic ID, Schreiben wirkt nicht.
--   "11"  BYPASS   1 Bit  (spaeter: Steuerregister, CTRL_REQ)
-- Bit 0 wird zuerst geschoben (LSB first), wie bei jedem DR.
--
-- Alles laeuft im TCK-Takt; es gibt keinen Uebergang in den Systemtakt.

library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity vjtag_probe is
	generic(
		ID : std_logic_vector(31 downto 0)
		);
end entity vjtag_probe;

architecture rtl of vjtag_probe is

	signal tck     : std_logic;
	signal tdi     : std_logic;
	signal tdo     : std_logic;
	signal ir_in   : std_logic_vector(1 downto 0);
	signal st_cdr  : std_logic;
	signal st_sdr  : std_logic;
	signal st_udr  : std_logic;

	signal sr      : std_logic_vector(31 downto 0) := (others => '0');	-- Schieberegister
	signal scratch : std_logic_vector(31 downto 0) := (others => '0');
	signal byp     : std_logic := '0';
	signal is_byp  : std_logic;

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

	is_byp <= '1' when ir_in = "00" or ir_in = "11" else '0';

	process(tck)
	begin
		if rising_edge(tck) then
			if st_cdr = '1' then
				if ir_in = "10" then
					sr <= ID;
				elsif ir_in = "01" then
					sr <= scratch;
				end if;
				byp <= '0';
			elsif st_sdr = '1' then
				if is_byp = '1' then
					byp <= tdi;
				else
					sr <= tdi & sr(31 downto 1);
				end if;
			end if;
			if st_udr = '1' and ir_in = "01" then
				scratch <= sr;
			end if;
		end if;
	end process;

	tdo <= byp when is_byp = '1' else sr(0);

end architecture rtl;
