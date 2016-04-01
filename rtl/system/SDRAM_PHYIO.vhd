-- DDR2 memory interface
-- Andrew Read, March 2016
-- This project is based on a working DDR2 interface very kindly donated by a friend

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_textio.all;

-- DQS not used in READ Cycles.
-- ODT disabled.


entity SDRAM_PHYIO is 
port (
	CLK   : in  std_logic;   							-- 100MHz clock
	CLK_90 : in std_logic;								-- 100MHz clock 90 degree phase shift
    nrst : in  std_logic;								-- active low reset
     
	-- user interface
	wrrd_ba_add : in std_logic_vector(2 downto 0);		-- bank address
	wrrd_ras_add : in std_logic_vector(12 downto 0);	-- row address
	wrrd_cas_add : in std_logic_vector(8 downto 0);		-- column address
	wr_we : in std_logic;								-- set high to request write
	wr_add : in std_logic_vector(25 downto 0);			-- NOT USED
	wr_dat : in std_logic_vector(31 downto 0);			-- write data
	wr_ack : out std_logic;								-- hold write request until ack goes high
	rd_re : in std_logic;								-- set high to request read
	rd_add : in std_logic_vector(25 downto 0);			-- NOT USED
	rd_dat : out std_logic_vector(31 downto 0);			-- read data
	rd_ack : out std_logic;   							-- hold read request until ack goes high
	rd_valid : out std_logic;							-- register read rd_dat when ack goes high
	refresh : in std_logic;								-- cycle refresh high to allow periodic SDRAM self-refrech

	-- DDR2 SDRAM interface (MT47H64M16HR-25E)
	SDRAM_A : out std_logic_vector(13 downto 0);		-- address inputs: should be (12 downto 0), no A[13] in 16x 
	SDRAM_BA : out std_logic_vector(2 downto 0);		-- bank address
	SDRAM_CKE      : out std_logic;						-- clock enable
	SDRAM_CK       : out std_logic;						-- positive clock (differential pair)
	SDRAM_nCK	   : out std_logic;						-- negative clock (differential pair)
	SDRAM_DQ       : inout std_logic_vector(15 downto 0);  	-- bidirectional data input / output  
	SDRAM_DQS	   : out std_logic_vector(1 downto 0);		-- bidirectional data strobe (input not currently used)
	--SDRAM_nDQS	   : out std_logic_vector(1 downto 0);	-- differential DQS not currently used
	SDRAM_DM       : out std_logic_vector(1 downto 0);		-- data mask for write data
	SDRAM_nCAS     : out std_logic;						-- CAS# command input
	SDRAM_nCS      : out std_logic;						-- chip select
	SDRAM_nRAS     : out std_logic;						-- RAS# command input
	SDRAM_nWE      : out std_logic);					-- WE#  command input

end SDRAM_PHYIO;

-- MT47H64M16HR-25E addressing
-- Banks	 			    8 
-- Rows	 			    8,192 
-- Columns			    1,024 
-- Addresses	   67,108,864 
-- Word size	 	       16 
-- Bits	 		1,073,741,824 
-- Gbits			  1.00000

architecture Struct of SDRAM_PHYIO is      


component OBUFDS is
-- differential output buffer
-- ug471 p. 45
-- instantiate using libraries code
  generic(
      CAPACITANCE : string     := "DONT_CARE";
      IOSTANDARD  : string     := "DEFAULT";	-- DIFF_HSTL_II_18 is the default for differential I/O's
      SLEW        : string     := "SLOW"
    );

  port(
    O  : out std_ulogic;		-- positive signal matches input
    OB : out std_ulogic;		-- negative signal

    I : in std_ulogic
    );
end component;

component ODDR
-- DDR output buffer
-- DDR is impletmented directly from the clock without manual multiplexing
-- ug471 p. 127
-- instantiate using libraries code
  generic(
	DDR_CLK_EDGE : string := "OPPOSITE_EDGE";  	-- in OPPOSITE_EDGE mode D2 is captured on a falling clock edge and
												-- 	presented at output on the next rising clock edge
												-- in SAME_EDGE mode D2 is captured on a rising clock edge and 
												-- 	presented at output one full clock cycle later on the rising endge
												-- in both cases D1 is captured on a rising clock edge and presented 
												-- 	at output on the next falling clock edge 
												
	INIT         : bit    := '0';				-- initial value of Q
	SRTYPE       : string := "SYNC"				-- set/reset with respect to clock
      );
  port(
      Q           : out std_ulogic;				-- output
      C           : in  std_ulogic;				-- clock input port
      CE          : in  std_ulogic;				-- clock enable port (low disables the output port on Q)
      D1          : in  std_ulogic;				-- inputs
      D2          : in  std_ulogic;
      R           : in  std_ulogic := 'L';		-- synchronous reset
      S           : in  std_ulogic := 'L'		-- synchronous set
    );
end component; 

component IDDR
-- DDR input buffer
-- ug471 p110
  generic(
      DDR_CLK_EDGE : string := "OPPOSITE_EDGE";
											-- in OPPOSITE_EDGE mode Q1 is updated on a falling edge and Q2 on a rising edge
											-- in SAME_EDGE mode, Q1 and Q2 are both updated on a rising edge, however there
											--	is a latency of 1 clock cycle separating a data pair
											-- in SAME_EDGE_PIPELINE mode, Q1 and Q2 are both updated on a rising edge
											--	there is no latency between signal pairs but an additional latency at the start
      INIT_Q1      : bit    := '0';
      INIT_Q2      : bit    := '0';
      IS_C_INVERTED : bit := '0';
      IS_D_INVERTED : bit := '0';
      SRTYPE       : string := "SYNC"
      );
  port(
      Q1          : out std_ulogic;			-- outputs
      Q2          : out std_ulogic;
      C           : in  std_ulogic;			-- clock input port
      CE          : in  std_ulogic;			-- clock enable port
      D           : in  std_ulogic;			-- input
      R           : in  std_ulogic := 'L';	-- reset
      S           : in  std_ulogic := 'L'	-- set
    );
end component;

type fsm_type is (init, 
			init_precharge, init_precharge_done,
			init_mode_2, init_mode_2_done,
			init_mode_3, init_mode_3_done,
			init_mode_1, init_mode_1_done,
			init_mode_0, init_mode_0_done, 
			init_precharge_0, init_precharge_0_done,    
			init_refresh_0, init_refresh_0_done,
			init_refresh_1, init_refresh_1_done,
			init_mode_0_2, init_mode_0_2_done, 
			init_mode_1_2, init_mode_1_2_done,
			init_mode_1_3, init_mode_1_3_done,   
			write_0, write_1, write_2, write_3, write_4, write_5,
			idle, 
			bank_0, bank_done,  
			active,
			precharge_0, precharge_done,
			read_0, read_1, read_2, read_3, read_done,
			refresh_0);
			
-- DDR2 SRAM commands (1Gb_DDD2.pdf, p70) 						CKE CS# RAS# CAS# WE#
constant CMD_LOAD_MODE			: std_logic_vector(4 downto 0) := "10000";
constant CMD_REFRESH			: std_logic_vector(4 downto 0) := "10001";
constant CMD_ENTER_SELF_REFRESH : std_logic_vector(4 downto 0) := "00001";
constant CMD_EXIT_SELF_REFRESH	: std_logic_vector(4 downto 0) := "10111";
constant CMD_PRECHARGE			: std_logic_vector(4 downto 0) := "10010";
constant CMD_ACTIVATE			: std_logic_vector(4 downto 0) := "10011";
constant CMD_WRITE 				: std_logic_vector(4 downto 0) := "10100";  -- also WRITE with auto precharge
constant CMD_READ				: std_logic_vector(4 downto 0) := "10101";	-- also READ with auto precharge
constant CMD_NOP				: std_logic_vector(4 downto 0) := "10111";
constant CMD_DESELECT			: std_logic_vector(4 downto 0) := "11111";
constant CMD_ENTER_POWER_DOWN	: std_logic_vector(4 downto 0) := "00111";
constant CMD_EXIT_POWER_DOWN	: std_logic_vector(4 downto 0) := "10111";

signal SDRAM_dq_out_tmp : std_logic_vector(15 downto 0);
signal SDRAM_dq_out : std_logic_vector(31 downto 0);
signal SDRAM_dq_in_tmp : std_logic_vector(15 downto 0);
signal SDRAM_dq_in : std_logic_vector(31 downto 0);
signal SDRAM_dqs_out_tmp : std_logic_vector(1 downto 0);
signal state : fsm_type; 
signal counter : integer range 0 to 1000;
signal dq_write : std_logic;
signal dqs_write : std_logic; 
signal dm_write : std_logic_vector(3 downto 0);
signal bank_row_active : std_logic_vector(13 downto 0);
signal bank_active : std_logic_vector(2 downto 0);
signal clk_int_xor_delay : std_logic;
signal clk_int_rise : std_logic := '0';   
signal clk_int_fall : std_logic := '0';
signal clk_int_xor : std_logic;
signal command : std_logic_vector(4 downto 0);
signal rd_dat_r : std_logic_vector(31 downto 0);
signal dqs_out_ce : std_logic;	

begin    

-----------------------------------------------------
--	PHY: SDRAM commands
-----------------------------------------------------

SDRAM_CKE	<= COMMAND(4);
SDRAM_nCS	<= COMMAND(3);
SDRAM_nRAS	<= COMMAND(2);
SDRAM_nCAS	<= COMMAND(1);
SDRAM_nWE	<= COMMAND(0);

-----------------------------------------------------
--	PHY: SDRAM_CLK
-----------------------------------------------------

-- Workaround to forward a clock via an OBUF or OBUFDS

-- Xilinx recommends an alternative plan for clock forwarding (ug471, p 128)
--	use an output DDR, set D1 <= '1' and D2 <= '0'
--	clock and DDR data will be propogated with identical delays

-- CK/CK# should be delayed 1/4 cycle with respect to commands and data

--clk_rise_reset : process (CLK, nrst)
--begin
--if (nrst = '0') then
--   clk_int_rise <= '0';
--else if (CLK'event and CLK='1') then
--   clk_int_rise <= NOT clk_int_rise;
--end if;
--end if;
--end process;
--
--clk_fall_reset : process (CLK, nrst)
--begin
--if (nrst = '0') then
--   clk_int_fall <= '0';
--else if (CLK'event and CLK='0') then
--   clk_int_fall <= clk_int_rise; 
--end if;
--end if;
--end process;
--
--clk_int_xor <= clk_int_fall XOR clk_int_rise; 
--clk_int_xor_delay <= clk_int_xor after 300 ps;       
--
-- DDR clock
OBUFDSi : OBUFDS 
  port map (
    O  => SDRAM_CK,
    OB => SDRAM_nCK,

    I => clk_90
    );

--CK : ODDR 
--  generic map(
--      DDR_CLK_EDGE => "SAME_EDGE"
--      )
--  port map(
--      Q           => SDRAM_CK,
--      C           => CLK_90,
--      CE          => '1',
--      D1          => '0',
--      D2          => '1',
--      R           => '0',
--      S           => '0'
--    );
	
	
--nCK : ODDR 
--  generic map(
--      DDR_CLK_EDGE => "SAME_EDGE"
--      )
--  port map(
--      Q           => SDRAM_nCK,
--      C           => CLK_90,
--      CE          => '1',
--      D1          => '1',
--      D2          => '0',
--      R           => '0',
--      S           => '0'
--    );
-----------------------------------------------------
--	PHY: SDRAM_DQ
-----------------------------------------------------
							  
dq_oddr : for i in 0 to 15 generate				  
dq_oddrn : ODDR 
  generic map(
      DDR_CLK_EDGE => "SAME_EDGE",	-- override generic
									--	data signals for DRR output are updated on the same edge
      INIT         => '0',
      SRTYPE       => "SYNC"
      )
  port map(
      Q           => SDRAM_dq_out_tmp(i),
      C           => CLK,
      CE          => '1',
      D1          => SDRAM_dq_out(i),		-- D1 is the signal transmitted on the falling edge
      D2          => SDRAM_dq_out(i + 16),  -- multiplex a 32 bit signal into a 16x DDR interface
      R           => '0',
      S           => '0'
    );
end generate;         

SDRAM_dq_in_tmp <= SDRAM_DQ after 1 ps; -- reflect board timing "after 1 ps" is ignored by synthesis

dq_iddr : for i in 0 to 15 generate
dq_iddrn : IDDR
  generic map(
      DDR_CLK_EDGE => "OPPOSITE_EDGE",	-- possibly replace with SAME_EDGE_PIPELINE and add one cycle of latency
      INIT_Q1      => '0',
      INIT_Q2      => '0',
      IS_C_INVERTED => '0',
      IS_D_INVERTED => '0',
      SRTYPE       => "SYNC"
      )
  port map(
      Q1          => SDRAM_dq_in(i + 16),	-- multiplex a x16 DDR interface in to a 32 bit signal
      Q2          => SDRAM_dq_in(i),		-- Q2 is the signal received on the falling edge
      C           => CLK,
      CE          => '1',
      D           => SDRAM_dq_in_tmp(i),
      R           => '0',
      S           => '0'
    );
end generate;

SDRAM_DQ <= SDRAM_dq_out_tmp when (dq_write = '1') OR					-- maybe can do this with set?
							      (dqs_write = '1') else "ZZZZZZZZZZZZZZZZ";   
						
-----------------------------------------------------
--	PHY: SDRAM_DQS (single ended)
-----------------------------------------------------
			 
dqs_oddr : for i in 0 to 1 generate				  
dqs_oddrn : ODDR 
  generic map(
      DDR_CLK_EDGE => "SAME_EDGE",
      INIT         => '0',
      SRTYPE       => "SYNC"
      )
  port map(
      Q           => SDRAM_dqs_out_tmp(i),
      C           => CLK_90,
      CE          => dqs_out_ce,
      D1          => '1', -- '1'
      D2          => '0', -- '0'
      R           => '0',
      S           => '0'
    );
end generate;  
--SDRAM_DQS <= SDRAM_dqs_out_tmp;

SDRAM_DQS <= SDRAM_dqs_out_tmp when (state = write_1 OR state = write_2 OR state = write_3 OR state = write_4 OR state = write_5) else "ZZ";   

--with state select
--	 SDRAM_DQS <= SDRAM_dqs_out_tmp when write_2,
--				SDRAM_dqs_out_tmp when write_3,
--				SDRAM_dqs_out_tmp when write_4,
--				"00" when write_5,					-- postamble
--				"ZZ" when others;

with state select
	dqs_out_ce <= '0' when write_1, 		-- preamble
				'0'	when write_5,			-- postamble
				'1' when others;
						
								 
--SDRAM_nDQS <= "ZZ"; -- removed completely

-----------------------------------------------------
--	PHY: SDRAM_DM
-----------------------------------------------------
							  
dm_oddr : for i in 0 to 1 generate				  
dm_oddrn : ODDR 
  generic map(
      DDR_CLK_EDGE => "SAME_EDGE",
      INIT         => '0',
      SRTYPE       => "SYNC"
      )
  port map(
      Q           => SDRAM_DM(i),		-- data mask.  Assert high to mask
      C           => CLK,				
      CE          => '1',
      D1          => NOT dm_write(i),
      D2          => NOT dm_write(i + 2),
      R           => '0',
      S           => '0'
    );
end generate;    

-----------------------------------------------------
--	Glue Logic:
-----------------------------------------------------

SDRAM_dq_out <= wr_dat;
rd_dat <= rd_dat_r;

process
begin
	wait until rising_edge(CLK);
	rd_dat_r <= SDRAM_dq_in;			-- register data in
end process;

-----------------------------------------------------
--	FSM
-----------------------------------------------------
gen_fsm : process (CLK, nrst)
variable bank : integer range 0 to 3;
begin
if (nrst='0') then
	state <= init;
	SDRAM_A <= conv_std_logic_vector(0, SDRAM_A'length);
	SDRAM_BA <= "000";
	COMMAND <= CMD_ENTER_POWER_DOWN;
	--SDRAM_nCAS <= '1';
	--SDRAM_nCS <= '1';
	--SDRAM_nRAS <= '1';
	--SDRAM_nWE <= '1';
	--SDRAM_CKE <= '0';
	dq_write <= '0';
	dqs_write <= '0';
	dm_write <= "0000";
	bank_active <= conv_std_logic_vector(0, bank_active'length);
	bank_row_active <= conv_std_logic_vector(0, bank_row_active'length); 
	wr_ack <= '0';         
	rd_valid <= '0';
	rd_ack <= '0';
    counter <= 0;
    bank_active <= "000";
elsif (CLK'event and CLK='1') then
case (state) is
-----------------------------------------------------
--	set nCS
-----------------------------------------------------
when init =>	
			if (counter = 10) then
				state <= init_precharge;
				counter <= 0;
			else
				counter <= counter + 1;
			end if;
			COMMAND <= CMD_EXIT_POWER_DOWN;
			--SDRAM_nCS <= '0';  
			--SDRAM_CKE <= '1';
			wr_ack <= '0';
-----------------------------------------------------
--	initial precharge all command (1Gb_DDR2 p87)
-----------------------------------------------------
when init_precharge => 
			SDRAM_BA <= "000";	
			SDRAM_A <= "00010000000000";		-- A10 high indicates an all bank precharge command
			--SDRAM_nCAS <= '1';					-- PRECHARGE command (1GB_DDR2 p70)
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '0';
			COMMAND <= CMD_PRECHARGE;
			state <= init_precharge_done;
when init_precharge_done =>						-- NOP command	
			SDRAM_BA <= "000";	
			SDRAM_A <= "00010000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 4) then				-- tRPA (precharge all) timing requirement = 12.5ns (p36)
				state <= init_mode_2;			-- follow prescribed init sequence (1Gb_DDR2 p87)
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	
-----------------------------------------------------
--	init_mode 2 Register
-----------------------------------------------------   
when init_mode_2 =>
			SDRAM_BA <= "010";					-- Extended Mode Register (EMR) 2
			SDRAM_A <= "00000000000000";		-- SDRAM_A is used to set the mode register
												-- E7 '0' = 1x refresh rate (0C to 85C)
												-- all other bits must be zero (1GB_DDR p85)
			--SDRAM_nCAS <= '0';					-- LOAD MODE command (1GB_DDR p70)
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '0';
			COMMAND <= CMD_LOAD_MODE;
			state <= init_mode_2_done;
when init_mode_2_done =>						-- NOP command	
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 2) then				-- tMRD timing requirement is 2 clock cycles (p37)
				state <= init_mode_3;			-- follow prescribed init sequence (1Gb_DDR2 p87)
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	  
-----------------------------------------------------
--	init_mode 3 Register
-----------------------------------------------------   
when init_mode_3 =>
			SDRAM_BA <= "011";					-- Extended Mode Register (EMR) 3
			SDRAM_A <= "00000000000000";		-- See 1GB_DDR2 p86  for register definition		
			--SDRAM_nCAS <= '0';
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '0';
			COMMAND <= CMD_LOAD_MODE;
			state <= init_mode_3_done;
when init_mode_3_done =>			
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 2) then				-- tMRD timing requirement is 2 clock cycles (p37)
				state <= init_mode_1;
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	         
-----------------------------------------------------
--	init_mode 1 Register
-----------------------------------------------------   
when init_mode_1 =>								
			SDRAM_BA <= "001";					-- Extended Mode Register (EMR) 1	
			SDRAM_A <= "00010000000100";		-- DQS# disable	/ RTT = 75 Ohms
--					   "00010001000100"			-- DQS# disable / RTT = 50 Ohms 		
												-- See 1GB_DDR p81 for register definition 										
			--SDRAM_nCAS <= '0';	
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '0';
			COMMAND <= CMD_LOAD_MODE;
			state <= init_mode_1_done;
when init_mode_1_done =>			
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 2) then				-- tMRD timing requirement is 2 clock cycles (p37)
				state <= init_mode_0;			-- follow prescribed init sequence (1Gb_DDR2 p87)
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	
-----------------------------------------------------
--	init_mode 0 Register
-----------------------------------------------------   
when init_mode_0 =>
			SDRAM_BA <= "000";					-- Mode register
			SDRAM_A <= "00010100110010";		-- Burst length = 4 / CAS latency = 3 / Reset DLL / Write recovery = 3
												-- Write recovery time = 15ns
			--SDRAM_nCAS <= '0';
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '0';
			COMMAND <= CMD_LOAD_MODE;
			state <= init_mode_0_done;
when init_mode_0_done =>			
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 250) then				-- 200 cycles of clock until READ/WRITE are required following DLL reset
				state <= init_precharge_0;		-- follow prescribed init sequence (1Gb_DDR2 p87)
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	    
-----------------------------------------------------
--	Precharge 0
-----------------------------------------------------   
when init_precharge_0 =>						-- another init precharge command
			SDRAM_BA <= "000";	
 			SDRAM_A <= "00010000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '0';
			COMMAND <= CMD_PRECHARGE;
			state <= init_precharge_0_done;
when init_precharge_0_done =>			
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 2) then				-- tRPA (precharge all) timing requirement = 12.5ns (p36)
				state <= init_refresh_0;		-- follow prescribed init sequence (1Gb_DDR2 p87)
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	  
-----------------------------------------------------
--	refresh 0
-----------------------------------------------------   
when init_refresh_0 =>
			SDRAM_BA <= "000";					-- REFRESH command
 			SDRAM_A <= "00010000000000";		-- A10 actually has no effect
			--SDRAM_nCAS <= '0';
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '1';
			COMMAND <= CMD_REFRESH;
			state <= init_refresh_0_done;
when init_refresh_0_done =>			
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 26) then				-- tRFC (REFRESH interval) = 127.5ns (p37)
				state <= init_refresh_1;		-- follow prescribed init sequence (1Gb_DDR2 p87)
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	  
-----------------------------------------------------
--	refresh 1
-----------------------------------------------------   
when init_refresh_1 =>							-- two or more refresh commands are required (note 10, p89)
			SDRAM_BA <= "000";	
 			SDRAM_A <= "00010000000000";
			--SDRAM_nCAS <= '0';
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '1';
			COMMAND <= CMD_REFRESH;
			state <= init_refresh_1_done;
when init_refresh_1_done =>			
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 26) then
				state <= init_mode_0_2;			-- follow prescribed init sequence (1Gb_DDR2 p87)
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	
-----------------------------------------------------
--	init_mode 0 Register 2nd
-----------------------------------------------------   
when init_mode_0_2 =>
			SDRAM_BA <= "000";					-- Mode register
 			SDRAM_A <= "00010000110010";		--same settings EXCEPT do not reset the DLL
--				   (cf."00010100110010" first time)
			--SDRAM_nCAS <= '0';
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '0';
			COMMAND <= CMD_LOAD_MODE;
			state <= init_mode_0_2_done;
when init_mode_0_2_done =>			
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 1) then				-- tMRD timing requirement is 2 clock cycles (p37)
				state <= init_mode_1_2;			-- follow prescribed init sequence (1Gb_DDR2 p87)
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	          
-----------------------------------------------------
--	init_mode 1 Register 2nd
-----------------------------------------------------   
when init_mode_1_2 =>
			SDRAM_BA <= "001";					-- EMR 1
 			SDRAM_A <= "00011110000100";		-- Default OCD / DQS# disable / RTT = 75 Ohm
--					   "00011111000100"			-- Default OCD / DQS# disable / RTT = 50 Ohm
												-- See 1GB_DDR p81 for register definition 
			--SDRAM_nCAS <= '0';
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '0';
			COMMAND <= CMD_LOAD_MODE;
			state <= init_mode_1_2_done;
when init_mode_1_2_done =>			
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 1) then				-- tMRD timing requirement is 2 clock cycles (p37)
				state <= init_mode_1_3;			-- follow prescribed init sequence (1Gb_DDR2 p87)
				counter <= 0;
			else
				counter <= counter + 1;
			end if;	
-----------------------------------------------------
--	init_mode 1 Register 3rd
-----------------------------------------------------   
when init_mode_1_3 =>
			SDRAM_BA <= "001";					-- EMR 1
 			SDRAM_A <= "00010000000100";		-- Exit OCD / DQS# disable / RTT = 75 Ohm
--                     "00010001000100"			-- Exit OCD / DQS# disable / RTT = 75 Ohm
			--SDRAM_nCAS <= '0';
			--SDRAM_nRAS <= '0';
			--SDRAM_nWE <= '0';
			COMMAND <= CMD_LOAD_MODE;
			state <= init_mode_1_3_done;
when init_mode_1_3_done =>			
			SDRAM_BA <= "000";	
			SDRAM_A <= "00000000000000";
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			if (counter = 20) then				-- tMRD timing requirement is 2 clock cycles (p37)
				if (wr_we = '1') then
					state <= idle; --write_0;
					counter <= 0;
				end if;
			else
				counter <= counter + 1;
			end if;	             
-----------------------------------------------------
--	IDLE
-----------------------------------------------------
when idle =>	
			--SDRAM_nCAS <= '1';					-- NOP
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			wr_ack <= '0';
			rd_valid <= '0';
			dqs_write <= '0';
			dq_write <= '0';
			dm_write <= "0000";              
			if (wr_we = '1') OR
		 	   (rd_re = '1') then  				-- Should there be a way to get from idle to recharge directly?
		 	   	SDRAM_BA <= wrrd_ba_add;		-- Bank address in BA[2:0] (8) - 1Gb_DDR2 p2
 				SDRAM_A <= '0' & wrrd_ras_add;  -- Row address in A[12:0] (8K) - 1Gb_DDR2 p2
				--SDRAM_nCAS <= '1';				-- BANK ACTIVATE command (p90)
				--SDRAM_nRAS <= '0';
				--SDRAM_nWE <= '1';  
				COMMAND <= CMD_ACTIVATE;
				state <= bank_0;
				bank_active <= wrrd_ba_add; 			-- save the activating bank (to detect a change)
				bank_row_active <= '0' & wrrd_ras_add;  -- save the activating row (to detect a change)
														-- ACTIVE to PRECHARGE delay tRAS = 70us MAX (p36) : has this been considered?
		 	end if;
-----------------------------------------------------
--	Bank Active
-----------------------------------------------------
when bank_0 => 									-- first state after activating a bank
			--SDRAM_nRAS <= '1';					-- NOP command (p71)
			COMMAND <= CMD_NOP;
	   		state <= bank_done;
-----------------------------------------------------
--	Bank Active Done
-----------------------------------------------------
when bank_done =>
			COMMAND <= CMD_NOP;
			state <= active;  					-- tRCD (ROW to COLUMN delay) = 12.5 ns
-----------------------------------------------------
--	Active
-----------------------------------------------------
when active =>									-- Command to Bank n, 1Gb_DDDR2 p71
			--SDRAM_nCAS <= '1';					-- NOP command
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			wr_ack <= '0';
			rd_valid <= '0';
			dqs_write <= '0';
			dq_write <= '0';
			dm_write <= "0000";
			-----------------------------------------------------
			--	Bank handling
			-----------------------------------------------------
			if (	(wr_we = '1') OR
			   		(rd_re = '1') ) 							   		AND
			   	(	(NOT (bank_active = wrrd_ba_add)) OR							-- changing bank
			   		(NOT (bank_row_active(12 downto 0) = wrrd_ras_add)) ) then		-- changing row
				SDRAM_A <= "00000000000000";
				--SDRAM_nRAS <= '0';				-- PRECHARGE (deactivate row)
				--SDRAM_nCAS <= '1';
				--SDRAM_nWE <= '0';         
				COMMAND <= CMD_PRECHARGE;
				state <= precharge_0;
			-----------------------------------------------------
			--	CAS handling
			-----------------------------------------------------     
			elsif (wr_we = '1') OR
			   	  (rd_re = '1') then
				SDRAM_A <= "0000" & wrrd_cas_add(8 downto 0) & '0';
												-- Column address in A[9:0] (1K) - 1Gb_DDR2 p2
				-- MT47H64M16HR-25E is WORD addressable. wrrd_cas_add is a LONGWORD address
	   			--SDRAM_nCAS <= '0';
				--SDRAM_nRAS <= '1';
				if (wr_we = '1') then
					--SDRAM_nWE <= '0';
					COMMAND <= CMD_WRITE;
					state <= write_0;
				else
					--SDRAM_nWE <= '1';			
					state <= read_0; 
					COMMAND <= CMD_READ;
					rd_ack <= '1';
				end if;
			-----------------------------------------------------
			--	Refresh handling
			-----------------------------------------------------  
			elsif (refresh = '1') then
				SDRAM_A <= "00000000000000";	-- PRECHARGE
				--SDRAM_nRAS <= '0';
				--SDRAM_nCAS <= '1';
				--SDRAM_nWE <= '0';     
				COMMAND <= CMD_PRECHARGE;
				state <= precharge_0;				
		 	end if;
-----------------------------------------------------
--	Precharge All Delay
-----------------------------------------------------
when precharge_0 => 				-- tRPA (precharge all) timing requirement = 12.5ns (p36)
			--SDRAM_nRAS <= '1';		-- NOP
			--SDRAM_nWE <= '1';  
			COMMAND <= CMD_NOP;
	   		state <= precharge_done; 
	   		counter <= 0;
-----------------------------------------------------
--	Precharge All Done
-----------------------------------------------------
when precharge_done =>
			if (refresh = '1') then
				if (counter = 20) then
					--SDRAM_nCAS <= '0';
					--SDRAM_nRAS <= '0';
					COMMAND <= CMD_REFRESH;
					state <= refresh_0;
				else
					COMMAND <= CMD_NOP;
					counter <= counter + 1;
				end if;					
			else
				state <= idle;  
			end if;
-----------------------------------------------------
--	Refresh All Delay
-----------------------------------------------------
when refresh_0 => 										
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';	
			COMMAND <= CMD_NOP;
			if (refresh = '0') then
				state <= idle;  
			end if;
-----------------------------------------------------
--	Write 0
-----------------------------------------------------
when write_0 => 										-- SDRAM registers WRITE command
			--SDRAM_nCAS <= '1';							-- NOP
			--SDRAM_nWE <= '1';
			COMMAND <= CMD_NOP;
			dm_write <= "1100";							-- dm MASK is inverted before output, so '1' here means write enable
														-- dm needs to appear coincident with the data
														-- dm is output through the DDR interface
			state <= write_1;
-----------------------------------------------------
--	Write 1
-----------------------------------------------------
when write_1 =>
			dq_write <= '1';							-- enable DQ strobe (1Gb_DDR2 p84)
			dm_write <= "0011";
			COMMAND <= CMD_NOP;
			state <= write_2;
-----------------------------------------------------
--	Write 2
-----------------------------------------------------
when write_2 =>
			dm_write <= "0000";   						-- 4n prefectch with x16 requires a second longword 
			COMMAND <= CMD_NOP;
			state <= write_3;							--  however the last 32 bits are not presented by the controller
-----------------------------------------------------
--	Write 3
-----------------------------------------------------
when write_3 =>
			COMMAND <= CMD_NOP;
			state <= write_4;
-----------------------------------------------------
--	Write 4
-----------------------------------------------------
when write_4 =>
			wr_ack <= '1';
			dq_write <= '0';							-- disable DQ strobe
			COMMAND <= CMD_NOP;
			state <= write_5;
-----------------------------------------------------
--	Write 4
-----------------------------------------------------
when write_5 =>      
			wr_ack <= '0';
			COMMAND <= CMD_NOP;
			state <= active;
-----------------------------------------------------
--	Read 0
-----------------------------------------------------
when read_0 =>											-- SDRAM registers READ command
			SDRAM_BA <= wrrd_ba_add;
			SDRAM_A <= "00000000000000";				-- NOP (active bank commands, p 71)
			--SDRAM_nCAS <= '1';
			--SDRAM_nRAS <= '1';
			--SDRAM_nWE <= '1';
			--SDRAM_CKE <= '1';
			COMMAND <= CMD_NOP;
			state <= read_1;
			rd_ack <= '0';
-----------------------------------------------------
--	Read 1
-----------------------------------------------------
when read_1 => 											-- 1st cycle of CAS latency
			COMMAND <= CMD_NOP;
			state <= read_2; 
-----------------------------------------------------
--	Read 2
-----------------------------------------------------
when read_2 =>											-- 2nd cycle of CAS latency
			COMMAND <= CMD_NOP;
			state <= read_3; 
-----------------------------------------------------
--	Read 3
-----------------------------------------------------
when read_3 => 											-- 3rd cycle of CAS latency
			COMMAND <= CMD_NOP;
			state <= read_done;
-----------------------------------------------------
--	Read Done [CAS latency is set to 3]
-----------------------------------------------------
when read_done => 										-- IDDR buffer has registered signal at the output
			COMMAND <= CMD_NOP;
			rd_valid <= '1';							-- "rd_dat <= SDRAM_dq_in" is made as a concurrent statement and rd_dat is not registered
 			state <= active;							-- keep ROW open and return to ACTIVE state (next access likely on same row)							
														-- 4n prefetch with x16 yields a 64 bit word, the latter 32 bits currently ignored
			
-----------------------------------------------------
--	Others
-----------------------------------------------------
when others => 
end case;
end if;
end process;


end Struct;
