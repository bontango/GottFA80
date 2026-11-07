-- boot message on Gottlieb 80B display (2 x 20 characters, Rockwell 10941)
-- 80B Version
-- part of  GottFA80
-- bontango 01.2026
--
-- v 1.0 07.11.2026 first working version (the 01.2026 file was a stub)
--
-- Drives the 80B alphanumeric display directly on J2, i.e. it replaces what the
-- game normally does via RIOT U5 and the two 74175 latches:
--   data(7 downto 0) : D0..D7 (on J2: D0..D3 = seg 2,6,7,1  D4..D7 = seg 10,14,15,9)
--   LD1, LD2         : load strobe row 1 / row 2, active HIGH pulse (J2 seg 8 / 16)
--   D_Reset          : display reset, active LOW (J2 seg 24)
-- All levels are LINE levels, exactly as top/SYS80.vhd puts them on disp_segments
-- (segments_80B). Mapping to J2 is done by the top level.
--
-- Protocol as in the LISY80 display PIC (LISY80\MPLABX\Displays_6x_K42.X\displays.c):
--   reset   : D_Reset low 100 ms, then D7 high 1 ms ("parallel mode")
--   init    : to both rows  01 94 (digit counter 20), 01 06 (32 cycles/grid),
--                           01 5C (duty cycle); to row 1  01 0E (start refresh)
--   refresh : per row 01 C0 (buffer pointer 0) and 20 characters, then a pause,
--             forever - new texts (FA-Control) appear without an extra trigger.
--   byte    : data, LD high 10 us, LD low 3 us, pause 10 us.
-- 0x01 announces a command, so a character never goes out as 0x01: everything
-- below 0x20 becomes a blank, lower case becomes upper case, bit 7 is cleared.
--
-- show = '0' keeps the module idle (outputs low, D_Reset high = inactive). Every
-- rising edge of show starts with reset + init again.
-- SD_error = '1' replaces row 2 by error_row2.
--
-- CLK_HZ: frequency of clk_in. All times are derived from it; the shortest step
-- is one clock, so the module also works on slow clocks (80 kHz: 12.5 us steps).
-- VHDL-93 (also used by the Quartus 13.0sp1 folders).

LIBRARY ieee;
USE ieee.std_logic_1164.all;

    entity boot_message_80B is
        generic(
            CLK_HZ  : integer := 50000000
            );
        port(
            clk_in   : in std_logic;
            show     : in std_logic;
            SD_error : in std_logic;
            --output (display control, line levels on J2)
            data     : out std_logic_vector(7 downto 0);
            LD1      : out std_logic;
            LD2      : out std_logic;
            D_Reset  : out std_logic;
            -- input (display data)
            row1       : in  string(1 to 20);
            row2       : in  string(1 to 20);
            error_row2 : in  string(1 to 20)
            );
    end boot_message_80B;
    ---------------------------------------------------
    architecture Behavioral of boot_message_80B is

        function imax(a, b : integer) return integer is
        begin
            if a > b then return a; end if;
            return b;
        end function;

        -- clocks for a time in microseconds, at least 1. Split for n >= 1000,
        -- otherwise 50000 * 100000 overflows the 32 bit integer.
        function us(n : integer) return integer is
        begin
            if n >= 1000 then
                return imax(1, (CLK_HZ / 1000) * (n / 1000));
            end if;
            return imax(1, (CLK_HZ / 1000) * n / 1000);
        end function;

        constant T_RESET : integer := us(100000);  -- D_Reset low
        constant T_D7    : integer := us(1000);    -- D7 high, and the same again low
        constant T_SETUP : integer := us(2);       -- data stable before LD
        constant T_LD    : integer := us(10);      -- LD high
        constant T_HOLD  : integer := us(3);       -- data stable after LD
        constant T_GAP   : integer := us(10);      -- pause to the next byte
        constant T_PAUSE : integer := us(20000);   -- pause between two refreshes

        -- step sequence: 0..7 init, then 44 refresh steps (FRAME_FIRST..FRAME_LAST)
        constant INIT_LAST   : integer := 7;
        constant FRAME_FIRST : integer := 8;
        constant FRAME_LAST  : integer := FRAME_FIRST + 43;

        type STATE_T is (IDLE, RST, D7_HIGH, D7_LOW, B_SETUP, B_LD, B_HOLD, B_GAP, PAUSE);
        signal state : STATE_T := IDLE;
        signal tmr   : integer range 0 to T_RESET := 0;
        signal step  : integer range 0 to FRAME_LAST := 0;

        signal cur_byte : std_logic_vector(7 downto 0);
        signal cur_r1   : std_logic;   -- byte goes to row 1
        signal cur_r2   : std_logic;   -- byte goes to row 2
        signal row2_eff : string(1 to 20);

        -- character -> display code (see header)
        function to_code(c : character) return std_logic_vector is
            variable n : integer range 0 to 255;
            variable v : std_logic_vector(7 downto 0);
        begin
            n := character'pos(c) mod 128;
            if n >= 97 and n <= 122 then        -- 'a'..'z' -> 'A'..'Z'
                n := n - 32;
            elsif n < 32 or n = 127 then        -- control chars -> blank
                n := 32;
            end if;
            for i in 0 to 7 loop
                if (n / (2 ** i)) mod 2 = 1 then v(i) := '1'; else v(i) := '0'; end if;
            end loop;
            return v;
        end function;

    begin

    row2_eff <= error_row2 when SD_error = '1' else row2;

    -- byte and row(s) of the current step
    seq: process(step, row1, row2_eff)
        variable k : integer range 0 to 63;
    begin
        cur_byte <= x"01";
        cur_r1   <= '1';
        cur_r2   <= '1';
        if step <= INIT_LAST then
            case step is
                when 1      => cur_byte <= x"94";            -- digit counter 20
                when 3      => cur_byte <= x"06";            -- 32 cycles per grid
                when 5      => cur_byte <= x"5C";            -- duty cycle
                when 6      => cur_r2 <= '0';                -- 01 to row 1 only
                when 7      => cur_byte <= x"0E"; cur_r2 <= '0';  -- start refresh
                when others => null;                         -- 0, 2, 4: 01
            end case;
        else
            k := step - FRAME_FIRST;
            if k < 22 then                                   -- row 1
                cur_r2 <= '0';
                if k = 1 then
                    cur_byte <= x"C0";                       -- buffer pointer 0
                elsif k >= 2 then
                    cur_byte <= to_code(row1(k - 1));
                end if;
            else                                             -- row 2
                cur_r1 <= '0';
                if k = 23 then
                    cur_byte <= x"C0";
                elsif k >= 24 then
                    cur_byte <= to_code(row2_eff(k - 23));
                end if;
            end if;
        end if;
    end process;

    boot_message_80B: process (clk_in)
    begin
        if rising_edge(clk_in) then
            if show = '0' then
                state   <= IDLE;
                LD1     <= '0';
                LD2     <= '0';
                D_Reset <= '1';
                data    <= (others => '0');
                tmr     <= 0;
                step    <= 0;
            else
                if tmr > 0 then
                    tmr <= tmr - 1;
                end if;
                case state is
                    when IDLE =>                   -- show just went high
                        D_Reset <= '0';
                        tmr     <= T_RESET - 1;
                        state   <= RST;
                    when RST =>
                        if tmr = 0 then
                            D_Reset <= '1';
                            data    <= x"80";      -- D7 high: parallel mode
                            tmr     <= T_D7 - 1;
                            state   <= D7_HIGH;
                        end if;
                    when D7_HIGH =>
                        if tmr = 0 then
                            data  <= x"00";
                            tmr   <= T_D7 - 1;
                            state <= D7_LOW;
                        end if;
                    when D7_LOW =>
                        if tmr = 0 then
                            step  <= 0;
                            state <= B_SETUP;
                            tmr   <= T_SETUP - 1;
                            data  <= x"01";        -- = cur_byte of step 0
                        end if;
                    when B_SETUP =>
                        data <= cur_byte;
                        if tmr = 0 then
                            LD1   <= cur_r1;
                            LD2   <= cur_r2;
                            tmr   <= T_LD - 1;
                            state <= B_LD;
                        end if;
                    when B_LD =>
                        if tmr = 0 then
                            LD1   <= '0';
                            LD2   <= '0';
                            tmr   <= T_HOLD - 1;
                            state <= B_HOLD;
                        end if;
                    when B_HOLD =>
                        if tmr = 0 then
                            tmr   <= T_GAP - 1;
                            state <= B_GAP;
                        end if;
                    when B_GAP =>
                        if tmr = 0 then
                            if step = FRAME_LAST then
                                step  <= FRAME_FIRST;
                                tmr   <= T_PAUSE - 1;
                                state <= PAUSE;
                            else
                                step  <= step + 1;
                                tmr   <= T_SETUP - 1;
                                state <= B_SETUP;
                            end if;
                        end if;
                    when PAUSE =>
                        if tmr = 0 then
                            tmr   <= T_SETUP - 1;
                            state <= B_SETUP;
                        end if;
                end case;
            end if; -- show
        end if; --rising edge
    end process;

    end Behavioral;
