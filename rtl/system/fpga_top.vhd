-- DDR2 memory interface
-- Andrew Read, March 2016
-- This project is based on a working DDR2 interface very kindly donated by a friend

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
USE IEEE.std_logic_arith.all;

entity fpga_top is port(
	clk : in std_logic;
	nrst : in std_logic;

	led : out std_logic_vector(1 downto 0);
	sevenseg : out STD_LOGIC_VECTOR (6 downto 0);
	anode : out STD_LOGIC_VECTOR (7 downto 0);	

	SDRAM_A : out std_logic_vector(13 downto 0);
	SDRAM_BA : out std_logic_vector(2 downto 0);
	SDRAM_CKE      : out std_logic;
	SDRAM_CK       : out std_logic;
	SDRAM_nCK	   : out std_logic;
	SDRAM_DQ       : inout std_logic_vector(15 downto 0);  
	SDRAM_DQS	   : inout std_logic_vector(1 downto 0);
	--SDRAM_nDQS	   : inout std_logic_vector(1 downto 0);
	SDRAM_UDQM    : out std_logic;
	SDRAM_LDQM    : out std_logic;
	SDRAM_nCAS     : out std_logic;
	SDRAM_nCS      : out std_logic;
	SDRAM_nRAS     : out std_logic;
	SDRAM_nWE      : out std_logic;
	SDRAM_ODT      : out std_logic);
end fpga_top;

architecture RTL of fpga_top is

component ByteHEXdisplay is
    Port ( 
	clk		 	: in  STD_LOGIC;
	ssData		: in  STD_LOGIC_VECTOR (31 downto 0);
	sevenseg 	: out  STD_LOGIC_VECTOR (6 downto 0);
	anode 		: out  STD_LOGIC_VECTOR (7 downto 0)
           );
end component;

component SDRAM_CTRL is 
port (
	CLK   : in  std_logic;
	CLK_130 : in std_logic;
    nrst : in  std_logic; 

	wrrd_ba_add : in std_logic_vector(2 downto 0);
	wrrd_ras_add : in std_logic_vector(12 downto 0);
	wrrd_cas_add : in std_logic_vector(8 downto 0);
	
	wr_we : in std_logic_vector(3 downto 0);
	wr_add : in std_logic_vector(25 downto 0);
	wr_dat : in std_logic_vector(31 downto 0);
	wr_ack : out std_logic;

	rd_re : in std_logic;
	rd_add : in std_logic_vector(25 downto 0);
	rd_dat : out std_logic_vector(31 downto 0);
	rd_ack : out std_logic;
	rd_valid : out std_logic;

	SDRAM_A : out std_logic_vector(13 downto 0);
	SDRAM_BA : out std_logic_vector(2 downto 0);
	SDRAM_CKE      : out std_logic;
	SDRAM_CK       : out std_logic;
	SDRAM_nCK	   : out std_logic;
	SDRAM_DQ       : inout std_logic_vector(15 downto 0); 
	SDRAM_DQS	   : inout std_logic_vector(1 downto 0);
	--SDRAM_nDQS   : inout std_logic_vector(1 downto 0);
	SDRAM_DM       : out std_logic_vector(1 downto 0);
	SDRAM_nCAS     : out std_logic;
	SDRAM_nCS      : out std_logic;
	SDRAM_nRAS     : out std_logic;
	SDRAM_nWE      : out std_logic);

end component;

component clk_manager
  Port ( 
    clk_in1 : in STD_LOGIC;
    clk_out1 : out STD_LOGIC;
    clk_out2 : out STD_LOGIC   
  ); 
end component;  

type fsm_type is (init,
			write_0_0, write_0_1, 
			write_1_0, write_1_1, write_1_2, write_1_3,
			write_2_0, write_2_1, write_2_2, write_2_3, write_2_4, write_2_5,
			write_3_0, write_3_1, 
			write_4_0, write_4_1,
			read_0_0, read_0_1, read_0_2,
			read_1_0, read_1_1, read_1_2, read_1_3, read_1_4, read_1_5,
			read_2_0, read_2_1, read_2_2, read_2_3, read_2_4, read_2_5, read_2_6, read_2_7, read_2_8, read_2_9, read_2_10, read_2_11,
			read_3_0, read_3_1, read_3_2,
			read_4_0, read_4_1, read_4_2,
			refreshWait);

signal wrrd_ba_add : std_logic_vector(2 downto 0);
signal wrrd_ras_add : std_logic_vector(12 downto 0);
signal wrrd_cas_add : std_logic_vector(8 downto 0);

signal wr_we : std_logic_vector(3 downto 0);
signal wr_add : std_logic_vector(25 downto 0);
signal wr_dat : std_logic_vector(31 downto 0);
signal wr_ack : std_logic;

signal rd_re : std_logic;
signal rd_add : std_logic_vector(25 downto 0);
signal rd_dat, rd_dat_reg, rd_dat_reg0 : std_logic_vector(31 downto 0);
signal rd_ack : std_logic;
signal rd_valid : std_logic;   
signal bug_found : std_logic;

signal SDRAM_DM : std_logic_vector(1 downto 0);
signal clk_int : std_logic;
signal clk_int_130 : std_logic;
signal nrst_reg : std_logic;
signal state : fsm_type; 
signal counter : integer range 0 to 32768;

signal time_cnt1 : integer range 0 to 65535;
signal time_cnt2 : integer range 0 to 4095;
signal led_toggle : std_logic;

signal ssdata : std_logic_vector(31 downto 0);
                     
begin

SDRAM_ODT <= '0';              

-----------------------------------------------------
--	clk
-----------------------------------------------------
CLOCKMANAGER: clk_manager


  port map
   (-- Clock in ports
    clk_in1 => clk,
    clk_out1 => clk_int,
    clk_out2 => clk_int_130);
    

----------------------------------------------
-- nrst_reg
----------------------------------------------

nrst_reg_proc : process (clk_int) begin
if (clk_int = '1' and clk_int'event) then
   nrst_reg <= '0';
   if (nrst = '1') then
      nrst_reg <= '1';
   end if;
end if;
end process;

-----------------------------------------------------
--	For relaxing the timing: rd_dat gets registered
-----------------------------------------------------
rd_dat_reg_gen : process (clk_int, nrst_reg)
begin
if (nrst_reg='0') then
	rd_dat_reg <= conv_std_logic_vector(0, rd_dat_reg'length);  
--	rd_dat_reg0 <= conv_std_logic_vector(0, rd_dat_reg0'length);
elsif (clk_int'event and clk_int='1') then	
	rd_dat_reg <= rd_dat_reg0;                  					-- one cycle delay for some reason                 
end if;
end process;

	-- rd_dat is already registered by PHYIO
	rd_dat_reg0 <= rd_dat;  

-----------------------------------------------------
--	FSM
-----------------------------------------------------
gen_fsm : process (clk_int, nrst_reg)
variable counter_bus : std_logic_vector(15 downto 0);
begin
if (nrst_reg='0') then
	wrrd_ba_add <= conv_std_logic_vector(0, wrrd_ba_add'length);
	wrrd_ras_add <= conv_std_logic_vector(0, wrrd_ras_add'length);
	wrrd_cas_add <= conv_std_logic_vector(0, wrrd_cas_add'length);
	led <= "00";
	state <= init;
	wr_add <= conv_std_logic_vector(0, wr_add'length);
	wr_dat <= conv_std_logic_vector(0, wr_dat'length);
	wr_we <= "0000";
	rd_re <= '0';
	rd_add <= conv_std_logic_vector(0, rd_add'length);    
	counter <= 0;            
	bug_found <= '0'; 
	time_cnt1 <= 0;
	time_cnt2 <= 0;
	led_toggle <= '0';
	ssdata <= x"01234567";
elsif (clk_int'event and clk_int='1') then
case (state) is
-----------------------------------------------------
--	mode
-----------------------------------------------------
when init =>	state <= write_0_0;
-----------------------------------------------------
--	write bank: 0 page: 0 add: 0 data: 5555AAAA
-----------------------------------------------------
when write_0_0 => 	
				wr_we <= "1111";
				wr_dat <= x"7755AACC";  
				wrrd_cas_add <= conv_std_logic_vector(0, wrrd_cas_add'length);
				state <= write_0_1;
when write_0_1 => 
				if (wr_ack = '1') then
						wr_we <= "0000";
						state <= read_0_0;
						rd_re <= '1';
		    	end if;
-----------------------------------------------------
--	read  bank: 0 page: 0 add: 0 data: 0000FFF0
-----------------------------------------------------
when read_0_0 => 
				if (rd_ack = '1') then
					rd_re <= '0';
			 		state <= read_0_1;
			 	end if;
when read_0_1 => 	
				if (rd_valid = '1') then 
					state <= read_0_2;
				end if;
when read_0_2 =>  
				--state <= write_4_0;
 				--counter <= 32768;
               	--------------------
               state <= write_1_0;
               ssdata <= rd_dat_reg;
				if NOT (rd_dat_reg(31 downto 0) = x"7755AACC") then
				--if NOT (rd_dat_reg(31 downto 0) = x"AAAA5555") then
	               	bug_found <= '1';
				end if;
-----------------------------------------------------
--	write bank: 0 page: 0 add: 0 data: 0000FFFF
-----------------------------------------------------
when write_1_0 => 	
				wr_we <= "1111";
				wrrd_cas_add <= conv_std_logic_vector(0, wrrd_cas_add'length);
				wr_dat <= x"0000FFFF";
				state <= write_1_1;
when write_1_1 => 
				if (wr_ack = '1') then
					wr_we <= "0000";
					state <= write_1_2;
		    	end if;        
-----------------------------------------------------
--	write bank: 0 page: 0 add: 1 data: 0001FFFE
-----------------------------------------------------
when write_1_2 => 	
				wr_we <= "1111";
				wrrd_cas_add <= conv_std_logic_vector(1, wrrd_cas_add'length);
				wr_dat <= x"0001FFFE";
				state <= write_1_3;
when write_1_3 => 
				if (wr_ack = '1') then
					wr_we <= "0000";
					state <= read_1_0;
					rd_re <= '1';
			   		wrrd_cas_add <= conv_std_logic_vector(0, wrrd_cas_add'length);
		    	end if;
-----------------------------------------------------
--	read  bank: 0 page: 0 add: 0 data: 0000FFFF
-----------------------------------------------------
when read_1_0 => 
				if (rd_ack = '1') then
					rd_re <= '0';
			 		state <= read_1_1;
			 	end if;
when read_1_1 => 	
				if (rd_valid = '1') then      
					state <= read_1_2;
				end if;
when read_1_2 =>
				state <= read_1_3;
				rd_re <= '1';
				wrrd_cas_add <= conv_std_logic_vector(1, wrrd_cas_add'length);
				if NOT (rd_dat_reg(31 downto 0) = x"0000FFFF") then
                	bug_found <= '1';
			 	end if;
-----------------------------------------------------
--	read  bank: 0 page: 0 add: 1 data: 0001FFFE
-----------------------------------------------------
when read_1_3 => 
				if (rd_ack = '1') then
					rd_re <= '0';
			 		state <= read_1_4;
			 	end if;
when read_1_4 => 	
				if (rd_valid = '1') then
					state <= read_1_5;
				end if;
when read_1_5 => 
               	state <= write_2_0;
				if NOT (rd_dat_reg(31 downto 0) = x"0001FFFE") then
                	bug_found <= '1';
			 	end if;
-----------------------------------------------------
--	write bank: 0 page: 1 add: 1 data: 0011FFEE
-----------------------------------------------------
when write_2_0 => 	
				wr_we <= "1111";
				wrrd_cas_add <= conv_std_logic_vector(1, wrrd_cas_add'length);
				wrrd_ras_add <= "0" & x"001";
				wr_dat <= x"0011FFEE";
				state <= write_2_1;
when write_2_1 => 
				if (wr_ack = '1') then
					wr_we <= "0000";
					state <= write_2_2;
		    	end if;        
-----------------------------------------------------
--	write bank: 0 page: 2 add: 1 data: 0021FFDE
-----------------------------------------------------
when write_2_2 => 	
				wr_we <= "1111";
				wrrd_ras_add <= "0" & x"002";
				wr_dat <= x"0021FFDE";
				state <= write_2_3;
when write_2_3 => 
				if (wr_ack = '1') then
					wr_we <= "0000";
					state <= write_2_4;
		    	end if;
-----------------------------------------------------
--	write bank: 1 page: 2 add: 1 data: 0121FEDE
-----------------------------------------------------
when write_2_4 => 	
				wr_we <= "1111";
				wrrd_ba_add <= "001";
				wr_dat <= x"0121FEDE";
				state <= write_2_5;
when write_2_5 => 
				if (wr_ack = '1') then
					wr_we <= "0000";
					state <= read_2_0;
					rd_re <= '1';
					wrrd_ba_add <= "000";
					wrrd_ras_add <= "0" & x"000";  
		    	end if;
-----------------------------------------------------
--	read  bank: 0 page: 0 add: 1 data: 0001FFFE
-----------------------------------------------------
when read_2_0 => 
				if (rd_ack = '1') then
					rd_re <= '0';
			 		state <= read_2_1;
			 	end if;
when read_2_1 => 	
				if (rd_valid = '1') then
					state <= read_2_2;
				end if;
when read_2_2 => 
				state <= read_2_3;
				rd_re <= '1';
				wrrd_ras_add <= "0" & x"001";
				if NOT (rd_dat_reg(31 downto 0) = x"0001FFFE") then
	               	bug_found <= '1';
				end if;
-----------------------------------------------------
--	read  bank: 0 page: 1 add: 1 data: 0011FFEE
-----------------------------------------------------
when read_2_3 => 
				if (rd_ack = '1') then
					rd_re <= '0';
			 		state <= read_2_4;
			 	end if;
when read_2_4 => 	
				if (rd_valid = '1') then
					state <= read_2_5;
				end if;
when read_2_5 => 
				state <= read_2_6;
				rd_re <= '1';
				wrrd_ras_add <= "0" & x"002";
				if NOT (rd_dat_reg(31 downto 0) = x"0011FFEE") then
	              	bug_found <= '1';
				end if;
-----------------------------------------------------
--	read  bank: 0 page: 2 add: 1 data: 0021FFDE
-----------------------------------------------------
when read_2_6 => 
				if (rd_ack = '1') then
					rd_re <= '0';
			 		state <= read_2_7;
			 	end if;
when read_2_7 => 	
				if (rd_valid = '1') then
					state <= read_2_8;
				end if;
when read_2_8 =>
               	state <= read_2_9;
				rd_re <= '1';
				wrrd_ba_add <= "001";
				wrrd_ras_add <= "0" & x"002";
				if NOT (rd_dat_reg(31 downto 0) = x"0021FFDE") then
                	bug_found <= '1';
			 	end if;
-----------------------------------------------------
--	read  bank: 1 page: 2 add: 1 data: 0121FEDE
-----------------------------------------------------
when read_2_9 => 
				if (rd_ack = '1') then
					rd_re <= '0';
			 		state <= read_2_10;
			 	end if;
when read_2_10 => 	
				if (rd_valid = '1') then
					state <= read_2_11;
				end if;
when read_2_11 => 
               	state <= write_3_0;
				if NOT (rd_dat_reg(31 downto 0) = x"0121FEDE") then
	               	bug_found <= '1';
			 	end if;
				counter <= 256;
-----------------------------------------------------
--	write bank: 3 page: 3 add: 0..255 data: 0330<cas>
-----------------------------------------------------
when write_3_0 => 	
				wr_we <= "1111";
				wrrd_ba_add <= "011";
				wrrd_ras_add <= "0" & x"003";
				wrrd_cas_add <= conv_std_logic_vector(counter, wrrd_cas_add'length);
				wr_dat <= x"0330" & conv_std_logic_vector(counter, 16);
				state <= write_3_1;
when write_3_1 => 
				if (wr_ack = '1') then           
					if (counter = 0) then
						wr_we <= "0000";
						state <= read_3_0;  
						rd_re <= '1';
						counter <= 256;
				   		wrrd_cas_add <= conv_std_logic_vector(256, wrrd_cas_add'length);
					else            
						counter <= counter / 2;
						wrrd_cas_add <= conv_std_logic_vector(counter / 2, wrrd_cas_add'length);
						wr_dat <= x"0330" & conv_std_logic_vector(counter / 2, 16);
					end if;
		    	end if;        
-----------------------------------------------------
--	read  bank: 0 page: 0 add: 0 data: 0000FFFF
-----------------------------------------------------
when read_3_0 => 
				if (rd_ack = '1') then
					rd_re <= '0';
			 		state <= read_3_1;
			 	end if;
when read_3_1 => 	
				if (rd_valid = '1') then      
					state <= read_3_2;
				end if;
when read_3_2 =>
 				if (counter = 0) then 
 					state <= write_4_0;
 					counter <= 32768;
 				else 
					rd_re <= '1';
					state <= read_3_0;
					counter <= counter / 2;
					wrrd_cas_add <= conv_std_logic_vector(counter / 2, wrrd_cas_add'length);
 				end if;
				if (NOT (rd_dat_reg(31 downto 16) = x"0330")) OR
				   (NOT (rd_dat_reg(15 downto 9) = "0000000")) OR
				   (NOT (rd_dat_reg(8 downto 0) = conv_std_logic_vector(counter, wrrd_cas_add'length))) then
                	bug_found <= '1';
			 	end if;
-----------------------------------------------------
--	write bank: 3 page: 3 add: 0..255 data: 0330<cas>
-----------------------------------------------------
when write_4_0 => 	
				wr_we <= "1111"; 
				counter_bus := conv_std_logic_vector(counter, counter_bus'length); 
				wrrd_ba_add <= counter_bus(15 downto 13);
				wrrd_ras_add <= counter_bus(12 downto 0);
				wrrd_cas_add <= conv_std_logic_vector(4, wrrd_cas_add'length);
				wr_dat <= conv_std_logic_vector(counter + time_cnt2, 32);
				state <= write_4_1;
when write_4_1 => 
				if (wr_ack = '1') then           
					if (counter = 0) then
						wr_we <= "0000";
						state <= read_4_0;  
						rd_re <= '1';
						counter <= 32768;
						counter_bus := conv_std_logic_vector(32768, counter_bus'length); 
						wrrd_ba_add <= counter_bus(15 downto 13);
						wrrd_ras_add <= counter_bus(12 downto 0);
					else            
						counter <= counter / 2;
						counter_bus := conv_std_logic_vector(counter / 2, counter_bus'length); 
						wrrd_ba_add <= counter_bus(15 downto 13);
						wrrd_ras_add <= counter_bus(12 downto 0);
						wr_dat <= conv_std_logic_vector((counter / 2) + time_cnt2, 32);
					end if;
		    	end if;     
-----------------------------------------------------
--	read  bank: 0 page: 0 add: 0 data: 0000FFFF
-----------------------------------------------------
when read_4_0 => 
				if (rd_ack = '1') then
					rd_re <= '0';
			 		state <= read_4_1;
			 	end if;
when read_4_1 => 	
				if (rd_valid = '1') then      
					state <= read_4_2;
				end if;
when read_4_2 =>
 				if (counter = 0) then 
 					state <= refreshWait;
 					counter <= 32768;
 				else 
					rd_re <= '1';
					state <= read_4_0;
					counter <= counter / 2;
					counter_bus := conv_std_logic_vector(counter / 2, counter_bus'length); 
					wrrd_ba_add <= counter_bus(15 downto 13);
					wrrd_ras_add <= counter_bus(12 downto 0);
 				end if;
				if (NOT (rd_dat_reg(31 downto 0) = conv_std_logic_vector(counter + time_cnt2, 32))) then
                	bug_found <= '1';
			 	end if;
-----------------------------------------------------
--	refreshWait
-----------------------------------------------------
when refreshWait => 	
				led(0) <= not led_toggle;
				if (bug_found = '0') then
					led(1) <= '1';
					if (time_cnt1 = 4095) then
						time_cnt1 <= 0;
						if (time_cnt2 = 4095) then 
							state <= read_3_0;
							rd_re <= '1';
							counter <= 256;
							wrrd_ba_add <= "011";
							wrrd_ras_add <= "0" & x"003";
				  			wrrd_cas_add <= conv_std_logic_vector(256, wrrd_cas_add'length);
				   			time_cnt2 <= 0;       
							led_toggle <= not led_toggle;
						else      
							state <= write_4_0;
							time_cnt2 <= time_cnt2 + 1;
						end if;      
					else
						state <= write_4_0;
						time_cnt1 <= time_cnt1 + 1;
					end if;
				else
					led(1) <= '0';    
		  			if (time_cnt1 = 65535) then
						time_cnt1 <= 0;
						if (time_cnt2 = 511) then
							time_cnt2 <= 0;       
							led_toggle <= not led_toggle;
						else
							time_cnt2 <= time_cnt2 + 1;
						end if;      
					else
						time_cnt1 <= time_cnt1 + 1;
					end if;
				end if;
when others => 
end case;                  
end if;
end process;


SDRAM_UDQM <= SDRAM_DM(1);
SDRAM_LDQM <= SDRAM_DM(0);

-----------------------------------------------------
--	SDRAM_CTRL
-----------------------------------------------------
SDRAM_CTRLi : SDRAM_CTRL 
port map (
	CLK   => clk_int,
	CLK_130 => clk_int_130,
    nrst => nrst_reg,  

	wrrd_ba_add => wrrd_ba_add,
	wrrd_ras_add => wrrd_ras_add,
	wrrd_cas_add => wrrd_cas_add,
	
	wr_we => wr_we,
	wr_add => wr_add,
	wr_dat => wr_dat,
	wr_ack => wr_ack,
	rd_re => rd_re,
	rd_add => rd_add,
	rd_dat => rd_dat,
	rd_ack => rd_ack,  
	rd_valid => rd_valid,

	SDRAM_A 		=> SDRAM_A,
	SDRAM_BA 		=> SDRAM_BA,
	SDRAM_CKE      	=> SDRAM_CKE,
	SDRAM_CK        => SDRAM_CK,
	SDRAM_nCK	    => SDRAM_nCK,
	SDRAM_DQ       	=> SDRAM_DQ,
	SDRAM_DQS	    => SDRAM_DQS,
	--SDRAM_nDQS	    => SDRAM_nDQS,
	SDRAM_DM    	=> SDRAM_DM,
	SDRAM_nCAS     	=> SDRAM_nCAS,
	SDRAM_nCS      	=> SDRAM_nCS,
	SDRAM_nRAS     	=> SDRAM_nRAS,
	SDRAM_nWE      	=> SDRAM_nWE);

hex : ByteHEXdisplay
Port map ( 
	clk	=> clk_int,
	ssData	=> ssData,
	sevenseg => sevenseg,
	anode => anode
);


end RTL;
