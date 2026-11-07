--
-- SD_Card.vhd
-- read SD card in 'raw' Mode to move code to RAM/ROM
-- version with reset_l and 16KByte
-- for GottFA80
-- bontango 06.2025
--
-- v050
-- v052 07.11.2026 CMD8-Antwort auch 1 Byte spaeter, CMD0/CMD8 bis 8x wiederholen
--      (Warmstart per Reset-Taste endete mit Blinkcode 4 = CMD8)
-- v053 07.11.2026 CMD8: erste Antwort im ganzen Fenster suchen (NCR bis 8 Byte);
--      Diagnose-Ausgaenge err_cmd/err_rx (optional, fuer die 80B-Anzeige)
-- v054 07.11.2026 vor CMD0 immer CMD12 senden, Wiederholungen ab dort: nach Reset-Taste
--      steckte die Karte noch im CMD18-Lesen (Anzeige "SD E3 FFFFFFFFFFFFFF")

library IEEE;
use IEEE.std_logic_1164.all;
--use IEEE.std_logic_arith.all;
--use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

	entity SD_Card is
		port(
		i_Clk		: IN STD_LOGIC  := '1';
		-- Control/Data Signals,
		i_Rst_L : in std_logic;     -- FPGA Reset		
		-- PMOD SPI Interface
		o_SPI_Clk  : out std_logic;
		i_SPI_MISO : in std_logic;
		o_SPI_MOSI : out std_logic;
		o_SPI_CS_n : out std_logic;
		-- selektion
		selection : in std_logic_vector(7 downto 0);
		-- sd card
		address_sd_card	: buffer  std_logic_vector(13 downto 0);
		data_sd_card	: out std_logic_vector(7 downto 0);
		wr_rom :  out std_logic;		
		-- start CPU
		cpu_reset_l : out STD_LOGIC;
		-- feedback
		SDcard_error : out STD_LOGIC;
		-- Diagnose (v053, darf offen bleiben): beim Eintritt in den Fehlerzustand
		-- gemerkt - err_cmd = Blinkcode (3 CMD0, 4 CMD8, 6 ACMD41), err_rx = die
		-- 7 Byte des Antwortfensters nach dem Befehl (Byte 7..13)
		err_cmd : out std_logic_vector(3 downto 0);
		err_rx  : out std_logic_vector(55 downto 0)
		);
    end SD_Card;
	 
   architecture Behavioral of SD_Card is		
		type STATE_T is ( Startdelay, send_read_request, wait_for_read, continue, 
								initiate_read_sector, wait_for_begin_of_data,check_for_FE_flag, sector_read, wait_for_byte_read,
								check_sector_byte, inc_addr_and_unset_wr, stop_read, delay_and_repeat, all_done, error, stop );
		signal state_A : STATE_T;       
		
		
		-- SPI stuff for SD card commands	
		signal TX_Data_A : std_LOGIC_VECTOR ( 111 downto 0); -- 14 Bytes ( 6 cmd bytes, 1 NCR ,1 Return ,4 CMD Echo )
		signal RX_Data_A : std_LOGIC_VECTOR ( 111 downto 0);  -- we also send 0xFF with CS disable before and after
		signal TX_Start_A : std_LOGIC;
		signal TX_Done_A : std_LOGIC;
		signal MOSI_A : std_LOGIC;
		signal SS_A :  std_LOGIC;
		signal SPI_Clk_A :  std_LOGIC;

		-- SPI stuff for SD card read, byte by byte
		signal TX_Data_R : std_LOGIC_VECTOR ( 7 downto 0); 
		signal RX_Data_R : std_LOGIC_VECTOR ( 7 downto 0);
		signal TX_Start_R : std_LOGIC;
		signal TX_Done_R : std_LOGIC;
		signal MOSI_R : std_LOGIC;
		signal SS_R :  std_LOGIC;
		signal SPI_Clk_R :  std_LOGIC;
		
		-----		
		signal cmd_count : integer range 0 to 16; 
		signal R1_response : std_LOGIC_VECTOR (7 downto 0);		
		signal R1_response_2 : std_LOGIC_VECTOR (7 downto 0);		
		signal Echo_response : std_LOGIC_VECTOR (7 downto 0);		
		signal active_master : std_LOGIC_VECTOR (1 downto 0) := "00";
		signal do_not_disable_SS : std_LOGIC;		
		signal do_not_enable_SS : std_LOGIC;	
		signal sector : unsigned (15 downto 0);	
		
		signal byte_count : integer range 0 to 520; 		
		
		signal attempts : integer range 0 to 5000;
		signal cmd8_tries : integer range 0 to 8;   -- Wiederholungen CMD0/CMD8 (v052)
		signal counter  : integer range 0 to 100000000;   -- delay, for 10ms use 500.000

		-- Diagnose (v053): Befehl und rohe Antwort beim Eintritt in den Fehlerzustand
		signal err_lat : std_logic;

		-- CMD8 (R7): Antwortfenster = Byte 7..13 nach dem Befehl (RX(55 downto 0)).
		-- R1 = erstes Byte mit Bit 7 = 0; muss 01 sein, Echo AA 4 Byte spaeter,
		-- soweit das noch im Fenster liegt.
		function r7_ok(rx : std_logic_vector(111 downto 0)) return boolean is
			variable b : std_logic_vector(7 downto 0);
		begin
			for i in 8 to 13 loop
				b := rx(111 - 8 * i downto 104 - 8 * i);
				if b(7) = '0' then
					if b /= x"01" then
						return false;
					end if;
					if i + 4 <= 13 then
						return rx(111 - 8 * (i + 4) downto 104 - 8 * (i + 4)) = x"AA";
					end if;
					return true;
				end if;
			end loop;
			return false;
		end function;
	begin
		
		-- signals for the two SPI Master
	o_SPI_MOSI <=	
	MOSI_A when active_master = "01" else
	MOSI_R when active_master = "10" else
	'0';

	o_SPI_Clk <=
	SPI_Clk_A when active_master = "01"  else
	SPI_Clk_R when active_master = "10"  else
	'0';

	o_SPI_CS_n <=
	SS_A when active_master = "01"  else
	'0' when active_master = "10" else
	'1';
	
	
SD_CARD_ACCESS: entity work.SPI_Master
    generic map (      
      Laenge => 112,
		SPI_Taktfrequenz => 400000) -- 400KHz for commands
    port map (
			  TX_Data  => TX_Data_A,
           RX_Data  => RX_Data_A,
           MOSI     => MOSI_A,
           MISO     => i_SPI_MISO,
           SCLK     => SPI_Clk_A,
           SS       => SS_A,
           TX_Start => TX_Start_A,
           TX_Done  => TX_Done_A,
           clk      => i_Clk,	  
			  do_not_disable_SS => do_not_disable_SS,
			  do_not_enable_SS => do_not_enable_SS
      );
		
SD_CARD_READ: entity work.SPI_Master --read i byte by byte (slooow)
    generic map (      
      Laenge => 8,
		SPI_Taktfrequenz => 400000) -- 400KHz for commands
    port map (
			  TX_Data  => TX_Data_R,
           RX_Data  => RX_Data_R,
           MOSI     => MOSI_R,
           MISO     => i_SPI_MISO,
           SCLK     => SPI_Clk_R,
           SS       => SS_R,
           TX_Start => TX_Start_R,
           TX_Done  => TX_Done_R,
           clk      => i_Clk,
			  do_not_disable_SS => do_not_disable_SS,
			  do_not_enable_SS => do_not_enable_SS
      );

		
		SD_Card: process (i_Clk, i_Rst_L )
			--constant all_high : std_LOGIC_VECTOR (47 downto 0) := x"FFFFFFFFFFFF";
			constant CMD0 : std_LOGIC_VECTOR (47 downto 0) := x"400000000095"; --reset			
			constant CMD8 : std_LOGIC_VECTOR (47 downto 0) := x"48000001AA87"; --check the version of SD card					
			--constant CMD1 : std_LOGIC_VECTOR (47 downto 0) := x"4100000000F9"; -- initiate the initialization process (old cards)
			--only support for 'new' Sd cards at the moment
			constant CMD55 : std_LOGIC_VECTOR (47 downto 0) := x"7700000000FF";	-- leading cmd for AMD commands 
			constant ACMD41 : std_LOGIC_VECTOR (47 downto 0) := x"6940000000FF";	-- initiate the initialization process			
			constant CMD17 : std_LOGIC_VECTOR (47 downto 0) := x"5100000000FF"; --single-read block
			constant CMD18 : std_LOGIC_VECTOR (47 downto 0) := x"5200000000FF"; --multi-read block
			constant CMD12 : std_LOGIC_VECTOR (47 downto 0) := x"4C00000000FF"; --stop to read data
			constant CMD58 : std_LOGIC_VECTOR (47 downto 0) := x"7A00000000FF"; --read OCR
			
			variable sectorcount: integer range 0 to 10000;
			variable gamenumber: integer range 0 to 255;
			
		begin
		if rising_edge(i_Clk) then
			if i_Rst_L = '0' then --Reset condidition (reset_l)    
				cpu_reset_l <= '0';
				TX_Start_A <= '0';		
				TX_Start_R <= '0';		
				TX_Data_R <= x"FF";				
				cmd_count <= 0;
				active_master <= "00";
				do_not_disable_SS <= '0'; --default
				do_not_enable_SS <= '0'; --default
				wr_rom <= '0';
				address_sd_card <= (others => '0');
				byte_count <= 0;
				SDcard_error <= '1'; -- active low
				counter <= 0;
				attempts <= 0;
				cmd8_tries <= 0;
				err_lat <= '0';
				state_A <= Startdelay;
			else			
				case state_A is
				-- STATE MASCHINE ----------------
				 when Startdelay => 
						active_master <= "01";			
					--give SD card time to power up					
					counter <= counter +1;					
					if ( counter = 25000000 ) then --500ms 
						state_A <= send_read_request;
						counter <= 0;						
					end if;																													
				when send_read_request =>						
				   case cmd_count is
					   -- v054: zuerst CMD12 (CS low). Nach einem Warmstart kann die Karte noch
					   -- im Mehrblock-Lesen (CMD18) vom letzten Boot stecken und liefert dann
					   -- Daten statt Antworten (CMD0 scheinbar ok, CMD8 falsch, spaeter nur FF)
					   -- bis zum Ausschalten. Nach dem Einschalten oder im Ruhezustand ist CMD12
					   -- wirkungslos (ungueltig bzw. falsche CRC im SD-Modus).
					   when 0 => TX_Data_A <= x"FF" & CMD12 & x"FFFFFFFFFFFFFF";
					   when 1 => TX_Data_A <= x"FF" & x"FFFFFFFFFFFF" & x"FFFFFFFFFFFFFF"; -- init
									 do_not_enable_SS <= '1';
						when 2 => TX_Data_A <= x"FF" & CMD0 & x"FFFFFFFFFFFFFF"; --go idle state, resets SD card						
									 do_not_enable_SS <= '0';
						when 3 => TX_Data_A <= x"FF" & CMD8 & x"FFFFFFFFFFFFFF";	-- send interface condition
						when 4 => TX_Data_A <= x"FF" & CMD55 & x"FFFFFFFFFFFFFF";						
						when 5 => TX_Data_A <= x"FF" & ACMD41 & x"FFFFFFFFFFFFFF";		
						when 6 => TX_Data_A <= x"FF" & CMD58 & x"FFFFFFFFFFFFFF";		
						when 7 => TX_Data_A <= x"FF" & CMD18 & x"FFFFFFFFFFFFFF";	
									 do_not_disable_SS <= '1';
									 -- special: calculate sector on BallyFA SD
									 -- where to read rom dependign on dip switch
									 -- first rom starts at sector 660
									 -- we have 16KByte of data
									 -- which is 32 sectors 512Byte each
									 -- calculate startsector ( 32 sectors a 512 Byte) each
									 gamenumber := to_integer(unsigned(selection));									 
									 sectorcount := gamenumber * 32 + 660;									 									 
									 TX_Data_A(79 downto 64)  <= std_logic_vector(to_unsigned(sectorcount, 16));									 
						when 8 => TX_Data_A <= x"FF" & CMD12 & x"FFFFFFFFFFFFFF";	
									 do_not_disable_SS <= '0';	
						when others => TX_Data_A <= x"FF" & x"FFFFFFFFFFFF" & x"FFFFFFFFFFFFFF"; --  read
					end case;
					TX_Start_A <= '1'; -- set flag for sending byte		
					state_A <= wait_for_read;					
										
				when wait_for_read =>					
						if (TX_Done_A = '1') then -- Master sets TX_Done when TX is done ;-)
							TX_Start_A <= '0'; -- reset flag 		
								-- we assume R1 Response is at fix postion ( 1 Byte nCR, then R1)
								-- some cards have it one position later so lets try this also
								R1_response <= RX_Data_A( 47 downto 40);								
								R1_response_2 <= RX_Data_A( 39 downto 32);	--sometimes R1 response comes late							
								Echo_response <= RX_Data_A( 15 downto 8);								
							state_A <= continue;							
						end if;
										
				when continue =>		
					if (TX_Done_A = '0') then -- Master sets back TX_Done when ready again				
								cmd_count <= cmd_count +1;
								case cmd_count is
									when 2 => --check response of CMD0
										if (( R1_response /= x"01") and ( R1_response_2 /= x"01")) then
											if (attempts < 8) then
												cmd_count <= 0; --repeat (v054: ab CMD12, Takte mit CS high, CMD0)
												attempts <= attempts +1;
												state_A <= delay_and_repeat; 
											else											
												state_A <= error;
											end if;	
										else --success
											attempts <= 0;
											state_A <= send_read_request; -- next cmd to send																																						
										end if;																		
									when 3 => --check response of CMD8
										-- R7 = R1 + 4 Byte, Echo AA im letzten. R1 nach 1 oder 2 Byte NCR
										-- (wie bei CMD0). Nach einem Warmstart (Reset-Taste, Karte schon
										-- initialisiert) kommt die Antwort bei manchen Karten 1 Byte spaeter;
										-- bis v050 brach das hier ab (Blinkcode 4). Jetzt beide Positionen
										-- und bei Fehlschlag bis zu 8x ab CMD0 wiederholen.
										-- v053: NCR darf bis 8 Byte sein - zusaetzlich die erste Antwort
										-- im ganzen Fenster suchen (r7_ok), Echo nur pruefen, soweit im Fenster.
										if ( R1_response = x"01" and Echo_response = x"AA") or
										   ( R1_response_2 = x"01" and RX_Data_A(7 downto 0) = x"AA") or
										   r7_ok(RX_Data_A) then
											cmd8_tries <= 0;
											state_A <= send_read_request; -- next cmd to send
										elsif (cmd8_tries < 8) then
											cmd8_tries <= cmd8_tries +1;
											cmd_count <= 0; -- repeat from CMD12/CMD0 (v054)
											state_A <= delay_and_repeat;
										else
											state_A <= error;
										end if;
									when 5 => -- count 5 is SD card init--repeat CMD55 & ACMD41 until card is READY
										if (( R1_response /= x"00") and ( R1_response_2 /= x"00")) then 										
											if (attempts < 5000) then
												cmd_count <= 4; --repeat go back to CMD55
												attempts <= attempts +1;
												state_A <= delay_and_repeat; 
											else
												state_A <= error;
											end if;	
										else --success
											attempts <= 0;
											state_A <= send_read_request; -- next cmd to send																																						
										end if;													
									when 7 => --last command send, we now read data
										cmd_count <= 0;	
										TX_Data_R <= x"FF";
										active_master <= "10";		
										address_sd_card <= (others => '0');			
										byte_count <= 0;							
										state_A <= initiate_read_sector;
									when 8 => -- we send CMD12 to stop read sector, all done
										wr_rom <= '0';		
										-- start cpu
										cpu_reset_l <= '1';						
										state_A <= all_done;																
										
									when others =>
										state_A <= send_read_request; -- next cmd to send																											
								end case;
					end if;
					
				when delay_and_repeat =>	
					counter <= counter +1;					
					if ( counter = 5000000 ) then --100ms 
						state_A <= send_read_request;
						counter <= 0;						
					end if;					
					
		--------------------------------------
		-- second master  --------------------
		-- read 16 sectors -------------------
		--------------------------------------
		
				when initiate_read_sector =>				
							TX_Start_R <= '1'; -- set flag for sending byte												
							state_A <= wait_for_begin_of_data;					
							
				when wait_for_begin_of_data =>
							if (TX_Done_R = '1') then -- Master sets TX_Done when TX is done ;-)
							TX_Start_R <= '0'; -- reset flag 		
							state_A <= check_for_FE_flag;
						end if;
						
				when check_for_FE_flag =>							
						if (TX_Done_R = '0') then -- Master sets back TX_Done when ready again						
						data_sd_card <= RX_Data_R;
						   if RX_Data_R = x"FE" then							
								state_A <= sector_read; --flag found, next byte is data
							else
								state_A <= initiate_read_sector; --next byte to read and check
							end if;							
						end if;
	
				when sector_read =>
							TX_Start_R <= '1'; -- set flag for sending byte		
							wr_rom <= '0'; --stop writing to ram/rom
							state_A <= wait_for_byte_read;					
							
				when wait_for_byte_read =>
							if (TX_Done_R = '1') then -- Master sets TX_Done when TX is done ;-)							
									TX_Start_R <= '0'; -- reset flag 	
									-- count byte
									byte_count <= byte_count +1;		
									--assign data
									data_sd_card <= RX_Data_R;											
									state_A <= check_sector_byte;
							end if;
							
				when check_sector_byte =>							
						if (TX_Done_R = '0') then -- Master sets back TX_Done when ready again
							-- where are we in sector read?
							if byte_count <= 512 then	-- in sector read
								wr_rom <= '1';	-- write to ram/rom with current data & address
								state_A <= inc_addr_and_unset_wr;		-- write to ram/rom
							elsif byte_count <= 514 then -- in crc read
								-- no write for crc
								state_A <= sector_read;		-- next byte						
							else -- sector read finished
								byte_count <= 0;
								state_A <= initiate_read_sector;		-- next sector					
							end if;																											
						end if;
						
				when inc_addr_and_unset_wr =>		
								wr_rom <= '0';	
								-- prepare address for next
								address_sd_card <= std_LOGIC_VECTOR(unsigned(address_sd_card) +1);
								-- finished?																
								if unsigned(address_sd_card) = X"3FFF" then -- "11111111111111" then 										
										state_A <= stop_read;		--just read last byte
								else
										state_A <= sector_read;		-- next byte						
								end if;
												
				when stop_read =>																
								cmd_count <= 8; --we use cmd counter from init routine								
								active_master <= "01"; --because sending of a command								
								state_A <= send_read_request; 
								
				when all_done =>		
					SDcard_error <= '1'; --active low
					
				when error =>		-- blinkcode according to cmd
					if err_lat = '0' then
						err_lat <= '1';
						err_cmd <= std_logic_vector(to_unsigned(cmd_count, 4));
						err_rx  <= RX_Data_A(55 downto 0);
					end if;
					counter <= counter +1;				
					if ( counter = 50000000 ) then --1s							
						SDcard_error <= '0'; --active low
					end if;						
					if ( counter = 100000000 ) then --1s							
						SDcard_error <= '1'; --active low
						cmd_count <= cmd_count -1;
						counter <= 0;
					end if;	
					if (cmd_count = 0) then
						state_A <= stop;
					end if;
														
					
				when stop =>						
					if ( counter = 50000000 ) then --1s							
						SDcard_error <= '0'; --active low
					else
						counter <= counter +1;						
					end if;						

					
				end case;	
			end if; --rst 
		end if; --rising edge					
	end process;
				
					
    end Behavioral;				
