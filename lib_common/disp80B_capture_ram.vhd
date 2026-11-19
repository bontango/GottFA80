-- disp80B_capture_ram.vhd - like disp80B_capture.vhd, but the 2 x 20 characters live in
-- a dual-clock RAM (one M9K) instead of 320 flip-flops.
-- part of  GottFA80
-- bontango 11.2026
--
-- v 1.0 19.11.2026 for FA-Control "lite" (lib_common\fa_lite_sys80.vhd): the monitor reads
--                  the characters over Virtual JTAG, i.e. clocked by TCK. Write port =
--                  clk (50 MHz), read port = rclk. Address 0..19 = row 1, 20..39 = row 2.
--
-- Decoding exactly as disp80B_capture.vhd (LISY80 lisy/displays.c, display_sendtorow):
--   0x01          announces a command; the next byte is the command.
--   0xC0..0xDF    (command) buffer pointer = byte and 0x1F (for the row(s) strobed).
--   other command ignored.
--   any other byte is a character at the pointer, pointer + 1, after 19 back to 0.
-- Characters are stored with bit 7 cleared. D_Reset (active LOW) clears both rows: the
-- RAM cannot be cleared at once, a counter writes 40 blanks (40 clocks). A byte that
-- comes during these 40 clocks is lost - the game waits 100 ms after a reset anyway.
-- A byte for row 1 and one for row 2 on the same clock (one LD pulse to both rows,
-- e.g. the init commands) cannot both be written; characters always go to one row only.
-- Should both come at once, row 1 wins.
-- VHDL-93.

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

    entity disp80B_capture_ram is
        port(
            clk     : in  std_logic;
            data    : in  std_logic_vector(7 downto 0);
            LD1     : in  std_logic;
            LD2     : in  std_logic;
            D_Reset : in  std_logic;
            -- read port
            rclk    : in  std_logic;
            raddr   : in  integer range 0 to 39;
            q       : out std_logic_vector(7 downto 0)
            );
    end disp80B_capture_ram;
    ---------------------------------------------------
    architecture Behavioral of disp80B_capture_ram is
        type ram_t is array (0 to 63) of std_logic_vector(6 downto 0);
        signal ram        : ram_t := (others => "0100000");
        signal ptr1, ptr2 : integer range 0 to 19 := 0;
        signal cmd1, cmd2 : std_logic := '0';   -- last byte of this row was 0x01
        signal ld1_s      : std_logic_vector(2 downto 0) := (others => '0');  -- sync + edge
        signal ld2_s      : std_logic_vector(2 downto 0) := (others => '0');
        signal rst_s      : std_logic_vector(1 downto 0) := (others => '1');
        signal clr_cnt    : integer range 0 to 40 := 40;   -- 40 = not clearing
        signal we         : std_logic;
        signal wa         : integer range 0 to 63;
        signal wd         : std_logic_vector(6 downto 0);
        signal q7         : std_logic_vector(6 downto 0);
    begin

    capture: process (clk)
        variable n : integer range 0 to 255;
    begin
        if rising_edge(clk) then
            ld1_s <= ld1_s(1 downto 0) & LD1;
            ld2_s <= ld2_s(1 downto 0) & LD2;
            rst_s <= rst_s(0) & D_Reset;
            we    <= '0';
            wd    <= data(6 downto 0);
            n     := to_integer(unsigned(data));
            if rst_s(1) = '0' then
                ptr1    <= 0;
                ptr2    <= 0;
                cmd1    <= '0';
                cmd2    <= '0';
                clr_cnt <= 0;
            elsif clr_cnt < 40 then
                we      <= '1';
                wa      <= clr_cnt;
                wd      <= "0100000";
                clr_cnt <= clr_cnt + 1;
            else
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
                        we <= '1';
                        wa <= ptr1;
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
                    elsif ld1_s(2 downto 1) /= "01" then
                        we <= '1';
                        wa <= 20 + ptr2;
                        if ptr2 = 19 then ptr2 <= 0; else ptr2 <= ptr2 + 1; end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- simple dual-port RAM, two clocks (Quartus infers an M9K)
    wport: process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(wa) <= wd;
            end if;
        end if;
    end process;

    rport: process (rclk)
    begin
        if rising_edge(rclk) then
            q7 <= ram(raddr);
        end if;
    end process;

    q <= '0' & q7;

    end Behavioral;
