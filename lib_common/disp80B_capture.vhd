-- disp80B_capture.vhd - reads what goes to the Gottlieb 80B display (2 x 20 chars)
-- part of  GottFA80
-- bontango 11.2026
--
-- v 1.0 07.11.2026
--
-- Listens on the J2 display bus like the two Rockwell 10941 do and keeps a copy of
-- both rows - for the FA-Control monitor, but usable anywhere. Inputs are LINE
-- levels as in top/SYS80.vhd (segments_80B) and as boot_message_80B drives them:
--   data(7 downto 0) : D0..D7
--   LD1, LD2         : load strobe row 1 / row 2, a byte is taken on the RISING edge
--   D_Reset          : active LOW, clears both rows
-- LD1/LD2/D_Reset come straight from RIOT outputs (cpu_clk) and are sampled twice
-- here. data must be stable while LD rises - it is, the game latches D0..D7 into
-- the 74175 long before it pulses LD.
--
-- Decoding as LISY80 (lisy/displays.c, display_sendtorow):
--   0x01          announces a command; the next byte is the command.
--   0xC0..0xDF    (command) buffer pointer = byte and 0x1F (for the row(s) strobed).
--   other command ignored (digit counter, duty cycle, refresh, modes).
--   any other byte is a character at the pointer, pointer + 1, after 19 back to 0.
-- Characters are stored with bit 7 cleared (bit 7 = dot / cursor on the 10941).

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

    entity disp80B_capture is
        port(
            clk     : in  std_logic;
            data    : in  std_logic_vector(7 downto 0);
            LD1     : in  std_logic;
            LD2     : in  std_logic;
            D_Reset : in  std_logic;
            row1    : out string(1 to 20);
            row2    : out string(1 to 20)
            );
    end disp80B_capture;
    ---------------------------------------------------
    architecture Behavioral of disp80B_capture is
        signal r1, r2     : string(1 to 20) := (others => ' ');
        signal ptr1, ptr2 : integer range 0 to 19 := 0;
        signal cmd1, cmd2 : std_logic := '0';   -- last byte of this row was 0x01
        signal ld1_s      : std_logic_vector(2 downto 0) := (others => '0');  -- sync + edge
        signal ld2_s      : std_logic_vector(2 downto 0) := (others => '0');
        signal rst_s      : std_logic_vector(1 downto 0) := (others => '1');
    begin

    row1 <= r1;
    row2 <= r2;

    capture: process (clk)
        variable n  : integer range 0 to 255;
        variable ch : character;
    begin
        if rising_edge(clk) then
            ld1_s <= ld1_s(1 downto 0) & LD1;
            ld2_s <= ld2_s(1 downto 0) & LD2;
            rst_s <= rst_s(0) & D_Reset;
            if rst_s(1) = '0' then
                r1   <= (others => ' ');
                r2   <= (others => ' ');
                ptr1 <= 0;
                ptr2 <= 0;
                cmd1 <= '0';
                cmd2 <= '0';
            else
                n  := to_integer(unsigned(data));
                ch := character'val(n mod 128);
                -- row 1
                if ld1_s(2 downto 1) = "01" then
                    if cmd1 = '1' then
                        cmd1 <= '0';
                        if n >= 16#C0# and n <= 16#DF# then
                            if n mod 32 <= 19 then ptr1 <= n mod 32; else ptr1 <= 0; end if;
                        end if;
                    elsif n = 1 then
                        cmd1 <= '1';
                    else
                        r1(ptr1 + 1) <= ch;
                        if ptr1 = 19 then ptr1 <= 0; else ptr1 <= ptr1 + 1; end if;
                    end if;
                end if;
                -- row 2
                if ld2_s(2 downto 1) = "01" then
                    if cmd2 = '1' then
                        cmd2 <= '0';
                        if n >= 16#C0# and n <= 16#DF# then
                            if n mod 32 <= 19 then ptr2 <= n mod 32; else ptr2 <= 0; end if;
                        end if;
                    elsif n = 1 then
                        cmd2 <= '1';
                    else
                        r2(ptr2 + 1) <= ch;
                        if ptr2 = 19 then ptr2 <= 0; else ptr2 <= ptr2 + 1; end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    end Behavioral;
